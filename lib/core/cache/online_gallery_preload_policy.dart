import 'dart:math';

abstract final class OnlineGalleryPreloadPolicy {
  static const double _minimumLoadAheadDistance = 900;
  static const double _loadAheadScreens = 1.25;
  // Rendering stays close to the viewport; network/image prefetch keeps its
  // larger independent lookahead below. A 1.25-screen render cache built 60+
  // pending cards in one navigation frame on a 7-column desktop grid.
  static const double _renderCacheExtentScreens = 0.35;
  static const double _thumbnailLookaheadScreens = 1.25;

  static double loadAheadDistance(double viewportHeight) => max(
    _minimumLoadAheadDistance,
    viewportHeight * _loadAheadScreens,
  ).toDouble();

  static double cacheExtent(double viewportHeight) =>
      max(0, viewportHeight * _renderCacheExtentScreens).toDouble();

  static int lookaheadItemCount({
    required double viewportHeight,
    required double itemWidth,
    required int columnCount,
  }) {
    if (viewportHeight <= 0 || itemWidth <= 0 || columnCount <= 0) return 12;
    final rowsPerScreen = (viewportHeight / itemWidth).ceil();
    return (rowsPerScreen * columnCount * _thumbnailLookaheadScreens)
        .ceil()
        .clamp(12, 48)
        .toInt();
  }
}
