import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../core/shortcuts/shortcut_config.dart';
import '../../../core/shortcuts/shortcut_manager.dart';
import '../../providers/shortcuts_provider.dart';

/// 快捷键感知包装器
/// 按用户配置把快捷键分派给回调，配置未就绪时使用默认绑定
class ShortcutAwareWidget extends ConsumerStatefulWidget {
  /// 子组件
  final Widget child;

  /// 当前上下文类型
  final ShortcutContext contextType;

  /// 快捷键动作映射
  /// key: 快捷键ID, value: 回调函数
  final Map<String, VoidCallback> shortcuts;

  /// 首次挂载时有生效的快捷键才自动聚焦锚点，否则让给子组件自己的 autofocus
  final bool autofocus;

  /// 锚点焦点节点（可选），调用方负责销毁
  /// 按原样使用，不改写 skipTraversal；换节点时锚点上的焦点会转移到新节点
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

  bool? _anchorAutofocus;

  late final Map<Type, Action<Intent>> _actions = {
    _ShortcutIntent: CallbackAction<_ShortcutIntent>(onInvoke: _invoke),
  };

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? _createOwnedFocusNode();
  }

  @override
  void didUpdateWidget(ShortcutAwareWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autofocus != oldWidget.autofocus) {
      _anchorAutofocus = null;
    }
    if (widget.focusNode != oldWidget.focusNode) {
      _replaceFocusNode(ownedPrevious: oldWidget.focusNode == null);
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  FocusNode _createOwnedFocusNode() => FocusNode(
    debugLabel: 'ShortcutAwareWidget(${widget.contextType.name})',
    skipTraversal: true,
  );

  void _replaceFocusNode({required bool ownedPrevious}) {
    final hadPrimaryFocus = _focusNode.hasPrimaryFocus;
    if (ownedPrevious) {
      _focusNode.dispose();
    }
    _focusNode = widget.focusNode ?? _createOwnedFocusNode();
    if (hadPrimaryFocus) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = resolveDispatchShortcutConfig(
      ref.watch(shortcutConfigNotifierProvider),
    );
    final shortcuts = _resolveShortcuts(config);
    // 只在首次挂载判定：无生效快捷键时把 autofocus 让给子组件，之后也不因配置变化抢焦点
    final anchorAutofocus = _anchorAutofocus ??=
        widget.autofocus && shortcuts.isNotEmpty;

    // 各状态共用同一结构且不带随配置变化的 key，否则 child 子树会重挂并丢失状态与焦点
    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: _actions,
        child: Focus(
          focusNode: _focusNode,
          autofocus: anchorAutofocus,
          child: widget.child,
        ),
      ),
    );
  }

  Map<ShortcutActivator, Intent> _resolveShortcuts(ShortcutConfig config) {
    if (!config.enableShortcuts) return const {};

    final resolved = <ShortcutActivator, Intent>{};
    for (final shortcutId in widget.shortcuts.keys) {
      final binding = config.bindings[shortcutId];
      if (binding == null || !_appliesToCurrentContext(binding.context)) {
        continue;
      }

      final activator = AppShortcutManager.parseActivator(
        binding.effectiveShortcut,
      );
      if (activator != null) {
        resolved[activator] = _ShortcutIntent(shortcutId);
      }
    }
    return resolved;
  }

  bool _appliesToCurrentContext(ShortcutContext bindingContext) =>
      bindingContext == ShortcutContext.global ||
      bindingContext == widget.contextType;

  Object? _invoke(_ShortcutIntent intent) {
    widget.shortcuts[intent.shortcutId]?.call();
    return null;
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
