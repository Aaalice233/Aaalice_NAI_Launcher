import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../core/shortcuts/shortcut_config.dart';
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

      // 创建 LogicalKeySet
      final keys = <LogicalKeyboardKey>{};
      if (parsed.modifiers.contains(ShortcutModifier.control)) {
        keys.add(LogicalKeyboardKey.control);
      }
      if (parsed.modifiers.contains(ShortcutModifier.alt)) {
        keys.add(LogicalKeyboardKey.alt);
      }
      if (parsed.modifiers.contains(ShortcutModifier.shift)) {
        keys.add(LogicalKeyboardKey.shift);
      }
      if (parsed.modifiers.contains(ShortcutModifier.meta)) {
        keys.add(LogicalKeyboardKey.meta);
      }

      final mainKey = _getLogicalKey(parsed.key);
      if (mainKey == null) continue;
      keys.add(mainKey);

      if (keys.isEmpty) continue;

      // 创建唯一的 Intent
      final intent = _ShortcutIntent(shortcutId);
      shortcutsMap[LogicalKeySet.fromSet(keys)] = intent;
    }

    // 如果没有快捷键，直接返回子组件
    if (shortcutsMap.isEmpty) {
      return widget.child;
    }

    // 使用 CallbackShortcuts + FocusScope 确保快捷键在子组件获得焦点时也能工作
    return CallbackShortcuts(
      bindings: shortcutsMap.map((keySet, intent) =>
        MapEntry(
          keySet,
          () {
            if (intent is _ShortcutIntent) {
              final callback = widget.shortcuts[intent.shortcutId];
              callback?.call();
            }
          },
        ),
      ),
      child: FocusScope(
        autofocus: widget.autofocus,
        child: widget.child,
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

      // 创建 LogicalKeySet
      final keys = <LogicalKeyboardKey>{};
      if (parsed.modifiers.contains(ShortcutModifier.control)) {
        keys.add(LogicalKeyboardKey.control);
      }
      if (parsed.modifiers.contains(ShortcutModifier.alt)) {
        keys.add(LogicalKeyboardKey.alt);
      }
      if (parsed.modifiers.contains(ShortcutModifier.shift)) {
        keys.add(LogicalKeyboardKey.shift);
      }
      if (parsed.modifiers.contains(ShortcutModifier.meta)) {
        keys.add(LogicalKeyboardKey.meta);
      }

      final mainKey = _getLogicalKey(parsed.key);
      if (mainKey == null) continue;
      keys.add(mainKey);

      if (keys.isEmpty) continue;

      // 创建唯一的 Intent
      final intent = _ShortcutIntent(shortcutId);
      shortcutsMap[LogicalKeySet.fromSet(keys)] = intent;
    }

    // 如果没有快捷键，直接返回子组件
    if (shortcutsMap.isEmpty) {
      return widget.child;
    }

    // 使用 CallbackShortcuts + FocusScope 确保快捷键在子组件获得焦点时也能工作
    return CallbackShortcuts(
      bindings: shortcutsMap.map((keySet, intent) =>
        MapEntry(
          keySet,
          () {
            if (intent is _ShortcutIntent) {
              final callback = widget.shortcuts[intent.shortcutId];
              callback?.call();
            }
          },
        ),
      ),
      child: FocusScope(
        autofocus: widget.autofocus,
        child: widget.child,
      ),
    );
  }

  LogicalKeyboardKey? _getLogicalKey(ShortcutKey key) {
    switch (key) {
      case ShortcutKey.keyA:
        return LogicalKeyboardKey.keyA;
      case ShortcutKey.keyB:
        return LogicalKeyboardKey.keyB;
      case ShortcutKey.keyC:
        return LogicalKeyboardKey.keyC;
      case ShortcutKey.keyD:
        return LogicalKeyboardKey.keyD;
      case ShortcutKey.keyE:
        return LogicalKeyboardKey.keyE;
      case ShortcutKey.keyF:
        return LogicalKeyboardKey.keyF;
      case ShortcutKey.keyG:
        return LogicalKeyboardKey.keyG;
      case ShortcutKey.keyH:
        return LogicalKeyboardKey.keyH;
      case ShortcutKey.keyI:
        return LogicalKeyboardKey.keyI;
      case ShortcutKey.keyJ:
        return LogicalKeyboardKey.keyJ;
      case ShortcutKey.keyK:
        return LogicalKeyboardKey.keyK;
      case ShortcutKey.keyL:
        return LogicalKeyboardKey.keyL;
      case ShortcutKey.keyM:
        return LogicalKeyboardKey.keyM;
      case ShortcutKey.keyN:
        return LogicalKeyboardKey.keyN;
      case ShortcutKey.keyO:
        return LogicalKeyboardKey.keyO;
      case ShortcutKey.keyP:
        return LogicalKeyboardKey.keyP;
      case ShortcutKey.keyQ:
        return LogicalKeyboardKey.keyQ;
      case ShortcutKey.keyR:
        return LogicalKeyboardKey.keyR;
      case ShortcutKey.keyS:
        return LogicalKeyboardKey.keyS;
      case ShortcutKey.keyT:
        return LogicalKeyboardKey.keyT;
      case ShortcutKey.keyU:
        return LogicalKeyboardKey.keyU;
      case ShortcutKey.keyV:
        return LogicalKeyboardKey.keyV;
      case ShortcutKey.keyW:
        return LogicalKeyboardKey.keyW;
      case ShortcutKey.keyX:
        return LogicalKeyboardKey.keyX;
      case ShortcutKey.keyY:
        return LogicalKeyboardKey.keyY;
      case ShortcutKey.keyZ:
        return LogicalKeyboardKey.keyZ;
      case ShortcutKey.digit0:
        return LogicalKeyboardKey.digit0;
      case ShortcutKey.digit1:
        return LogicalKeyboardKey.digit1;
      case ShortcutKey.digit2:
        return LogicalKeyboardKey.digit2;
      case ShortcutKey.digit3:
        return LogicalKeyboardKey.digit3;
      case ShortcutKey.digit4:
        return LogicalKeyboardKey.digit4;
      case ShortcutKey.digit5:
        return LogicalKeyboardKey.digit5;
      case ShortcutKey.digit6:
        return LogicalKeyboardKey.digit6;
      case ShortcutKey.digit7:
        return LogicalKeyboardKey.digit7;
      case ShortcutKey.digit8:
        return LogicalKeyboardKey.digit8;
      case ShortcutKey.digit9:
        return LogicalKeyboardKey.digit9;
      case ShortcutKey.f1:
        return LogicalKeyboardKey.f1;
      case ShortcutKey.f2:
        return LogicalKeyboardKey.f2;
      case ShortcutKey.f3:
        return LogicalKeyboardKey.f3;
      case ShortcutKey.f4:
        return LogicalKeyboardKey.f4;
      case ShortcutKey.f5:
        return LogicalKeyboardKey.f5;
      case ShortcutKey.f6:
        return LogicalKeyboardKey.f6;
      case ShortcutKey.f7:
        return LogicalKeyboardKey.f7;
      case ShortcutKey.f8:
        return LogicalKeyboardKey.f8;
      case ShortcutKey.f9:
        return LogicalKeyboardKey.f9;
      case ShortcutKey.f10:
        return LogicalKeyboardKey.f10;
      case ShortcutKey.f11:
        return LogicalKeyboardKey.f11;
      case ShortcutKey.f12:
        return LogicalKeyboardKey.f12;
      case ShortcutKey.enter:
        return LogicalKeyboardKey.enter;
      case ShortcutKey.escape:
        return LogicalKeyboardKey.escape;
      case ShortcutKey.space:
        return LogicalKeyboardKey.space;
      case ShortcutKey.tab:
        return LogicalKeyboardKey.tab;
      case ShortcutKey.backspace:
        return LogicalKeyboardKey.backspace;
      case ShortcutKey.delete:
        return LogicalKeyboardKey.delete;
      case ShortcutKey.insert:
        return LogicalKeyboardKey.insert;
      case ShortcutKey.home:
        return LogicalKeyboardKey.home;
      case ShortcutKey.end:
        return LogicalKeyboardKey.end;
      case ShortcutKey.pageup:
        return LogicalKeyboardKey.pageUp;
      case ShortcutKey.pagedown:
        return LogicalKeyboardKey.pageDown;
      case ShortcutKey.arrowup:
        return LogicalKeyboardKey.arrowUp;
      case ShortcutKey.arrowdown:
        return LogicalKeyboardKey.arrowDown;
      case ShortcutKey.arrowleft:
        return LogicalKeyboardKey.arrowLeft;
      case ShortcutKey.arrowright:
        return LogicalKeyboardKey.arrowRight;
      case ShortcutKey.comma:
        return LogicalKeyboardKey.comma;
      case ShortcutKey.period:
        return LogicalKeyboardKey.period;
      case ShortcutKey.slash:
        return LogicalKeyboardKey.slash;
      case ShortcutKey.semicolon:
        return LogicalKeyboardKey.semicolon;
      case ShortcutKey.quote:
        return LogicalKeyboardKey.quoteSingle;
      case ShortcutKey.bracketleft:
        return LogicalKeyboardKey.bracketLeft;
      case ShortcutKey.bracketright:
        return LogicalKeyboardKey.bracketRight;
      case ShortcutKey.backslash:
        return LogicalKeyboardKey.backslash;
      case ShortcutKey.minus:
        return LogicalKeyboardKey.minus;
      case ShortcutKey.equal:
        return LogicalKeyboardKey.equal;
      case ShortcutKey.backquote:
        return LogicalKeyboardKey.backquote;
    }
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
