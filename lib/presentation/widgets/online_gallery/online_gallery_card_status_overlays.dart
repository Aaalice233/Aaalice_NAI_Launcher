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
    this.badgeUsesModelColor = false,
  });

  final bool favoriteReadOnly;
  final String favoriteReadOnlyTooltip;
  final IconData? secondaryFavoriteIcon;
  final String? secondaryFavoriteTooltip;
  final String? badgeLabel;
  final bool badgeUsesModelColor;
  final int mediaCount;

  @override
  Widget build(BuildContext context) {
    final hasFavoriteStatus =
        favoriteReadOnly ||
        (secondaryFavoriteIcon != null && secondaryFavoriteTooltip != null);
    final hasSourceBadge = badgeLabel != null;
    final hasMediaCountBadge = mediaCount > 1;
    final hasGalleryStatus = hasSourceBadge || hasMediaCountBadge;

    if (!hasFavoriteStatus && !hasGalleryStatus) {
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
        if (hasFavoriteStatus && hasGalleryStatus) const SizedBox(height: 4),
        if (hasSourceBadge)
          _GallerySourceBadge(
            label: badgeLabel!,
            backgroundColor: badgeUsesModelColor
                ? _modelBadgeColor(badgeLabel!)
                : null,
          ),
        if (hasSourceBadge && hasMediaCountBadge) const SizedBox(height: 4),
        if (hasMediaCountBadge) _GalleryMediaCountBadge(count: mediaCount),
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
    this.codexBadgeLabel,
    this.ratingLabel,
    this.ratingColor,
    required this.isVideo,
    required this.isAnimated,
    required this.videoLabel,
    required this.animatedLabel,
  });

  final int? rank;
  final String? codexBadgeLabel;
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

    if (rank == null &&
        codexBadgeLabel == null &&
        !hasRating &&
        !hasMediaType) {
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
        if (rank != null &&
            (codexBadgeLabel != null || hasRating || hasMediaType))
          const SizedBox(height: 4),
        if (codexBadgeLabel != null)
          _GallerySourceBadge(label: codexBadgeLabel!),
        if (codexBadgeLabel != null && (hasRating || hasMediaType))
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

class _GallerySourceBadge extends StatelessWidget {
  const _GallerySourceBadge({required this.label, this.backgroundColor});

  final String label;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('online-gallery-card-source-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.brush_outlined, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryMediaCountBadge extends StatelessWidget {
  const _GalleryMediaCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('online-gallery-card-media-count-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.collections_outlined, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps well-known model families visually distinct while producing a stable
/// fallback for model labels that AI TAG adds later.
Color _modelBadgeColor(String label) {
  final normalized = label.trim().toLowerCase();
  if (normalized.contains('nai v5')) return const Color(0xFF9F1239);
  if (normalized.contains('nai v4.5')) return const Color(0xFF6D28D9);
  if (normalized.contains('nai v4')) return const Color(0xFF1D4ED8);
  if (normalized.contains('nai v3')) return const Color(0xFF0F766E);
  if (normalized.contains('sdxl')) return const Color(0xFFB45309);
  if (normalized.contains('stable diffusion') ||
      RegExp(r'\bsd(?:\s|$)').hasMatch(normalized)) {
    return const Color(0xFF3F6212);
  }
  if (normalized.contains('comfy')) return const Color(0xFF9D174D);

  const fallbackPalette = <Color>[
    Color(0xFF075985),
    Color(0xFF7E22CE),
    Color(0xFF0F766E),
    Color(0xFFB45309),
    Color(0xFFB91C1C),
    Color(0xFF3F6212),
  ];
  var hash = 0;
  for (final codeUnit in normalized.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7FFFFFFF;
  }
  return fallbackPalette[hash % fallbackPalette.length];
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
