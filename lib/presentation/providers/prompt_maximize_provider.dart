import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'prompt_maximize_provider.g.dart';

/// 提示词编辑区域最大化状态 Provider
///
/// 管理桌面布局中提示词输入区域的最大化状态。
/// 使用 Riverpod 状态管理，确保主题切换等场景下状态不丢失。
@riverpod
class PromptMaximizeNotifier extends _$PromptMaximizeNotifier {
  @override
  bool build() {
    // 默认不最大化
    return false;
  }

  /// 切换最大化状态
  void toggle() {
    state = !state;
  }

  /// 设置最大化状态
  void setMaximized(bool value) {
    state = value;
  }

  /// 重置为非最大化状态
  void reset() {
    state = false;
  }
}
