import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../core/shortcuts/shortcut_config.dart';
import '../../../core/shortcuts/shortcut_key_mapping.dart';
import '../../providers/shortcuts_provider.dart';

/// 快捷键感知包装器
/// 自动处理快捷键的注册和注销
class ShortcutAwareWidget extends ConsumerStatefulWidget {
  /// 子组件
  final Widget child;

  /// 当前上下文类型
  final ShortcutContext contextType;

  /// 快捷键动作映射
  /// key: 快捷键ID, value: 回调函数
  final Map<String, VoidCallback> shortcuts;

  /// 是否自动聚焦
  final bool autofocus;

  /// 焦点节点（可选）
  final FocusNode? focusNode;

  const ShortcutAwareWidget({
    super.key,
    required this.child,
    required this.contextType,
    required this.shortcuts,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  ConsumerState<ShortcutAwareWidget> createState() => _ShortcutAwareWidgetState();
}

class _ShortcutAwareWidgetState extends ConsumerState<ShortcutAwareWidget> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 从 Provider 读取用户配置
    final config = ref.watch(shortcutConfigNotifierProvider);

    return config.when(
      data: (config) => _buildWithConfig(context, config),
      loading: () => _buildWithDefaultShortcuts(),
      error: (_, __) => _buildWithDefaultShortcuts(),
    );
  }

  /// 使用用户配置构建
  Widget _buildWithConfig(BuildContext context, ShortcutConfig config) {
    // 如果禁用快捷键，使用 FocusScope 包裹子组件以确保焦点管理一致
    if (!config.enableShortcuts) {
      return FocusScope(
        autofocus: widget.autofocus,
        child: widget.child,
      );
    }

    // 构建快捷键映射（使用 Shortcuts widget 的 Map 格式）
    final shortcutsMap = <LogicalKeySet, Intent>{};

    for (final entry in widget.shortcuts.entries) {
      final shortcutId = entry.key;

      // 从用户配置获取快捷键
      final binding = config.bindings[shortcutId];
      if (binding == null || !binding.enabled) continue;

      // 检查上下文
      if (binding.context != ShortcutContext.global &&
          binding.context != widget.contextType) {
        continue;
      }

      final shortcut = binding.effectiveShortcut;
      if (shortcut == null || shortcut.isEmpty) continue;

      final parsed = ShortcutParser.parse(shortcut);
      if (parsed == null) continue;

      // 创建唯一的 Intent
      final intent = _ShortcutIntent(shortcutId);
      shortcutsMap[LogicalKeySet.fromSet(parsed.logicalKeys)] = intent;
    }

    // 如果没有快捷键，直接返回子组件
    if (shortcutsMap.isEmpty) {
      return widget.child;
    }

    // 构建 Actions Map - 只需要注册一次 _ShortcutIntent 的处理
    final actionsMap = <Type, Action<Intent>>{
      _ShortcutIntent: CallbackAction<_ShortcutIntent>(
        onInvoke: (intent) {
          final callback = widget.shortcuts[intent.shortcutId];
          callback?.call();
          return null;
        },
      ),
    };

    // 使用 Shortcuts + Actions + Focus 确保快捷键在整个子树中都能工作
    // 即使子组件（如 TextField）获得焦点，快捷键也能正常触发
    // 收集所有生效的快捷键字符串作为 key 的一部分
    final activeShortcuts = <String>[];
    for (final entry in widget.shortcuts.entries) {
      final binding = config.bindings[entry.key];
      if (binding != null && binding.enabled) {
        final shortcut = binding.effectiveShortcut;
        if (shortcut != null && shortcut.isNotEmpty) {
          activeShortcuts.add('${entry.key}:$shortcut');
        }
      }
    }
    activeShortcuts.sort(); // 确保顺序一致
    final configKey = activeShortcuts.join('|');

    // 关键修复：使用 Shortcuts.manager 并创建新的 ShortcutManager 实例
    // 因为 Flutter 的 Shortcuts widget 内部会缓存 shortcuts，即使 key 变化也可能不更新
    // 通过显式创建新的 ShortcutManager，确保快捷键映射总是被正确更新
    final shortcutManager = ShortcutManager(shortcuts: shortcutsMap);

    return Shortcuts.manager(
      key: ValueKey('shortcuts_${config.enableShortcuts}_$configKey'),
      manager: shortcutManager,
      child: Actions(
        key: ValueKey('actions_${config.enableShortcuts}_$configKey'),
        actions: actionsMap,
        child: Focus(
          autofocus: widget.autofocus,
          skipTraversal: true, // 不参与焦点遍历，只作为快捷键的锚点
          child: widget.child,
        ),
      ),
    );
  }

  /// 使用默认快捷键构建（加载中或出错时）
  Widget _buildWithDefaultShortcuts() {
    final shortcutsMap = <LogicalKeySet, Intent>{};

    for (final entry in widget.shortcuts.entries) {
      final shortcutId = entry.key;

      // 获取默认快捷键
      final defaultShortcut = DefaultShortcuts.all[shortcutId];
      if (defaultShortcut == null) continue;

      final parsed = ShortcutParser.parse(defaultShortcut);
      if (parsed == null) continue;

      // 检查上下文
      final shortcutContext = DefaultShortcuts.getContext(shortcutId);
      if (shortcutContext != ShortcutContext.global &&
          shortcutContext != widget.contextType) {
        continue;
      }

      // 创建唯一的 Intent
      final intent = _ShortcutIntent(shortcutId);
      shortcutsMap[LogicalKeySet.fromSet(parsed.logicalKeys)] = intent;
    }

    // 如果没有快捷键，直接返回子组件
    if (shortcutsMap.isEmpty) {
      return widget.child;
    }

    // 构建 Actions Map - 只需要注册一次 _ShortcutIntent 的处理
    final actionsMap = <Type, Action<Intent>>{
      _ShortcutIntent: CallbackAction<_ShortcutIntent>(
        onInvoke: (intent) {
          final callback = widget.shortcuts[intent.shortcutId];
          callback?.call();
          return null;
        },
      ),
    };

    // 使用 Shortcuts + Actions + Focus 确保快捷键在整个子树中都能工作
    // 使用 ValueKey 基于默认快捷键哈希值
    final defaultHash = Object.hash(
      'default',
      shortcutsMap.hashCode,
    );

    // 关键修复：使用 Shortcuts.manager 并创建新的 ShortcutManager 实例
    final shortcutManager = ShortcutManager(shortcuts: shortcutsMap);

    return Shortcuts.manager(
      key: ValueKey('shortcuts_default_$defaultHash'),
      manager: shortcutManager,
      child: Actions(
        key: ValueKey('actions_default_$defaultHash'),
        actions: actionsMap,
        child: Focus(
          autofocus: widget.autofocus,
          skipTraversal: true,
          child: widget.child,
        ),
      ),
    );
  }
}

/// 内部 Intent 类，用于标识快捷键动作
class _ShortcutIntent extends Intent {
  final String shortcutId;

  const _ShortcutIntent(this.shortcutId);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ShortcutIntent && other.shortcutId == shortcutId;
  }

  @override
  int get hashCode => shortcutId.hashCode;
}

/// 全局快捷键包装器
/// 用于在应用级别注册全局快捷键
class GlobalShortcuts extends StatelessWidget {
  /// 子组件
  final Widget child;

  /// 快捷键动作映射
  final Map<String, VoidCallback> shortcuts;

  const GlobalShortcuts({
    super.key,
    required this.child,
    required this.shortcuts,
  });

  @override
  Widget build(BuildContext context) {
    return ShortcutAwareWidget(
      contextType: ShortcutContext.global,
      shortcuts: shortcuts,
      autofocus: true,
      child: child,
    );
  }
}

/// 页面级快捷键包装器
/// 用于在页面级别注册快捷键
class PageShortcuts extends StatelessWidget {
  /// 子组件
  final Widget child;

  /// 页面上下文类型
  final ShortcutContext contextType;

  /// 快捷键动作映射
  final Map<String, VoidCallback> shortcuts;

  const PageShortcuts({
    super.key,
    required this.child,
    required this.contextType,
    required this.shortcuts,
  });

  @override
  Widget build(BuildContext context) {
    return ShortcutAwareWidget(
      contextType: contextType,
      shortcuts: shortcuts,
      autofocus: true,
      child: child,
    );
  }
}
