import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/api_constants.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/nai_metadata_parser.dart';
import '../../data/datasources/remote/nai_image_enhancement_api_service.dart';
import '../../data/datasources/remote/nai_image_generation_api_service.dart';
import '../../data/datasources/remote/nai_tag_suggestion_api_service.dart';
import '../../data/models/character/character_prompt.dart' as ui_character;
import '../../data/models/image/image_params.dart';
import '../../data/models/tag/tag_suggestion.dart';
import '../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../data/models/vibe/vibe_reference_v4.dart';
import '../../data/repositories/local_gallery_repository.dart';
import '../../data/services/statistics_cache_service.dart';
import 'character_prompt_provider.dart';
import '../../data/services/alias_resolver_service.dart';
import 'fixed_tags_provider.dart';
import 'image_save_settings_provider.dart';
import 'local_gallery_provider.dart';
import 'prompt_config_provider.dart';
import 'queue_execution_provider.dart';
import 'subscription_provider.dart';

part 'image_generation_provider.g.dart';

/// 生成的图像（带唯一ID）
class GeneratedImage {
  final String id;
  final Uint8List bytes;
  final DateTime createdAt;
  final int width;
  final int height;

  GeneratedImage({
    required this.id,
    required this.bytes,
    required this.width,
    required this.height,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 创建新的生成图像（自动生成ID）
  factory GeneratedImage.create(
    Uint8List bytes, {
    required int width,
    required int height,
  }) {
    return GeneratedImage(
      id: const Uuid().v4(),
      bytes: bytes,
      width: width,
      height: height,
    );
  }

  /// 获取宽高比
  double get aspectRatio => width / height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeneratedImage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 生成状态
enum GenerationStatus {
  idle,
  generating,
  completed,
  error,
  cancelled,
}

/// 图像生成状态
class ImageGenerationState {
  final GenerationStatus status;
  final List<GeneratedImage> currentImages;
  final List<GeneratedImage> history;
  final String? errorMessage;
  final double progress;
  final int currentImage; // 当前第几张 (1-based)
  final int totalImages; // 总共几张

  /// 流式预览图像（渐进式生成过程中的预览）
  final Uint8List? streamPreview;

  /// 当前批次的分辨率（点击生成时捕获）
  final int? batchWidth;
  final int? batchHeight;

  /// 中央区域显示的图像（独立于历史记录，清除历史时保留）
  final List<GeneratedImage> displayImages;

  /// 中央区域显示图像的分辨率
  final int? displayWidth;
  final int? displayHeight;

  const ImageGenerationState({
    this.status = GenerationStatus.idle,
    this.currentImages = const [],
    this.history = const [],
    this.errorMessage,
    this.progress = 0.0,
    this.currentImage = 0,
    this.totalImages = 0,
    this.streamPreview,
    this.batchWidth,
    this.batchHeight,
    this.displayImages = const [],
    this.displayWidth,
    this.displayHeight,
  });

  ImageGenerationState copyWith({
    GenerationStatus? status,
    List<GeneratedImage>? currentImages,
    List<GeneratedImage>? history,
    String? errorMessage,
    double? progress,
    int? currentImage,
    int? totalImages,
    Uint8List? streamPreview,
    bool clearStreamPreview = false,
    int? batchWidth,
    int? batchHeight,
    List<GeneratedImage>? displayImages,
    int? displayWidth,
    int? displayHeight,
  }) {
    return ImageGenerationState(
      status: status ?? this.status,
      currentImages: currentImages ?? this.currentImages,
      history: history ?? this.history,
      errorMessage: errorMessage,
      progress: progress ?? this.progress,
      currentImage: currentImage ?? this.currentImage,
      totalImages: totalImages ?? this.totalImages,
      streamPreview:
          clearStreamPreview ? null : (streamPreview ?? this.streamPreview),
      batchWidth: batchWidth ?? this.batchWidth,
      batchHeight: batchHeight ?? this.batchHeight,
      displayImages: displayImages ?? this.displayImages,
      displayWidth: displayWidth ?? this.displayWidth,
      displayHeight: displayHeight ?? this.displayHeight,
    );
  }

  bool get isGenerating => status == GenerationStatus.generating;
  bool get hasImages => displayImages.isNotEmpty;

  /// 是否有流式预览图像
  bool get hasStreamPreview =>
      streamPreview != null && streamPreview!.isNotEmpty;
}

/// 图像生成状态 Notifier
@Riverpod(keepAlive: true)
class ImageGenerationNotifier extends _$ImageGenerationNotifier {
  @override
  ImageGenerationState build() {
    return const ImageGenerationState();
  }

  /// 生成图像
  /// 重试延迟策略 (毫秒)
  static const List<int> _retryDelays = [1000, 2000, 4000];
  static const int _maxRetries = 3;

  bool _isCancelled = false;

  Future<void> generate(ImageParams params) async {
    _isCancelled = false;

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

    // 读取 UI 设置，转换为 API 参数
    // 质量标签：由 API 的 qualityToggle 参数控制，后端自动添加
    final addQualityTags = ref.read(qualityTagsSettingsProvider);

    // UC 预设：由 API 的 ucPreset 参数控制，后端自动填充负向提示词
    // UcPresetType.heavy -> 0, light -> 1, humanFocus -> 2, none -> 3
    final ucPresetType = ref.read(ucPresetSettingsProvider);
    final ucPresetValue = ucPresetType.index; // enum index 正好对应 API 值

    // 解析别名（将 <词库名> 展开为实际内容）
    final aliasResolver = ref.read(aliasResolverServiceProvider.notifier);
    final promptWithAliases =
        aliasResolver.resolveAliases(effectiveParams.prompt);
    if (promptWithAliases != effectiveParams.prompt) {
      AppLogger.d(
        'Resolved aliases in prompt',
        'AliasResolver',
      );
      effectiveParams = effectiveParams.copyWith(prompt: promptWithAliases);
    }

    // 应用固定词到提示词
    final fixedTagsState = ref.read(fixedTagsNotifierProvider);
    final promptWithFixedTags =
        fixedTagsState.entries.applyToPrompt(effectiveParams.prompt);
    if (promptWithFixedTags != effectiveParams.prompt) {
      AppLogger.d(
        'Applied fixed tags: ${fixedTagsState.enabledCount} entries',
        'FixedTags',
      );
      effectiveParams = effectiveParams.copyWith(prompt: promptWithFixedTags);
    }

    // 读取多角色提示词配置并转换为 API 格式
    final characterConfig = ref.read(characterPromptNotifierProvider);
    final apiCharacters = _convertCharactersToApiFormat(characterConfig);

    // 将设置应用到参数（不在客户端修改提示词内容，让后端处理）
    final ImageParams baseParams = effectiveParams.copyWith(
      qualityToggle: addQualityTags,
      ucPreset: ucPresetValue,
      characters: apiCharacters,
      // 如果有角色且使用自定义位置，启用坐标模式
      useCoords: apiCharacters.isNotEmpty && !characterConfig.globalAiChoice,
    );

    // 如果只生成 1 张，直接生成（不需要再随机，已经在开头随机过了）
    if (batchCount == 1 && batchSize == 1) {
      await _generateSingle(baseParams, 1, 1);
      // 注意：生成完成通知由 QueueExecutionNotifier 统一管理
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
      batchWidth: baseParams.width,
      batchHeight: baseParams.height,
    );

    final allImages = <GeneratedImage>[];
    final random = Random();
    int generatedImages = 0;

    // 当前使用的参数（可能会被抽卡模式修改）
    ImageParams currentParams = baseParams;

    for (int batch = 0; batch < batchCount; batch++) {
      if (_isCancelled) break;

      // 如果开启抽卡模式且不是第一批且不在队列执行中，先随机新提示词再生成
      // 第一批已在方法开头随机过了
      // 队列执行时跳过抽卡模式
      if (randomMode && batch > 0 && !isQueueExecuting) {
        final randomPrompt = await generateAndApplyRandomPrompt();
        if (randomPrompt.isNotEmpty) {
          AppLogger.d(
            'Batch ${batch + 1}/$batchCount - Random before generation: $randomPrompt',
            'RandomMode',
          );
          // 重新读取角色配置并更新参数
          final newCharacterConfig = ref.read(characterPromptNotifierProvider);
          final newApiCharacters =
              _convertCharactersToApiFormat(newCharacterConfig);
          currentParams = currentParams.copyWith(
            prompt: randomPrompt,
            characters: newApiCharacters,
            useCoords: newApiCharacters.isNotEmpty &&
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
        seed: random.nextInt(4294967295),
      );

      try {
        // 使用流式 API 生成，支持预览
        final imageBytes = await _generateBatchWithStream(
          batchParams,
          generatedImages + 1,
          totalImages,
        );
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
        } else {
          generatedImages += batchSize; // 即使失败也要跳过，避免死循环
        }
      } catch (e) {
        if (_isCancelled || e.toString().contains('cancelled')) {
          state = state.copyWith(
            status: GenerationStatus.cancelled,
            progress: 0.0,
            currentImage: 0,
            totalImages: 0,
          );
          return;
        }
        // 本批次失败，继续下一批
        AppLogger.e('生成第 ${batch + 1} 批失败: $e');
        generatedImages += batchSize;
      }
    }

    // 完成（不再随机，保持图像和提示词对应）
    state = state.copyWith(
      status: _isCancelled
          ? GenerationStatus.cancelled
          : GenerationStatus.completed,
      currentImages: List.from(allImages),
      displayImages: List.from(allImages), // 确保中央区域显示所有生成的图片
      displayWidth: baseParams.width,
      displayHeight: baseParams.height,
      progress: 1.0,
      currentImage: 0,
      totalImages: 0,
    );

    // 生成完成后刷新 Anlas 余额
    ref.read(subscriptionNotifierProvider.notifier).refreshBalance();

    // 注意：生成完成通知由 QueueExecutionNotifier 统一管理
    // 以避免循环依赖（ImageGenerationNotifier ↔ QueueExecutionNotifier）

    // 自动保存：如果启用且生成成功，保存所有图像
    if (!_isCancelled && allImages.isNotEmpty) {
      await _autoSaveIfEnabled(allImages, baseParams);
    }
  }

  /// 自动保存图像（如果启用）
  Future<void> _autoSaveIfEnabled(
    List<GeneratedImage> images,
    ImageParams params,
  ) async {
    final saveSettings = ref.read(imageSaveSettingsNotifierProvider);
    if (!saveSettings.autoSave) return;

    try {
      final saveDir = await LocalGalleryRepository.instance.getImageDirectory();
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final characterConfig = ref.read(characterPromptNotifierProvider);

      // 构建 V4 多角色提示词结构
      final charCaptions = <Map<String, dynamic>>[];
      final charNegCaptions = <Map<String, dynamic>>[];

      for (final char in characterConfig.characters
          .where((c) => c.enabled && c.prompt.isNotEmpty)) {
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
      for (final image in images) {
        try {
          // 从图片元数据中提取实际的 seed
          int actualSeed = params.seed;
          if (params.seed == -1) {
            final extractedMeta =
                await NaiMetadataParser.extractFromBytes(image.bytes);
            if (extractedMeta != null &&
                extractedMeta.seed != null &&
                extractedMeta.seed! > 0) {
              actualSeed = extractedMeta.seed!;
            } else {
              actualSeed = Random().nextInt(4294967295);
            }
          }

          final commentJson = <String, dynamic>{
            'prompt': params.prompt,
            'uc': params.negativePrompt,
            'seed': actualSeed,
            'steps': params.steps,
            'width': params.width,
            'height': params.height,
            'scale': params.scale,
            'uncond_scale': 0.0,
            'cfg_rescale': params.cfgRescale,
            'n_samples': 1,
            'noise_schedule': params.noiseSchedule,
            'sampler': params.sampler,
            'sm': params.smea,
            'sm_dyn': params.smeaDyn,
          };

          if (charCaptions.isNotEmpty) {
            commentJson['v4_prompt'] = {
              'caption': {
                'base_caption': params.prompt,
                'char_captions': charCaptions,
              },
              'use_coords': !characterConfig.globalAiChoice,
              'use_order': true,
            };
            commentJson['v4_negative_prompt'] = {
              'caption': {
                'base_caption': params.negativePrompt,
                'char_captions': charNegCaptions,
              },
              'use_coords': false,
              'use_order': false,
            };
          }

          final metadata = {
            'Description': params.prompt,
            'Software': 'NovelAI',
            'Source': _getModelSourceName(params.model),
            'Comment': jsonEncode(commentJson),
          };

          final embeddedBytes = await NaiMetadataParser.embedMetadata(
            image.bytes,
            jsonEncode(metadata),
          );

          final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
          final file = File('${saveDir.path}/$fileName');
          await file.writeAsBytes(embeddedBytes);
          savedCount++;

          // 避免文件名冲突
          await Future.delayed(const Duration(milliseconds: 2));
        } catch (e) {
          AppLogger.e('自动保存图像失败: $e');
        }
      }

      if (savedCount > 0) {
        // 刷新本地图库
        ref.read(localGalleryNotifierProvider.notifier).refresh();

        // 增量更新统计缓存，避免下次启动时完全重新计算
        try {
          final cacheService = ref.read(statisticsCacheServiceProvider);
          await cacheService.incrementImageCount(savedCount);
        } catch (e) {
          AppLogger.w('统计缓存增量更新失败: $e', 'AutoSave');
        }

        AppLogger.d('自动保存完成: $savedCount 张图像', 'AutoSave');
      }
    } catch (e) {
      AppLogger.e('自动保存失败: $e');
    }
  }

  /// 获取模型源名称
  String _getModelSourceName(String model) {
    if (model.contains('diffusion-4-5')) {
      return 'NovelAI Diffusion V4.5';
    } else if (model.contains('diffusion-4')) {
      return 'NovelAI Diffusion V4';
    } else if (model.contains('diffusion-3')) {
      return 'NovelAI Diffusion V3';
    }
    return 'NovelAI Diffusion';
  }

  /// 带重试的生成
  ///
  /// 返回 (图像列表, Vibe哈希映射)
  Future<(List<Uint8List>, Map<int, String>)> _generateWithRetry(
    ImageParams params,
  ) async {
    final apiService = ref.read(naiImageGenerationApiServiceProvider);

    for (int retry = 0; retry <= _maxRetries; retry++) {
      try {
        // 使用新的 API，返回图像和哈希映射
        return await apiService.generateImage(
          params,
          onProgress: (received, total) {
            // 单张进度暂不更新
          },
        );
      } catch (e) {
        if (_isCancelled || e.toString().contains('cancelled')) {
          rethrow;
        }

        if (retry < _maxRetries) {
          AppLogger.w(
            '生成失败，${_retryDelays[retry]}ms 后重试 (${retry + 1}/$_maxRetries): $e',
          );
          await Future.delayed(Duration(milliseconds: _retryDelays[retry]));
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
            .updateVibeReferenceV4(index, vibeEncoding: encoding);
        AppLogger.d(
          'Saved Vibe encoding for index $index (hash length: ${encoding.length})',
          'Generation',
        );
      }
    }
  }

  /// 使用流式 API 生成批次图像（支持预览）
  ///
  /// 对于多批次生成，每次生成一张图像并显示流式预览
  /// [params] 生成参数（nSamples 表示本批次要生成的数量）
  /// [currentStart] 当前批次起始图像编号
  /// [total] 总图像数量
  Future<List<Uint8List>> _generateBatchWithStream(
    ImageParams params,
    int currentStart,
    int total,
  ) async {
    final apiService = ref.read(naiImageGenerationApiServiceProvider);
    final batchSize = params.nSamples;
    final images = <Uint8List>[];
    bool useNonStreamFallback = false; // 记录是否需要回退到非流式

    // 逐张生成以支持流式预览
    for (int i = 0; i < batchSize; i++) {
      if (_isCancelled) break;

      // 更新当前进度
      state = state.copyWith(
        currentImage: currentStart + i,
        progress: (currentStart + i - 1) / total,
        clearStreamPreview: true,
      );

      // 为每张图使用不同的种子
      // seed == -1 表示随机，保持 -1 让 API 生成随机种子
      // 否则每张图使用 seed + 偏移量
      final singleParams = params.copyWith(
        nSamples: 1,
        seed: params.seed == -1 ? -1 : params.seed + i,
      );

      Uint8List? image;
      for (int retry = 0; retry <= _maxRetries; retry++) {
        try {
          // 如果已知流式不支持，直接使用非流式 API
          if (useNonStreamFallback) {
            final fallbackImages = await apiService.generateImageCancellable(
              singleParams,
              onProgress: (received, total) {},
            );
            if (fallbackImages.isNotEmpty) {
              images.add(fallbackImages.first);
              break;
            }
            continue;
          }

          final stream = apiService.generateImageStream(singleParams);
          bool streamingNotAllowed = false;

          await for (final chunk in stream) {
            if (_isCancelled) {
              return images;
            }

            if (chunk.hasError) {
              // 检测流式生成不被允许的错误，自动回退到非流式
              final errorLower = chunk.error?.toLowerCase() ?? '';
              if (errorLower.contains('streaming is not allowed') ||
                  errorLower.contains('streaming not allowed') ||
                  errorLower.contains('stream is not allowed') ||
                  errorLower.contains('stream not allowed')) {
                AppLogger.w(
                  'Streaming not allowed for this model, falling back to non-stream API for batch',
                  'Generation',
                );
                streamingNotAllowed = true;
                useNonStreamFallback = true; // 后续所有图像都使用非流式
                break;
              }
              throw Exception(chunk.error);
            }

            if (chunk.hasPreview) {
              // 更新流式预览
              state = state.copyWith(
                progress: (currentStart + i - 1 + chunk.progress) / total,
                streamPreview: chunk.previewImage,
              );
            }

            if (chunk.isComplete && chunk.hasFinalImage) {
              image = chunk.finalImage;
            }
          }

          // 如果流式不支持，重新用非流式生成当前图像
          if (streamingNotAllowed) {
            final fallbackImages = await apiService.generateImageCancellable(
              singleParams,
              onProgress: (received, total) {},
            );
            if (fallbackImages.isNotEmpty) {
              images.add(fallbackImages.first);
              break;
            }
            continue;
          }

          if (image != null) {
            images.add(image);
            break; // 成功，退出重试循环
          } else {
            // 流式 API 未返回图像，使用非流式 API
            final fallbackImages = await apiService.generateImageCancellable(
              singleParams,
              onProgress: (received, total) {},
            );
            if (fallbackImages.isNotEmpty) {
              images.add(fallbackImages.first);
              break;
            }
          }
        } catch (e) {
          if (_isCancelled || e.toString().contains('cancelled')) {
            return images;
          }

          // 检测流式生成不被允许的错误，自动回退到非流式
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('streaming is not allowed') ||
              errorStr.contains('streaming not allowed') ||
              errorStr.contains('stream is not allowed') ||
              errorStr.contains('stream not allowed')) {
            AppLogger.w(
              'Streaming not allowed for this model (exception), falling back to non-stream API for batch',
              'Generation',
            );
            useNonStreamFallback = true;
            // 用非流式重新生成当前图像
            try {
              final fallbackImages = await apiService.generateImageCancellable(
                singleParams,
                onProgress: (received, total) {},
              );
              if (fallbackImages.isNotEmpty) {
                images.add(fallbackImages.first);
              }
            } catch (fallbackError) {
              AppLogger.e('非流式回退生成失败: $fallbackError');
            }
            break;
          }

          if (retry < _maxRetries) {
            AppLogger.w(
              '生成失败，${_retryDelays[retry]}ms 后重试 (${retry + 1}/$_maxRetries): $e',
            );
            await Future.delayed(Duration(milliseconds: _retryDelays[retry]));
          } else {
            AppLogger.e('生成第 ${currentStart + i} 张图像失败: $e');
            // 继续生成下一张，不抛出异常
          }
        }
      }
    }

    return images;
  }

  /// 生成单张（使用流式 API 支持渐进式预览）
  Future<void> _generateSingle(
    ImageParams params,
    int current,
    int total,
  ) async {
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
      final stream = apiService.generateImageStream(params);

      Uint8List? finalImage;
      bool streamingNotAllowed = false;

      await for (final chunk in stream) {
        if (_isCancelled) {
          state = state.copyWith(
            status: GenerationStatus.cancelled,
            progress: 0.0,
            currentImage: 0,
            totalImages: 0,
            clearStreamPreview: true,
          );
          return;
        }

        if (chunk.hasError) {
          // 检测流式生成不被允许的错误，自动回退到非流式
          final errorLower = chunk.error?.toLowerCase() ?? '';
          if (errorLower.contains('streaming is not allowed') ||
              errorLower.contains('streaming not allowed') ||
              errorLower.contains('stream is not allowed') ||
              errorLower.contains('stream not allowed')) {
            AppLogger.w(
              'Streaming not allowed for this model, falling back to non-stream API',
              'Generation',
            );
            streamingNotAllowed = true;
            break;
          }
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
          state = state.copyWith(
            progress: chunk.progress,
            streamPreview: chunk.previewImage,
          );
        }

        if (chunk.isComplete && chunk.hasFinalImage) {
          finalImage = chunk.finalImage;
        }
      }

      // 如果流式不被支持，回退到非流式 API
      if (streamingNotAllowed) {
        final (imageBytes, vibeEncodings) = await _generateWithRetry(params);
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
          displayWidth: params.width,
          displayHeight: params.height,
          history: [...generatedList, ...state.history].take(50).toList(),
          progress: 1.0,
          currentImage: 0,
          totalImages: 0,
          clearStreamPreview: true,
        );
        // 保存 Vibe 编码哈希到状态
        if (vibeEncodings.isNotEmpty) {
          _saveVibeEncodings(vibeEncodings);
        }
        // 自动保存
        await _autoSaveIfEnabled(generatedList, params);
        return;
      }

      if (finalImage != null) {
        final generatedImage = GeneratedImage.create(
          finalImage,
          width: params.width,
          height: params.height,
        );
        state = state.copyWith(
          status: GenerationStatus.completed,
          currentImages: [generatedImage],
          displayImages: [generatedImage],
          displayWidth: params.width,
          displayHeight: params.height,
          history: [generatedImage, ...state.history].take(50).toList(),
          progress: 1.0,
          currentImage: 0,
          totalImages: 0,
          clearStreamPreview: true,
        );
        // 自动保存
        await _autoSaveIfEnabled([generatedImage], params);
      } else {
        // 流式 API 未返回图像，回退到非流式 API
        AppLogger.w(
          'Stream API returned no image, falling back to non-stream API',
          'Generation',
        );
        final (imageBytes, vibeEncodings) = await _generateWithRetry(params);
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
          displayWidth: params.width,
          displayHeight: params.height,
          history: [...generatedList, ...state.history].take(50).toList(),
          progress: 1.0,
          currentImage: 0,
          totalImages: 0,
          clearStreamPreview: true,
        );
        // 保存 Vibe 编码哈希到状态
        if (vibeEncodings.isNotEmpty) {
          _saveVibeEncodings(vibeEncodings);
        }
        // 自动保存
        await _autoSaveIfEnabled(generatedList, params);
      }
    } catch (e) {
      if (_isCancelled || e.toString().contains('cancelled')) {
        state = state.copyWith(
          status: GenerationStatus.cancelled,
          progress: 0.0,
          currentImage: 0,
          totalImages: 0,
          clearStreamPreview: true,
        );
      } else {
        // 检测流式生成不被允许的错误，自动回退到非流式
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('streaming is not allowed') ||
            errorStr.contains('streaming not allowed') ||
            errorStr.contains('stream is not allowed') ||
            errorStr.contains('stream not allowed')) {
          AppLogger.w(
            'Streaming not allowed for this model (exception), falling back to non-stream API',
            'Generation',
          );
          try {
            final (imageBytes, vibeEncodings) =
                await _generateWithRetry(params);
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
              displayWidth: params.width,
              displayHeight: params.height,
              history: [...generatedList, ...state.history].take(50).toList(),
              progress: 1.0,
              currentImage: 0,
              totalImages: 0,
              clearStreamPreview: true,
            );
            if (vibeEncodings.isNotEmpty) {
              _saveVibeEncodings(vibeEncodings);
            }
            // 自动保存
            await _autoSaveIfEnabled(generatedList, params);
            return;
          } catch (fallbackError) {
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
  }

  /// 取消生成
  void cancel() {
    _isCancelled = true;
    final apiService = ref.read(naiImageGenerationApiServiceProvider);
    apiService.cancelGeneration();

    state = state.copyWith(
      status: GenerationStatus.cancelled,
      progress: 0.0,
      currentImage: 0,
      totalImages: 0,
    );
  }

  /// 清除当前图像
  void clearCurrent() {
    state = state.copyWith(
      currentImages: [],
      status: GenerationStatus.idle,
    );
  }

  /// 清除错误
  void clearError() {
    if (state.status == GenerationStatus.error) {
      state = state.copyWith(
        status: GenerationStatus.idle,
        errorMessage: null,
      );
    }
  }

  /// 清除历史记录（包含当前批次图像）
  void clearHistory() {
    state = state.copyWith(
      currentImages: [],
      history: [],
    );
  }

  /// 将 UI 层的角色提示词配置转换为 API 层的格式
  ///
  /// [config] UI 层的角色提示词配置
  /// 返回 API 层的 CharacterPrompt 列表
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

    return enabledCharacters.map((uiChar) {
      // 计算位置字符串
      String? position;
      if (!config.globalAiChoice &&
          uiChar.positionMode == ui_character.CharacterPositionMode.custom &&
          uiChar.customPosition != null) {
        position = uiChar.customPosition!.toNaiString();
      }

      return CharacterPrompt(
        prompt: uiChar.prompt,
        negativePrompt: uiChar.negativePrompt,
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

    // 应用主提示词
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updatePrompt(result.mainPrompt);

    // 应用角色提示词
    if (result.hasCharacters && isV4Model) {
      final characterPrompts = result.toCharacterPrompts();
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

    return result.mainPrompt;
  }
}

/// 图像生成参数 Notifier
@Riverpod(keepAlive: true)
class GenerationParamsNotifier extends _$GenerationParamsNotifier {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  ImageParams build() {
    // 从本地存储加载默认参数和上次使用的参数
    final storage = ref.read(localStorageServiceProvider);

    return ImageParams(
      prompt: storage.getLastPrompt(),
      negativePrompt: storage.getLastNegativePrompt(),
      model: storage.getDefaultModel(),
      sampler: storage.getDefaultSampler(),
      steps: storage.getDefaultSteps(),
      scale: storage.getDefaultScale(),
      width: storage.getDefaultWidth(),
      height: storage.getDefaultHeight(),
      smea: storage.getLastSmea(),
      smeaDyn: storage.getLastSmeaDyn(),
      cfgRescale: storage.getLastCfgRescale(),
      noiseSchedule: storage.getLastNoiseSchedule(),
      // 从存储加载种子锁定状态
      seed: storage.getSeedLocked() && storage.getLockedSeedValue() != null
          ? storage.getLockedSeedValue()!
          : -1,
    );
  }

  // ==================== 种子锁定 ====================

  /// 获取种子是否锁定
  bool get isSeedLocked => _storage.getSeedLocked();

  /// 切换种子锁定状态
  void toggleSeedLock() {
    final wasLocked = _storage.getSeedLocked();
    final newLocked = !wasLocked;

    if (newLocked) {
      // 锁定：保存当前种子值（如果是-1则生成新种子）
      final currentSeed = state.seed;
      final seedToLock =
          currentSeed == -1 ? Random().nextInt(4294967295) : currentSeed;
      _storage.setLockedSeedValue(seedToLock);
      _storage.setSeedLocked(true);
      state = state.copyWith(seed: seedToLock);
    } else {
      // 解锁：保留当前种子值，只取消锁定状态
      _storage.setSeedLocked(false);
      _storage.setLockedSeedValue(null);
      // 触发 state 变化以刷新 UI（保持种子值不变）
      state = state.copyWith();
    }
  }

  /// 更新提示词
  void updatePrompt(String prompt) {
    state = state.copyWith(prompt: prompt);
    _storage.setLastPrompt(prompt);
  }

  /// 更新负向提示词
  void updateNegativePrompt(String negativePrompt) {
    state = state.copyWith(negativePrompt: negativePrompt);
    _storage.setLastNegativePrompt(negativePrompt);
  }

  /// 更新模型
  void updateModel(String model) {
    state = state.copyWith(model: model);
    _storage.setDefaultModel(model);
  }

  /// 更新尺寸
  void updateSize(int width, int height) {
    state = state.copyWith(width: width, height: height);
    _storage.setDefaultWidth(width);
    _storage.setDefaultHeight(height);
  }

  /// 更新步数
  void updateSteps(int steps) {
    state = state.copyWith(steps: steps);
    _storage.setDefaultSteps(steps);
  }

  /// 更新 Scale
  void updateScale(double scale) {
    state = state.copyWith(scale: scale);
    _storage.setDefaultScale(scale);
  }

  /// 更新采样器
  void updateSampler(String sampler) {
    state = state.copyWith(sampler: sampler);
    _storage.setDefaultSampler(sampler);
  }

  /// 更新种子
  void updateSeed(int seed) {
    state = state.copyWith(seed: seed);
  }

  /// 随机种子
  void randomizeSeed() {
    state = state.copyWith(seed: -1);
  }

  /// 更新 SMEA Auto (V3 模型)
  void updateSmeaAuto(bool smeaAuto) {
    state = state.copyWith(smeaAuto: smeaAuto);
  }

  /// 更新 SMEA (V3 模型)
  void updateSmea(bool smea) {
    state = state.copyWith(smea: smea);
    _storage.setLastSmea(smea);
  }

  /// 更新 SMEA DYN (V3 模型)
  void updateSmeaDyn(bool smeaDyn) {
    state = state.copyWith(smeaDyn: smeaDyn);
    _storage.setLastSmeaDyn(smeaDyn);
  }

  /// 更新 CFG Rescale
  void updateCfgRescale(double cfgRescale) {
    state = state.copyWith(cfgRescale: cfgRescale);
    _storage.setLastCfgRescale(cfgRescale);
  }

  /// 更新噪声计划
  void updateNoiseSchedule(String noiseSchedule) {
    state = state.copyWith(noiseSchedule: noiseSchedule);
    _storage.setLastNoiseSchedule(noiseSchedule);
  }

  /// 重置为默认值
  void reset() {
    final storage = ref.read(localStorageServiceProvider);

    state = ImageParams(
      model: storage.getDefaultModel(),
      sampler: storage.getDefaultSampler(),
      steps: storage.getDefaultSteps(),
      scale: storage.getDefaultScale(),
      width: storage.getDefaultWidth(),
      height: storage.getDefaultHeight(),
    );
  }

  // ==================== 生成动作 ====================

  /// 更新生成动作
  void updateAction(ImageGenerationAction action) {
    state = state.copyWith(action: action);
  }

  // ==================== img2img 参数 ====================

  /// 设置源图像
  void setSourceImage(Uint8List? image) {
    state = state.copyWith(sourceImage: image);
  }

  /// 更新强度 (img2img)
  void updateStrength(double strength) {
    state = state.copyWith(strength: strength);
  }

  /// 更新噪声 (img2img)
  void updateNoise(double noise) {
    state = state.copyWith(noise: noise);
  }

  /// 清除 img2img 设置
  void clearImg2Img() {
    state = state.copyWith(
      action: ImageGenerationAction.generate,
      sourceImage: null,
      strength: 0.7,
      noise: 0.0,
    );
  }

  // ==================== Inpainting 参数 ====================

  /// 设置蒙版图像
  void setMaskImage(Uint8List? mask) {
    state = state.copyWith(maskImage: mask);
  }

  /// 清除 Inpainting 设置
  void clearInpainting() {
    state = state.copyWith(
      action: ImageGenerationAction.generate,
      sourceImage: null,
      maskImage: null,
    );
  }

  // ==================== Vibe Transfer 参数 ====================

  /// 添加 Vibe 参考图
  /// 注意：Vibe Transfer 和角色参考互斥，添加一个会清除另一个
  void addVibeReference(VibeReference vibe) {
    if (state.vibeReferences.length >= 4) return; // 最多4张
    state = state.copyWith(
      vibeReferences: [...state.vibeReferences, vibe],
      characterReferences: [], // 互斥：清除角色参考
    );
  }

  /// 移除 Vibe 参考图
  void removeVibeReference(int index) {
    if (index < 0 || index >= state.vibeReferences.length) return;
    final newList = [...state.vibeReferences];
    newList.removeAt(index);
    state = state.copyWith(vibeReferences: newList);
  }

  /// 更新 Vibe 参考图配置
  void updateVibeReference(
    int index, {
    double? strength,
    double? informationExtracted,
  }) {
    if (index < 0 || index >= state.vibeReferences.length) return;
    final newList = [...state.vibeReferences];
    final current = newList[index];
    newList[index] = VibeReference(
      image: current.image,
      strength: strength ?? current.strength,
      informationExtracted:
          informationExtracted ?? current.informationExtracted,
    );
    state = state.copyWith(vibeReferences: newList);
  }

  /// 清除所有 Vibe 参考图
  void clearVibeReferences() {
    state = state.copyWith(vibeReferences: []);
  }

  // ==================== V4 Vibe Transfer 参数 ====================

  /// 添加 V4 Vibe 参考
  /// 支持预编码 (.naiv4vibe, PNG 带元数据) 和原始图片
  /// 注意：Vibe Transfer 和角色参考互斥，添加一个会清除另一个
  void addVibeReferenceV4(VibeReferenceV4 vibe) {
    if (state.vibeReferencesV4.length >= 16) return; // V4 支持最多 16 张
    state = state.copyWith(
      vibeReferencesV4: [...state.vibeReferencesV4, vibe],
      characterReferences: [], // 互斥：清除角色参考
    );
  }

  /// 批量添加 V4 Vibe 参考
  /// 注意：Vibe Transfer 和角色参考互斥，添加一个会清除另一个
  void addVibeReferencesV4(List<VibeReferenceV4> vibes) {
    final remaining = 16 - state.vibeReferencesV4.length;
    if (remaining <= 0) return;

    final toAdd = vibes.take(remaining).toList();
    state = state.copyWith(
      vibeReferencesV4: [...state.vibeReferencesV4, ...toAdd],
      characterReferences: [], // 互斥：清除角色参考
    );
  }

  /// 移除 V4 Vibe 参考
  void removeVibeReferenceV4(int index) {
    if (index < 0 || index >= state.vibeReferencesV4.length) return;
    final newList = [...state.vibeReferencesV4];
    newList.removeAt(index);
    state = state.copyWith(vibeReferencesV4: newList);
  }

  /// 更新 V4 Vibe 参考配置
  void updateVibeReferenceV4(
    int index, {
    double? strength,
    double? infoExtracted,
    String? vibeEncoding, // 新增：编码哈希
  }) {
    if (index < 0 || index >= state.vibeReferencesV4.length) return;
    final newList = [...state.vibeReferencesV4];
    final current = newList[index];
    newList[index] = current.copyWith(
      strength: strength ?? current.strength,
      infoExtracted: infoExtracted ?? current.infoExtracted,
      vibeEncoding: vibeEncoding ?? current.vibeEncoding,
    );
    state = state.copyWith(vibeReferencesV4: newList);
  }

  /// 清除所有 V4 Vibe 参考
  void clearVibeReferencesV4() {
    state = state.copyWith(vibeReferencesV4: []);
  }

  /// 设置 Vibe 强度标准化开关
  void setNormalizeVibeStrength(bool value) {
    state = state.copyWith(normalizeVibeStrength: value);
  }

  // ==================== 角色参考参数 (V4+ 模型) ====================

  /// 添加角色参考图
  /// 注意：角色参考最多1张，且和 Vibe Transfer 互斥
  void addCharacterReference(CharacterReference ref) {
    if (state.characterReferences.isNotEmpty) return; // 最多1张
    state = state.copyWith(
      characterReferences: [...state.characterReferences, ref],
      vibeReferences: [], // 清除 Vibe Transfer（互斥）
      vibeReferencesV4: [], // 清除 V4 Vibe Transfer（互斥）
    );
  }

  /// 移除角色参考图
  void removeCharacterReference(int index) {
    if (index < 0 || index >= state.characterReferences.length) return;
    final newList = [...state.characterReferences];
    newList.removeAt(index);
    state = state.copyWith(characterReferences: newList);
  }

  /// 更新角色参考图配置（仅支持更新描述）
  void updateCharacterReference(
    int index, {
    String? description,
  }) {
    if (index < 0 || index >= state.characterReferences.length) return;
    final newList = [...state.characterReferences];
    final current = newList[index];
    newList[index] = CharacterReference(
      image: current.image,
      description: description ?? current.description,
    );
    state = state.copyWith(characterReferences: newList);
  }

  /// 清除所有角色参考图
  void clearCharacterReferences() {
    state = state.copyWith(characterReferences: []);
  }

  /// 更新角色参考 Style Aware 开关
  void setCharacterReferenceStyleAware(bool value) {
    state = state.copyWith(characterReferenceStyleAware: value);
  }

  /// 更新角色参考 Fidelity 值
  void setCharacterReferenceFidelity(double value) {
    state = state.copyWith(characterReferenceFidelity: value.clamp(0.0, 1.0));
  }

  // ==================== 多角色参数 (V4 模型) ====================

  /// 添加角色
  void addCharacter(CharacterPrompt character) {
    if (state.characters.length >= 6) return; // 最多6个角色
    state = state.copyWith(
      characters: [...state.characters, character],
    );
  }

  /// 移除角色
  void removeCharacter(int index) {
    if (index < 0 || index >= state.characters.length) return;
    final newList = [...state.characters];
    newList.removeAt(index);
    state = state.copyWith(characters: newList);
  }

  /// 更新角色
  void updateCharacter(int index, CharacterPrompt character) {
    if (index < 0 || index >= state.characters.length) return;
    final newList = [...state.characters];
    newList[index] = character;
    state = state.copyWith(characters: newList);
  }

  /// 清除所有角色
  void clearCharacters() {
    state = state.copyWith(characters: []);
  }

  /// 更新生成数量
  void updateNSamples(int nSamples) {
    state = state.copyWith(nSamples: nSamples < 1 ? 1 : nSamples);
  }

  // ==================== 高级参数 ====================

  /// 更新 UC 预设
  void updateUcPreset(int ucPreset) {
    state = state.copyWith(ucPreset: ucPreset.clamp(0, 7));
  }

  /// 更新质量标签开关
  void updateQualityToggle(bool qualityToggle) {
    state = state.copyWith(qualityToggle: qualityToggle);
  }

  /// 更新多样性增强 (V4+)
  void updateVarietyPlus(bool varietyPlus) {
    state = state.copyWith(varietyPlus: varietyPlus);
  }

  /// 更新 Decrisp (V3 模型)
  void updateDecrisp(bool decrisp) {
    state = state.copyWith(decrisp: decrisp);
  }

  /// 更新使用坐标模式 (V4+ 多角色)
  void updateUseCoords(bool useCoords) {
    state = state.copyWith(useCoords: useCoords);
  }

  /// 更新添加原始图像
  void updateAddOriginalImage(bool addOriginalImage) {
    state = state.copyWith(addOriginalImage: addOriginalImage);
  }
}

// ==================== 标签建议 Provider ====================

/// 标签建议状态
class TagSuggestionState {
  final List<TagSuggestion> suggestions;
  final bool isLoading;
  final String? error;

  const TagSuggestionState({
    this.suggestions = const [],
    this.isLoading = false,
    this.error,
  });

  TagSuggestionState copyWith({
    List<TagSuggestion>? suggestions,
    bool? isLoading,
    String? error,
  }) {
    return TagSuggestionState(
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 标签建议 Notifier
@riverpod
class TagSuggestionNotifier extends _$TagSuggestionNotifier {
  Timer? _debounceTimer;

  @override
  TagSuggestionState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return const TagSuggestionState();
  }

  /// 获取标签建议 (带防抖)
  void fetchSuggestions(String input, {String? model}) {
    _debounceTimer?.cancel();

    if (input.trim().length < 2) {
      state = const TagSuggestionState();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      state = state.copyWith(isLoading: true, error: null);

      try {
        final apiService = ref.read(naiTagSuggestionApiServiceProvider);
        final suggestions = await apiService.suggestTags(input, model: model);
        state = state.copyWith(
          suggestions: suggestions,
          isLoading: false,
        );
      } catch (e) {
        state = state.copyWith(
          isLoading: false,
          error: e.toString(),
        );
      }
    });
  }

  /// 清除建议
  void clearSuggestions() {
    _debounceTimer?.cancel();
    state = const TagSuggestionState();
  }
}

// ==================== 图片放大 Provider ====================

/// 放大状态
enum UpscaleStatus {
  idle,
  processing,
  completed,
  error,
}

/// 放大状态
class UpscaleState {
  final UpscaleStatus status;
  final Uint8List? result;
  final String? error;
  final double progress;

  const UpscaleState({
    this.status = UpscaleStatus.idle,
    this.result,
    this.error,
    this.progress = 0.0,
  });

  UpscaleState copyWith({
    UpscaleStatus? status,
    Uint8List? result,
    String? error,
    double? progress,
  }) {
    return UpscaleState(
      status: status ?? this.status,
      result: result ?? this.result,
      error: error,
      progress: progress ?? this.progress,
    );
  }
}

/// 放大 Notifier
@riverpod
class UpscaleNotifier extends _$UpscaleNotifier {
  @override
  UpscaleState build() {
    return const UpscaleState();
  }

  /// 放大图像
  Future<void> upscale(Uint8List image, {int scale = 2}) async {
    state = state.copyWith(
      status: UpscaleStatus.processing,
      progress: 0.0,
      error: null,
      result: null,
    );

    try {
      final apiService = ref.read(naiImageEnhancementApiServiceProvider);
      final result = await apiService.upscaleImage(
        image,
        scale: scale,
        onProgress: (received, total) {
          if (total > 0) {
            state = state.copyWith(progress: received / total);
          }
        },
      );

      state = state.copyWith(
        status: UpscaleStatus.completed,
        result: result,
        progress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        status: UpscaleStatus.error,
        error: e.toString(),
        progress: 0.0,
      );
    }
  }

  /// 清除结果
  void clear() {
    state = const UpscaleState();
  }
}

/// 质量标签设置 Notifier
@Riverpod(keepAlive: true)
class QualityTagsSettings extends _$QualityTagsSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() {
    return _storage.getAddQualityTags();
  }

  /// 切换质量标签开关
  void toggle() {
    state = !state;
    _storage.setAddQualityTags(state);
  }

  /// 设置质量标签开关
  void set(bool value) {
    state = value;
    _storage.setAddQualityTags(value);
  }
}

/// 自动补全设置 Notifier
@Riverpod(keepAlive: true)
class AutocompleteSettings extends _$AutocompleteSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() {
    return _storage.getEnableAutocomplete();
  }

  /// 切换自动补全开关
  void toggle() {
    state = !state;
    _storage.setEnableAutocomplete(state);
  }

  /// 设置自动补全开关
  void set(bool value) {
    state = value;
    _storage.setEnableAutocomplete(value);
  }
}

/// 自动格式化设置 Notifier
@Riverpod(keepAlive: true)
class AutoFormatPromptSettings extends _$AutoFormatPromptSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() {
    return _storage.getAutoFormatPrompt();
  }

  /// 切换自动格式化开关
  void toggle() {
    state = !state;
    _storage.setAutoFormatPrompt(state);
  }

  /// 设置自动格式化开关
  void set(bool value) {
    state = value;
    _storage.setAutoFormatPrompt(value);
  }
}

/// 高亮强调设置 Notifier
@Riverpod(keepAlive: true)
class HighlightEmphasisSettings extends _$HighlightEmphasisSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() {
    return _storage.getHighlightEmphasis();
  }

  /// 切换高亮强调开关
  void toggle() {
    state = !state;
    _storage.setHighlightEmphasis(state);
  }

  /// 设置高亮强调开关
  void set(bool value) {
    state = value;
    _storage.setHighlightEmphasis(value);
  }
}

/// SD语法自动转换设置 Notifier
@Riverpod(keepAlive: true)
class SdSyntaxAutoConvertSettings extends _$SdSyntaxAutoConvertSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() {
    return _storage.getSdSyntaxAutoConvert();
  }

  /// 切换SD语法自动转换开关
  void toggle() {
    state = !state;
    _storage.setSdSyntaxAutoConvert(state);
  }

  /// 设置SD语法自动转换开关
  void set(bool value) {
    state = value;
    _storage.setSdSyntaxAutoConvert(value);
  }
}

/// 负面提示词预设设置 Notifier
@Riverpod(keepAlive: true)
class UcPresetSettings extends _$UcPresetSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  UcPresetType build() {
    final index = _storage.getUcPresetType();
    if (index >= 0 && index < UcPresetType.values.length) {
      return UcPresetType.values[index];
    }
    return UcPresetType.heavy; // 默认使用 Heavy
  }

  /// 设置预设类型
  void set(UcPresetType type) {
    state = type;
    _storage.setUcPresetType(type.index);
  }
}

/// 抽卡模式设置 Notifier（生成时自动随机提示词）
@Riverpod(keepAlive: true)
class RandomPromptMode extends _$RandomPromptMode {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() {
    return _storage.getRandomPromptMode();
  }

  /// 切换抽卡模式
  void toggle() {
    state = !state;
    _storage.setRandomPromptMode(state);
  }

  /// 设置抽卡模式
  void set(bool value) {
    state = value;
    _storage.setRandomPromptMode(value);
  }
}

/// 每次请求生成图片数量设置 Notifier（1-4张）
@Riverpod(keepAlive: true)
class ImagesPerRequest extends _$ImagesPerRequest {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  int build() {
    return _storage.getImagesPerRequest();
  }

  /// 设置每次请求数量
  void set(int value) {
    state = value.clamp(1, 4);
    _storage.setImagesPerRequest(state);
  }
}
