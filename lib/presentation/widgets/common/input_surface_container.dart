import 'package:flutter/material.dart';

import '../../themes/core/input_surface_style.dart';

/// Shared deep surface for editable controls.
///
/// Focus is expressed with a crisp outer outline rather than an inner glow or
/// shadow. The stroke is painted inside the existing bounds, so state changes
/// never alter layout.
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
  final Color? borderColor;
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
    final effectiveBorderColor = !isEnabled
        ? (borderColor ?? colors.outlineVariant).withValues(alpha: 0.18)
        : hasError
        ? (borderColor ?? colors.error).withValues(alpha: focused ? 0.9 : 0.62)
        : focused
        ? colors.primary.withValues(alpha: 0.68)
        : (borderColor ?? colors.outlineVariant).withValues(alpha: 0.4);
    final effectiveBorderWidth = hasError || focused
        ? 1.0
        : borderWidth > 0
        ? borderWidth
        : 0.0;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120);

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      constraints: constraints,
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? inputSurfaceFillColor(colors),
        borderRadius: BorderRadius.circular(borderRadius),
        border: effectiveBorderWidth > 0
            ? Border.all(
                color: effectiveBorderColor,
                width: effectiveBorderWidth,
                strokeAlign: BorderSide.strokeAlignInside,
              )
            : null,
      ),
      child: child,
    );
  }
}
