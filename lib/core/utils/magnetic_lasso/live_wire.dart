import 'dart:math';
import 'dart:typed_data';

import 'edge_cost_map.dart';

/// Finds minimum-cost paths from an anchor pixel through an [EdgeCostMap].
class LiveWire {
  LiveWire(this.map, {required int contrast})
    : contrast = contrast.clamp(1, 100);

  final EdgeCostMap map;

  /// Strengths at or below `contrast / 100` are treated as zero.
  final int contrast;

  _SearchWindow? _window;

  bool get hasSeed => _window != null;

  /// Computes the complete shortest-path tree within [radius] pixels of the
  /// seed on each axis, clipped to the image. The seed must be in the image and
  /// [radius] must be nonnegative.
  void setSeed(int x, int y, {required int radius}) {
    RangeError.checkValueInInterval(x, 0, map.width - 1, 'x');
    RangeError.checkValueInInterval(y, 0, map.height - 1, 'y');
    if (radius < 0) throw RangeError.range(radius, 0, null, 'radius');

    final left = x - min<int>(radius, x);
    final top = y - min<int>(radius, y);
    final right = x + min<int>(radius, map.width - 1 - x);
    final bottom = y + min<int>(radius, map.height - 1 - y);
    final width = right - left + 1;
    final window = _SearchWindow(
      left,
      top,
      width,
      bottom - top + 1,
      (y - top) * width + x - left,
    );
    _runDijkstra(window, _costsForWindow(window));
    _window = window;
  }

  bool containsInWindow(int x, int y) => _window?.contains(x, y) ?? false;

  /// Returns the path from seed to target, including both endpoints, or null
  /// if the target is outside the current window or there is no seed.
  List<Point<int>>? pathTo(int x, int y) {
    final window = _window;
    if (window == null || !window.contains(x, y)) return null;

    final path = <Point<int>>[];
    var pixel = (y - window.top) * window.width + x - window.left;
    while (true) {
      path.add(
        Point(
          window.left + pixel % window.width,
          window.top + pixel ~/ window.width,
        ),
      );
      if (pixel == window.seed) break;
      pixel = window.predecessors[pixel];
    }
    return path.reversed.toList();
  }

  /// Finds the strongest effective edge within a circle of radius [width].
  /// Ties prefer the closest pixel, then the first in row-major order.
  Point<int> snap(int x, int y, {required int width}) {
    if (width <= 0 || contrast == 100) return Point(x, y);

    final left = max(0, x - width);
    final right = x + min<int>(width, map.width - 1 - x);
    final top = max(0, y - width);
    final bottom = y + min<int>(width, map.height - 1 - y);
    final radiusSquared = width.toDouble() * width;
    final threshold = contrast / 100;
    var bestX = x;
    var bestY = y;
    var bestStrength = 0.0;
    var bestDistance = 0;
    for (var py = top; py <= bottom; py++) {
      final row = py * map.width;
      final dy = py - y;
      for (var px = left; px <= right; px++) {
        final dx = px - x;
        final distance = dx * dx + dy * dy;
        if (distance > radiusSquared) continue;
        final strength = _effectiveStrength(map.strength[row + px], threshold);
        if (strength > bestStrength ||
            strength == bestStrength && distance < bestDistance) {
          bestX = px;
          bestY = py;
          bestStrength = strength;
          bestDistance = distance;
        }
      }
    }
    return Point(bestX, bestY);
  }

  ({Uint8List straight, Uint8List diagonal}) _costsForWindow(
    _SearchWindow window,
  ) {
    final straight = Uint8List(window.predecessors.length);
    final diagonal = Uint8List(straight.length);
    final threshold = contrast / 100;
    var pixel = 0;
    for (var y = 0; y < window.height; y++) {
      final row = (window.top + y) * map.width + window.left;
      for (var x = 0; x < window.width; x++, pixel++) {
        final index = row + x;
        final strength = _effectiveStrength(map.strength[index], threshold);
        final zeroPenalty = map.zeroCrossing[index] == 1 ? 0 : 1;
        final cost = ((0.65 * (1 - strength) + 0.25 * zeroPenalty + 0.10) * 100)
            .round();
        straight[pixel] = cost;
        diagonal[pixel] = (cost * 1.4142).round();
      }
    }
    return (straight: straight, diagonal: diagonal);
  }
}

double _effectiveStrength(double strength, double threshold) =>
    strength <= threshold ? 0.0 : (strength - threshold) / (1 - threshold);

class _SearchWindow {
  _SearchWindow(this.left, this.top, this.width, this.height, this.seed)
    : predecessors = Int32List(width * height);

  final int left;
  final int top;
  final int width;
  final int height;
  final int seed;
  final Int32List predecessors;

  bool contains(int x, int y) =>
      x >= left && x < left + width && y >= top && y < top + height;
}

void _runDijkstra(
  _SearchWindow window,
  ({Uint8List straight, Uint8List diagonal}) costs,
) {
  // round(100 * 1.4142) is 141, the greatest possible edge cost.
  const bucketCount = 142;
  final buckets = List.generate(bucketCount, (_) => <int>[]);
  final predecessors = window.predecessors;
  final distances = Int64List(predecessors.length);
  final width = window.width;
  final height = window.height;
  final straight = costs.straight;
  final diagonal = costs.diagonal;

  // Store distance + 1 so zero denotes a pixel that has not been reached.
  distances[window.seed] = 1;
  buckets[0].add(window.seed);
  var pending = 1;
  var distance = 1;
  var bucketIndex = 0;
  while (pending != 0) {
    final bucket = buckets[bucketIndex];
    if (bucket.isEmpty) {
      distance++;
      bucketIndex++;
      if (bucketIndex == bucketCount) bucketIndex = 0;
      continue;
    }
    final pixel = bucket.removeLast();
    pending--;
    // A cheaper path may have inserted this pixel again in an earlier bucket.
    if (distances[pixel] != distance) continue;

    final y = pixel ~/ width;
    final x = pixel - y * width;
    final minDx = x == 0 ? 0 : -1;
    final maxDx = x + 1 == width ? 0 : 1;
    final minDy = y == 0 ? 0 : -1;
    final maxDy = y + 1 == height ? 0 : 1;
    // Fixed neighbor order, LIFO order within a bucket, and strict improvement
    // ensure that equal-cost paths always resolve to the same predecessor.
    for (var dy = minDy; dy <= maxDy; dy++) {
      final row = pixel + dy * width;
      for (var dx = minDx; dx <= maxDx; dx++) {
        if (dx == 0 && dy == 0) continue;
        final next = row + dx;
        final step = dx == 0 || dy == 0 ? straight[next] : diagonal[next];
        final candidate = distance + step;
        final previous = distances[next];
        if (previous != 0 && candidate >= previous) continue;

        distances[next] = candidate;
        predecessors[next] = pixel;
        final nextBucket = bucketIndex + step;
        buckets[nextBucket < bucketCount
                ? nextBucket
                : nextBucket - bucketCount]
            .add(next);
        pending++;
      }
    }
  }
}
