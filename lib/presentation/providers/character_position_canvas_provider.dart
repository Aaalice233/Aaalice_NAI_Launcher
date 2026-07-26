import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'prompt_maximize_provider.dart';

part 'character_position_canvas_provider.g.dart';

/// 角色位置画布开关
///
/// 打开时图像预览区变成位置画布：在预览图上直接拖动角色锚点设置构图位置。
/// 经典布局的提示词全屏编辑模式会遮住预览区，打开画布时强制退出全屏，
/// 保证画布可见。
@riverpod
class CharacterPositionCanvas extends _$CharacterPositionCanvas {
  @override
  bool build() => false;

  void open() {
    // 全屏编辑遮住预览区，先退出（官网式布局无全屏概念，调用无害）
    ref.read(promptMaximizeNotifierProvider.notifier).setMaximized(false);
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
