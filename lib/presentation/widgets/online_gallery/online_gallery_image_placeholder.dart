import 'package:flutter/material.dart';

/// Stable, low-contrast surface used while gallery media is unavailable.
class OnlineGalleryImagePlaceholder extends StatelessWidget {
  const OnlineGalleryImagePlaceholder({
    super.key,
    this.failed = false,
    this.loading = false,
  });

  final bool failed;
  final bool loading;

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
          : loading
          ? Center(
              child: Icon(
                Icons.downloading_rounded,
                size: 20,
                color: colors.onSurfaceVariant.withValues(alpha: 0.28),
              ),
            )
          : const SizedBox.expand(),
    );
  }
}
