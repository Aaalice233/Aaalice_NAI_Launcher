import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/magnetic_lasso/edge_cost_map.dart';

void main() {
  group('EdgeCostMap', () {
    test('rejects wrong RGBA lengths and nonpositive dimensions', () {
      expect(() => EdgeCostMap.build(Uint8List(3), 1, 1), throwsArgumentError);
      expect(() => EdgeCostMap.build(Uint8List(5), 1, 1), throwsArgumentError);
      expect(() => EdgeCostMap.build(Uint8List(8), 1, 1), throwsArgumentError);
      expect(() => EdgeCostMap.build(Uint8List(0), 0, 1), throwsArgumentError);
      expect(() => EdgeCostMap.build(Uint8List(0), 1, -1), throwsArgumentError);
    });

    test('uses RGB Sobel even when both colors have the same luminance', () {
      // 0.587 * 31 == 0.299 * 1 + 0.114 * 157.
      final left = [0, 31, 0, 255];
      final right = [1, 0, 157, 255];
      final rgba = Uint8List.fromList([...left, ...left, ...right, ...right]);
      final map = EdgeCostMap.build(rgba, 4, 1);

      expect(map.strength, orderedEquals([0, 1, 1, 0]));
      expect(map.zeroCrossing, everyElement(0));
    });

    test('premultiplies RGB by alpha before both edge calculations', () {
      final rgba = Uint8List.fromList([
        231,
        123,
        255,
        0,
        0,
        134,
        63,
        0,
        255,
        0,
        0,
        64,
        255,
        0,
        0,
        64,
      ]);
      final opaque = Uint8List.fromList([
        0,
        0,
        0,
        255,
        0,
        0,
        0,
        255,
        64,
        0,
        0,
        255,
        64,
        0,
        0,
        255,
      ]);
      final map = EdgeCostMap.build(rgba, 4, 1);
      final reference = EdgeCostMap.build(opaque, 4, 1);

      expect(map.strength, orderedEquals(reference.strength));
      expect(map.zeroCrossing, orderedEquals(reference.zeroCrossing));
    });

    test('uses P99 rather than the maximum gradient and clips outliers', () {
      final rgba = _grayscaleRow(
        List.generate(300, (x) {
          if (x < 100) return 0;
          if (x < 200) return 40;
          return x < 299 ? 140 : 255;
        }),
      );
      final map = EdgeCostMap.build(rgba, 300, 1);

      expect(map.strength[99], closeTo(0.4, 1e-6));
      expect(map.strength[199], 1);
      expect(map.strength[299], 1); // Sobel samples clamp at the image border.
    });

    test('leaves all strengths zero when P99 itself is zero', () {
      final rgba = _grayscaleRow(List.generate(400, (x) => x == 200 ? 255 : 0));
      final map = EdgeCostMap.build(rgba, 400, 1);

      expect(map.strength, everyElement(0));
    });

    test('marks both sides of an equal-magnitude zero crossing', () {
      final map = EdgeCostMap.build(_grayscaleRow([0, 0, 255, 255]), 4, 1);

      expect(map.zeroCrossing, orderedEquals([0, 1, 1, 0]));
    });

    test('marks only the smaller Laplacian at an unequal zero crossing', () {
      final map = EdgeCostMap.build(
        _grayscaleRow([0, 0, 0, 100, 150, 150, 150]),
        7,
        1,
      );

      expect(map.zeroCrossing, orderedEquals([0, 0, 0, 1, 0, 0, 0]));
    });

    test(
      'buildAsync returns the same dimensions and features as build',
      () async {
        final row = _grayscaleRow([0, 0, 220, 220, 160, 160]);
        final rgba = Uint8List.fromList([...row, ...row]);
        final sync = EdgeCostMap.build(rgba, 6, 2);
        final background = await EdgeCostMap.buildAsync(rgba, 6, 2);

        expect(background.width, sync.width);
        expect(background.height, sync.height);
        expect(background.strength, orderedEquals(sync.strength));
        expect(background.zeroCrossing, orderedEquals(sync.zeroCrossing));
      },
    );
  });
}

Uint8List _grayscaleRow(List<int> values) => Uint8List.fromList([
  for (final v in values) ...[v, v, v, 255],
]);
