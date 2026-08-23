import 'dart:math';

abstract final class OnlineGalleryPreloadPolicy {
  static const double _minimumLoadAheadDistance = 900;
  static const double _loadAheadScreens = 1.25;
  static const double _cacheExtentScreens = 0.75;

  static double loadAheadDistance(double viewportHeight) => max(
    _minimumLoadAheadDistance,
    viewportHeight * _loadAheadScreens,
  ).toDouble();

  static double cacheExtent(double viewportHeight) =>
      max(0, viewportHeight * _cacheExtentScreens).toDouble();

  static int lookaheadItemCount({
    required double viewportHeight,
    required double itemWidth,
    required int columnCount,
  }) {
    if (viewportHeight <= 0 || itemWidth <= 0 || columnCount <= 0) return 12;
    final rowsPerScreen = (viewportHeight / itemWidth).ceil();
    return (rowsPerScreen * columnCount * _cacheExtentScreens)
        .ceil()
        .clamp(12, 48)
        .toInt();
  }
}
