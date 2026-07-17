import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/image_save_utils.dart';
import '../../core/utils/image_share_sanitizer.dart';
import '../../core/utils/inpaint_mask_utils.dart';
import '../../core/utils/nai_prompt_formatter.dart';
import '../../core/utils/nai_resolution_adapter.dart';
import '../../core/utils/pica_lanczos_resizer.dart';
import '../../core/utils/prompt_preset_resolution.dart';
import '../../data/services/image_metadata_service.dart';
import '../../data/datasources/remote/nai_image_generation_api_service.dart';
import '../../data/models/character/character_prompt.dart' as ui_character;
import '../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/image/image_params.dart';
import '../../data/models/image/image_stream_chunk.dart';
import '../../data/repositories/gallery_folder_repository.dart';
import '../../data/services/statistics_cache_service.dart';
import '../../data/services/alias_resolver_service.dart';
import 'character_prompt_provider.dart';
import 'fixed_tags_provider.dart';
import 'image_save_settings_provider.dart';
import 'local_gallery_provider.dart';
import 'prompt_config_provider.dart';
import 'quality_preset_provider.dart';
import 'queue_execution_provider.dart';
import 'subscription_provider.dart';
import 'uc_preset_provider.dart';

import 'generation/generation_models.dart';
import 'generation/generation_params_notifier.dart';
import 'generation/generation_settings_notifiers.dart';
import 'generation/image_workflow_controller.dart';

export 'generation/generation_models.dart';
export 'generation/generation_params_notifier.dart';
export 'generation/generation_auxiliary_notifiers.dart';
export 'generation/generation_settings_notifiers.dart';
export 'generation/reference_panel_notifier.dart';

// Simplified ImageGenerationProvider - new exports
export 'generation/image_generation_service.dart';
export 'generation/batch_generation_notifier.dart';
export 'generation/stream_generation_notifier.dart';
export 'generation/metadata_preload_notifier.dart';
export 'generation/retry_policy_notifier.dart';

part 'image_generation_provider.g.dart';

class _RememberedStreamPreview {
  const _RememberedStreamPreview({
    required this.bytes,
    required this.params,
    this.focusedPreviewPlacement,
  });

  final Uint8List bytes;
  final ImageParams params;
  final FocusedStreamPreviewPlacement? focusedPreviewPlacement;
}

/// 图像生成状态 Notifier
@Riverpod(keepAlive: true)
class ImageGenerationNotifier extends _$ImageGenerationNotifier {
  @override
  ImageGenerationState build() {
    return const ImageGenerationState();
  }

  void _retainSharePreparationCacheForCurrentHistory() {
    final retainedImageIds = <String>{
      for (final image in state.currentImages) image.id,
      for (final image in state.history) image.id,
    };
    unawaited(
      ShareImagePreparationService.instance.retainHistoryImageIds(
        retainedImageIds,
      ),
    );
  }

  /// 生成图像
  /// 重试延迟策略 (毫秒)
  static const List<int> _retryDelays = [1000, 2000, 4000];
  static const int _maxRetries = 3;
  static const int _randomSeedExclusiveUpperBound = 4294967295;

  bool _isCancelled = false;
  int _generationRunCounter = 0;
  int _activeGenerationRunId = 0;
  final Map<String, _RememberedStreamPreview> _streamPreviewsForSnapshots =
      <String, _RememberedStreamPreview>{};
  final Set<String> _failedStreamSnapshotKeys = <String>{};
  int? _activeRequestGenerationRunId;
  int? _activeRequestStartImage;
  int? _activeRequestEndImage;
  bool _activeRequestCancelRequested = false;

  int _startGenerationRun() {
    _isCancelled = false;
    _activeGenerationRunId = ++_generationRunCounter;
    _streamPreviewsForSnapshots.clear();
    _failedStreamSnapshotKeys.clear();
    _clearActiveRequest();
    return _activeGenerationRunId;
  }

  void _invalidateGenerationRun() {
    _isCancelled = true;
    _activeGenerationRunId = ++_generationRunCounter;
    _clearActiveRequest();
  }

  bool _isCurrentGenerationRun(int generationRunId) =>
      generationRunId == _activeGenerationRunId;

  bool _shouldAbortGenerationRun(int generationRunId) =>
      _isCancelled || !_isCurrentGenerationRun(generationRunId);

  ImageParams _materializeRandomSeed(ImageParams params) {
    if (params.seed != -1) return params;

    return params.copyWith(
      seed: Random().nextInt(_randomSeedExclusiveUpperBound),
    );
  }

  String _streamSnapshotKey(int generationRunId, int imageNumber) =>
      '$generationRunId:$imageNumber';

  void _beginActiveRequest({
    required int generationRunId,
    required int startImage,
    required int requestSize,
  }) {
    _activeRequestGenerationRunId = generationRunId;
    _activeRequestStartImage = startImage;
    _activeRequestEndImage = startImage + requestSize - 1;
    _activeRequestCancelRequested = false;
  }

  void _endActiveRequest({
    required int generationRunId,
    required int startImage,
  }) {
    if (_activeRequestGenerationRunId == generationRunId &&
        _activeRequestStartImage == startImage) {
      _clearActiveRequest();
    }
  }

  void _clearActiveRequest() {
    _activeRequestGenerationRunId = null;
    _activeRequestStartImage = null;
    _activeRequestEndImage = null;
    _activeRequestCancelRequested = false;
  }

  bool _isActiveRequestCancel(int generationRunId, int startImage) =>
      _activeRequestCancelRequested &&
      _activeRequestGenerationRunId == generationRunId &&
      _activeRequestStartImage == startImage;

  bool _activeRequestHasRemainingImages() {
    final endImage = _activeRequestEndImage;
    return endImage != null && state.totalImages > endImage;
  }

  void _rememberStreamPreview({
    required Uint8List bytes,
    required ImageParams params,
    required int generationRunId,
    required int imageNumber,
    FocusedStreamPreviewPlacement? focusedPreviewPlacement,
  }) {
    if (_shouldAbortGenerationRun(generationRunId) || bytes.isEmpty) {
      return;
    }

    _streamPreviewsForSnapshots[_streamSnapshotKey(
      generationRunId,
      imageNumber,
    )] = _RememberedStreamPreview(
      bytes: Uint8List.fromList(bytes),
      params: params,
      focusedPreviewPlacement: focusedPreviewPlacement?.copyWith(
        sourceImage: Uint8List.fromList(focusedPreviewPlacement.sourceImage),
        maskImage: focusedPreviewPlacement.maskImage == null
            ? null
            : Uint8List.fromList(focusedPreviewPlacement.maskImage!),
      ),
    );
  }

  void _clearRememberedStreamPreview({int? generationRunId, int? imageNumber}) {
    if (generationRunId != null && imageNumber != null) {
      _streamPreviewsForSnapshots.remove(
        _streamSnapshotKey(generationRunId, imageNumber),
      );
      return;
    }

    _streamPreviewsForSnapshots.clear();
  }

  bool _appendFailedStreamSnapshotToHistory({
    required int generationRunId,
    required int imageNumber,
  }) {
    if (!_isCurrentGenerationRun(generationRunId)) return false;

    final key = _streamSnapshotKey(generationRunId, imageNumber);
    final rememberedPreview = _streamPreviewsForSnapshots[key];
    if (rememberedPreview == null || rememberedPreview.bytes.isEmpty) {
      return false;
    }
    if (!_failedStreamSnapshotKeys.add(key)) return false;

    final previewBytes = _materializeRememberedStreamPreview(rememberedPreview);
    final params = rememberedPreview.params;
    final resolvedSize =
        _resolveImageSize(
          previewBytes,
          width: rememberedPreview.focusedPreviewPlacement == null
              ? params.width
              : null,
          height: rememberedPreview.focusedPreviewPlacement == null
              ? params.height
              : null,
        ) ??
        (params.width, params.height);
    final snapshot = GeneratedImage.create(
      previewBytes,
      width: resolvedSize.$1,
      height: resolvedSize.$2,
      kind: GeneratedImageKind.failedStreamSnapshot,
      metadata: _metadataFromParams(
        params,
        outputWidth: resolvedSize.$1,
        outputHeight: resolvedSize.$2,
      ),
    );

    state = state.copyWith(
      history: [snapshot, ...state.history].take(50).toList(),
      clearStreamPreview: true,
    );
    _retainSharePreparationCacheForCurrentHistory();
    _clearRememberedStreamPreview(
      generationRunId: generationRunId,
      imageNumber: imageNumber,
    );
    return true;
  }

  Uint8List _materializeRememberedStreamPreview(
    _RememberedStreamPreview rememberedPreview,
  ) {
    final placement = rememberedPreview.focusedPreviewPlacement;
    if (placement == null || !placement.isValid) {
      return rememberedPreview.bytes;
    }

    final materialized = _compositeFocusedStreamPreview(
      previewBytes: rememberedPreview.bytes,
      focusedPreviewPlacement: placement,
    );
    return materialized ?? rememberedPreview.bytes;
  }

  Uint8List? _compositeFocusedStreamPreview({
    required Uint8List previewBytes,
    required FocusedStreamPreviewPlacement focusedPreviewPlacement,
  }) {
    final source = img.decodeImage(focusedPreviewPlacement.sourceImage);
    final preview = img.decodeImage(previewBytes);
    final mask = focusedPreviewPlacement.maskImage == null
        ? null
        : img.decodeImage(focusedPreviewPlacement.maskImage!);
    if (source == null || preview == null) {
      return null;
    }

    final dstX = (focusedPreviewPlacement.xPercent * source.width)
        .round()
        .clamp(0, max(0, source.width - 1))
        .toInt();
    final dstY = (focusedPreviewPlacement.yPercent * source.height)
        .round()
        .clamp(0, max(0, source.height - 1))
        .toInt();
    final dstW = (focusedPreviewPlacement.widthPercent * source.width)
        .round()
        .clamp(1, max(1, source.width - dstX))
        .toInt();
    final dstH = (focusedPreviewPlacement.heightPercent * source.height)
        .round()
        .clamp(1, max(1, source.height - dstY))
        .toInt();

    final img.Image resizedPreview;
    final img.Image? resizedMask;
    if (mask == null) {
      resizedPreview = PicaLanczosResizer.resizeImage(
        preview,
        width: dstW,
        height: dstH,
      );
      resizedMask = null;
    } else {
      final requestPreview = PicaLanczosResizer.resizeImage(
        preview,
        width: mask.width,
        height: mask.height,
      );
      final requestPatch = InpaintMaskUtils.applyCompositeMaskToGeneratedImage(
        requestPreview,
        mask,
      );
      resizedPreview = PicaLanczosResizer.resizeImage(
        requestPatch,
        width: dstW,
        height: dstH,
      );
      resizedMask = null;
    }
    final composed = img.Image.from(source, noAnimation: true);
    img.compositeImage(
      composed,
      resizedPreview,
      dstX: dstX,
      dstY: dstY,
      dstW: dstW,
      dstH: dstH,
      mask: resizedMask,
      blend: mask == null ? img.BlendMode.direct : img.BlendMode.alpha,
    );

    return Uint8List.fromList(img.encodePng(composed, level: 1));
  }

  bool _appendFailedStreamSnapshotsForCurrentSlots(int generationRunId) {
    var appended = false;
    final slots = state.streamPreviewSlots;
    if (slots.isNotEmpty) {
      for (final slot in slots.reversed) {
        appended =
            _appendFailedStreamSnapshotToHistory(
              generationRunId: generationRunId,
              imageNumber: slot.imageNumber,
            ) ||
            appended;
      }
      return appended;
    }

    if (state.currentImage > 0) {
      appended = _appendFailedStreamSnapshotToHistory(
        generationRunId: generationRunId,
        imageNumber: state.currentImage,
      );
    }
    return appended;
  }

  List<StreamPreviewSlot> _replaceStreamPreviewSlot(
    List<StreamPreviewSlot> slots,
    StreamPreviewSlot replacement,
  ) {
    var replaced = false;
    final updated = <StreamPreviewSlot>[
      for (final slot in slots)
        if (slot.imageNumber == replacement.imageNumber) replacement else slot,
    ];
    replaced = slots.any((slot) => slot.imageNumber == replacement.imageNumber);
    if (!replaced) updated.add(replacement);

    return updated..sort((a, b) => a.imageNumber.compareTo(b.imageNumber));
  }

  NaiImageMetadata _metadataFromParams(
    ImageParams params, {
    int? outputWidth,
    int? outputHeight,
  }) {
    assert(
      (outputWidth == null) == (outputHeight == null),
      'Output width and height must be provided together.',
    );
    final metadataParams = outputWidth != null && outputHeight != null
        ? params.copyWith(width: outputWidth, height: outputHeight)
        : params;
    final (charCaptions, charNegCaptions) = _buildCharacterCaptions(
      metadataParams,
    );
    final commentJson = ImageSaveUtils.buildCommentJson(
      params: metadataParams,
      actualSeed: metadataParams.seed,
      charCaptions: charCaptions,
      charNegCaptions: charNegCaptions,
      useCoords: metadataParams.useCoords,
    );
    final rawJson = jsonEncode(commentJson);
    return NaiImageMetadata.fromNaiComment({
      'Comment': rawJson,
      'Software': 'NovelAI',
      'Source': _modelSourceName(metadataParams.model),
    }, rawJson: rawJson);
  }

  (
    List<Map<String, dynamic>> charCaptions,
    List<Map<String, dynamic>> charNegCaptions,
  )
  _buildCharacterCaptions(ImageParams params) {
    final charCaptions = <Map<String, dynamic>>[];
    final charNegCaptions = <Map<String, dynamic>>[];

    for (final char in params.characters) {
      charCaptions.add({
        'char_caption': char.prompt,
        'centers': [
          {'x': 0.5, 'y': 0.5},
        ],
      });
      charNegCaptions.add({
        'char_caption': char.negativePrompt,
        'centers': [
          {'x': 0.5, 'y': 0.5},
        ],
      });
    }

    return (charCaptions, charNegCaptions);
  }

  String _modelSourceName(String model) {
    if (model.contains('diffusion-4-5')) {
      if (model.contains('curated')) {
        return 'NovelAI Diffusion V4.5 Curated';
      }
      return 'NovelAI Diffusion V4.5 Full';
    }
    if (model.contains('diffusion-4')) {
      if (model.contains('curated')) {
        return 'NovelAI Diffusion V4 Curated';
      }
      return 'NovelAI Diffusion V4 Full';
    }
    if (model.contains('furry') && model.contains('-3')) {
      return 'NovelAI Furry Diffusion V3';
    }
    if (model.contains('diffusion-3')) {
      return 'NovelAI Diffusion V3';
    }
    if (model.contains('diffusion-2')) {
      return 'NovelAI Diffusion V2';
    }
    if (model.contains('furry')) {
      return 'NovelAI Furry Diffusion';
    }
    return 'NovelAI';
  }

  Future<ImageParams> _prepareVibesForGeneration(ImageParams params) async {
    if (params.vibeReferencesV4.isEmpty) {
      return params;
    }

    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final encodedVibes = await notifier.ensureVibeReferencesEncoded(
      params.vibeReferencesV4,
      model: params.model,
      syncCurrentState: true,
    );

    if (identical(encodedVibes, params.vibeReferencesV4)) {
      return params;
    }

    return params.copyWith(vibeReferencesV4: encodedVibes);
  }

  PromptPresetResolution _resolvePromptPresets(ImageParams params) {
    final qualityState = ref.read(qualityPresetNotifierProvider);
    final qualityContent = ref
        .read(qualityPresetNotifierProvider.notifier)
        .getEffectiveContent(params.model);
    final ucState = ref.read(ucPresetNotifierProvider);
    final ucPresetContent = ref
        .read(ucPresetNotifierProvider.notifier)
        .getEffectiveContent(params.model);

    return resolvePromptPresetSettings(
      prompt: params.prompt,
      negativePrompt: params.negativePrompt,
      qualityMode: qualityState.mode,
      qualityContent: qualityContent,
      ucPresetType: ucState.presetType,
      ucPresetContent: ucPresetContent,
      useCustomUcPreset: ucState.isCustom,
    );
  }

  Future<void> generate(ImageParams params) async {
    final generationRunId = _startGenerationRun();

    // 获取抽卡模式设置
    final randomMode = ref.read(randomPromptModeProvider);

    // 检查队列执行状态 - 队列运行时不应用抽卡模式
    // 使用 try-catch 避免循环依赖错误（QueueExecutionNotifier 监听 ImageGenerationNotifier）
    bool isQueueExecuting = false;
    try {
      final queueExecutionState = ref.read(queueExecutionNotifierProvider);
      isQueueExecuting =
          queueExecutionState.isRunning || queueExecutionState.isReady;
    } catch (e) {
      // 循环依赖或 provider 未初始化时，默认不在队列执行中
      isQueueExecuting = false;
    }

    // 如果开启抽卡模式且不在队列执行中，先随机提示词再生成
    // 这样生成的图像和显示的提示词能对应上
    // 队列执行时跳过抽卡模式，使用队列任务的原始提示词
    ImageParams effectiveParams = params;
    if (randomMode && !isQueueExecuting) {
      final randomPrompt = await generateAndApplyRandomPrompt();
      if (_shouldAbortGenerationRun(generationRunId)) return;
      if (randomPrompt.isNotEmpty) {
        AppLogger.d(
          'Random prompt before generation: $randomPrompt',
          'RandomMode',
        );
        // 重新读取角色配置（已被 generateAndApplyRandomPrompt 更新）
        final characterConfig = ref.read(characterPromptNotifierProvider);
        final apiCharacters = _convertCharactersToApiFormat(characterConfig);
        effectiveParams = params.copyWith(
          prompt: randomPrompt,
          characters: apiCharacters,
          useCoords:
              apiCharacters.isNotEmpty && !characterConfig.globalAiChoice,
        );
      }
    }

    // 开始生成前清空当前图片
    state = state.copyWith(
      currentImages: [],
      status: GenerationStatus.generating,
      batchWidth: effectiveParams.width,
      batchHeight: effectiveParams.height,
    );

    // nSamples = 批次数量（请求次数）
    // batchSize = 每次请求生成的图片数量
    final batchCount = effectiveParams.nSamples;
    final batchSize = ref.read(imagesPerRequestProvider);
    final totalImages = batchCount * batchSize;

    // 解析别名（将 <词库名> 展开为实际内容）
    // 统一在此处解析所有提示词（主提示词、负向提示词）
    final aliasResolver = ref.read(aliasResolverServiceProvider.notifier);
    final promptWithAliases = aliasResolver.resolveAliases(
      effectiveParams.prompt,
    );
    final negativeWithAliases = aliasResolver.resolveAliases(
      effectiveParams.negativePrompt,
    );
    if (promptWithAliases != effectiveParams.prompt ||
        negativeWithAliases != effectiveParams.negativePrompt) {
      AppLogger.d('Resolved aliases in prompts', 'AliasResolver');
      effectiveParams = effectiveParams.copyWith(
        prompt: promptWithAliases,
        negativePrompt: negativeWithAliases,
      );
    }

    // 应用固定词到提示词
    final fixedTagsState = ref.read(fixedTagsNotifierProvider);
    final promptWithFixedTags = fixedTagsState.applyToPrompt(
      effectiveParams.prompt,
    );
    final negativePromptWithFixedTags = fixedTagsState.applyToNegativePrompt(
      effectiveParams.negativePrompt,
    );
    if (promptWithFixedTags != effectiveParams.prompt ||
        negativePromptWithFixedTags != effectiveParams.negativePrompt) {
      AppLogger.d(
        'Applied fixed tags: positive=${fixedTagsState.enabledCount}, negative=${fixedTagsState.negativeEnabledCount}',
        'FixedTags',
      );
      effectiveParams = effectiveParams.copyWith(
        prompt: promptWithFixedTags,
        negativePrompt: negativePromptWithFixedTags,
      );
    }

    final presetResolution = _resolvePromptPresets(effectiveParams);
    effectiveParams = effectiveParams.copyWith(
      prompt: presetResolution.prompt,
      negativePrompt: presetResolution.negativePrompt,
    );

    // 读取多角色提示词配置并转换为 API 格式
    final characterConfig = ref.read(characterPromptNotifierProvider);
    final apiCharacters = _convertCharactersToApiFormat(characterConfig);

    // NAI 官方预设保持为 API 开关；自定义预设展开成显式提示词，避免官方预设重复生效。
    final ImageParams baseParams = effectiveParams.copyWith(
      qualityToggle: presetResolution.qualityToggle,
      ucPreset: presetResolution.ucPreset,
      characters: apiCharacters,
      // 如果有角色且使用自定义位置，启用坐标模式
      useCoords: apiCharacters.isNotEmpty && !characterConfig.globalAiChoice,
    );
    final preparedParams = await _prepareVibesForGeneration(baseParams);
    if (_shouldAbortGenerationRun(generationRunId)) return;

    // 如果只生成 1 张，直接生成；随机种子在进入请求前实体化，便于失败快照保留真实 seed。
    if (batchCount == 1 && batchSize == 1) {
      await _generateSingle(
        _materializeRandomSeed(preparedParams),
        1,
        1,
        generationRunId,
      );
      // 注意：生成完成通知由 QueueExecutionNotifier 统一管理
      // 点数消耗由 AnlasBalanceWatcher 自动监听余额变化记录
      return;
    }

    // 多张图片：按批次循环请求
    state = state.copyWith(
      status: GenerationStatus.generating,
      progress: 0.0,
      errorMessage: null,
      currentImage: 1,
      totalImages: totalImages,
      currentImages: [],
      batchWidth: preparedParams.width,
      batchHeight: preparedParams.height,
    );

    final allImages = <GeneratedImage>[];
    final random = Random();
    int generatedImages = 0;
    Object? lastBatchError;
    DateTime? concurrencyDeadline;

    // 当前使用的参数（可能会被抽卡模式修改）
    ImageParams currentParams = preparedParams;

    for (int batch = 0; batch < batchCount; batch++) {
      if (_shouldAbortGenerationRun(generationRunId)) break;

      // 如果开启抽卡模式且不是第一批且不在队列执行中，先随机新提示词再生成
      // 第一批已在方法开头随机过了
      // 队列执行时跳过抽卡模式
      if (randomMode && batch > 0 && !isQueueExecuting) {
        final randomPrompt = await generateAndApplyRandomPrompt();
        if (_shouldAbortGenerationRun(generationRunId)) return;
        if (randomPrompt.isNotEmpty) {
          AppLogger.d(
            'Batch ${batch + 1}/$batchCount - Random before generation: $randomPrompt',
            'RandomMode',
          );
          // 重新读取角色配置并更新参数
          final newCharacterConfig = ref.read(characterPromptNotifierProvider);
          final newApiCharacters = _convertCharactersToApiFormat(
            newCharacterConfig,
          );
          currentParams = currentParams.copyWith(
            prompt: randomPrompt,
            characters: newApiCharacters,
            useCoords:
                newApiCharacters.isNotEmpty &&
                !newCharacterConfig.globalAiChoice,
          );
        }
      }

      // 更新当前进度
      state = state.copyWith(
        currentImage: generatedImages + 1,
        progress: generatedImages / totalImages,
      );

      // 每批使用不同的随机种子
      final batchParams = currentParams.copyWith(
        nSamples: batchSize,
        seed: random.nextInt(_randomSeedExclusiveUpperBound),
      );

      try {
        // 使用流式 API 生成，支持预览
        final imageBytes = await _generateBatchWithStream(
          batchParams,
          generatedImages + 1,
          totalImages,
          generationRunId,
        );
        if (_shouldAbortGenerationRun(generationRunId)) return;
        if (imageBytes.isNotEmpty) {
          // 将字节数据包装成带唯一ID的 GeneratedImage
          final generatedList = imageBytes
              .map(
                (b) => GeneratedImage.create(
                  b,
                  width: batchParams.width,
                  height: batchParams.height,
                ),
              )
              .toList();
          allImages.addAll(generatedList);
          generatedImages += imageBytes.length;
          // 立即更新显示和历史
          state = state.copyWith(
            currentImages: List.from(allImages),
            history: [...generatedList, ...state.history].take(50).toList(),
            clearStreamPreview: true,
          );
          _retainSharePreparationCacheForCurrentHistory();
        } else {
          generatedImages += batchSize; // 即使失败也要跳过，避免死循环
        }
      } catch (e) {
        if (_isCancelledError(e, generationRunId)) {
          if (_isCurrentGenerationRun(generationRunId)) {
            _appendFailedStreamSnapshotsForCurrentSlots(generationRunId);
            state = state.copyWith(
              status: GenerationStatus.cancelled,
              progress: 0.0,
              currentImage: 0,
              totalImages: 0,
              clearStreamPreview: true,
            );
          }
          // 点数消耗由 AnlasBalanceWatcher 自动监听余额变化记录
          return;
        }
        // 并发限制：等待 NAI 释放额度后重试当前批次（取消可随时中断）
        if (_isConcurrencyLimited(e)) {
          concurrencyDeadline ??= DateTime.now().add(_concurrencyRetryBudget);
          if (DateTime.now().isBefore(concurrencyDeadline)) {
            AppLogger.w(
              'NAI 并发限制(429)，${_concurrencyRetryInterval.inSeconds}s 后自动重试第 ${batch + 1} 批',
              'Generation',
            );
            await Future.delayed(_concurrencyRetryInterval);
            if (_shouldAbortGenerationRun(generationRunId)) return;
            batch--;
            continue;
          }
        }
        // 本批次失败，继续下一批
        _appendFailedStreamSnapshotsForCurrentSlots(generationRunId);
        lastBatchError = e;
        AppLogger.e('生成第 ${batch + 1} 批失败: $e');
        generatedImages += batchSize;
      }
    }

    if (!_isCurrentGenerationRun(generationRunId)) return;

    if (!_isCancelled && allImages.isEmpty) {
      state = state.copyWith(
        status: GenerationStatus.error,
        errorMessage:
            lastBatchError?.toString() ?? 'No images returned from generation',
        progress: 0.0,
        currentImage: 0,
        totalImages: 0,
        clearStreamPreview: true,
      );
      return;
    }

    // 完成（不再随机，保持图像和提示词对应）
    state = state.copyWith(
      status: _isCancelled
          ? GenerationStatus.cancelled
          : GenerationStatus.completed,
      currentImages: List.from(allImages),
      displayImages: List.from(allImages), // 确保中央区域显示所有生成的图片
      displayWidth: allImages.isEmpty
          ? preparedParams.width
          : allImages.first.width,
      displayHeight: allImages.isEmpty
          ? preparedParams.height
          : allImages.first.height,
      progress: 1.0,
      currentImage: 0,
      totalImages: 0,
    );

    // 生成完成后刷新 Anlas 余额
    // 点数消耗由 AnlasBalanceWatcher 自动监听余额变化记录
    await ref.read(subscriptionNotifierProvider.notifier).refreshBalance();
    if (_shouldAbortGenerationRun(generationRunId)) return;

    // 注意：生成完成通知由 QueueExecutionNotifier 统一管理
    // 以避免循环依赖（ImageGenerationNotifier ↔ QueueExecutionNotifier）

    // 自动保存：如果启用且生成成功，保存所有图像
    if (!_isCancelled && allImages.isNotEmpty) {
      await _autoSaveIfEnabled(allImages, preparedParams);
    }
  }

  /// 自动保存图像（如果启用）
  Future<void> _autoSaveIfEnabled(
    List<GeneratedImage> images,
    ImageParams params,
  ) async {
    final saveSettings = ref.read(imageSaveSettingsNotifierProvider);
    await _saveImagesToGallery(
      images,
      params,
      saveImages: saveSettings.autoSave,
    );
  }

  /// 将外部结果登记到历史记录，并可选地直接保存到本地图库
  ///
  /// [addToDisplay] 为 true 时，将图像插入当前结果和中央预览列表首位。
  /// [replaceCurrentDisplay] 为 true 时，将当前结果和中央预览替换为该图像，
  /// 既有图像仍保留在历史记录中。
  Future<String?> registerExternalImage(
    Uint8List imageBytes, {
    required ImageParams params,
    int? width,
    int? height,
    bool saveToLocal = false,
    String? saveDirectoryPath,
    bool syncToGalleryIndex = true,
    bool addToDisplay = false,
    bool replaceCurrentDisplay = false,
  }) async {
    assert(
      !addToDisplay || !replaceCurrentDisplay,
      'addToDisplay and replaceCurrentDisplay cannot both be true.',
    );

    final resolvedSize =
        _resolveImageSize(imageBytes, width: width, height: height) ??
        (params.width, params.height);

    final existingMetadata = await ImageMetadataService().getMetadataFromBytes(
      imageBytes,
    );
    final effectiveParams = params.copyWith(
      width: resolvedSize.$1,
      height: resolvedSize.$2,
    );
    final normalizedBytes = await ImageSaveUtils.rebuildImageBytesWithMetadata(
      imageBytes: imageBytes,
      params: effectiveParams,
      actualSeed: existingMetadata?.seed,
    );

    final generatedImage = GeneratedImage.create(
      normalizedBytes,
      width: resolvedSize.$1,
      height: resolvedSize.$2,
    );

    final shouldDisplay = addToDisplay || replaceCurrentDisplay;
    state = state.copyWith(
      currentImages: replaceCurrentDisplay
          ? [generatedImage]
          : addToDisplay
          ? [generatedImage, ...state.currentImages]
          : state.currentImages,
      history: [generatedImage, ...state.history].take(50).toList(),
      displayImages: replaceCurrentDisplay
          ? [generatedImage]
          : addToDisplay
          ? [generatedImage, ...state.displayImages]
          : state.displayImages,
      displayWidth: shouldDisplay ? resolvedSize.$1 : state.displayWidth,
      displayHeight: shouldDisplay ? resolvedSize.$2 : state.displayHeight,
    );
    _retainSharePreparationCacheForCurrentHistory();

    if (saveToLocal) {
      await _saveImagesToGallery(
        [generatedImage],
        effectiveParams,
        saveImages: true,
        saveDirectoryPath: saveDirectoryPath,
        syncToGalleryIndex: syncToGalleryIndex,
      );
      return _firstSavedPathForImage(generatedImage.id);
    }

    _preloadMetadataInBackground([generatedImage]);
    return null;
  }

  String? _firstSavedPathForImage(String id) {
    for (final image in state.history) {
      if (image.id == id && image.filePath != null) {
        return image.filePath;
      }
    }
    return null;
  }

  Future<void> _saveImagesToGallery(
    List<GeneratedImage> images,
    ImageParams params, {
    required bool saveImages,
    String? saveDirectoryPath,
    bool syncToGalleryIndex = true,
  }) async {
    if (!saveImages) return;

    try {
      final saveDirPath =
          saveDirectoryPath ??
          await GalleryFolderRepository.instance.getRootPath();
      if (saveDirPath == null) return;
      final saveDir = Directory(saveDirPath);
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // 使用已解析别名的角色提示词（来自 params.characters）
      final characterConfig = ref.read(characterPromptNotifierProvider);

      // 获取固定词信息
      final fixedTagsState = ref.read(fixedTagsNotifierProvider);
      final fixedPrefixTags = fixedTagsState.enabledPrefixes
          .sortedByOrder()
          .map((e) => e.weightedContent)
          .where((c) => c.isNotEmpty)
          .toList();
      final fixedSuffixTags = fixedTagsState.enabledSuffixes
          .sortedByOrder()
          .map((e) => e.weightedContent)
          .where((c) => c.isNotEmpty)
          .toList();
      final fixedNegativePrefixTags = fixedTagsState.negativeEnabledPrefixes
          .sortedByOrder()
          .map((e) => e.weightedContent)
          .where((c) => c.isNotEmpty)
          .toList();
      final fixedNegativeSuffixTags = fixedTagsState.negativeEnabledSuffixes
          .sortedByOrder()
          .map((e) => e.weightedContent)
          .where((c) => c.isNotEmpty)
          .toList();

      AppLogger.i(
        '[ImageGeneration] Fixed tags for save: positive=${fixedTagsState.enabledCount}, negative=${fixedTagsState.negativeEnabledCount}, prefix=$fixedPrefixTags, suffix=$fixedSuffixTags, negativePrefix=$fixedNegativePrefixTags, negativeSuffix=$fixedNegativeSuffixTags',
        'ImageGeneration',
      );

      // 构建 V4 多角色提示词结构（直接使用已解析的 params.characters）
      final charCaptions = <Map<String, dynamic>>[];
      final charNegCaptions = <Map<String, dynamic>>[];

      for (final char in params.characters) {
        charCaptions.add({
          'char_caption': char.prompt,
          'centers': [
            {'x': 0.5, 'y': 0.5},
          ],
        });
        charNegCaptions.add({
          'char_caption': char.negativePrompt,
          'centers': [
            {'x': 0.5, 'y': 0.5},
          ],
        });
      }

      int savedCount = 0;
      final savedFilePaths = <String>[];
      final savedImages = <GeneratedImage>[];

      for (final image in images) {
        try {
          final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
          final filePath = p.join(saveDirPath, fileName);

          if (ImageSaveUtils.hasEmbeddedNovelAiMetadata(image.bytes)) {
            await File(filePath).writeAsBytes(image.bytes);
            savedCount++;
            savedFilePaths.add(filePath);

            final updatedImage = image.copyWithFilePath(filePath);
            _updateImageInState(image.id, updatedImage);
            savedImages.add(updatedImage);

            await Future.delayed(const Duration(milliseconds: 2));
            continue;
          }

          // 从图片元数据中提取实际的 seed
          int actualSeed = params.seed;
          if (params.seed == -1) {
            final extractedMeta = await ImageMetadataService()
                .getMetadataFromBytes(image.bytes);
            if (extractedMeta != null &&
                extractedMeta.seed != null &&
                extractedMeta.seed! > 0) {
              actualSeed = extractedMeta.seed!;
            } else {
              actualSeed = Random().nextInt(4294967295);
            }
          }

          AppLogger.i(
            '[ImageGeneration] Saving image with fixed_prefix=$fixedPrefixTags, fixed_suffix=$fixedSuffixTags, fixed_negative_prefix=$fixedNegativePrefixTags, fixed_negative_suffix=$fixedNegativeSuffixTags',
            'ImageGeneration',
          );

          await ImageSaveUtils.saveImageWithMetadata(
            imageBytes: image.bytes,
            filePath: filePath,
            params: params.copyWith(width: image.width, height: image.height),
            actualSeed: actualSeed,
            fixedPrefixTags: fixedPrefixTags,
            fixedSuffixTags: fixedSuffixTags,
            fixedNegativePrefixTags: fixedNegativePrefixTags,
            fixedNegativeSuffixTags: fixedNegativeSuffixTags,
            charCaptions: charCaptions,
            charNegCaptions: charNegCaptions,
            useCoords: !characterConfig.globalAiChoice,
            useStealth: false,
          );
          savedCount++;
          savedFilePaths.add(filePath);

          // 更新 filePath 到 GeneratedImage
          final updatedImage = image.copyWithFilePath(filePath);
          _updateImageInState(image.id, updatedImage);
          savedImages.add(updatedImage);

          // 避免文件名冲突
          await Future.delayed(const Duration(milliseconds: 2));
        } catch (e) {
          AppLogger.e('自动保存图像失败: $e');
        }
      }

      if (savedCount > 0) {
        if (syncToGalleryIndex) {
          // 【优化】使用即时添加新图像，避免全量扫描延迟
          final galleryNotifier = ref.read(
            localGalleryNotifierProvider.notifier,
          );
          final addedCount = await galleryNotifier.addNewlySavedImages(
            savedFilePaths,
          );

          // 如果即时添加失败或数量不匹配，回退到传统刷新方式
          if (addedCount < savedCount) {
            AppLogger.w(
              '[AutoSave] Immediate add returned $addedCount, expected $savedCount. Falling back to refresh.',
              'AutoSave',
            );
            await galleryNotifier.refresh();
          } else {
            AppLogger.i(
              '[AutoSave] Added $addedCount new images immediately without full scan',
              'AutoSave',
            );
          }
        }

        // 增量更新统计缓存，避免下次启动时完全重新计算
        try {
          final cacheService = ref.read(statisticsCacheServiceProvider);
          await cacheService.incrementImageCount(savedCount);
        } catch (e) {
          AppLogger.w('统计缓存增量更新失败: $e', 'AutoSave');
        }

        if (savedImages.isNotEmpty) {
          _preloadMetadataInBackground(savedImages);
        }

        AppLogger.d('自动保存完成: $savedCount 张图像', 'AutoSave');
      }
    } catch (e) {
      AppLogger.e('自动保存失败: $e');
    }
  }

  /// 检查错误是否为取消操作
  bool _hasCancelledText(dynamic error) =>
      error.toString().toLowerCase().contains('cancelled');

  bool _isCancelledError(dynamic error, [int? generationRunId]) {
    final runWasCancelled = generationRunId == null
        ? _isCancelled
        : _shouldAbortGenerationRun(generationRunId);
    if (runWasCancelled) return true;

    // Current generation paths have run ids. Do not convert a remote
    // "Cancelled" error into a user cancellation unless this run is stale.
    return generationRunId == null && _hasCancelledText(error);
  }

  bool _isRemoteCancelledError(dynamic error, int generationRunId) =>
      !_shouldAbortGenerationRun(generationRunId) && _hasCancelledText(error);

  /// NAI 并发限制（429）自动等待重试。
  /// 取消生成后服务器仍会占用账号并发额度直至孤儿任务结束，
  /// 期间新请求会立即 429；自动等待释放而不是直接报错。
  static const Duration _concurrencyRetryInterval = Duration(seconds: 3);
  static const Duration _concurrencyRetryBudget = Duration(seconds: 90);

  bool _isConcurrencyLimited(dynamic error) {
    if (error is DioException) return error.response?.statusCode == 429;
    return error.toString().contains('API_ERROR_429');
  }

  /// 检查错误是否为流式不支持
  bool _isStreamingNotAllowed(String error) {
    final lower = error.toLowerCase();
    return lower.contains('streaming is not allowed') ||
        lower.contains('streaming not allowed') ||
        lower.contains('stream is not allowed') ||
        lower.contains('stream not allowed');
  }

  /// 带重试的生成
  Future<(List<Uint8List>, Map<int, String>)> _generateWithRetry(
    ImageParams params,
    int generationRunId,
  ) async {
    final apiService = ref.read(naiImageGenerationApiServiceProvider);
    final workflow = ref.read(imageWorkflowControllerProvider);

    for (int retry = 0; retry <= _maxRetries; retry++) {
      try {
        if (_shouldAbortGenerationRun(generationRunId)) {
          throw StateError('Generation cancelled');
        }

        final result = await apiService.generateImage(
          params,
          onProgress: (_, __) {},
          focusedInpaintEnabled: workflow.focusedInpaintEnabled,
          minimumContextMegaPixels: workflow.minimumContextMegaPixels,
          focusedSelectionRect: workflow.focusedSelectionRect,
        );
        if (_shouldAbortGenerationRun(generationRunId)) {
          throw StateError('Generation cancelled');
        }
        return result;
      } catch (e) {
        if (_isCancelledError(e, generationRunId)) rethrow;
        if (_isRemoteCancelledError(e, generationRunId)) rethrow;
        if (_isConcurrencyLimited(e)) rethrow; // 交给上层等待并发额度释放

        if (retry < _maxRetries) {
          AppLogger.w(
            '生成失败，${_retryDelays[retry]}ms 后重试 (${retry + 1}/$_maxRetries): $e',
          );
          await Future.delayed(Duration(milliseconds: _retryDelays[retry]));
          if (_shouldAbortGenerationRun(generationRunId)) {
            throw StateError('Generation cancelled');
          }
        } else {
          rethrow;
        }
      }
    }

    return (<Uint8List>[], <int, String>{});
  }

  /// 保存 Vibe 编码哈希到状态
  ///
  /// [vibeEncodings] 索引到编码哈希的映射
  void _saveVibeEncodings(Map<int, String> vibeEncodings) {
    AppLogger.d(
      'Saving ${vibeEncodings.length} Vibe encodings to state',
      'Generation',
    );
    for (final entry in vibeEncodings.entries) {
      final index = entry.key;
      final encoding = entry.value;
      if (encoding.isNotEmpty) {
        ref
            .read(generationParamsNotifierProvider.notifier)
            .updateVibeReference(index, vibeEncoding: encoding);
        AppLogger.d(
          'Saved Vibe encoding for index $index (hash length: ${encoding.length})',
          'Generation',
        );
      }
    }
  }

  /// 使用流式 API 生成批次图像（支持预览）
  ///
  /// [params] 生成参数（nSamples 表示本次请求要生成的图片数量）
  /// [currentStart] 当前批次起始图像编号
  /// [total] 总图像数量
  Future<List<Uint8List>> _generateBatchWithStream(
    ImageParams params,
    int currentStart,
    int total,
    int generationRunId,
  ) async {
    final apiService = ref.read(naiImageGenerationApiServiceProvider);
    final workflow = ref.read(imageWorkflowControllerProvider);
    final requestParams = _materializeRandomSeed(params);
    final batchSize = max(1, requestParams.nSamples);
    var useNonStreamFallback = false;

    int imageNumberForSample(int sampleIndex) {
      final sampleOffset = sampleIndex.clamp(0, batchSize - 1).toInt();
      return currentStart + sampleOffset;
    }

    double progressForBatch({
      required int completedSamples,
      double inFlightProgress = 0.0,
    }) {
      final batchProgress = (completedSamples + inFlightProgress)
          .clamp(0.0, batchSize.toDouble())
          .toDouble();
      return ((currentStart - 1) + batchProgress) / total;
    }

    void clearRememberedPreviewsForRequest(int count) {
      for (var i = 0; i < count; i++) {
        _clearRememberedStreamPreview(
          generationRunId: generationRunId,
          imageNumber: currentStart + i,
        );
      }
    }

    Future<List<Uint8List>> runNonStreamFallback() async {
      final fallback = await apiService.generateImageCancellable(
        requestParams,
        onProgress: (_, __) {},
        focusedInpaintEnabled: workflow.focusedInpaintEnabled,
        minimumContextMegaPixels: workflow.minimumContextMegaPixels,
        focusedSelectionRect: workflow.focusedSelectionRect,
      );
      if (_shouldAbortGenerationRun(generationRunId) ||
          _isActiveRequestCancel(generationRunId, currentStart)) {
        return const <Uint8List>[];
      }
      clearRememberedPreviewsForRequest(fallback.length);
      return fallback;
    }

    final initialSlots = [
      for (var i = 0; i < batchSize; i++)
        StreamPreviewSlot(
          imageNumber: currentStart + i,
          totalImages: total,
          progress: 0.0,
        ),
    ];
    _beginActiveRequest(
      generationRunId: generationRunId,
      startImage: currentStart,
      requestSize: batchSize,
    );
    state = state.copyWith(
      currentImage: currentStart,
      progress: progressForBatch(completedSamples: 0),
      streamPreviewSlots: initialSlots,
      clearStreamPreview: true,
    );

    try {
      for (int retry = 0; retry <= _maxRetries; retry++) {
        final finalImages = <int, Uint8List>{};

        try {
          if (useNonStreamFallback) {
            return await runNonStreamFallback();
          }

          var streamingNotAllowed = false;
          await for (final chunk in apiService.generateImageStream(
            requestParams,
            focusedInpaintEnabled: workflow.focusedInpaintEnabled,
            minimumContextMegaPixels: workflow.minimumContextMegaPixels,
            focusedSelectionRect: workflow.focusedSelectionRect,
          )) {
            if (_shouldAbortGenerationRun(generationRunId)) {
              return const <Uint8List>[];
            }
            if (_isActiveRequestCancel(generationRunId, currentStart)) {
              _appendFailedStreamSnapshotsForCurrentSlots(generationRunId);
              return const <Uint8List>[];
            }

            if (chunk.hasError) {
              if (_isActiveRequestCancel(generationRunId, currentStart) &&
                  _hasCancelledText(chunk.error ?? '')) {
                _appendFailedStreamSnapshotsForCurrentSlots(generationRunId);
                return const <Uint8List>[];
              }
              if (_isStreamingNotAllowed(chunk.error ?? '')) {
                AppLogger.w(
                  'Streaming not allowed, falling back to non-stream API',
                  'Generation',
                );
                streamingNotAllowed = true;
                useNonStreamFallback = true;
                break;
              }
              throw Exception(chunk.error);
            }

            final imageNumber = imageNumberForSample(chunk.sampleIndex);
            if (chunk.hasPreview) {
              _rememberStreamPreview(
                bytes: chunk.previewImage!,
                params: requestParams,
                generationRunId: generationRunId,
                imageNumber: imageNumber,
                focusedPreviewPlacement: chunk.focusedPreviewPlacement,
              );
              final slot = StreamPreviewSlot(
                imageNumber: imageNumber,
                totalImages: total,
                progress: chunk.progress.clamp(0.0, 0.99).toDouble(),
                previewBytes: chunk.previewImage,
                focusedPreviewPlacement: chunk.focusedPreviewPlacement,
              );
              state = state.copyWith(
                currentImage: imageNumber,
                progress: progressForBatch(
                  completedSamples: finalImages.length,
                  inFlightProgress: slot.progress,
                ),
                streamPreview: chunk.previewImage,
                focusedPreviewPlacement: chunk.focusedPreviewPlacement,
                streamPreviewSlots: _replaceStreamPreviewSlot(
                  state.streamPreviewSlots,
                  slot,
                ),
              );
            }

            if (chunk.isComplete && chunk.hasFinalImage) {
              finalImages[chunk.sampleIndex] = chunk.finalImage!;
              _rememberStreamPreview(
                bytes: chunk.finalImage!,
                params: requestParams,
                generationRunId: generationRunId,
                imageNumber: imageNumber,
              );
              final slot = StreamPreviewSlot(
                imageNumber: imageNumber,
                totalImages: total,
                progress: 1.0,
                previewBytes: chunk.finalImage,
              );
              state = state.copyWith(
                currentImage: imageNumber,
                progress: progressForBatch(
                  completedSamples: finalImages.length,
                ),
                streamPreview: chunk.finalImage,
                clearFocusedPreviewPlacement: true,
                streamPreviewSlots: _replaceStreamPreviewSlot(
                  state.streamPreviewSlots,
                  slot,
                ),
              );
            }
          }

          if (_shouldAbortGenerationRun(generationRunId)) {
            return const <Uint8List>[];
          }
          if (_isActiveRequestCancel(generationRunId, currentStart)) {
            _appendFailedStreamSnapshotsForCurrentSlots(generationRunId);
            return const <Uint8List>[];
          }

          if (streamingNotAllowed) {
            final fallback = await runNonStreamFallback();
            if (fallback.isNotEmpty) return fallback;
            continue;
          }

          if (finalImages.isNotEmpty) {
            final orderedImages = finalImages.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key));
            clearRememberedPreviewsForRequest(batchSize);
            return orderedImages.map((entry) => entry.value).toList();
          }

          final fallback = await runNonStreamFallback();
          if (fallback.isNotEmpty) return fallback;
        } catch (e) {
          if (_isActiveRequestCancel(generationRunId, currentStart)) {
            _appendFailedStreamSnapshotsForCurrentSlots(generationRunId);
            return const <Uint8List>[];
          }
          if (_isCancelledError(e, generationRunId)) {
            _appendFailedStreamSnapshotsForCurrentSlots(generationRunId);
            final orderedImages = finalImages.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key));
            return orderedImages.map((entry) => entry.value).toList();
          }
          if (_isRemoteCancelledError(e, generationRunId)) {
            _appendFailedStreamSnapshotsForCurrentSlots(generationRunId);
            rethrow;
          }
          if (_isConcurrencyLimited(e)) rethrow; // 交给上层等待并发额度释放

          if (_isStreamingNotAllowed(e.toString())) {
            AppLogger.w(
              'Streaming not allowed (exception), falling back to non-stream API',
              'Generation',
            );
            useNonStreamFallback = true;
            try {
              final fallback = await runNonStreamFallback();
              if (fallback.isNotEmpty) return fallback;
            } catch (fallbackError) {
              _appendFailedStreamSnapshotsForCurrentSlots(generationRunId);
              AppLogger.e('非流式回退生成失败: $fallbackError');
            }
            break;
          }

          if (retry < _maxRetries) {
            AppLogger.w(
              '生成失败，${_retryDelays[retry]}ms 后重试 (${retry + 1}/$_maxRetries): $e',
            );
            await Future.delayed(Duration(milliseconds: _retryDelays[retry]));
            if (_shouldAbortGenerationRun(generationRunId)) {
              return const <Uint8List>[];
            }
          } else {
            AppLogger.e('生成第 $currentStart 批图像失败: $e');
            _appendFailedStreamSnapshotsForCurrentSlots(generationRunId);
            rethrow;
          }
        }
      }

      _appendFailedStreamSnapshotsForCurrentSlots(generationRunId);
      return const <Uint8List>[];
    } finally {
      _endActiveRequest(
        generationRunId: generationRunId,
        startImage: currentStart,
      );
    }
  }

  /// 生成单张（使用流式 API 支持渐进式预览）
  Future<void> _generateSingle(
    ImageParams params,
    int current,
    int total,
    int generationRunId, {
    DateTime? concurrencyDeadline,
  }) async {
    if (_shouldAbortGenerationRun(generationRunId)) return;

    state = state.copyWith(
      status: GenerationStatus.generating,
      progress: 0.0,
      errorMessage: null,
      currentImage: current,
      totalImages: total,
      clearStreamPreview: true,
    );

    try {
      final apiService = ref.read(naiImageGenerationApiServiceProvider);
      final workflow = ref.read(imageWorkflowControllerProvider);

      final stream = apiService.generateImageStream(
        params,
        focusedInpaintEnabled: workflow.focusedInpaintEnabled,
        minimumContextMegaPixels: workflow.minimumContextMegaPixels,
        focusedSelectionRect: workflow.focusedSelectionRect,
      );

      final finalImages = <int, Uint8List>{};
      bool streamingNotAllowed = false;

      await for (final chunk in stream) {
        if (_shouldAbortGenerationRun(generationRunId)) return;

        if (chunk.hasError) {
          if (_isStreamingNotAllowed(chunk.error ?? '')) {
            AppLogger.w(
              'Streaming not allowed, falling back to non-stream API',
              'Generation',
            );
            streamingNotAllowed = true;
            break;
          }
          if (_isConcurrencyLimited(chunk.error ?? '') &&
              DateTime.now().isBefore(
                concurrencyDeadline ??= DateTime.now().add(
                  _concurrencyRetryBudget,
                ),
              )) {
            // 并发限制：等待 NAI 释放额度后自动重试（取消可随时中断）
            AppLogger.w(
              'NAI 并发限制(429)，${_concurrencyRetryInterval.inSeconds}s 后自动重试',
              'Generation',
            );
            await Future.delayed(_concurrencyRetryInterval);
            if (_shouldAbortGenerationRun(generationRunId)) return;
            return _generateSingle(
              params,
              current,
              total,
              generationRunId,
              concurrencyDeadline: concurrencyDeadline,
            );
          }
          _appendFailedStreamSnapshotToHistory(
            generationRunId: generationRunId,
            imageNumber: current,
          );
          state = state.copyWith(
            status: GenerationStatus.error,
            errorMessage: chunk.error,
            progress: 0.0,
            currentImage: 0,
            totalImages: 0,
            clearStreamPreview: true,
          );
          return;
        }

        if (chunk.hasPreview) {
          // 更新流式预览
          if (_shouldAbortGenerationRun(generationRunId)) return;
          _rememberStreamPreview(
            bytes: chunk.previewImage!,
            params: params,
            generationRunId: generationRunId,
            imageNumber: current,
            focusedPreviewPlacement: chunk.focusedPreviewPlacement,
          );
          state = state.copyWith(
            progress: chunk.progress,
            streamPreview: chunk.previewImage,
            focusedPreviewPlacement: chunk.focusedPreviewPlacement,
          );
        }

        if (chunk.isComplete && chunk.hasFinalImage) {
          finalImages[chunk.sampleIndex] = chunk.finalImage!;
          _rememberStreamPreview(
            bytes: chunk.finalImage!,
            params: params,
            generationRunId: generationRunId,
            imageNumber: current,
          );
          state = state.copyWith(
            progress: 1.0,
            streamPreview: chunk.finalImage,
            clearFocusedPreviewPlacement: true,
          );
        }
      }

      // 如果流式不被支持，回退到非流式 API
      if (streamingNotAllowed) {
        final (imageBytes, vibeEncodings) = await _generateWithRetry(
          params,
          generationRunId,
        );
        if (_shouldAbortGenerationRun(generationRunId)) return;
        if (imageBytes.isEmpty) {
          throw Exception('No images returned from generation');
        }
        final generatedList = imageBytes
            .map(
              (b) => GeneratedImage.create(
                b,
                width: params.width,
                height: params.height,
              ),
            )
            .toList();
        state = state.copyWith(
          status: GenerationStatus.completed,
          currentImages: generatedList,
          displayImages: generatedList,
          displayWidth: generatedList.first.width,
          displayHeight: generatedList.first.height,
          history: [...generatedList, ...state.history].take(50).toList(),
          progress: 1.0,
          currentImage: 0,
          totalImages: 0,
          clearStreamPreview: true,
        );
        _retainSharePreparationCacheForCurrentHistory();
        _clearRememberedStreamPreview(
          generationRunId: generationRunId,
          imageNumber: current,
        );
        // 保存 Vibe 编码哈希到状态
        if (vibeEncodings.isNotEmpty) {
          _saveVibeEncodings(vibeEncodings);
        }
        // 自动保存
        await _autoSaveIfEnabled(generatedList, params);
        // 后台预解析元数据（不阻塞）
        _preloadMetadataInBackground(generatedList);
        return;
      }

      if (finalImages.isNotEmpty) {
        if (_shouldAbortGenerationRun(generationRunId)) return;
        final orderedImages = finalImages.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        final generatedList = orderedImages
            .map(
              (entry) => GeneratedImage.create(
                entry.value,
                width: params.width,
                height: params.height,
              ),
            )
            .toList();
        state = state.copyWith(
          status: GenerationStatus.completed,
          currentImages: generatedList,
          displayImages: generatedList,
          displayWidth: generatedList.first.width,
          displayHeight: generatedList.first.height,
          history: [...generatedList, ...state.history].take(50).toList(),
          progress: 1.0,
          currentImage: 0,
          totalImages: 0,
          clearStreamPreview: true,
        );
        _retainSharePreparationCacheForCurrentHistory();
        _clearRememberedStreamPreview(
          generationRunId: generationRunId,
          imageNumber: current,
        );
        // 自动保存
        await _autoSaveIfEnabled(generatedList, params);
        // 后台预解析元数据（不阻塞）
        _preloadMetadataInBackground(generatedList);
      } else {
        // 流式 API 未返回图像，回退到非流式 API
        AppLogger.w(
          'Stream API returned no image, falling back to non-stream API',
          'Generation',
        );
        final (imageBytes, vibeEncodings) = await _generateWithRetry(
          params,
          generationRunId,
        );
        if (_shouldAbortGenerationRun(generationRunId)) return;
        if (imageBytes.isEmpty) {
          throw Exception('No images returned from generation');
        }
        final generatedList = imageBytes
            .map(
              (b) => GeneratedImage.create(
                b,
                width: params.width,
                height: params.height,
              ),
            )
            .toList();
        state = state.copyWith(
          status: GenerationStatus.completed,
          currentImages: generatedList,
          displayImages: generatedList,
          displayWidth: generatedList.first.width,
          displayHeight: generatedList.first.height,
          history: [...generatedList, ...state.history].take(50).toList(),
          progress: 1.0,
          currentImage: 0,
          totalImages: 0,
          clearStreamPreview: true,
        );
        _retainSharePreparationCacheForCurrentHistory();
        _clearRememberedStreamPreview(
          generationRunId: generationRunId,
          imageNumber: current,
        );
        // 保存 Vibe 编码哈希到状态
        if (vibeEncodings.isNotEmpty) {
          _saveVibeEncodings(vibeEncodings);
        }
        // 自动保存
        await _autoSaveIfEnabled(generatedList, params);
        // 后台预解析元数据（不阻塞）
        _preloadMetadataInBackground(generatedList);
      }
    } catch (e) {
      if (_isCancelledError(e, generationRunId)) {
        if (_isCurrentGenerationRun(generationRunId)) {
          _appendFailedStreamSnapshotToHistory(
            generationRunId: generationRunId,
            imageNumber: current,
          );
          state = state.copyWith(
            status: GenerationStatus.cancelled,
            progress: 0.0,
            currentImage: 0,
            totalImages: 0,
            clearStreamPreview: true,
          );
        }
      } else if (_isConcurrencyLimited(e) &&
          DateTime.now().isBefore(
            concurrencyDeadline ??= DateTime.now().add(_concurrencyRetryBudget),
          )) {
        // 并发限制：等待 NAI 释放额度后自动重试（取消可随时中断）
        AppLogger.w(
          'NAI 并发限制(429)，${_concurrencyRetryInterval.inSeconds}s 后自动重试',
          'Generation',
        );
        await Future.delayed(_concurrencyRetryInterval);
        if (_shouldAbortGenerationRun(generationRunId)) return;
        return _generateSingle(
          params,
          current,
          total,
          generationRunId,
          concurrencyDeadline: concurrencyDeadline,
        );
      } else if (_isStreamingNotAllowed(e.toString())) {
        AppLogger.w(
          'Streaming not allowed (exception), falling back to non-stream API',
          'Generation',
        );
        try {
          final (imageBytes, vibeEncodings) = await _generateWithRetry(
            params,
            generationRunId,
          );
          if (_shouldAbortGenerationRun(generationRunId)) return;
          if (imageBytes.isEmpty) {
            throw Exception('No images returned from generation');
          }
          final generatedList = imageBytes
              .map(
                (b) => GeneratedImage.create(
                  b,
                  width: params.width,
                  height: params.height,
                ),
              )
              .toList();
          state = state.copyWith(
            status: GenerationStatus.completed,
            currentImages: generatedList,
            displayImages: generatedList,
            displayWidth: generatedList.first.width,
            displayHeight: generatedList.first.height,
            history: [...generatedList, ...state.history].take(50).toList(),
            progress: 1.0,
            currentImage: 0,
            totalImages: 0,
            clearStreamPreview: true,
          );
          _retainSharePreparationCacheForCurrentHistory();
          _clearRememberedStreamPreview(
            generationRunId: generationRunId,
            imageNumber: current,
          );
          if (vibeEncodings.isNotEmpty) {
            _saveVibeEncodings(vibeEncodings);
          }
          await _autoSaveIfEnabled(generatedList, params);
          if (_shouldAbortGenerationRun(generationRunId)) return;
          // 后台预解析元数据（不阻塞）
          _preloadMetadataInBackground(generatedList);
        } catch (fallbackError) {
          if (_isCancelledError(fallbackError, generationRunId) ||
              !_isCurrentGenerationRun(generationRunId)) {
            if (_isCurrentGenerationRun(generationRunId)) {
              _appendFailedStreamSnapshotToHistory(
                generationRunId: generationRunId,
                imageNumber: current,
              );
            }
            return;
          }
          _appendFailedStreamSnapshotToHistory(
            generationRunId: generationRunId,
            imageNumber: current,
          );
          state = state.copyWith(
            status: GenerationStatus.error,
            errorMessage: fallbackError.toString(),
            progress: 0.0,
            currentImage: 0,
            totalImages: 0,
            clearStreamPreview: true,
          );
        }
      } else {
        if (!_isCurrentGenerationRun(generationRunId)) return;
        _appendFailedStreamSnapshotToHistory(
          generationRunId: generationRunId,
          imageNumber: current,
        );
        state = state.copyWith(
          status: GenerationStatus.error,
          errorMessage: e.toString(),
          progress: 0.0,
          currentImage: 0,
          totalImages: 0,
          clearStreamPreview: true,
        );
      }
    }
  }

  /// 跳过当前请求，继续后续批次。
  void skipCurrentRequest() {
    final generationRunId = _activeGenerationRunId;
    final apiService = ref.read(naiImageGenerationApiServiceProvider);

    if (_activeRequestGenerationRunId != generationRunId ||
        !_activeRequestHasRemainingImages()) {
      cancel();
      return;
    }

    _activeRequestCancelRequested = true;
    _appendFailedStreamSnapshotsForCurrentSlots(generationRunId);
    apiService.cancelGeneration();
    state = state.copyWith(clearStreamPreview: true);
  }

  /// 取消生成并停止后续批次。
  void cancel() {
    final generationRunId = _activeGenerationRunId;
    final apiService = ref.read(naiImageGenerationApiServiceProvider);

    _appendFailedStreamSnapshotsForCurrentSlots(generationRunId);
    _invalidateGenerationRun();
    apiService.cancelGeneration();

    state = state.copyWith(
      status: GenerationStatus.cancelled,
      progress: 0.0,
      currentImage: 0,
      totalImages: 0,
      clearStreamPreview: true,
    );
  }

  /// 清除当前图像
  void clearCurrent() {
    state = state.copyWith(currentImages: [], status: GenerationStatus.idle);
    _retainSharePreparationCacheForCurrentHistory();
  }

  /// 清除错误
  void clearError() {
    if (state.status == GenerationStatus.error) {
      state = state.copyWith(status: GenerationStatus.idle, errorMessage: null);
    }
  }

  /// 清除历史记录（包含当前批次图像）
  void clearHistory() {
    state = state.copyWith(currentImages: [], history: []);
    _retainSharePreparationCacheForCurrentHistory();
  }

  /// 更新显示图像列表
  ///
  /// 用于保存图像后更新 filePath 等信息
  void updateDisplayImages(List<GeneratedImage> images) {
    state = state.copyWith(displayImages: images);
  }

  /// 更新指定生成图像的本地文件路径。
  void updateImageFilePath(String imageId, String filePath) {
    GeneratedImage? image;
    for (final candidate in [
      ...state.currentImages,
      ...state.history,
      ...state.displayImages,
    ]) {
      if (candidate.id == imageId) {
        image = candidate;
        break;
      }
    }

    if (image == null) return;
    _updateImageInState(imageId, image.copyWithFilePath(filePath));
  }

  /// 更新状态中的单个图像
  ///
  /// 用于自动保存后更新图像的 filePath
  void _updateImageInState(String imageId, GeneratedImage updatedImage) {
    // 更新 currentImages
    final updatedCurrentImages = state.currentImages.map((img) {
      return img.id == imageId ? updatedImage : img;
    }).toList();

    // 更新 history
    final updatedHistory = state.history.map((img) {
      return img.id == imageId ? updatedImage : img;
    }).toList();

    // 更新 displayImages
    final updatedDisplayImages = state.displayImages.map((img) {
      return img.id == imageId ? updatedImage : img;
    }).toList();

    state = state.copyWith(
      currentImages: updatedCurrentImages,
      history: updatedHistory,
      displayImages: updatedDisplayImages,
    );
    _retainSharePreparationCacheForCurrentHistory();

    AppLogger.d(
      'Updated filePath for image $imageId: ${updatedImage.filePath}',
      'AutoSave',
    );
  }

  /// 将 UI 层的角色提示词配置转换为 API 层的格式
  ///
  /// [config] UI 层的角色提示词配置
  /// 返回 API 层的 CharacterPrompt 列表
  ///
  /// 注意：此方法会统一解析角色提示词中的别名
  List<CharacterPrompt> _convertCharactersToApiFormat(
    ui_character.CharacterPromptConfig config,
  ) {
    // 过滤出启用且有提示词的角色
    final enabledCharacters = config.characters
        .where((c) => c.enabled && c.prompt.isNotEmpty)
        .toList();

    if (enabledCharacters.isEmpty) {
      return [];
    }

    // 获取别名解析器统一解析角色提示词
    final aliasResolver = ref.read(aliasResolverServiceProvider.notifier);

    return enabledCharacters.map((uiChar) {
      // 计算位置字符串
      String? position;
      if (!config.globalAiChoice &&
          uiChar.positionMode == ui_character.CharacterPositionMode.custom &&
          uiChar.customPosition != null) {
        position = uiChar.customPosition!.toNaiString();
      }

      // 解析角色提示词中的别名
      return CharacterPrompt(
        prompt: aliasResolver.resolveAliases(uiChar.prompt),
        negativePrompt: aliasResolver.resolveAliases(uiChar.negativePrompt),
        position: position,
      );
    }).toList();
  }

  /// 统一随机提示词生成并应用方法
  ///
  /// 此方法是随机按钮和自动随机模式的唯一入口
  /// 生成随机提示词并自动应用到主提示词和角色提示词
  ///
  /// [seed] 随机种子（可选）
  /// 返回生成的主提示词字符串（用于日志/显示）
  Future<String> generateAndApplyRandomPrompt({int? seed}) async {
    // 获取当前模型是否为 V4
    final params = ref.read(generationParamsNotifierProvider);
    final isV4Model = params.isV4Model;

    // 使用统一的生成入口
    final result = await ref
        .read(promptConfigNotifierProvider.notifier)
        .generateRandomPrompt(isV4Model: isV4Model, seed: seed);

    // 格式化生成的提示词（空格转下划线等）
    final formattedPrompt = NaiPromptFormatter.format(result.mainPrompt);

    // 应用主提示词
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updatePrompt(formattedPrompt);

    // 记录格式化信息
    if (formattedPrompt != result.mainPrompt) {
      AppLogger.d(
        'Formatted random prompt: ${result.mainPrompt} → $formattedPrompt',
        'RandomMode',
      );
    }

    // 应用角色提示词（同时进行格式化）
    if (result.hasCharacters && isV4Model) {
      final characterPrompts = result.toCharacterPrompts().map((char) {
        return char.copyWith(
          prompt: NaiPromptFormatter.format(char.prompt),
          negativePrompt: char.negativePrompt.isNotEmpty
              ? NaiPromptFormatter.format(char.negativePrompt)
              : char.negativePrompt,
        );
      }).toList();
      AppLogger.d(
        'Random result: ${result.characterCount} characters, prompts: ${characterPrompts.length}',
        'RandomMode',
      );
      for (var i = 0; i < characterPrompts.length; i++) {
        AppLogger.d(
          'Character $i: ${characterPrompts[i].prompt}',
          'RandomMode',
        );
      }
      ref
          .read(characterPromptNotifierProvider.notifier)
          .replaceAll(characterPrompts);

      AppLogger.d(
        'Applied ${result.characterCount} characters from random generation',
        'RandomMode',
      );
    } else if (result.noHumans) {
      // 无人物场景，清空角色
      ref.read(characterPromptNotifierProvider.notifier).clearAll();
      AppLogger.d('No humans scene, cleared characters', 'RandomMode');
    }

    return formattedPrompt;
  }

  // ============================================================
  // 后台元数据解析（生成完成后立即启动）
  // ============================================================

  /// 后台并行解析图像元数据
  ///
  /// 在图像生成完成后立即启动，将图像加入预加载队列。
  /// 队列会按顺序处理，支持连续生成多张图像时的排队机制。
  /// 这样用户打开详情页时元数据已经准备好了，无需等待。
  void _preloadMetadataInBackground(List<GeneratedImage> images) {
    if (images.isEmpty) return;

    final service = ImageMetadataService();

    AppLogger.d(
      'Enqueuing ${images.length} images for metadata preloading',
      'MetadataPreload',
    );

    // 将图像加入预加载队列
    for (final image in images) {
      service.enqueuePreload(
        taskId: image.id,
        filePath: image.filePath,
        bytes: image.filePath == null ? image.bytes : null,
      );
    }

    // 输出队列状态
    final status = service.getPreloadQueueStatus();
    AppLogger.d(
      'Preload queue status: length=${status['queueLength']}, '
          'processing=${status['processingCount']}, isProcessing=${status['isProcessing']}',
      'MetadataPreload',
    );
  }

  (int, int)? _resolveImageSize(
    Uint8List imageBytes, {
    int? width,
    int? height,
  }) {
    final encodedSize = NaiResolutionAdapter.readImageSize(imageBytes);
    if (encodedSize != null) {
      return encodedSize;
    }

    if (width != null && height != null) {
      return (width, height);
    }

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return null;
    }

    return (decoded.width, decoded.height);
  }
}
