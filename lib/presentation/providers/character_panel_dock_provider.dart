import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';

part 'character_panel_dock_provider.g.dart';

/// 多角色面板停靠状态 Provider
///
/// 管理多角色提示词面板在中央图像区域的停靠显示状态。
/// - true: 面板停靠在中央区域，覆盖图像预览
/// - false: 面板以对话框形式显示（默认）
///
/// 与提示词全屏模式互斥：当提示词全屏时自动退出停靠模式
@riverpod
class CharacterPanelDock extends _$CharacterPanelDock {
  @override
  bool build() {
    // 从本地存储加载停靠状态
    final storage = ref.read(localStorageServiceProvider);
    return storage.getCharacterPanelDocked();
  }

  /// 切换停靠状态
  Future<void> toggle() async {
    final newValue = !state;
    state = newValue;

    // 保存到本地存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setCharacterPanelDocked(newValue);
  }

  /// 设置停靠状态
  Future<void> setDocked(bool value) async {
    state = value;

    // 保存到本地存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setCharacterPanelDocked(value);
  }

  /// 退出停靠模式
  Future<void> undock() async {
    state = false;

    // 保存到本地存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setCharacterPanelDocked(false);
  }
}
