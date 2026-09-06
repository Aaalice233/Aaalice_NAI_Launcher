import 'package:flutter/material.dart';

import '../../adaptive/interaction_policy.dart';
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
    this.focusedBorderColor,
    this.borderWidth = 0,
    this.padding,
    this.hasError = false,
    this.isFocused = false,
    this.keyboardFocusOnly = false,
  });

  final Widget child;
  final double borderRadius;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final bool? enabled;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final bool hasError;
  final bool isFocused;
  // Editable fields indicate the active input even after a pointer click;
  // selectors only need a focus outline during keyboard navigation.
  final bool keyboardFocusOnly;

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
    focused =
        focused &&
        (!keyboardFocusOnly ||
            context.interactionPolicy.keyboardNavigationActive);
    final colors = Theme.of(context).colorScheme;
    final isEnabled = enabled ?? true;
    final showsRestingBorder = borderWidth > 0;
    final effectiveBorderColor = !isEnabled
        ? showsRestingBorder
              ? (borderColor ?? colors.outlineVariant).withValues(alpha: 0.18)
              : Colors.transparent
        : hasError
        ? (borderColor ?? colors.error).withValues(alpha: focused ? 0.9 : 0.62)
        : focused
        ? focusedBorderColor ?? colors.primary.withValues(alpha: 0.68)
        : showsRestingBorder
        ? (borderColor ?? colors.outlineVariant).withValues(alpha: 0.4)
        : Colors.transparent;
    final effectiveBorderWidth = showsRestingBorder ? borderWidth : 1.0;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120);

    return Container(
      width: width,
      height: height,
      constraints: constraints,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        clipBehavior: Clip.antiAlias,
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor ?? inputSurfaceFillColor(colors),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: effectiveBorderColor,
            width: effectiveBorderWidth,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: child,
      ),
    );
  }
}
