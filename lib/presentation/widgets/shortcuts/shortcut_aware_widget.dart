import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../core/shortcuts/shortcut_config.dart';
import '../../../core/shortcuts/shortcut_manager.dart';
import '../../providers/shortcuts_provider.dart';
import '../../selection/card_selection_scope.dart';
import 'editable_text_focus.dart';
import 'fallback_focus_home.dart';

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

  /// 锚点是页面的焦点归属：焦点退回到所在作用域时收回到锚点
  /// 只在锚点首次挂载拿到 autofocus 时生效
  final bool reclaimFallbackFocus;

  const ShortcutAwareWidget({
    super.key,
    required this.child,
    required this.contextType,
    required this.shortcuts,
    this.autofocus = false,
    this.reclaimFallbackFocus = false,
  });

  @override
  ConsumerState<ShortcutAwareWidget> createState() => _ShortcutAwareWidgetState();
}

class _ShortcutAwareWidgetState extends ConsumerState<ShortcutAwareWidget> {
  late final FocusNode _focusNode = FocusNode(
    debugLabel: 'ShortcutAwareWidget(${widget.contextType.name})',
    skipTraversal: true,
  );

  bool? _anchorAutofocus;

  late final Map<Type, Action<Intent>> _actions = {
    _ShortcutIntent: _ShortcutAction(),
  };

  @override
  void didUpdateWidget(ShortcutAwareWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autofocus != oldWidget.autofocus) {
      _anchorAutofocus = null;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = resolveDispatchShortcutConfig(
      ref.watch(shortcutConfigNotifierProvider),
    );
    final shortcuts = _resolveShortcuts(config);
    // 只在首次挂载时判定，之后配置变化不抢焦点
    final anchorAutofocus = _anchorAutofocus ??=
        widget.autofocus && shortcuts.isNotEmpty;

    // 各状态共用同一结构且不带随配置变化的 key，否则 child 子树会重挂并丢失状态与焦点
    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: _actions,
        child: FallbackFocusHome(
          focusNode: _focusNode,
          enabled: widget.reclaimFallbackFocus && anchorAutofocus,
          child: Focus(
            focusNode: _focusNode,
            autofocus: anchorAutofocus,
            child: widget.child,
          ),
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

      final shortcut = binding.effectiveShortcut;
      final parsed = shortcut == null ? null : ShortcutParser.parse(shortcut);
      final activator = AppShortcutManager.parseActivator(shortcut);
      if (parsed != null && activator != null) {
        resolved[activator] = _ShortcutIntent(
          shortcutId,
          dispatcher: this,
          yieldsToTextInput: parsed.isTextEditingKey,
        );
      }
    }
    return resolved;
  }

  bool _appliesToCurrentContext(ShortcutContext bindingContext) =>
      bindingContext == ShortcutContext.global ||
      bindingContext == widget.contextType;

  void _invoke(String shortcutId) => widget.shortcuts[shortcutId]?.call();
}

/// 内部 Intent 类，用于标识快捷键动作
class _ShortcutIntent extends Intent {
  final String shortcutId;

  /// 动作按焦点就近查找，包装器嵌套时找到的是内层的，回调必须回到发出方
  final _ShortcutAwareWidgetState dispatcher;

  final bool yieldsToTextInput;

  const _ShortcutIntent(
    this.shortcutId, {
    required this.dispatcher,
    required this.yieldsToTextInput,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ShortcutIntent &&
        other.shortcutId == shortcutId &&
        identical(other.dispatcher, dispatcher) &&
        other.yieldsToTextInput == yieldsToTextInput;
  }

  @override
  int get hashCode =>
      Object.hash(shortcutId, identityHashCode(dispatcher), yieldsToTextInput);
}

class _ShortcutAction extends Action<_ShortcutIntent> {
  // 停用时按键继续冒泡，落到输入框自身的编辑处理
  @override
  bool isEnabled(_ShortcutIntent intent) =>
      !(intent.yieldsToTextInput && isWritableTextFocused());

  @override
  Object? invoke(_ShortcutIntent intent) {
    intent.dispatcher._invoke(intent.shortcutId);
    return null;
  }
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

  /// 锚点是页面的焦点归属；页面另有内层焦点归属时关闭
  final bool reclaimFallbackFocus;

  const PageShortcuts({
    super.key,
    required this.child,
    required this.contextType,
    required this.shortcuts,
    this.reclaimFallbackFocus = true,
  });

  @override
  Widget build(BuildContext context) {
    return ShortcutAwareWidget(
      contextType: contextType,
      shortcuts: shortcuts,
      autofocus: true,
      reclaimFallbackFocus: reclaimFallbackFocus,
      child: child,
    );
  }
}

/// 带卡片多选的页面快捷键包装器，需放在 [CardSelectionScope] 之内
/// 焦点只交给内层多选处理器，页面快捷键才位于按键冒泡路径上；
/// 内层 FocusScope 承接输入框失焦，焦点不会退回到处理器之上的路由作用域
class CardSelectionPageShortcuts extends StatelessWidget {
  /// 子组件
  final Widget child;

  /// 页面上下文类型
  final ShortcutContext contextType;

  /// 快捷键动作映射
  final Map<String, VoidCallback> shortcuts;

  const CardSelectionPageShortcuts({
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
      child: CardSelectionShortcuts(
        child: _PageFocusScope(
          debugLabel: 'CardSelectionPageShortcuts(${contextType.name})',
          child: child,
        ),
      ),
    );
  }
}

/// 页面内层焦点作用域
/// 遍历到首尾时交给上层作用域，Tab 能离开页面到达导航栏
class _PageFocusScope extends StatefulWidget {
  const _PageFocusScope({required this.debugLabel, required this.child});

  final String debugLabel;
  final Widget child;

  @override
  State<_PageFocusScope> createState() => _PageFocusScopeState();
}

class _PageFocusScopeState extends State<_PageFocusScope> {
  late final FocusScopeNode _node = FocusScopeNode(
    debugLabel: widget.debugLabel,
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FocusScope(node: _node, child: widget.child);
}
