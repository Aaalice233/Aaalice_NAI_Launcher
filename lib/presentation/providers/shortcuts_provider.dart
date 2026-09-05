import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/shortcuts/default_shortcuts.dart';
import '../../core/shortcuts/shortcut_config.dart';
import '../../core/shortcuts/shortcut_key_mapping.dart';
import '../../core/shortcuts/shortcut_storage.dart';

part 'shortcuts_provider.g.dart';

/// 快捷键存储Provider
@Riverpod(keepAlive: true)
ShortcutStorage shortcutStorage(Ref ref) {
  return ShortcutStorage();
}

/// 快捷键配置Provider
@Riverpod(keepAlive: true)
class ShortcutConfigNotifier extends _$ShortcutConfigNotifier {
  ShortcutStorage? _storage;

  @override
  Future<ShortcutConfig> build() async {
    // 初始化时从存储加载
    _storage = ref.read(shortcutStorageProvider);
    await _storage!.init();
    return await _storage!.loadConfig();
  }

  /// 获取当前状态（用于同步访问）
  ShortcutConfig get currentState {
    return state.valueOrNull ?? ShortcutConfig.createDefault();
  }

  /// 初始化存储（在main.dart中调用）
  Future<void> init() async {
    _storage ??= ref.read(shortcutStorageProvider);
    await _storage!.init();
    final config = await _storage!.loadConfig();
    state = AsyncValue.data(config);
  }

  /// 更新快捷键绑定
  Future<void> updateBinding(ShortcutBinding binding) async {
    final newState = currentState.updateBinding(binding);
    state = AsyncValue.data(newState);
    await _save();
  }

  /// 设置自定义快捷键
  Future<void> setCustomShortcut(String id, String? shortcut) async {
    final newState = currentState.setCustomShortcut(id, shortcut);
    state = AsyncValue.data(newState);
    await _save();
  }

  /// 启用/禁用快捷键
  Future<void> setEnabled(String id, bool enabled) async {
    final newState = currentState.setEnabled(id, enabled);
    state = AsyncValue.data(newState);
    await _save();
  }

  /// 重置指定快捷键为默认
  Future<void> resetToDefault(String id) async {
    final newState = currentState.resetToDefault(id);
    state = AsyncValue.data(newState);
    await _save();
  }

  /// 重置所有快捷键为默认
  Future<void> resetAllToDefault() async {
    final newState = currentState.resetAllToDefault();
    state = AsyncValue.data(newState);
    await _save();
  }

  /// 更新全局设置
  Future<void> updateSettings({
    bool? showShortcutBadges,
    bool? showShortcutInTooltip,
    bool? enableShortcuts,
    bool? showInMenus,
  }) async {
    final newState = currentState.copyWith(
      showShortcutBadges: showShortcutBadges ?? currentState.showShortcutBadges,
      showShortcutInTooltip:
          showShortcutInTooltip ?? currentState.showShortcutInTooltip,
      enableShortcuts: enableShortcuts ?? currentState.enableShortcuts,
      showInMenus: showInMenus ?? currentState.showInMenus,
    );
    state = AsyncValue.data(newState);
    await _save();
  }

  /// 检查快捷键是否有冲突
  List<String> findConflicts(
    String shortcut, {
    required ShortcutContext context,
    String? excludeId,
  }) {
    return currentState.findConflicts(
      shortcut,
      context: context,
      excludeId: excludeId,
    );
  }

  /// 获取指定ID的有效快捷键
  String? getEffectiveShortcut(String id) {
    if (!currentState.enableShortcuts) return null;
    return currentState.getEffectiveShortcut(id);
  }

  /// 导出配置
  Future<String> exportConfig() async {
    if (_storage == null) return '';
    return await _storage!.exportConfig();
  }

  /// 导入配置
  Future<void> importConfig(String jsonString) async {
    if (_storage == null) return;
    final config = await _storage!.importConfig(jsonString);
    state = AsyncValue.data(config);
  }

  /// 保存到存储
  Future<void> _save() async {
    if (_storage == null) return;
    await _storage!.saveConfig(currentState);
  }
}

/// 快捷键绑定编辑状态
@riverpod
class ShortcutEditingNotifier extends _$ShortcutEditingNotifier {
  @override
  String? build() => null;

  /// 开始编辑
  void startEditing(String shortcutId) {
    state = shortcutId;
  }

  /// 取消编辑
  void cancelEditing() {
    state = null;
  }
}

/// 快捷键冲突检测Provider
@riverpod
List<String> shortcutConflicts(
  Ref ref,
  String shortcut,
  ShortcutContext context,
  String? excludeId,
) {
  final configAsync = ref.watch(shortcutConfigNotifierProvider);
  return configAsync.when(
    data: (config) =>
        config.findConflicts(shortcut, context: context, excludeId: excludeId),
    loading: () => [],
    error: (_, __) => [],
  );
}

/// 获取指定ID的有效快捷键
@riverpod
String? effectiveShortcut(Ref ref, String id) {
  final configAsync = ref.watch(shortcutConfigNotifierProvider);
  return configAsync.when(
    data: (config) {
      if (!config.enableShortcuts) return null;
      return config.getEffectiveShortcut(id);
    },
    loading: () => null,
    error: (_, __) => null,
  );
}

/// 按上下文分组的快捷键
@riverpod
Map<ShortcutContext, List<ShortcutBinding>> shortcutsByContext(Ref ref) {
  final configAsync = ref.watch(shortcutConfigNotifierProvider);
  return configAsync.when(
    data: (config) => config.getBindingsByContext(),
    loading: () => {},
    error: (_, __) => {},
  );
}

/// 搜索快捷键
@riverpod
List<ShortcutBinding> searchShortcuts(Ref ref, String query) {
  final configAsync = ref.watch(shortcutConfigNotifierProvider);
  return configAsync.when(
    data: (config) {
      if (query.isEmpty) return config.bindings.values.toList();
      return config.search(query);
    },
    loading: () => [],
    error: (_, __) => [],
  );
}

/// 快捷键帮助对话框显示状态
@riverpod
class ShortcutHelpDialogNotifier extends _$ShortcutHelpDialogNotifier {
  @override
  bool build() => false;

  void show() => state = true;
  void hide() => state = false;
  void toggle() => state = !state;
}

/// 获取特定上下文的快捷键映射
/// 用于构建Shortcuts widget
Map<ShortcutActivator, VoidCallback> buildContextShortcuts(
  BuildContext buildContext,
  WidgetRef ref,
  ShortcutContext contextType,
  Map<String, VoidCallback> actionMap,
) {
  final config = ref.read(shortcutConfigNotifierProvider.notifier).currentState;
  final result = <ShortcutActivator, VoidCallback>{};

  if (!config.enableShortcuts) return result;

  for (final entry in actionMap.entries) {
    final shortcutId = entry.key;
    final callback = entry.value;

    final binding = config.bindings[shortcutId];
    if (binding == null) continue;
    if (!binding.enabled) continue;
    if (binding.context != ShortcutContext.global &&
        binding.context != contextType) {
      continue;
    }

    final shortcut = binding.effectiveShortcut;
    if (shortcut == null || shortcut.isEmpty) continue;

    final parsed = ShortcutParser.parse(shortcut);
    if (parsed == null) continue;

    final activator = SingleActivator(
      parsed.key.logicalKeyboardKey,
      control: parsed.modifiers.contains(ShortcutModifier.control),
      alt: parsed.modifiers.contains(ShortcutModifier.alt),
      shift: parsed.modifiers.contains(ShortcutModifier.shift),
      meta: parsed.modifiers.contains(ShortcutModifier.meta),
    );

    result[activator] = callback;
  }

  return result;
}
