import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../themes/core/layered_surface_style.dart';

/// A thin boundary keeps the floating editor identifiable over similar neutral
/// surfaces without adding outlines to its individual controls.
class PromptActionSurface extends StatelessWidget {
  const PromptActionSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: overlaySurfaceColor(colors),
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outline),
      ),
      child: child,
    );
  }
}

/// Measures the real action content before positioning it. Translation length,
/// text scaling and the keyboard therefore cannot invalidate a fixed height.
class PromptActionOverlay extends StatelessWidget {
  const PromptActionOverlay({
    super.key,
    required this.anchor,
    required this.overlaySize,
    required this.child,
  });
  final Rect anchor;
  final Size overlaySize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Scaffold removes consumed keyboard insets from its body. The root overlay
    // still spans the full view, so use the metrics above that resize boundary.
    final media = MediaQuery.of(Scaffold.maybeOf(context)?.context ?? context);
    final left = media.padding.left + 8;
    final top = media.padding.top + 8;
    final right = math.max(left, overlaySize.width - media.padding.right - 8);
    final bottom = math.max(
      top,
      overlaySize.height -
          math.max(media.padding.bottom, media.viewInsets.bottom) -
          8,
    );
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _PromptActionLayout(
          anchor,
          Rect.fromLTRB(left, top, right, bottom),
        ),
        child: SingleChildScrollView(
          key: const ValueKey('prompt-action-viewport'),
          child: child,
        ),
      ),
    );
  }
}

class _PromptActionLayout extends SingleChildLayoutDelegate {
  const _PromptActionLayout(this.anchor, this.bounds);
  final Rect anchor;
  final Rect bounds;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.min(420, bounds.width),
        maxHeight: bounds.height,
      );
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final above = anchor.top - childSize.height - 6;
    final y = above >= bounds.top ? above : anchor.bottom + 6;
    return Offset(
      anchor.left.clamp(
        bounds.left,
        math.max(bounds.left, bounds.right - childSize.width),
      ),
      y.clamp(
        bounds.top,
        math.max(bounds.top, bounds.bottom - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_PromptActionLayout oldDelegate) =>
      anchor != oldDelegate.anchor || bounds != oldDelegate.bounds;
}
