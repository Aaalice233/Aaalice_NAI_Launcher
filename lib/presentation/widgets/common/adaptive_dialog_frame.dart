import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gives dialog bodies a bounded viewport without forcing short content to
/// occupy the full available height. The reserved space accounts for route
/// insets, titles and action rows that live outside [child].
class AdaptiveDialogFrame extends StatelessWidget {
  const AdaptiveDialogFrame({
    super.key,
    required this.maxWidth,
    required this.maxHeight,
    required this.child,
    this.reservedVerticalSpace = 48,
    this.scaleReservedVerticalSpace = false,
    this.horizontalMargin = 24,
  });

  final double maxWidth;
  final double maxHeight;
  final double reservedVerticalSpace;
  final bool scaleReservedVerticalSpace;
  final double horizontalMargin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final scaleReserve = scaleReservedVerticalSpace
        ? math.max(0, mediaQuery.textScaler.scale(1) - 1) * 40
        : 0.0;
    final viewportHeight = math.max(
      0.0,
      mediaQuery.size.height -
          mediaQuery.padding.vertical -
          mediaQuery.viewInsets.vertical -
          reservedVerticalSpace -
          scaleReserve,
    );
    final viewportWidth = math.max(
      0.0,
      mediaQuery.size.width -
          mediaQuery.padding.horizontal -
          mediaQuery.viewInsets.horizontal -
          horizontalMargin * 2,
    );

    // AlertDialog measures its content intrinsically. LayoutBuilder cannot
    // provide intrinsic dimensions, so derive the bounds from the viewport.
    // Width remains stable on desktop, while height is only capped: forcing
    // maxHeight here makes every short dialog look like a mostly empty panel.
    return SizedBox(
      width: math.min(maxWidth, viewportWidth),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.min(maxHeight, viewportHeight),
        ),
        child: child,
      ),
    );
  }
}
