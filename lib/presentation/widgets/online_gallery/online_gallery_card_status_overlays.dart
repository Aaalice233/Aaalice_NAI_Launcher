import 'package:flutter/material.dart';

/// Groups the passive status markers that share a gallery card's top-right
/// corner so they never compete with its action controls.
class OnlineGalleryCardStatusOverlays extends StatelessWidget {
  const OnlineGalleryCardStatusOverlays({
    super.key,
    required this.favoriteReadOnly,
    required this.favoriteReadOnlyTooltip,
    required this.mediaCount,
    this.secondaryFavoriteIcon,
    this.secondaryFavoriteTooltip,
    this.badgeLabel,
  });

  final bool favoriteReadOnly;
  final String favoriteReadOnlyTooltip;
  final IconData? secondaryFavoriteIcon;
  final String? secondaryFavoriteTooltip;
  final String? badgeLabel;
  final int mediaCount;

  @override
  Widget build(BuildContext context) {
    final hasFavoriteStatus =
        favoriteReadOnly ||
        (secondaryFavoriteIcon != null && secondaryFavoriteTooltip != null);
    final hasSourceBadge = badgeLabel != null || mediaCount > 1;

    if (!hasFavoriteStatus && !hasSourceBadge) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const ValueKey('online-gallery-card-status-overlays'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (hasFavoriteStatus)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (secondaryFavoriteIcon != null &&
                  secondaryFavoriteTooltip != null)
                _FavoriteStatusIcon(
                  icon: secondaryFavoriteIcon!,
                  tooltip: secondaryFavoriteTooltip!,
                ),
              if (favoriteReadOnly && secondaryFavoriteIcon != null)
                const SizedBox(width: 4),
              if (favoriteReadOnly)
                _FavoriteStatusIcon(
                  icon: Icons.favorite,
                  tooltip: favoriteReadOnlyTooltip,
                ),
            ],
          ),
        if (hasFavoriteStatus && hasSourceBadge) const SizedBox(height: 4),
        if (hasSourceBadge)
          Container(
            key: const ValueKey('online-gallery-card-source-badge'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badgeLabel != null) ...[
                  const Icon(
                    Icons.brush_outlined,
                    size: 11,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    badgeLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (badgeLabel != null && mediaCount > 1)
                  const SizedBox(width: 6),
                if (mediaCount > 1) ...[
                  const Icon(
                    Icons.collections_outlined,
                    size: 11,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$mediaCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Lays out the status markers that share a gallery card's top-left corner.
///
/// Keeping them in one flow lets each marker use its rendered height at large
/// text scales instead of relying on offsets derived from the default height.
class OnlineGalleryCardLeftStatusOverlays extends StatelessWidget {
  const OnlineGalleryCardLeftStatusOverlays({
    super.key,
    this.rank,
    this.ratingLabel,
    this.ratingColor,
    required this.isVideo,
    required this.isAnimated,
    required this.videoLabel,
    required this.animatedLabel,
  });

  final int? rank;
  final String? ratingLabel;
  final Color? ratingColor;
  final bool isVideo;
  final bool isAnimated;
  final String videoLabel;
  final String animatedLabel;

  @override
  Widget build(BuildContext context) {
    final hasRating = ratingLabel != null && ratingColor != null;
    final hasMediaType = isVideo || isAnimated;

    if (rank == null && !hasRating && !hasMediaType) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const ValueKey('online-gallery-card-left-status-overlays'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rank != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (rank != null && (hasRating || hasMediaType))
          const SizedBox(height: 4),
        if (hasRating)
          OnlineGalleryCardRatingBadge(
            label: ratingLabel!,
            color: ratingColor!,
          ),
        if (hasRating && hasMediaType) const SizedBox(height: 4),
        if (hasMediaType)
          Container(
            key: const ValueKey('online-gallery-card-media-type-badge'),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: isVideo ? Colors.purple : Colors.blue,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isVideo ? Icons.play_circle_fill : Icons.gif_box,
                  size: 10,
                  color: Colors.white,
                ),
                const SizedBox(width: 2),
                Text(
                  isVideo ? videoLabel : animatedLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class OnlineGalleryCardRatingBadge extends StatelessWidget {
  const OnlineGalleryCardRatingBadge({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('online-gallery-card-rating-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _FavoriteStatusIcon extends StatelessWidget {
  const _FavoriteStatusIcon({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: Colors.redAccent),
      ),
    );
  }
}
