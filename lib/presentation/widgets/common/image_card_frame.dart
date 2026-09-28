import 'package:flutter/material.dart';

import '../../adaptive/interaction_policy.dart';
import '../../themes/theme_extension.dart';
import 'image_card_hover_motion.dart';
import 'image_viewport_surface.dart';

/// Media and business overlays keep their identity while the frame reacts.
class ImageCardFrame extends StatelessWidget {
  const ImageCardFrame({
    super.key,
    required this.child,
    this.information,
    this.badges = const [],
    this.actions,
    this.overlays = const [],
    this.width,
    this.height,
    this.radius = 12,
    this.clipRadius,
    this.hovered = false,
    this.focused = false,
    this.selected = false,
    this.previewActive = false,
    this.hoverScaleEnabled = true,
    this.restingShadow = false,
    this.hoverLift = 0,
    this.animate = true,
  });

  final Widget child;
  final Widget? information;
  final List<Widget> badges;
  final Widget? actions;
  final List<Widget> overlays;
  final double? width;
  final double? height;
  final double radius;
  final double? clipRadius;
  final bool hovered;
  final bool focused;
  final bool selected;
  final bool previewActive;
  final bool hoverScaleEnabled;
  final bool restingShadow;
  final double hoverLift;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context) || !animate;
    final showFocus =
        focused && context.interactionPolicy.keyboardNavigationActive;
    final edge = BorderRadius.circular(radius);
    final border = selected || previewActive || showFocus
        ? Border.all(
            color: previewActive && !selected
                ? theme.colorScheme.tertiary
                : theme.colorScheme.primary,
            width: selected || previewActive ? 2 : 1,
          )
        : null;
    return ImageCardHoverMotion(
      hovered: hovered,
      enabled: hoverScaleEnabled && animate,
      child: AnimatedContainer(
        width: width,
        height: height,
        duration: reduceMotion ? Duration.zero : theme.appTheme.fastDuration,
        curve: theme.appTheme.standardCurve,
        transform: Matrix4.translationValues(
          0,
          !reduceMotion && hovered ? -hoverLift : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: ImageViewportSurface.background,
          borderRadius: edge,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: hovered
                    ? 0.16
                    : restingShadow
                    ? 0.08
                    : 0,
              ),
              blurRadius: hovered
                  ? 14
                  : restingShadow
                  ? 6
                  : 0,
              offset: Offset(
                0,
                hovered
                    ? 6
                    : restingShadow
                    ? 2
                    : 0,
              ),
            ),
          ],
        ),
        // The selection/focus border must not resize the media viewport.
        foregroundDecoration: BoxDecoration(borderRadius: edge, border: border),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(clipRadius ?? radius),
          child:
              information == null &&
                  badges.isEmpty &&
                  actions == null &&
                  overlays.isEmpty
              ? child
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    child,
                    if (information != null) information!,
                    ...badges,
                    if (actions != null) actions!,
                    ...overlays,
                  ],
                ),
        ),
      ),
    );
  }
}
