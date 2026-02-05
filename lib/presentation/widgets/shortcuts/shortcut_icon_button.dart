import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/shortcuts/shortcut_manager.dart';
import '../../providers/shortcuts_provider.dart';
import 'shortcut_tooltip.dart';

/// 带快捷键提示的图标按钮
/// 自动在tooltip中显示快捷键
class ShortcutIconButton extends ConsumerWidget {
  /// 图标
  final IconData icon;

  /// 快捷键ID
  final String? shortcutId;

  /// 提示文本
  final String tooltip;

  /// 点击回调
  final VoidCallback? onPressed;

  /// 是否选中
  final bool isSelected;

  /// 图标大小
  final double iconSize;

  /// 视觉密度
  final VisualDensity? visualDensity;

  /// 内边距
  final EdgeInsetsGeometry? padding;

  const ShortcutIconButton({
    super.key,
    required this.icon,
    this.shortcutId,
    required this.tooltip,
    this.onPressed,
    this.isSelected = false,
    this.iconSize = 24,
    this.visualDensity,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final button = IconButton(
      icon: Icon(icon),
      isSelected: isSelected,
      iconSize: iconSize,
      visualDensity: visualDensity,
      padding: padding,
      onPressed: onPressed,
    );

    if (shortcutId == null) {
      return Tooltip(
        message: tooltip,
        child: button,
      );
    }

    return ShortcutTooltip(
      message: tooltip,
      shortcutId: shortcutId,
      child: button,
    );
  }
}

/// 带快捷键提示的浮动操作按钮
class ShortcutFab extends ConsumerWidget {
  /// 图标
  final IconData icon;

  /// 快捷键ID
  final String? shortcutId;

  /// 提示文本
  final String tooltip;

  /// 点击回调
  final VoidCallback? onPressed;

  /// 按钮背景色
  final Color? backgroundColor;

  /// 按钮前景色
  final Color? foregroundColor;

  /// 按钮大小
  final double? size;

  const ShortcutFab({
    super.key,
    required this.icon,
    this.shortcutId,
    required this.tooltip,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.size,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fab = FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      tooltip: tooltip,
      child: Icon(icon),
    );

    if (shortcutId == null) {
      return fab;
    }

    final shortcut = ref.watch(effectiveShortcutProvider(shortcutId!));
    if (shortcut == null) {
      return fab;
    }

    final shortcutLabel = AppShortcutManager.getDisplayLabel(shortcut);

    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      tooltip: '$tooltip ($shortcutLabel)',
      child: Icon(icon),
    );
  }
}

/// 带快捷键提示的菜单项
class ShortcutMenuItem extends ConsumerWidget {
  /// 标题
  final Widget title;

  /// 快捷键ID
  final String? shortcutId;

  /// 点击回调
  final VoidCallback? onTap;

  /// 前置图标
  final Widget? leading;

  /// 是否启用
  final bool enabled;

  const ShortcutMenuItem({
    super.key,
    required this.title,
    this.shortcutId,
    this.onTap,
    this.leading,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget? trailing;

    if (shortcutId != null) {
      final shortcut = ref.watch(effectiveShortcutProvider(shortcutId!));
      if (shortcut != null) {
        final shortcutLabel = AppShortcutManager.getDisplayLabel(shortcut);
        trailing = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            shortcutLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontFamily: 'monospace',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        );
      }
    }

    return ListTile(
      leading: leading,
      title: title,
      trailing: trailing,
      enabled: enabled,
      onTap: onTap,
    );
  }
}
