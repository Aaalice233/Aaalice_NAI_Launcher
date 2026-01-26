import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';

part 'prompt_maximize_provider.g.dart';

/// 提示词编辑区域最大化状态 Provider
///
/// 管理桌面布局中提示词输入区域的最大化状态。
/// 使用 Riverpod 状态管理，确保主题切换等场景下状态不丢失。
@riverpod
class PromptMaximizeNotifier extends _$PromptMaximizeNotifier {
  @override
  bool build() {
    // 从本地存储加载最大化状态
    final storage = ref.read(localStorageServiceProvider);
    return storage.getPromptMaximized();
  }

  /// 切换最大化状态
  Future<void> toggle() async {
    final newValue = !state;
    state = newValue;

    // 保存到本地存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setPromptMaximized(newValue);
  }

  /// 设置最大化状态
  Future<void> setMaximized(bool value) async {
    state = value;

    // 保存到本地存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setPromptMaximized(value);
  }

  /// 重置为非最大化状态
  Future<void> reset() async {
    state = false;

    // 保存到本地存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setPromptMaximized(false);
  }
}
