import 'package:flutter/material.dart';

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
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: failed
          ? Center(
              child: onRetry == null
                  ? Icon(
                      Icons.image_not_supported_outlined,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.38),
                    )
                  : IconButton(
                      onPressed: onRetry,
                      tooltip: context.l10n.common_retry,
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.62),
                      ),
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
