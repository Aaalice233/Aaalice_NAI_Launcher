import 'package:flutter/material.dart';

import '../../themes/core/input_surface_style.dart';

/// Shared deep surface for editable controls.
///
/// The default state is borderless. Focus and error feedback are painted
/// entirely inside the clipped surface, so state changes never alter layout.
class InputSurfaceContainer extends StatelessWidget {
  const InputSurfaceContainer({
    super.key,
    required this.child,
    this.borderRadius = 8,
    this.width,
    this.height,
    this.constraints,
    this.enabled,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0,
    this.padding,
    this.hasError = false,
    this.isFocused = false,
  });

  final Widget child;
  final double borderRadius;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final bool? enabled;
  final Color? backgroundColor;

  /// Optional focus-glow color retained for existing callers.
  final Color? borderColor;

  /// Retained for source compatibility; editable surfaces are borderless.
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final bool hasError;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      child: Builder(
        builder: (focusContext) => _buildSurface(
          context,
          isFocused || Focus.of(focusContext).hasFocus,
        ),
      ),
    );
  }

  Widget _buildSurface(BuildContext context, bool focused) {
    final colors = Theme.of(context).colorScheme;
    final isEnabled = enabled ?? true;
    final focusColor = borderColor ?? colors.primary;
    final glowColor = hasError
        ? colors.error.withValues(alpha: focused ? 0.92 : 0.68)
        : focused && isEnabled
        ? focusColor.withValues(alpha: focusColor.a * 0.82)
        : Colors.transparent;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120);
    final radius = BorderRadius.circular(borderRadius);

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      constraints: constraints,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor ?? inputSurfaceFillColor(colors),
        borderRadius: radius,
      ),
      child: CustomPaint(
        foregroundPainter: _InputSurfaceGlowPainter(
          borderRadius: radius,
          color: glowColor,
        ),
        child: padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );
  }
}

class _InputSurfaceGlowPainter extends CustomPainter {
  const _InputSurfaceGlowPainter({
    required this.borderRadius,
    required this.color,
  });

  final BorderRadius borderRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    paintInputInnerGlow(
      canvas,
      Offset.zero & size,
      borderRadius: borderRadius,
      color: color,
    );
  }

  @override
  bool shouldRepaint(_InputSurfaceGlowPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius || oldDelegate.color != color;
  }
}
