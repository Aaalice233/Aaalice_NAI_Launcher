import 'package:flutter/material.dart';

import '../shortcuts/shortcut_tooltip.dart';

/// 工具栏紧凑操作。
///
/// 默认态不绘制完整边框；激活、危险、悬停和键盘焦点通过语义色面表达。
class CompactIconButton extends StatelessWidget {
  const CompactIconButton({
    super.key,
    required this.icon,
    this.label,
    this.tooltip,
    this.onPressed,
    this.isActive = false,
    this.isDanger = false,
    this.isLoading = false,
    this.shortcutId,
  });

  final IconData icon;
  final String? label;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool isActive;
  final bool isDanger;
  final bool isLoading;
  final String? shortcutId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final message = tooltip ?? label;
    final enabled = onPressed != null && !isLoading;
    final hasLabel = label?.isNotEmpty ?? false;

    Color foreground(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return colorScheme.onSurface.withValues(alpha: 0.38);
      }
      if (isDanger) return colorScheme.error;
      if (isActive) return colorScheme.onPrimaryContainer;
      return colorScheme.onSurfaceVariant;
    }

    Color background(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) return Colors.transparent;
      if (isActive) {
        return states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.pressed)
            ? colorScheme.primaryContainer
            : colorScheme.primaryContainer.withValues(alpha: 0.72);
      }
      if (isDanger) {
        return states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.pressed)
            ? colorScheme.errorContainer
            : Colors.transparent;
      }
      if (states.contains(WidgetState.pressed)) {
        return colorScheme.surfaceContainerHighest;
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return colorScheme.surfaceContainerHigh;
      }
      return Colors.transparent;
    }

    final style = ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith(foreground),
      backgroundColor: WidgetStateProperty.resolveWith(background),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      side: const WidgetStatePropertyAll(BorderSide.none),
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: WidgetStatePropertyAll(Size(hasLabel ? 0 : 40, 36)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: hasLabel ? 10 : 8, vertical: 6),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.compact,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final iconWidget = isLoading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 18);

    Widget button;
    if (hasLabel) {
      button = TextButton.icon(
        onPressed: enabled ? onPressed : null,
        style: style,
        icon: iconWidget,
        label: Text(label!),
      );
    } else {
      button = IconButton(
        onPressed: enabled ? onPressed : null,
        style: style,
        icon: iconWidget,
        tooltip: shortcutId == null ? message : null,
      );
    }

    if (shortcutId != null) {
      button = ShortcutTooltip(
        message: message ?? '',
        shortcutId: shortcutId,
        child: button,
      );
    } else if (hasLabel && message != null && message != label) {
      button = Tooltip(message: message, child: button);
    }

    return button;
  }
}
