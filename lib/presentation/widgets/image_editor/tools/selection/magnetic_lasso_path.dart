import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../../core/utils/magnetic_lasso/edge_cost_map.dart';
import '../../../../../core/utils/magnetic_lasso/live_wire.dart';

typedef LassoPixel = math.Point<int>;

/// 一条待闭合的磁性套索路径，按锚点保存固定的像素段。
class MagneticLassoPath {
  MagneticLassoPath(this.frame, Offset start) {
    _segments.add([pixelAt(start)]);
  }

  final Rect frame;
  final _segments = <List<LassoPixel>>[];
  List<LassoPixel> _preview = const [];
  LiveWire? _wire;
  EdgeCostMap? get edgeMap => _wire?.map;

  int get anchorCount => _segments.length;
  LassoPixel get _first => _segments.first.first;
  LassoPixel get _last => _segments.last.last;
  Offset get start => _canvasPoint(_first);

  LassoPixel pixelAt(Offset point) => LassoPixel(
    (point.dx - frame.left).floor().clamp(0, frame.width.round() - 1),
    (point.dy - frame.top).floor().clamp(0, frame.height.round() - 1),
  );

  Offset _canvasPoint(LassoPixel pixel) =>
      frame.topLeft.translate(pixel.x + 0.5, pixel.y + 0.5);

  void setEdgeMap(
    EdgeCostMap map, {
    required int contrast,
    required int radius,
  }) {
    _wire = LiveWire(map, contrast: contrast);
    _seed(radius);
  }

  void _seed(int radius) => _wire?.setSeed(_last.x, _last.y, radius: radius);

  void _fix(List<LassoPixel> segment, int radius) {
    if (segment.length < 2) return;
    _segments.add(segment.sublist(1)); // 段起点已经是上一段的终点。
    _seed(radius);
  }

  List<LassoPixel>? _trace(LassoPixel target) =>
      _wire?.pathTo(target.x, target.y);

  void addAnchor(Offset point, int radius) {
    final target = pixelAt(point);
    _fix(_trace(target) ?? _line(_last, target), radius);
    clearPreview();
  }

  void removeAnchor(int radius) {
    _segments.removeLast();
    _seed(radius);
    clearPreview();
  }

  void clearPreview() => _preview = const [];

  void updatePreview(
    Offset point, {
    required int width,
    required int radius,
    required int interval,
    bool fixAnchors = true,
  }) {
    final pixel = pixelAt(point);
    final wire = _wire;
    if (wire == null) {
      _preview = [_last, pixel];
      return;
    }
    final target = wire.snap(pixel.x, pixel.y, width: width);
    var segment = _trace(target);
    if (segment == null && fixAnchors) {
      _fix(_preview, radius);
      segment = _trace(target);
    }
    if (fixAnchors && (segment == null || segment.length >= interval)) {
      _fix(segment ?? _line(_last, target), radius);
      clearPreview();
    } else {
      _preview = segment ?? _line(_last, target);
    }
  }

  Path previewPath(double scale) {
    final path = _toPath([
      for (final segment in _segments) ...segment.map(_canvasPoint),
      ..._preview.skip(1).map(_canvasPoint),
    ]);
    for (final segment in _segments) {
      path.addRect(
        Rect.fromCenter(
          center: _canvasPoint(segment.last),
          width: 6 / scale,
          height: 6 / scale,
        ),
      );
    }
    return path;
  }

  Path? closedPath() {
    final closing = _trace(_first) ?? _line(_last, _first);
    final points = _simplify([
      for (final segment in _segments) ...segment.map(_canvasPoint),
      ...closing.skip(1).map(_canvasPoint),
    ]);
    if (points.length < 3) return null;
    final path = _toPath(points)..close();
    final bounds = path.getBounds();
    return bounds.width <= 2 || bounds.height <= 2 ? null : path;
  }
}

Path _toPath(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  return path;
}

// Bresenham 整数直线，保留两端像素。
List<LassoPixel> _line(LassoPixel from, LassoPixel to) {
  final points = <LassoPixel>[];
  var x = from.x;
  var y = from.y;
  final dx = (to.x - x).abs();
  final dy = -(to.y - y).abs();
  final stepX = x < to.x ? 1 : -1;
  final stepY = y < to.y ? 1 : -1;
  var error = dx + dy;
  while (true) {
    points.add(LassoPixel(x, y));
    if (x == to.x && y == to.y) return points;
    final doubled = 2 * error;
    if (doubled >= dy) {
      error += dy;
      x += stepX;
    }
    if (doubled <= dx) {
      error += dx;
      y += stepY;
    }
  }
}

// 闭环做 Ramer–Douglas–Peucker 简化，最后一个重复起点交给 Path.close。
List<Offset> _simplify(List<Offset> points) {
  final last = points.length - 1;
  final keep = List.filled(points.length, false)..[0] = true;
  final pending = <(int, int)>[(0, last)];
  while (pending.isNotEmpty) {
    final (start, end) = pending.removeLast();
    var split = -1;
    var farthest = 0.75 * 0.75;
    for (var i = start + 1; i < end; i++) {
      final distance = _distanceSquared(points[i], points[start], points[end]);
      if (distance > farthest) {
        split = i;
        farthest = distance;
      }
    }
    if (split >= 0) {
      keep[split] = true;
      pending.add((start, split));
      pending.add((split, end));
    }
  }
  return [
    for (var i = 0; i < last; i++)
      if (keep[i]) points[i],
  ];
}

double _distanceSquared(Offset point, Offset start, Offset end) {
  final delta = end - start;
  final relative = point - start;
  final length = delta.distanceSquared;
  if (length == 0) return relative.distanceSquared;
  final t = ((relative.dx * delta.dx + relative.dy * delta.dy) / length).clamp(
    0.0,
    1.0,
  );
  return (relative - delta * t).distanceSquared;
}
