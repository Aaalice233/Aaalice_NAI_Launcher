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
    final interactionStyle =
        extension?.interactionStyle ?? AppInteractionStyle.material;
    final pixelFont = extension?.usePixelFont ?? false;

    // 字体样式调整
    final textStyle =
        pixelFont ? const TextStyle(fontSize: 16, letterSpacing: 1.2) : null;

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _getLoadingColor(theme, style, interactionStyle),
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

    Widget buttonWidget;

    switch (interactionStyle) {
      case AppInteractionStyle.physical:
        buttonWidget = _PhysicalButton(
          onPressed: isLoading ? null : onPressed,
          style: style,
          theme: theme,
          child: content,
        );
        break;
      case AppInteractionStyle.digital:
        buttonWidget = _DigitalButton(
          onPressed: isLoading ? null : onPressed,
          style: style,
          theme: theme,
          child: content,
        );
        break;
      case AppInteractionStyle.material:
      default:
        buttonWidget = _MaterialButton(
          onPressed: isLoading ? null : onPressed,
          style: style,
          child: content,
        );
        break;
    }

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: buttonWidget);
    }

    return buttonWidget;
  }

  Color _getLoadingColor(ThemeData theme, ThemedButtonStyle style,
      AppInteractionStyle interaction) {
    if (style == ThemedButtonStyle.filled) {
      return theme.colorScheme.onPrimary;
    }
    return theme.colorScheme.primary;
  }
}

/// 标准 Material 风格按钮
class _MaterialButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final ThemedButtonStyle style;
  final Widget child;

  const _MaterialButton({
    required this.onPressed,
    required this.style,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    void handlePress() {
      if (onPressed != null) {
        HapticFeedback.lightImpact();
        onPressed!();
      }
    }

    switch (style) {
      case ThemedButtonStyle.filled:
        return FilledButton(
          onPressed: onPressed == null ? null : handlePress,
          child: child,
        );
      case ThemedButtonStyle.outlined:
        return OutlinedButton(
          onPressed: onPressed == null ? null : handlePress,
          child: child,
        );
      case ThemedButtonStyle.text:
        return TextButton(
          onPressed: onPressed == null ? null : handlePress,
          child: child,
        );
    }
  }
}

/// 物理按键风格 (Cassette Futurism)
class _PhysicalButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final ThemedButtonStyle style;
  final ThemeData theme;
  final Widget child;

  const _PhysicalButton({
    required this.onPressed,
    required this.style,
    required this.theme,
    required this.child,
  });

  @override
  State<_PhysicalButton> createState() => _PhysicalButtonState();
}

class _PhysicalButtonState extends State<_PhysicalButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final enabled = widget.onPressed != null;

    // 颜色配置
    Color backgroundColor;
    Color foregroundColor;
    Color borderColor;
    Color shadowColor;

    switch (widget.style) {
      case ThemedButtonStyle.filled:
        backgroundColor =
            enabled ? theme.colorScheme.primary : theme.disabledColor;
        foregroundColor = theme.colorScheme.onPrimary;
        borderColor = theme.colorScheme.primaryContainer;
        shadowColor = Color.lerp(backgroundColor, Colors.black, 0.4)!;
        break;
      case ThemedButtonStyle.outlined:
        backgroundColor = theme.colorScheme.surface;
        foregroundColor =
            enabled ? theme.colorScheme.primary : theme.disabledColor;
        borderColor = enabled ? theme.colorScheme.primary : theme.disabledColor;
        shadowColor = Color.lerp(borderColor, Colors.black, 0.4)!;
        break;
      case ThemedButtonStyle.text:
        // Text button in physical style acts like a flat plate
        backgroundColor = Colors.transparent;
        foregroundColor =
            enabled ? theme.colorScheme.primary : theme.disabledColor;
        borderColor = Colors.transparent;
        shadowColor = Colors.transparent;
        break;
    }

    final double depth = widget.style == ThemedButtonStyle.text ? 0 : 4.0;
    final double offset = _isPressed ? depth : 0.0;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _isPressed = false);
              HapticFeedback.mediumImpact();
              widget.onPressed!();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        margin: EdgeInsets.only(top: offset, bottom: depth - offset),
        decoration: widget.style == ThemedButtonStyle.text
            ? null
            : BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12), // Chunky rounded
                border: Border.all(color: borderColor, width: 2),
                boxShadow: _isPressed || widget.style == ThemedButtonStyle.text
                    ? []
                    : [
                        BoxShadow(
                          color: shadowColor,
                          offset: Offset(0, depth),
                          blurRadius: 0, // Hard shadow for physical look
                        ),
                      ],
              ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: DefaultTextStyle(
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.bold,
            ),
            child: IconTheme(
              data: IconThemeData(color: foregroundColor),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 数字电子风格 (Motorola)
class _DigitalButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final ThemedButtonStyle style;
  final ThemeData theme;
  final Widget child;

  const _DigitalButton({
    required this.onPressed,
    required this.style,
    required this.theme,
    required this.child,
  });

  @override
  State<_DigitalButton> createState() => _DigitalButtonState();
}

class _DigitalButtonState extends State<_DigitalButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final enabled = widget.onPressed != null;

    // 基础颜色
    Color baseColor = theme.colorScheme.primary;
    Color onBaseColor = theme.colorScheme.onPrimary;

    if (!enabled) {
      baseColor = theme.disabledColor;
      onBaseColor = theme.colorScheme.onSurface.withOpacity(0.38);
    }

    // 状态颜色计算 (反色逻辑)
    Color backgroundColor;
    Color contentColor;
    BoxBorder? border;

    switch (widget.style) {
      case ThemedButtonStyle.filled:
        backgroundColor = _isPressed ? onBaseColor : baseColor;
        contentColor = _isPressed ? baseColor : onBaseColor;
        border = Border.all(color: baseColor, width: 2);
        break;
      case ThemedButtonStyle.outlined:
        backgroundColor = _isPressed ? baseColor : Colors.transparent;
        contentColor = _isPressed ? onBaseColor : baseColor;
        border = Border.all(color: baseColor, width: 2);
        break;
      case ThemedButtonStyle.text:
        backgroundColor =
            _isPressed ? baseColor.withOpacity(0.2) : Colors.transparent;
        contentColor = baseColor;
        border = null;
        break;
    }

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _isPressed = false);
              HapticFeedback.selectionClick();
              widget.onPressed!();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: border,
          borderRadius: BorderRadius.circular(2), // Sharp corners
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            color: contentColor,
            fontFamily: theme.textTheme.bodyMedium?.fontFamily,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5, // Digital spacing
          ),
          child: IconTheme(
            data: IconThemeData(color: contentColor, size: 18),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
