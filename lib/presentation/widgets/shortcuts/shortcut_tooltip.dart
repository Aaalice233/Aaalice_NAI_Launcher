import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/shortcuts/shortcut_manager.dart';
import '../../providers/shortcuts_provider.dart';

/// 快捷键提示组件
/// 自动在Tooltip中添加快捷键信息
class ShortcutTooltip extends ConsumerWidget {
  /// 子组件
  final Widget child;

  /// 提示消息（主文本）
  final String message;

  /// 快捷键ID
  final String? shortcutId;

  /// 是否优先使用富文本提示
  final bool preferRichTooltip;

  /// 等待显示提示的时长
  final Duration? waitDuration;

  const ShortcutTooltip({
    super.key,
    required this.message,
    required this.child,
    this.shortcutId,
    this.preferRichTooltip = true,
    this.waitDuration,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(shortcutConfigNotifierProvider);

    return configAsync.when(
      data: (config) {
        // 如果禁用快捷键提示或不显示在tooltip中，使用普通Tooltip
        if (!config.enableShortcuts ||
            !config.showShortcutInTooltip ||
            shortcutId == null) {
          return Tooltip(
            message: message,
            waitDuration: waitDuration,
            child: child,
          );
        }

        final shortcut = config.getEffectiveShortcut(shortcutId!);
        if (shortcut == null || shortcut.isEmpty) {
          return Tooltip(
            message: message,
            waitDuration: waitDuration,
            child: child,
          );
        }

        return _buildShortcutTooltip(context, shortcut);
      },
      loading: () => Tooltip(
        message: message,
        waitDuration: waitDuration,
        child: child,
      ),
      error: (_, __) => Tooltip(
        message: message,
        waitDuration: waitDuration,
        child: child,
      ),
    );
  }

  Widget _buildShortcutTooltip(BuildContext context, String shortcut) {
    final shortcutLabel = AppShortcutManager.getDisplayLabel(shortcut);

    if (preferRichTooltip) {
      return Tooltip(
        richMessage: WidgetSpan(
          child: _RichTooltipContent(
            message: message,
            shortcutLabel: shortcutLabel,
          ),
        ),
        waitDuration: waitDuration,
        child: child,
      );
    }

    return Tooltip(
      message: '$message ($shortcutLabel)',
      waitDuration: waitDuration,
      child: child,
    );
  }
}

/// 富文本提示内容
class _RichTooltipContent extends StatelessWidget {
  final String message;
  final String shortcutLabel;

  const _RichTooltipContent({
    required this.message,
    required this.shortcutLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              shortcutLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 快捷键徽章
/// 显示在按钮或操作旁边的小型快捷键标签
class ShortcutBadge extends ConsumerWidget {
  /// 快捷键ID
  final String shortcutId;

  /// 徽章位置
  final BadgePosition position;

  /// 子组件
  final Widget child;

  /// 徽章样式
  final ShortcutBadgeStyle style;

  const ShortcutBadge({
    super.key,
    required this.shortcutId,
    required this.child,
    this.position = BadgePosition.bottomRight,
    this.style = const ShortcutBadgeStyle(),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(shortcutConfigNotifierProvider);

    return configAsync.when(
      data: (config) {
        // 如果不显示徽章或快捷键被禁用，只返回子组件
        if (!config.enableShortcuts ||
            !config.showShortcutBadges ||
            !config.showInMenus) {
          return child;
        }

        final shortcut = config.getEffectiveShortcut(shortcutId);
        if (shortcut == null || shortcut.isEmpty) {
          return child;
        }

        return _buildBadge(context, shortcut);
      },
      loading: () => child,
      error: (_, __) => child,
    );
  }

  Widget _buildBadge(BuildContext context, String shortcut) {
    final shortcutLabel = AppShortcutManager.getDisplayLabel(shortcut);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          left: position == BadgePosition.topLeft ||
                  position == BadgePosition.bottomLeft
              ? style.offset.dx
              : null,
          right: position == BadgePosition.topRight ||
                  position == BadgePosition.bottomRight
              ? style.offset.dx
              : null,
          top: position == BadgePosition.topLeft ||
                  position == BadgePosition.topRight
              ? style.offset.dy
              : null,
          bottom: position == BadgePosition.bottomLeft ||
                  position == BadgePosition.bottomRight
              ? style.offset.dy
              : null,
          child: Container(
            padding: style.padding,
            decoration: BoxDecoration(
              color: style.backgroundColor ??
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(style.borderRadius),
              border: style.border,
            ),
            child: Text(
              shortcutLabel,
              style: style.textStyle ??
                  Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 徽章位置
enum BadgePosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// 徽章样式
class ShortcutBadgeStyle {
  final Offset offset;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Border? border;
  final TextStyle? textStyle;

  const ShortcutBadgeStyle({
    this.offset = const Offset(4, 4),
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    this.borderRadius = 4,
    this.backgroundColor,
    this.border,
    this.textStyle,
  });
}

/// 快捷键文本
/// 纯文本显示快捷键
class ShortcutText extends ConsumerWidget {
  /// 快捷键ID
  final String shortcutId;

  /// 文本样式
  final TextStyle? style;

  /// 如果快捷键未设置，显示的替代文本
  final String? fallback;

  const ShortcutText({
    super.key,
    required this.shortcutId,
    this.style,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(shortcutConfigNotifierProvider);

    return configAsync.when(
      data: (config) {
        final shortcut = config.getEffectiveShortcut(shortcutId);

        if (shortcut == null || shortcut.isEmpty) {
          if (fallback != null) {
            return Text(fallback!, style: style);
          }
          return const SizedBox.shrink();
        }

        final shortcutLabel = AppShortcutManager.getDisplayLabel(shortcut);

        return Text(
          shortcutLabel,
          style: style ??
              Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.outline,
                  ),
        );
      },
      loading: () =>
          fallback != null ? Text(fallback!, style: style) : const SizedBox.shrink(),
      error: (_, __) =>
          fallback != null ? Text(fallback!, style: style) : const SizedBox.shrink(),
    );
  }
}

/// 快捷键标签
/// 用于菜单项或列表项中显示快捷键
class ShortcutLabel extends ConsumerWidget {
  /// 快捷键ID
  final String shortcutId;

  /// 前景色
  final Color? foregroundColor;

  /// 背景色
  final Color? backgroundColor;

  const ShortcutLabel({
    super.key,
    required this.shortcutId,
    this.foregroundColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(shortcutConfigNotifierProvider);

    return configAsync.when(
      data: (config) {
        final shortcut = config.getEffectiveShortcut(shortcutId);

        if (shortcut == null || shortcut.isEmpty) {
          return const SizedBox.shrink();
        }

        return _buildLabel(context, shortcut);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildLabel(BuildContext context, String shortcut) {
    final theme = Theme.of(context);
    final shortcutLabel = AppShortcutManager.getDisplayLabel(shortcut);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        shortcutLabel,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foregroundColor ?? theme.colorScheme.onSurfaceVariant,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
