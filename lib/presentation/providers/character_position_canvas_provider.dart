import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/image/image_params.dart';
import 'character_prompt_provider.dart';
import 'generation_layout_mode_provider.dart';
import 'image_generation_provider.dart';
import 'prompt_maximize_provider.dart';

part 'character_position_canvas_provider.g.dart';

bool isCharacterPositionCanvasAvailable({
  required bool isV4Model,
  required bool hasCharacters,
  required bool isGenerating,
  required bool hasError,
}) {
  return isV4Model && hasCharacters && !isGenerating && !hasError;
}

/// 位置画布仅在 V4、多角色且未生成/报错时可占用预览区。
final characterPositionCanvasAvailableProvider = Provider<bool>((ref) {
  final isV4Model = ref.watch(
    generationParamsNotifierProvider.select((params) => params.isV4Model),
  );
  final hasCharacters = ref.watch(
    characterPromptNotifierProvider.select(
      (config) => config.characters.isNotEmpty,
    ),
  );
  final generationState = ref.watch(
    imageGenerationNotifierProvider.select(
      (state) => (state.isGenerating, state.status == GenerationStatus.error),
    ),
  );
  return isCharacterPositionCanvasAvailable(
    isV4Model: isV4Model,
    hasCharacters: hasCharacters,
    isGenerating: generationState.$1,
    hasError: generationState.$2,
  );
});

/// 角色位置画布开关
///
/// 打开时图像预览区变成位置画布：在预览图上直接拖动角色锚点设置构图位置。
/// 经典布局的提示词全屏编辑模式会遮住预览区，打开画布时强制退出全屏，
/// 保证画布可见。
@riverpod
class CharacterPositionCanvas extends _$CharacterPositionCanvas {
  @override
  bool build() {
    ref.listen<bool>(characterPositionCanvasAvailableProvider, (_, available) {
      if (!available && state) {
        state = false;
      }
    });
    return false;
  }

  void open() {
    if (!ref.read(characterPositionCanvasAvailableProvider)) {
      state = false;
      return;
    }

    final layoutMode = ref.read(generationLayoutModeNotifierProvider);
    final promptMaximized = ref.read(promptMaximizeNotifierProvider);
    if (layoutMode == GenerationLayoutMode.classic && promptMaximized) {
      unawaited(
        ref.read(promptMaximizeNotifierProvider.notifier).setMaximized(false),
      );
    }
    state = true;
  }

  void close() {
    state = false;
  }

  void toggle() {
    if (state) {
      close();
    } else {
      open();
    }
  }
}
