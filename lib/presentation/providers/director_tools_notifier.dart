import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/encoded_image_dimensions.dart';
import '../../core/services/anlas_calculator.dart';
import '../../core/services/pixel_snap/pixel_snap_options.dart';
import '../../core/services/pixel_snap/pixel_snap_progress.dart';
import '../../core/services/pixel_snap/pixel_snap_service.dart';
import '../../data/datasources/remote/nai_image_enhancement_api_service.dart';
import '../../data/models/director/director_emotion.dart';
import '../../data/models/director/director_tool_output.dart';
import '../../data/models/director/director_tool_type.dart';
import '../../data/services/auth_provider.dart';
import 'image_generation_provider.dart';
import 'subscription_provider.dart';

/// Emotion 预设
///
/// NAI augment API 要求 emotion prompt 格式为 `{mood};;{tags}`。
/// [emotion] 决定 API 识别的情绪关键词，[extraTags] 是附加提示词。
class EmotionPreset {
  const EmotionPreset(this.emotion, [this.extraTags = '']);
  final DirectorEmotion emotion;
  final String extraTags;

  String get mood => emotion.mood;
}

const emotionPresets = [
  EmotionPreset(DirectorEmotion.neutral),
  EmotionPreset(DirectorEmotion.happy, 'smile'),
  EmotionPreset(DirectorEmotion.sad, 'crying'),
  EmotionPreset(DirectorEmotion.angry, 'furrowed brow'),
  EmotionPreset(DirectorEmotion.scared),
  EmotionPreset(DirectorEmotion.surprised, 'open mouth, wide eyes'),
  EmotionPreset(DirectorEmotion.tired),
  EmotionPreset(DirectorEmotion.excited),
  EmotionPreset(DirectorEmotion.nervous),
  EmotionPreset(DirectorEmotion.thinking),
  EmotionPreset(DirectorEmotion.confused),
  EmotionPreset(DirectorEmotion.shy, 'blush, embarrassed, looking away'),
  EmotionPreset(DirectorEmotion.disgusted),
  EmotionPreset(DirectorEmotion.smug, 'half-closed eyes'),
  EmotionPreset(DirectorEmotion.bored),
  EmotionPreset(DirectorEmotion.laughing, 'open mouth'),
  EmotionPreset(DirectorEmotion.irritated),
  EmotionPreset(DirectorEmotion.aroused),
  EmotionPreset(DirectorEmotion.embarrassed),
  EmotionPreset(DirectorEmotion.worried),
  EmotionPreset(DirectorEmotion.love, 'heart'),
  EmotionPreset(DirectorEmotion.determined),
  EmotionPreset(DirectorEmotion.hurt),
  EmotionPreset(DirectorEmotion.playful, 'wink'),
];

class DirectorToolsState {
  const DirectorToolsState({
    this.selectedTool = DirectorToolType.removeBackground,
    this.defry = 0,
    this.prompt = '',
    this.isRunning = false,
    this.results = const [],
    this.selectedResultIndex = 0,
    this.error,
    this.sourceImage,
    this.imageWidth = 0,
    this.imageHeight = 0,
    this.pixelSnap = const PixelSnapOptions(),
    this.progress,
    this.pixelSnapResult,
    this.errorCause,
  });

  final DirectorToolType selectedTool;
  final int defry;
  final String prompt;
  final bool isRunning;

  /// 本次运行的全部结果，按服务端返回顺序排列；只有背景移除会多于一张。
  final List<DirectorToolImage> results;
  final int selectedResultIndex;
  final String? error;
  final Uint8List? sourceImage;
  final int imageWidth;
  final int imageHeight;

  final PixelSnapOptions pixelSnap;

  /// 本地计算的进度，仅 Pixel Snap 运行时非空。
  final PixelSnapProgress? progress;

  /// Pixel Snap 的结果元信息，用于结果区展示像素块数与色数。
  final PixelSnapOutput? pixelSnapResult;

  /// 原始异常对象。UI 靠它把已知失败翻成本地化文案，[error] 只是兜底文本。
  final Object? errorCause;

  DirectorToolImage? get selectedResult {
    if (results.isEmpty) return null;
    return results[selectedResultIndex.clamp(0, results.length - 1)];
  }

  /// 预览、对比、回填源图与回传调用方统一使用当前选中的那张。
  Uint8List? get result => selectedResult?.bytes;

  int estimatedAnlasCost({bool isOpus = false}) {
    if (selectedTool.runsLocally) return 0;
    if (imageWidth == 0 || imageHeight == 0) return 0;
    return AnlasCalculator.calculateAugmentCost(
      width: imageWidth,
      height: imageHeight,
      isBgRemoval: selectedTool == DirectorToolType.removeBackground,
      isOpus: isOpus,
    );
  }

  DirectorToolsState copyWith({
    DirectorToolType? selectedTool,
    int? defry,
    String? prompt,
    bool? isRunning,
    List<DirectorToolImage>? results,
    int? selectedResultIndex,
    String? error,
    Uint8List? sourceImage,
    int? imageWidth,
    int? imageHeight,
    PixelSnapOptions? pixelSnap,
    PixelSnapProgress? progress,
    PixelSnapOutput? pixelSnapResult,
    Object? errorCause,
    bool clearResult = false,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return DirectorToolsState(
      selectedTool: selectedTool ?? this.selectedTool,
      defry: defry ?? this.defry,
      prompt: prompt ?? this.prompt,
      isRunning: isRunning ?? this.isRunning,
      results: clearResult ? const [] : (results ?? this.results),
      selectedResultIndex: clearResult
          ? 0
          : (selectedResultIndex ?? this.selectedResultIndex),
      error: clearError ? null : (error ?? this.error),
      sourceImage: sourceImage ?? this.sourceImage,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      pixelSnap: pixelSnap ?? this.pixelSnap,
      progress: clearProgress ? null : (progress ?? this.progress),
      pixelSnapResult: clearResult
          ? null
          : (pixelSnapResult ?? this.pixelSnapResult),
      errorCause: clearError ? null : (errorCause ?? this.errorCause),
    );
  }
}

/// 一次结果登记中没能存进图库的结果序号，序号与 [DirectorToolsState.results] 对应。
@immutable
class DirectorResultRegistration {
  const DirectorResultRegistration({
    required this.total,
    required this.selectedIndex,
    this.failedIndices = const {},
  });

  final int total;
  final int selectedIndex;
  final Set<int> failedIndices;

  int get failedCount => failedIndices.length;

  bool get succeeded => failedIndices.isEmpty;

  bool get allFailed => total > 0 && failedCount == total;

  bool get selectedFailed => failedIndices.contains(selectedIndex);
}

final directorToolsNotifierProvider =
    NotifierProvider<DirectorToolsNotifier, DirectorToolsState>(
      DirectorToolsNotifier.new,
    );

class DirectorToolsNotifier extends Notifier<DirectorToolsState> {
  @override
  DirectorToolsState build() => const DirectorToolsState();

  Future<void> init(Uint8List sourceImage, {String? initialPrompt}) async {
    state = DirectorToolsState(
      sourceImage: sourceImage,
      prompt: initialPrompt ?? '',
    );
    await _resolveImageDimensions(sourceImage);
  }

  Future<void> _resolveImageDimensions(Uint8List bytes) async {
    try {
      final (w, h) = await readEncodedImageDimensions(
        await ui.ImmutableBuffer.fromUint8List(bytes),
      );
      state = state.copyWith(imageWidth: w, imageHeight: h);
    } catch (e) {
      AppLogger.d(
        'Failed to resolve director tool image dimensions: $e',
        'DirectorTools',
      );
    }
  }

  void selectTool(DirectorToolType tool) {
    state = state.copyWith(
      selectedTool: tool,
      clearResult: true,
      clearError: true,
    );
  }

  void updateDefry(int value) {
    state = state.copyWith(defry: value.clamp(0, 5));
  }

  void updatePrompt(String value) {
    state = state.copyWith(prompt: value);
  }

  /// 改参数不清结果：旧结果只是不再对应当前参数，本身仍然是一张有效输出。
  /// 与 [updateDefry]、[updatePrompt] 保持一致，真正该清的是切换工具和重新运行。
  void updatePixelSnapOptions(PixelSnapOptions options) {
    state = state.copyWith(pixelSnap: options);
  }

  PixelSnapCancellation? _pixelSnapCancellation;

  /// 取消正在跑的 Pixel Snap。其它工具没有取消入口。
  void cancelRun() => _pixelSnapCancellation?.cancel();

  /// 当前选中的 emotion preset（null 表示自定义）
  EmotionPreset? _activePreset;
  EmotionPreset? get activePreset => _activePreset;

  void applyEmotionPreset(EmotionPreset preset) {
    _activePreset = preset;
    state = state.copyWith(prompt: preset.extraTags);
  }

  Future<void> runTool() async {
    final source = state.sourceImage;
    if (source == null) return;
    // 门禁只拦要发请求、要扣 Anlas 的工具，本机工具与马赛克/水印编辑器一样直接放行。
    if (!state.selectedTool.runsLocally &&
        !requireAuthenticatedAction(ref, AuthPromptReason.directorTools)) {
      return;
    }

    state = state.copyWith(
      isRunning: true,
      clearError: true,
      clearResult: true,
      clearProgress: true,
    );

    if (state.selectedTool == DirectorToolType.pixelSnap) {
      await _runPixelSnap(source);
      return;
    }

    try {
      final service = ref.read(naiImageEnhancementApiServiceProvider);
      final prompt = state.prompt.trim();
      final defry = state.defry;

      final DirectorToolOutput output;
      switch (state.selectedTool) {
        case DirectorToolType.removeBackground:
          output = await service.removeBackground(source);
        case DirectorToolType.extractLineArt:
          output = await service.extractLineArt(source);
        case DirectorToolType.toSketch:
          output = await service.toSketch(source);
        case DirectorToolType.colorize:
          output = await service.colorize(
            source,
            prompt: prompt.isEmpty ? null : prompt,
            defry: defry,
          );
        case DirectorToolType.fixEmotion:
          final emotionPrompt = _buildEmotionPrompt(prompt);
          output = await service.fixEmotion(
            source,
            prompt: emotionPrompt,
            defry: defry,
          );
        case DirectorToolType.declutter:
          output = await service.declutter(source);
        case DirectorToolType.pixelSnap:
          // 上面已经分流，这里只是让 switch 保持穷举。
          return;
      }

      state = state.copyWith(
        results: output.images,
        selectedResultIndex: 0,
        isRunning: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isRunning: false);
    } finally {
      ref
          .read(subscriptionNotifierProvider.notifier)
          .schedulePostBillingRefresh();
    }
  }

  /// Pixel Snap 走本机计算，不碰订阅也不触发计费刷新。
  Future<void> _runPixelSnap(Uint8List source) async {
    final cancellation = PixelSnapCancellation();
    _pixelSnapCancellation = cancellation;
    try {
      final output = await const PixelSnapService().run(
        source,
        state.pixelSnap,
        cancellation: cancellation,
        onProgress: (progress) {
          if (!state.isRunning) return;
          state = state.copyWith(progress: progress);
        },
      );
      state = state.copyWith(
        results: DirectorToolOutput.single(output.pngBytes).images,
        selectedResultIndex: 0,
        pixelSnapResult: output,
        isRunning: false,
        clearProgress: true,
      );
    } on PixelSnapCancelledException {
      state = state.copyWith(isRunning: false, clearProgress: true);
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        errorCause: e,
        isRunning: false,
        clearProgress: true,
      );
    } finally {
      _pixelSnapCancellation = null;
    }
  }

  /// 构建 emotion 工具的 prompt，格式: `{mood};;{tags}`
  String _buildEmotionPrompt(String userPrompt) {
    final mood = _activePreset?.mood ?? DirectorEmotion.neutral.mood;
    return '$mood;;$userPrompt';
  }

  void selectResult(int index) {
    if (index < 0 || index >= state.results.length) return;
    if (index == state.selectedResultIndex) return;
    state = state.copyWith(selectedResultIndex: index);
  }

  /// 每张结果都进历史和图库，与官网开自动下载时逐张保存一致；
  /// 某张失败不连累其余几张，失败的序号交给调用方提示用户。
  Future<DirectorResultRegistration> registerResult() async {
    final results = state.results;
    final selectedIndex = state.selectedResultIndex;
    if (results.isEmpty) {
      return DirectorResultRegistration(total: 0, selectedIndex: selectedIndex);
    }
    var saveParams = ref.read(generationParamsNotifierProvider);
    if (state.selectedTool.needsPrompt && state.prompt.isNotEmpty) {
      saveParams = saveParams.copyWith(prompt: state.prompt);
    }
    final generation = ref.read(imageGenerationNotifierProvider.notifier);
    // 同一次处理的几张共用一个时刻，按时间命名时文件名只差后缀。
    final createdAt = DateTime.now();
    final failedIndices = <int>{};
    // 历史按登记先后倒排，逆序登记才能让第 0 张排在最前。
    for (var index = results.length - 1; index >= 0; index--) {
      final image = results[index];
      try {
        final savedPath = await generation.registerExternalImage(
          image.bytes,
          params: saveParams,
          saveToLocal: true,
          fileNameSuffix: image.fileNameSuffix,
          createdAt: createdAt,
          // 与 DLSS 增强、NovelAI 超分一致：加工结果顶替当前展示图，
          // 否则它只进历史，会排在仍占着当前区的原图下面。
          replaceCurrentDisplay: index == selectedIndex,
        );
        // 落盘失败只在保存层记日志，返回的路径为空是唯一信号。
        if (savedPath == null) failedIndices.add(index);
      } catch (error, stackTrace) {
        failedIndices.add(index);
        AppLogger.e(
          'Failed to register director tool result ${index + 1}',
          error,
          stackTrace,
          'DirectorTools',
        );
      }
    }
    return DirectorResultRegistration(
      total: results.length,
      selectedIndex: selectedIndex,
      failedIndices: Set.unmodifiable(failedIndices),
    );
  }

  void applyResultAsSource() {
    if (state.result == null) return;
    final newSource = state.result!;
    state = state.copyWith(
      sourceImage: newSource,
      clearResult: true,
      clearError: true,
    );
    _resolveImageDimensions(newSource);
  }

  void clearResult() {
    state = state.copyWith(clearResult: true, clearError: true);
  }
}
