import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../core/services/anlas_calculator.dart';
import '../../data/datasources/remote/nai_image_enhancement_api_service.dart';
import '../../data/models/director/director_tool_type.dart';
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

  int estimatedAnlasCost({bool isOpus = false}) {
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
    bool clearResult = false,
    bool clearError = false,
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
    _resolveImageDimensions(sourceImage);
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

    state = state.copyWith(
      isRunning: true,
      clearError: true,
      clearResult: true,
    );

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
