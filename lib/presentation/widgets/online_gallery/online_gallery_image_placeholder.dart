import 'package:flutter/material.dart';

import '../common/image_viewport_surface.dart';
import '../../../core/utils/localization_extension.dart';

/// Stable, low-contrast surface used while gallery media is unavailable.
class OnlineGalleryImagePlaceholder extends StatelessWidget {
  const OnlineGalleryImagePlaceholder({
    super.key,
    this.failed = false,
    this.loading = false,
    this.onRetry,
  });

  final bool failed;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ImageViewportSurface.background,
      child: failed
          ? Center(
              child: onRetry == null
                  ? const Icon(
                      Icons.image_not_supported_outlined,
                      color: ImageViewportSurface.mutedForeground,
                    )
                  : IconButton(
                      onPressed: onRetry,
                      tooltip: context.l10n.common_retry,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: ImageViewportSurface.mutedForeground,
                      ),
                    ),
            )
          : loading
          ? const Center(
              child: Icon(
                Icons.downloading_rounded,
                size: 20,
                color: ImageViewportSurface.mutedForeground,
              ),
            )
          : const SizedBox.expand(),
    );
  }
}
