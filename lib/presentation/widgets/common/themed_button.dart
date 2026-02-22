import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../themes/theme_extension.dart';
import '../shortcuts/shortcut_tooltip.dart';

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
  final String? shortcutId;

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

    if (shortcutId != null) {
      return ShortcutTooltip(
        message: tooltip ?? '',
        shortcutId: shortcutId,
        child: buttonWidget,
      );
    }

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: buttonWidget);
    }

    return buttonWidget;
  }

  Color _getLoadingColor(
    ThemeData theme,
    ThemedButtonStyle style,
    AppInteractionStyle interaction,
  ) {
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
class _PhysicalButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return _StyledButton(
      onPressed: onPressed,
      style: style,
      theme: theme,
      type: _ButtonType.physical,
      child: child,
    );
  }
}

/// 数字电子风格 (Motorola)
class _DigitalButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return _StyledButton(
      onPressed: onPressed,
      style: style,
      theme: theme,
      type: _ButtonType.digital,
      child: child,
    );
  }
}

enum _ButtonType { physical, digital }

/// 统一样式按钮基类
class _StyledButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final ThemedButtonStyle style;
  final ThemeData theme;
  final Widget child;
  final _ButtonType type;

  const _StyledButton({
    required this.onPressed,
    required this.style,
    required this.theme,
    required this.child,
    required this.type,
  });

  @override
  State<_StyledButton> createState() => _StyledButtonState();
}

class _StyledButtonState extends State<_StyledButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final enabled = widget.onPressed != null;

    final colors = _getColors(theme, enabled);
    final decoration = _getDecoration(colors, enabled);
    final textStyle = _getTextStyle(colors, theme);

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _isPressed = false);
              _hapticFeedback();
              widget.onPressed!();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        margin: decoration.margin,
        decoration: decoration.boxDecoration,
        child: Container(
          padding: decoration.padding,
          child: DefaultTextStyle(
            style: textStyle,
            child: IconTheme(
              data: IconThemeData(color: colors.foreground, size: 18),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }

  void _hapticFeedback() {
    if (widget.type == _ButtonType.physical) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  _ButtonColors _getColors(ThemeData theme, bool enabled) {
    final isPhysical = widget.type == _ButtonType.physical;

    if (isPhysical) {
      switch (widget.style) {
        case ThemedButtonStyle.filled:
          return _ButtonColors(
            background: enabled ? theme.colorScheme.primary : theme.disabledColor,
            foreground: theme.colorScheme.onPrimary,
            border: theme.colorScheme.primaryContainer,
          );
        case ThemedButtonStyle.outlined:
          return _ButtonColors(
            background: theme.colorScheme.surface,
            foreground: enabled ? theme.colorScheme.primary : theme.disabledColor,
            border: enabled ? theme.colorScheme.primary : theme.disabledColor,
          );
        case ThemedButtonStyle.text:
          return _ButtonColors(
            background: Colors.transparent,
            foreground: enabled ? theme.colorScheme.primary : theme.disabledColor,
            border: Colors.transparent,
          );
      }
    } else {
      final baseColor = enabled ? theme.colorScheme.primary : theme.disabledColor;
      final onBaseColor =
          enabled ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface.withOpacity(0.38);

      switch (widget.style) {
        case ThemedButtonStyle.filled:
          return _ButtonColors(
            background: _isPressed ? onBaseColor : baseColor,
            foreground: _isPressed ? baseColor : onBaseColor,
            border: baseColor,
          );
        case ThemedButtonStyle.outlined:
          return _ButtonColors(
            background: _isPressed ? baseColor : Colors.transparent,
            foreground: _isPressed ? onBaseColor : baseColor,
            border: baseColor,
          );
        case ThemedButtonStyle.text:
          return _ButtonColors(
            background: _isPressed ? baseColor.withOpacity(0.2) : Colors.transparent,
            foreground: baseColor,
            border: null,
          );
      }
    }
  }

  _ButtonDecoration _getDecoration(_ButtonColors colors, bool enabled) {
    final isPhysical = widget.type == _ButtonType.physical;

    if (isPhysical) {
      final depth = widget.style == ThemedButtonStyle.text ? 0.0 : 4.0;
      final offset = _isPressed ? depth : 0.0;

      return _ButtonDecoration(
        margin: EdgeInsets.only(top: offset, bottom: depth - offset),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        boxDecoration: widget.style == ThemedButtonStyle.text
            ? null
            : BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border!, width: 2),
                boxShadow: _isPressed || widget.style == ThemedButtonStyle.text
                    ? []
                    : [
                        BoxShadow(
                          color: Color.lerp(colors.background, Colors.black, 0.4)!,
                          offset: Offset(0, depth),
                          blurRadius: 0,
                        ),
                      ],
              ),
      );
    } else {
      return _ButtonDecoration(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        boxDecoration: BoxDecoration(
          color: colors.background,
          border: colors.border != null ? Border.all(color: colors.border!, width: 2) : null,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
  }

  TextStyle _getTextStyle(_ButtonColors colors, ThemeData theme) {
    final isPhysical = widget.type == _ButtonType.physical;

    return TextStyle(
      color: colors.foreground,
      fontWeight: FontWeight.bold,
      fontFamily: isPhysical ? null : theme.textTheme.bodyMedium?.fontFamily,
      letterSpacing: isPhysical ? null : 1.5,
    );
  }
}

class _ButtonColors {
  final Color background;
  final Color foreground;
  final Color? border;

  _ButtonColors({required this.background, required this.foreground, this.border});
}

class _ButtonDecoration {
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final BoxDecoration? boxDecoration;

  _ButtonDecoration({this.margin, required this.padding, this.boxDecoration});
}
