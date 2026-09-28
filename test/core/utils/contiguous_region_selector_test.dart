import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/contiguous_region_selector.dart';

void main() {
  group('ContiguousRegionSelector', () {
    test('selects only the four-connected matching region', () {
      final rgba = _rgbaImage(3, 3, [
        _red,
        _blue,
        _blue,
        _blue,
        _red,
        _blue,
        _blue,
        _blue,
        _red,
      ]);

      final result = ContiguousRegionSelector.selectRgba(
        rgba: rgba,
        width: 3,
        height: 3,
        startX: 0,
        startY: 0,
        tolerance: 0,
      );

      expect(result.mask, orderedEquals([1, 0, 0, 0, 0, 0, 0, 0, 0]));
      expect(result.selectedPixelCount, 1);
    });

    test('includes neighboring colors within per-channel tolerance', () {
      final rgba = _rgbaImage(4, 1, [
        const [100, 100, 100, 255],
        const [110, 90, 105, 255],
        const [121, 100, 100, 255],
        const [105, 105, 105, 255],
      ]);

      final result = ContiguousRegionSelector.selectRgba(
        rgba: rgba,
        width: 4,
        height: 1,
        startX: 0,
        startY: 0,
        tolerance: 20,
      );

      expect(result.mask, orderedEquals([1, 1, 0, 0]));
      expect(result.selectedPixelCount, 2);
    });

    test('treats fully transparent pixels as equal regardless of RGB', () {
      final rgba = _rgbaImage(3, 1, [
        const [255, 0, 0, 0],
        const [0, 255, 0, 0],
        const [0, 0, 255, 255],
      ]);

      final result = ContiguousRegionSelector.selectRgba(
        rgba: rgba,
        width: 3,
        height: 1,
        startX: 0,
        startY: 0,
        tolerance: 0,
      );

      expect(result.mask, orderedEquals([1, 1, 0]));
      expect(result.selectedPixelCount, 2);
    });

    test('can invert the contiguous selection', () {
      final rgba = _rgbaImage(3, 1, [_red, _red, _blue]);

      final result = ContiguousRegionSelector.selectRgba(
        rgba: rgba,
        width: 3,
        height: 1,
        startX: 0,
        startY: 0,
        tolerance: 0,
        invert: true,
      );

      expect(result.mask, orderedEquals([0, 0, 1]));
      expect(result.selectedPixelCount, 1);
    });

    test('returns an empty selection for an out-of-bounds seed', () {
      final result = ContiguousRegionSelector.selectRgba(
        rgba: _rgbaImage(1, 1, [_red]),
        width: 1,
        height: 1,
        startX: -1,
        startY: 0,
        tolerance: 0,
        invert: true,
      );

      expect(result.mask, orderedEquals([0]));
      expect(result.isEmpty, isTrue);
    });

    test('rejects a buffer smaller than the declared dimensions', () {
      expect(
        () => ContiguousRegionSelector.selectRgba(
          rgba: Uint8List(3),
          width: 1,
          height: 1,
          startX: 0,
          startY: 0,
          tolerance: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}

const List<int> _red = [255, 0, 0, 255];
const List<int> _blue = [0, 0, 255, 255];

Uint8List _rgbaImage(int width, int height, List<List<int>> pixels) {
  expect(pixels, hasLength(width * height));
  return Uint8List.fromList(pixels.expand((pixel) => pixel).toList());
}
