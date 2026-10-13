import 'dart:math' as math;
import 'dart:ui';

const double _fallbackMaxWidth = 500;
const double _fallbackMaxMediaHeight = 650;

/// Largest card whose media area keeps [aspectRatio] inside [maxSize].
///
/// [footerHeight] is docked below the media and included in the height.
Size fitImageCardSize({
  required double aspectRatio,
  required Size maxSize,
  double footerHeight = 0,
}) {
  final safeAspectRatio = aspectRatio.isFinite && aspectRatio > 0
      ? aspectRatio
      : 1.0;
  final footer = footerHeight.isFinite ? math.max(0.0, footerHeight) : 0.0;
  final maxWidth = maxSize.width.isFinite
      ? math.max(0.0, maxSize.width)
      : _fallbackMaxWidth;
  final maxMediaHeight = maxSize.height.isFinite
      ? math.max(0.0, maxSize.height - footer)
      : _fallbackMaxMediaHeight;

  var width = maxWidth;
  var mediaHeight = width / safeAspectRatio;
  if (mediaHeight > maxMediaHeight) {
    mediaHeight = maxMediaHeight;
    width = mediaHeight * safeAspectRatio;
  }

  final height = mediaHeight.clamp(0.0, maxMediaHeight) + footer;
  return Size(
    width.clamp(0.0, maxWidth).toDouble(),
    maxSize.height.isFinite
        ? math.min(height, math.max(0.0, maxSize.height))
        : height,
  );
}
