import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shortcuts/shortcut_tooltip.dart';

enum ThemedButtonStyle { filled, outlined, text }

/// 项目统一按钮入口。
///
/// 所有风格复用 Material 的焦点、键盘和语义状态；`outlined` 在全局主题中
/// 表现为低强调 tonal action，不再生成高对比空心框。
class ThemedButton extends StatelessWidget {
  const ThemedButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.style = ThemedButtonStyle.filled,
    this.isLoading = false,
    this.tooltip,
    this.shortcutId,
  });

  final VoidCallback? onPressed;
  final Widget? icon;
  final Widget label;
  final ThemedButtonStyle style;
  final bool isLoading;
  final String? tooltip;
  final String? shortcutId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveOnPressed = isLoading || onPressed == null
        ? null
        : () {
            HapticFeedback.lightImpact();
            onPressed!();
          };
    final foreground = style == ThemedButtonStyle.filled
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.primary;
    final content = _ThemedButtonContent(
      isLoading: isLoading,
      loadingColor: foreground,
      icon: icon,
      label: label,
    );

    final button = switch (style) {
      ThemedButtonStyle.filled => FilledButton(
        onPressed: effectiveOnPressed,
        child: content,
      ),
      ThemedButtonStyle.outlined => OutlinedButton(
        onPressed: effectiveOnPressed,
        child: content,
      ),
      ThemedButtonStyle.text => TextButton(
        onPressed: effectiveOnPressed,
        child: content,
      ),
    };

    if (shortcutId != null) {
      return ShortcutTooltip(
        message: tooltip ?? '',
        shortcutId: shortcutId,
        child: button,
      );
    }
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

class _ThemedButtonContent extends StatelessWidget {
  const _ThemedButtonContent({
    required this.isLoading,
    required this.loadingColor,
    required this.icon,
    required this.label,
  });

  final bool isLoading;
  final Color loadingColor;
  final Widget? icon;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasLeading = isLoading || icon != null;
        final leading = isLoading
            ? SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: loadingColor,
                ),
              )
            : icon;
        final labelWidget = DefaultTextStyle.merge(
          textAlign: TextAlign.center,
          child: label,
        );

        return Row(
          mainAxisSize: constraints.hasBoundedWidth
              ? MainAxisSize.max
              : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasLeading) ...[leading!, const SizedBox(width: 8)],
            if (constraints.hasBoundedWidth)
              Flexible(child: labelWidget)
            else
              labelWidget,
          ],
        );
      },
    );
  }
}
