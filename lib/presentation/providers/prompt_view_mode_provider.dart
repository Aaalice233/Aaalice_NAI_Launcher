import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';
import '../widgets/prompt/unified/unified_prompt_config.dart'
    show PromptViewMode;

part 'prompt_view_mode_provider.g.dart';

/// 全局提示词视图模式 Provider
///
/// 管理所有提示词输入框的视图模式状态（文本/标签）。
/// 主界面工具栏控制此 Provider，角色提示词编辑器读取此状态。
///
/// Requirements: 2.3, 4.1, 4.4
@riverpod
class PromptViewModeNotifier extends _$PromptViewModeNotifier {
  static const String _storageKey = 'prompt_view_mode';

  @override
  PromptViewMode build() {
    // 从本地存储加载视图模式
    final storage = ref.read(localStorageServiceProvider);
    final index = storage.getSetting<int>(_storageKey);

    if (index != null && index >= 0 && index < PromptViewMode.values.length) {
      return PromptViewMode.values[index];
    }

    return PromptViewMode.text; // 默认文本模式
  }

  /// 设置视图模式
  Future<void> setViewMode(PromptViewMode mode) async {
    state = mode;

    // 保存到本地存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setSetting(_storageKey, mode.index);
  }

  /// 切换视图模式
  Future<void> toggle() async {
    final newMode = state == PromptViewMode.text
        ? PromptViewMode.tags
        : PromptViewMode.text;
    await setViewMode(newMode);
  }
}
