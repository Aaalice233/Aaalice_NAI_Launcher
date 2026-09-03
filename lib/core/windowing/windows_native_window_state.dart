import 'package:flutter/services.dart';

import '../utils/window_state_persistence.dart';
import 'desktop_window_state_controller.dart';

class DesktopWorkAreas {
  const DesktopWorkAreas({
    required this.all,
    required this.primary,
    required this.primaryScaleFactor,
    required this.scaleFactors,
  });

  final List<Rect> all;
  final Rect primary;
  final double primaryScaleFactor;
  final Map<Rect, double> scaleFactors;
}

class WindowsNativeWindowStatePlatform implements DesktopWindowStatePlatform {
  const WindowsNativeWindowStatePlatform();

  static const MethodChannel _channel = MethodChannel(
    'com.nailauncher/window_state',
  );

  Future<DesktopWorkAreas> getWorkAreas() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'getWorkAreas',
    );
    final rawAreas = result?['areas'];
    final rawPrimary = result?['primary'];
    final primaryScaleFactor = _finiteDouble(result?['primaryScaleFactor']);
    if (rawAreas is! List ||
        rawPrimary is! Map ||
        primaryScaleFactor == null ||
        primaryScaleFactor <= 0) {
      throw const FormatException('Invalid native work-area response');
    }

    final areas = <Rect>[];
    final scaleFactors = <Rect, double>{};
    for (final value in rawAreas) {
      final area = _readRect(value);
      final scaleFactor = value is Map
          ? _finiteDouble(value['scaleFactor'])
          : null;
      if (area == null || scaleFactor == null || scaleFactor <= 0) continue;
      areas.add(area);
      scaleFactors[area] = scaleFactor;
    }
    final primary = _readRect(rawPrimary);
    if (areas.isEmpty || primary == null) {
      throw const FormatException('Native work-area response was empty');
    }
    return DesktopWorkAreas(
      all: areas,
      primary: primary,
      primaryScaleFactor: primaryScaleFactor,
      scaleFactors: scaleFactors,
    );
  }

  void setBoundsChangedHandler(Future<void> Function() handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'boundsChanged') await handler();
    });
  }

  Future<void> restore(WindowRestorePlan plan) {
    return _channel.invokeMethod<void>('restore', {
      ..._writeRect(plan.normalBounds),
      'maximized': plan.maximized,
    });
  }

  Future<void> synchronizeViewMetrics() {
    return _channel.invokeMethod<void>('synchronizeViewMetrics');
  }

  @override
  Future<DesktopWindowStateReading> readState() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'readState',
    );
    final bounds = _readRect(result?['bounds']);
    final maximized = result?['maximized'];
    final minimized = result?['minimized'];
    final scaleFactor = _finiteDouble(result?['scaleFactor']);
    if (bounds == null ||
        maximized is! bool ||
        minimized is! bool ||
        scaleFactor == null ||
        scaleFactor <= 0) {
      throw const FormatException('Invalid native window-state response');
    }
    return DesktopWindowStateReading(
      bounds: bounds,
      maximized: maximized,
      minimized: minimized,
      scaleFactor: scaleFactor,
    );
  }
}

Rect? _readRect(Object? value) {
  if (value is! Map) return null;
  final x = _finiteDouble(value['x']);
  final y = _finiteDouble(value['y']);
  final width = _finiteDouble(value['width']);
  final height = _finiteDouble(value['height']);
  if (x == null ||
      y == null ||
      width == null ||
      height == null ||
      width <= 0 ||
      height <= 0) {
    return null;
  }
  return Rect.fromLTWH(x, y, width, height);
}

Map<String, double> _writeRect(Rect rect) => {
  'x': rect.left,
  'y': rect.top,
  'width': rect.width,
  'height': rect.height,
};

double? _finiteDouble(Object? value) {
  if (value is num && value.isFinite) return value.toDouble();
  return null;
}
