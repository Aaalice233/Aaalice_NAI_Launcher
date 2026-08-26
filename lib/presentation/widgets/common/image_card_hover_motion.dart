import 'package:flutter/material.dart';

import '../../themes/theme_extension.dart';

/// Shared hover motion for interactive image cards.
///
/// The transform is paint-only, so cards keep their grid geometry while gaining
/// a clear pointer affordance. Reduced-motion mode retains other hover feedback
/// without scaling the image.
class ImageCardHoverMotion extends StatelessWidget {
  const ImageCardHoverMotion({
    super.key,
    required this.hovered,
    required this.child,
    this.enabled = true,
  });

  static const double hoverScale = 1.01;

  final bool hovered;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final scale = enabled && hovered && !reducedMotion ? hoverScale : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: reducedMotion || !enabled
          ? Duration.zero
          : theme.appTheme.fastDuration,
      curve: theme.appTheme.standardCurve,
      alignment: Alignment.center,
      child: child,
    );
  }
}
