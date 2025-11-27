import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../themes/theme_extension.dart';

enum ThemedButtonStyle {
  filled,
  outlined,
  text,
}

class ThemedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final Widget label;
  final ThemedButtonStyle style;
  final bool isLoading;
  final String? tooltip;

  const ThemedButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.style = ThemedButtonStyle.filled,
    this.isLoading = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppThemeExtension>();
    final pixelFont = extension?.usePixelFont ?? false;

    // 字体样式调整 (如果是像素风，可能需要调整大小)
    final textStyle = pixelFont ? const TextStyle(fontSize: 16, letterSpacing: 1.2) : null;
    
    Widget buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: style == ThemedButtonStyle.filled ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          icon!,
          const SizedBox(width: 8),
        ],
        DefaultTextStyle.merge(
          style: textStyle,
          child: label,
        ),
      ],
    );

    Widget button;
    switch (style) {
      case ThemedButtonStyle.filled:
        button = FilledButton(
          onPressed: isLoading ? null : _handlePress,
          child: buttonContent,
        );
        break;
      case ThemedButtonStyle.outlined:
        button = OutlinedButton(
          onPressed: isLoading ? null : _handlePress,
          child: buttonContent,
        );
        break;
      case ThemedButtonStyle.text:
        button = TextButton(
          onPressed: isLoading ? null : _handlePress,
          child: buttonContent,
        );
        break;
    }

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    
    return button;
  }

  void _handlePress() {
    if (onPressed != null) {
      HapticFeedback.lightImpact(); // 添加轻微触感
      onPressed!();
    }
  }
}

