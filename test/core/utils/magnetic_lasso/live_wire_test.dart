import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/magnetic_lasso/edge_cost_map.dart';
import 'package:nai_launcher/core/utils/magnetic_lasso/live_wire.dart';

void main() {
  group('LiveWire', () {
    test('follows a vertical step within one pixel', () {
      final map = _edgeMap(32, 32, (x, y) => x < 16 ? 0 : 255);
      final wire = LiveWire(map, contrast: 10)..setSeed(15, 2, radius: 30);
      final path = wire.pathTo(16, 29)!;

      expect(path.first, const Point(15, 2));
      expect(path.last, const Point(16, 29));
      for (final point in path) {
        expect((point.x - 15.5).abs(), lessThanOrEqualTo(1));
      }
    });

    test('follows the arc of a disk within two pixels', () {
      const center = Point(32, 32);
      const radius = 20;
      final map = _edgeMap(65, 65, (x, y) {
        final dx = x - center.x;
        final dy = y - center.y;
        return dx * dx + dy * dy <= radius * radius ? 20 : 240;
      });
      final wire = LiveWire(map, contrast: 10)..setSeed(32, 12, radius: 44);
      final path = wire.pathTo(52, 32)!;

      expect(path.first, const Point(32, 12));
      expect(path.last, const Point(52, 32));
      for (final point in path) {
        expect(
          (point.distanceTo(center) - radius).abs(),
          lessThanOrEqualTo(2),
          reason: 'Point $point is too far from the circle',
        );
      }
    });

    test('snaps to the nearest strongest edge only within the radius', () {
      final map = _edgeMap(32, 16, (x, y) => x < 16 ? 0 : 255);
      final wire = LiveWire(map, contrast: 10);

      expect(wire.snap(11, 8, width: 4), const Point(15, 8));
      expect(wire.snap(11, 8, width: 3), const Point(11, 8));
      expect(wire.snap(19, 8, width: 6), const Point(16, 8));
      expect(wire.snap(11, 8, width: 0), const Point(11, 8));
    });

    test('does not snap to a diagonal outside the circular search area', () {
      final map = _edgeMap(5, 5, (x, y) => x == 3 && y == 3 ? 255 : 0);
      final wire = LiveWire(map, contrast: 10);

      expect(wire.snap(1, 1, width: 1), const Point(1, 1));
      expect(wire.snap(1, 1, width: 2), const Point(2, 2));
    });

    test('filters weak edges at high contrast and clamps contrast', () {
      final map = _edgeMap(40, 10, (x, y) {
        if (x < 10) return 0;
        if (x < 30) return 40;
        return 240;
      });
      final low = LiveWire(map, contrast: 0);
      final high = LiveWire(map, contrast: 35);
      final maximum = LiveWire(map, contrast: 101);

      expect(low.map, same(map));
      expect(low.contrast, 1);
      expect(maximum.contrast, 100);
      expect(low.snap(7, 5, width: 3), const Point(9, 5));
      expect(high.snap(7, 5, width: 3), const Point(7, 5));
      expect(high.snap(27, 5, width: 3), const Point(29, 5));
      expect(maximum.snap(27, 5, width: 3), const Point(27, 5));
    });

    test(
      'clips its window and returns null when the target is unavailable',
      () {
        final map = _edgeMap(10, 10, (x, y) => 0);
        final wire = LiveWire(map, contrast: 10);

        expect(wire.hasSeed, isFalse);
        expect(wire.containsInWindow(0, 0), isFalse);
        expect(wire.pathTo(0, 0), isNull);

        wire.setSeed(1, 1, radius: 2);
        expect(wire.hasSeed, isTrue);
        expect(wire.containsInWindow(0, 0), isTrue);
        expect(wire.containsInWindow(3, 3), isTrue);
        expect(wire.containsInWindow(-1, 0), isFalse);
        expect(wire.pathTo(4, 1), isNull);
        expect(wire.pathTo(1, 1), [const Point(1, 1)]);

        wire.setSeed(7, 7, radius: 0);
        expect(wire.pathTo(1, 1), isNull);
        expect(wire.pathTo(7, 7), [const Point(7, 7)]);
      },
    );

    test('has deterministic ties between equal-cost paths', () {
      final map = _edgeMap(6, 6, (x, y) => 0);
      final wire = LiveWire(map, contrast: 10)..setSeed(0, 0, radius: 5);
      final path = wire.pathTo(3, 2)!;

      wire.setSeed(0, 0, radius: 5);
      expect(wire.pathTo(3, 2), orderedEquals(path));
    });

    test(
      'returns minimum costs throughout the window, with diagonal steps',
      () {
        final map = _edgeMap(7, 6, (x, y) => (29 * x * x + 91 * y) % 256);
        final wire = LiveWire(map, contrast: 20)..setSeed(0, 0, radius: 6);
        final points = [
          for (var y = 0; y < map.height; y++)
            for (var x = 0; x < map.width; x++) Point(x, y),
        ];
        final costs = _referenceCosts(wire, points);

        for (final target in points) {
          final path = wire.pathTo(target.x, target.y)!;
          expect(path.first, points.first);
          expect(path.last, target);
          var cost = 0;
          for (var i = 1; i < path.length; i++) {
            final delta = path[i] - path[i - 1];
            expect(max(delta.x.abs(), delta.y.abs()), 1);
            cost += _stepCost(wire, path[i - 1], path[i]);
          }
          expect(cost, costs[target], reason: 'Target $target');
        }
      },
    );
  });
}

EdgeCostMap _edgeMap(int width, int height, int Function(int, int) luminance) {
  final rgba = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final offset = (y * width + x) * 4;
      rgba.fillRange(offset, offset + 3, luminance(x, y));
      rgba[offset + 3] = 255;
    }
  }
  return EdgeCostMap.build(rgba, width, height);
}

// Scan unsettled pixels by distance instead of using a bucket queue.
Map<Point<int>, int> _referenceCosts(LiveWire wire, List<Point<int>> points) {
  final distances = {points.first: 0};
  final remaining = points.toSet();
  while (remaining.isNotEmpty) {
    final current = remaining
        .where(distances.containsKey)
        .reduce((a, b) => distances[a]! <= distances[b]! ? a : b);
    remaining.remove(current);
    for (final next in remaining) {
      final delta = next - current;
      if (max(delta.x.abs(), delta.y.abs()) > 1) continue;
      final cost = distances[current]! + _stepCost(wire, current, next);
      final previous = distances[next];
      if (previous == null || cost < previous) distances[next] = cost;
    }
  }
  return distances;
}

int _stepCost(LiveWire wire, Point<int> p, Point<int> q) {
  final map = wire.map;
  final index = q.y * map.width + q.x;
  final threshold = wire.contrast / 100;
  final strength = map.strength[index];
  final effective = strength <= threshold
      ? 0
      : (strength - threshold) / (1 - threshold);
  final zeroPenalty = map.zeroCrossing[index] == 1 ? 0 : 1;
  final cost = ((0.65 * (1 - effective) + 0.25 * zeroPenalty + 0.10) * 100)
      .round();
  return p.x == q.x || p.y == q.y ? cost : (cost * 1.4142).round();
}
