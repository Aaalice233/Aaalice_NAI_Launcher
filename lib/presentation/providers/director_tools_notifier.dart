import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../core/services/anlas_calculator.dart';
import '../../core/services/pixel_snap/pixel_snap_options.dart';
import '../../core/services/pixel_snap/pixel_snap_progress.dart';
import '../../core/services/pixel_snap/pixel_snap_service.dart';
import '../../data/datasources/remote/nai_image_enhancement_api_service.dart';
import '../../data/models/director/director_tool_type.dart';
import '../../data/services/auth_provider.dart';
import 'image_generation_provider.dart';
import 'subscription_provider.dart';

/// Emotion 预设
///
/// NAI augment API 要求 emotion prompt 格式为 `{mood};;{tags}`。
/// [mood] 是 API 识别的情绪关键词，[extraTags] 是附加提示词。
class EmotionPreset {
  const EmotionPreset(this.label, this.mood, [this.extraTags = '']);
  final String label;
  final String mood;
  final String extraTags;
}

const emotionPresets = [
  EmotionPreset('Neutral', 'neutral'),
  EmotionPreset('Happy', 'happy', 'smile'),
  EmotionPreset('Laugh', 'laughing', 'open mouth'),
  EmotionPreset('Sad', 'sad', 'crying'),
  EmotionPreset('Angry', 'angry', 'furrowed brow'),
  EmotionPreset('Surprised', 'surprised', 'open mouth, wide eyes'),
  EmotionPreset('Shy', 'shy', 'blush, embarrassed, looking away'),
  EmotionPreset('Excited', 'excited'),
  EmotionPreset('Disgusted', 'disgusted'),
  EmotionPreset('Smug', 'smug', 'half-closed eyes'),
  EmotionPreset('Worried', 'worried'),
  EmotionPreset('Love', 'love', 'heart'),
  EmotionPreset('Playful', 'playful', 'wink'),
  EmotionPreset('Tired', 'tired'),
];

class DirectorToolsState {
  const DirectorToolsState({
    this.selectedTool = DirectorToolType.removeBackground,
    this.defry = 0,
    this.prompt = '',
    this.isRunning = false,
    this.result,
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
  final Uint8List? result;
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
    Uint8List? result,
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
      result: clearResult ? null : (result ?? this.result),
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
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      codec.dispose();
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

      final Uint8List result;
      switch (state.selectedTool) {
        case DirectorToolType.removeBackground:
          result = await service.removeBackground(source);
        case DirectorToolType.extractLineArt:
          result = await service.extractLineArt(source);
        case DirectorToolType.toSketch:
          result = await service.toSketch(source);
        case DirectorToolType.colorize:
          result = await service.colorize(
            source,
            prompt: prompt.isEmpty ? null : prompt,
            defry: defry,
          );
        case DirectorToolType.fixEmotion:
          final emotionPrompt = _buildEmotionPrompt(prompt);
          result = await service.fixEmotion(
            source,
            prompt: emotionPrompt,
            defry: defry,
          );
        case DirectorToolType.declutter:
          result = await service.declutter(source);
        case DirectorToolType.pixelSnap:
          // 上面已经分流，这里只是让 switch 保持穷举。
          return;
      }

      state = state.copyWith(result: result, isRunning: false);
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
        result: output.pngBytes,
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
    final mood = _activePreset?.mood ?? 'neutral';
    return '$mood;;$userPrompt';
  }

  Future<void> registerResult() async {
    if (state.result == null) return;
    var saveParams = ref.read(generationParamsNotifierProvider);
    if (state.selectedTool.needsPrompt && state.prompt.isNotEmpty) {
      saveParams = saveParams.copyWith(prompt: state.prompt);
    }
    await ref
        .read(imageGenerationNotifierProvider.notifier)
        .registerExternalImage(
          state.result!,
          params: saveParams,
          saveToLocal: true,
          // 与 DLSS 增强、NovelAI 超分一致：加工结果顶替当前展示图，
          // 否则它只进历史，会排在仍占着当前区的原图下面。
          replaceCurrentDisplay: true,
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
