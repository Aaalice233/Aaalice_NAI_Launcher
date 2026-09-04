import 'dart:ui';

import '../constants/storage_keys.dart';

const double defaultWindowWidth = 1600;
const double defaultWindowHeight = 900;
const double minimumWindowWidth = 800;
const double minimumWindowHeight = 600;

class WindowStateSnapshot {
  const WindowStateSnapshot({
    required this.normalBounds,
    required this.maximized,
    this.positionKnown = true,
    this.scaleFactor = 1,
  });

  final Rect normalBounds;
  final bool maximized;
  final bool positionKnown;
  final double scaleFactor;

  WindowStateSnapshot copyWith({
    Rect? normalBounds,
    bool? maximized,
    bool? positionKnown,
    double? scaleFactor,
  }) {
    return WindowStateSnapshot(
      normalBounds: normalBounds ?? this.normalBounds,
      maximized: maximized ?? this.maximized,
      positionKnown: positionKnown ?? this.positionKnown,
      scaleFactor: scaleFactor ?? this.scaleFactor,
    );
  }

  Map<String, Object> toJson() => {
    'version': 2,
    'x': normalBounds.left,
    'y': normalBounds.top,
    'width': normalBounds.width,
    'height': normalBounds.height,
    'maximized': maximized,
    'scaleFactor': scaleFactor,
  };
}

class WindowRestorePlan {
  const WindowRestorePlan({
    required this.normalBounds,
    required this.maximized,
    required this.scaleFactor,
  });

  final Rect normalBounds;
  final bool maximized;
  final double scaleFactor;
}

WindowStateSnapshot readWindowStateSnapshot({
  required Object? storedState,
  required Object? legacyWidth,
  required Object? legacyHeight,
  required Object? legacyX,
  required Object? legacyY,
  double legacyScale = 1,
  Map<Rect, double> legacyWorkAreaScaleFactors = const {},
}) {
  if (storedState case final Map<Object?, Object?> values) {
    final version = _finiteDouble(values['version']);
    final width = _positiveFiniteDouble(values['width']);
    final height = _positiveFiniteDouble(values['height']);
    final x = _finiteDouble(values['x']);
    final y = _finiteDouble(values['y']);
    final maximized = values['maximized'];
    final scaleFactor = _positiveFiniteDouble(values['scaleFactor']) ?? 1;
    if (version == 2 &&
        width != null &&
        height != null &&
        x != null &&
        y != null &&
        maximized is bool) {
      return WindowStateSnapshot(
        normalBounds: Rect.fromLTWH(x, y, width, height),
        maximized: maximized,
        scaleFactor: scaleFactor,
      );
    }
  }

  final rawWidth = _positiveFiniteDouble(legacyWidth) ?? defaultWindowWidth;
  final rawHeight = _positiveFiniteDouble(legacyHeight) ?? defaultWindowHeight;
  final x = _finiteDouble(legacyX);
  final y = _finiteDouble(legacyY);
  final rawBounds = x != null && y != null
      ? Rect.fromLTWH(x, y, rawWidth, rawHeight)
      : null;
  final scaleFactor = rawBounds == null
      ? _validScale(legacyScale)
      : _bestLegacyScale(
          rawBounds,
          legacyWorkAreaScaleFactors,
          _validScale(legacyScale),
        );
  return WindowStateSnapshot(
    normalBounds: Rect.fromLTWH(
      (x ?? 0) * scaleFactor,
      (y ?? 0) * scaleFactor,
      rawWidth * scaleFactor,
      rawHeight * scaleFactor,
    ),
    maximized: false,
    positionKnown: x != null && y != null,
    scaleFactor: scaleFactor,
  );
}

WindowRestorePlan resolveWindowRestorePlan({
  required WindowStateSnapshot snapshot,
  required List<Rect> workAreas,
  required Rect? primaryWorkArea,
  Map<Rect, double> workAreaScaleFactors = const {},
}) {
  final validAreas = workAreas.where(_isValidWorkArea).toList(growable: false);
  final validPrimary =
      primaryWorkArea != null && _isValidWorkArea(primaryWorkArea)
      ? primaryWorkArea
      : null;

  if (validAreas.isEmpty && validPrimary == null) {
    final saved = snapshot.normalBounds;
    final hasPosition =
        snapshot.positionKnown && saved.left.isFinite && saved.top.isFinite;
    return WindowRestorePlan(
      normalBounds: Rect.fromLTWH(
        hasPosition ? saved.left : 0,
        hasPosition ? saved.top : 0,
        _validDimension(saved.width, defaultWindowWidth),
        _validDimension(saved.height, defaultWindowHeight),
      ),
      maximized: snapshot.maximized,
      scaleFactor: _validScale(snapshot.scaleFactor),
    );
  }

  final fallbackArea = validPrimary ?? validAreas.first;
  final areas = validAreas.isEmpty ? <Rect>[fallbackArea] : validAreas;
  final saved = snapshot.normalBounds;
  final hasPosition =
      snapshot.positionKnown && saved.left.isFinite && saved.top.isFinite;
  final bestArea = hasPosition ? _bestWorkArea(saved, areas) : null;
  final targetArea = bestArea ?? fallbackArea;
  final targetScale = _validScale(workAreaScaleFactors[targetArea]);
  final sourceScale = _validScale(snapshot.scaleFactor);
  final scaledSavedWidth = saved.width / sourceScale * targetScale;
  final scaledSavedHeight = saved.height / sourceScale * targetScale;
  final width = _fitDimension(
    _validDimension(scaledSavedWidth, defaultWindowWidth * targetScale),
    minimumWindowWidth * targetScale,
    targetArea.width,
  );
  final height = _fitDimension(
    _validDimension(scaledSavedHeight, defaultWindowHeight * targetScale),
    minimumWindowHeight * targetScale,
    targetArea.height,
  );

  final Offset position;
  if (!hasPosition || bestArea == null) {
    position = Offset(
      _centerCoordinate(targetArea.left, targetArea.width, width),
      _centerCoordinate(targetArea.top, targetArea.height, height),
    );
  } else {
    position = Offset(
      _fitCoordinate(saved.left, targetArea.left, targetArea.right - width),
      _fitCoordinate(saved.top, targetArea.top, targetArea.bottom - height),
    );
  }

  return WindowRestorePlan(
    normalBounds: Rect.fromLTWH(position.dx, position.dy, width, height),
    maximized: snapshot.maximized,
    scaleFactor: targetScale,
  );
}

bool isValidNormalWindowBounds(Rect bounds) {
  return bounds.left.isFinite &&
      bounds.top.isFinite &&
      bounds.width.isFinite &&
      bounds.height.isFinite &&
      bounds.width > 0 &&
      bounds.height > 0;
}

double _bestLegacyScale(
  Rect rawBounds,
  Map<Rect, double> workAreaScaleFactors,
  double fallback,
) {
  var bestScale = fallback;
  var bestIntersection = 0.0;
  for (final entry in workAreaScaleFactors.entries) {
    final scale = _validScale(entry.value);
    final physicalArea = entry.key;
    final legacyLogicalArea = Rect.fromLTRB(
      physicalArea.left / scale,
      physicalArea.top / scale,
      physicalArea.right / scale,
      physicalArea.bottom / scale,
    );
    final overlap = rawBounds.intersect(legacyLogicalArea);
    final intersection = overlap.width > 0 && overlap.height > 0
        ? overlap.width * overlap.height
        : 0.0;
    if (intersection > bestIntersection) {
      bestScale = scale;
      bestIntersection = intersection;
    }
  }
  return bestScale;
}

Rect? _bestWorkArea(Rect bounds, List<Rect> workAreas) {
  Rect? best;
  var bestIntersection = 0.0;
  for (final area in workAreas) {
    final overlap = bounds.intersect(area);
    final intersection = overlap.width > 0 && overlap.height > 0
        ? overlap.width * overlap.height
        : 0.0;
    if (intersection > bestIntersection) {
      best = area;
      bestIntersection = intersection;
    }
  }
  return best;
}

bool _isValidWorkArea(Rect area) =>
    area.left.isFinite &&
    area.top.isFinite &&
    area.width.isFinite &&
    area.height.isFinite &&
    area.width > 0 &&
    area.height > 0;

double _fitDimension(double value, double minimum, double available) {
  if (available < minimum) return minimum;
  return value.clamp(minimum, available).toDouble();
}

double _centerCoordinate(double start, double available, double windowSize) {
  if (windowSize >= available) return start;
  return start + (available - windowSize) / 2;
}

double _fitCoordinate(double value, double minimum, double maximum) {
  if (maximum < minimum) return minimum;
  return value.clamp(minimum, maximum).toDouble();
}

double _validDimension(double value, double fallback) =>
    value.isFinite && value > 0 ? value : fallback;

double _validScale(double? value) =>
    value != null && value.isFinite && value > 0 ? value : 1.0;

double? _positiveFiniteDouble(Object? value) {
  final number = _finiteDouble(value);
  return number != null && number > 0 ? number : null;
}

double? _finiteDouble(Object? value) {
  if (value is num && value.isFinite) return value.toDouble();
  return null;
}

Future<void> persistWindowStateSnapshot({
  required Future<void> Function(String key, Object value) put,
  required WindowStateSnapshot snapshot,
}) {
  return put(StorageKeys.windowStateV2, snapshot.toJson());
}
