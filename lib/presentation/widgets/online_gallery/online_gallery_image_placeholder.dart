import 'package:flutter/material.dart';

/// Stable, low-contrast surface used while gallery media is unavailable.
class OnlineGalleryImagePlaceholder extends StatelessWidget {
  const OnlineGalleryImagePlaceholder({super.key, this.failed = false});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: failed
          ? Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: colors.onSurfaceVariant.withValues(alpha: 0.38),
              ),
            )
          : const SizedBox.expand(),
    );
  }
}
