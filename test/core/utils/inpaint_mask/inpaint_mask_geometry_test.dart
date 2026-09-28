import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/inpaint_mask/inpaint_mask_geometry.dart';
import 'package:nai_launcher/core/utils/inpaint_mask/inpaint_mask_operations.dart';

Uint8List _rasterize(
  List<InpaintMaskRegion> regions, {
  int width = 16,
  int height = 16,
  double expandRatio = 0,
}) => InpaintMaskGeometry.rasterizeBinary(
  regions: regions,
  width: width,
  height: height,
  expandRatio: expandRatio,
);

int _countMasked(Uint8List mask) =>
    mask.fold(0, (total, value) => total + value);

void main() {
  group('InpaintMaskGeometry.rasterizeBinary', () {
    test(
      'fills a rect using the same outward rounding as createRectMaskBytes',
      () {
        const width = 20;
        const height = 10;
        const rect = Rect.fromLTRB(0.11, 0.21, 0.34, 0.68);

        final geometry = _rasterize(
          const [InpaintMaskRegion.rect(rect)],
          width: width,
          height: height,
        );
        final reference = InpaintMaskUtils.createRectMaskBytes(
          width: width,
          height: height,
          rect: Rect.fromLTRB(
            rect.left * width,
            rect.top * height,
            rect.right * width,
            rect.bottom * height,
          ),
        );
        final decoded = img.decodeImage(reference)!;

        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final expected = decoded.getPixel(x, y).r > 127 ? 1 : 0;
            expect(
              geometry[y * width + x],
              equals(expected),
              reason: 'pixel ($x,$y) diverged from createRectMaskBytes',
            );
          }
        }
      },
    );

    test('clamps out-of-range normalized bounds to the canvas', () {
      final mask = _rasterize(
        const [InpaintMaskRegion.rect(Rect.fromLTRB(-0.5, -0.5, 1.5, 1.5))],
        width: 8,
        height: 8,
      );

      expect(_countMasked(mask), equals(64));
    });

    test('ellipse stays inside its bounds and is horizontally symmetric', () {
      const size = 32;
      final mask = _rasterize(
        const [
          InpaintMaskRegion.ellipse(Rect.fromLTRB(0.25, 0.25, 0.75, 0.75)),
        ],
        width: size,
        height: size,
      );

      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          if (x < 8 || x >= 24 || y < 8 || y >= 24) {
            expect(mask[y * size + x], equals(0), reason: 'leaked at ($x,$y)');
          }
        }
      }
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size ~/ 2; x++) {
          expect(
            mask[y * size + x],
            equals(mask[y * size + (size - 1 - x)]),
            reason: 'row $y is not symmetric at column $x',
          );
        }
      }
      expect(mask[16 * size + 16], equals(1));
      expect(_countMasked(mask), lessThan(16 * 16));
    });

    test('polygon fills a triangle and leaves the opposite corner empty', () {
      const size = 16;
      final mask = _rasterize(
        const [
          InpaintMaskRegion.polygon([Offset(0, 0), Offset(1, 0), Offset(0, 1)]),
        ],
        width: size,
        height: size,
      );

      expect(mask[0], equals(1));
      expect(mask[size * size - 1], equals(0));
      final filled = _countMasked(mask);
      expect(filled, greaterThan(size * size ~/ 3));
      expect(filled, lessThan(size * size * 2 ~/ 3));
    });

    test('subtract punches a hole out of an earlier region', () {
      const size = 16;
      final mask = _rasterize(
        const [
          InpaintMaskRegion.rect(Rect.fromLTRB(0, 0, 1, 1)),
          InpaintMaskRegion.rect(
            Rect.fromLTRB(0.25, 0.25, 0.75, 0.75),
            mode: InpaintMaskRegionMode.subtract,
          ),
        ],
        width: size,
        height: size,
      );

      expect(mask[0], equals(1));
      expect(mask[8 * size + 8], equals(0));
      expect(_countMasked(mask), equals(size * size - 8 * 8));
    });

    test('rejects empty regions, bad extents and negative expansion', () {
      expect(
        () => _rasterize(const []),
        throwsA(isA<InpaintMaskGeometryException>()),
      );
      expect(
        () => _rasterize(const [
          InpaintMaskRegion.rect(Rect.fromLTRB(0.5, 0.5, 0.5, 0.9)),
        ]),
        throwsA(isA<InpaintMaskGeometryException>()),
      );
      expect(
        () => _rasterize(const [
          InpaintMaskRegion.polygon([Offset(0, 0), Offset(1, 1)]),
        ]),
        throwsA(isA<InpaintMaskGeometryException>()),
      );
      expect(
        () => _rasterize(const [
          InpaintMaskRegion.rect(Rect.fromLTRB(0, 0, 1, 1)),
        ], expandRatio: -0.1),
        throwsA(isA<InpaintMaskGeometryException>()),
      );
    });
  });

  group('InpaintMaskGeometry.expandBinary', () {
    test('grows a single pixel into a Chebyshev square', () {
      const size = 11;
      final mask = Uint8List(size * size);
      mask[5 * size + 5] = 1;

      final expanded = InpaintMaskGeometry.expandBinary(
        mask,
        width: size,
        height: size,
        radius: 2,
      );

      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final inside = (x - 5).abs() <= 2 && (y - 5).abs() <= 2;
          expect(
            expanded[y * size + x],
            equals(inside ? 1 : 0),
            reason: 'pixel ($x,$y)',
          );
        }
      }
    });

    test('matches repeated 3x3 dilation for the same radius', () {
      const width = 24;
      const height = 18;
      final mask = Uint8List(width * height);
      mask[4 * width + 6] = 1;
      mask[12 * width + 17] = 1;

      var reference = Uint8List.fromList(mask);
      for (var step = 0; step < 3; step++) {
        final next = Uint8List(width * height);
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            var hit = false;
            for (var dy = -1; dy <= 1 && !hit; dy++) {
              for (var dx = -1; dx <= 1; dx++) {
                final nx = x + dx;
                final ny = y + dy;
                if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
                if (reference[ny * width + nx] == 1) {
                  hit = true;
                  break;
                }
              }
            }
            next[y * width + x] = hit ? 1 : 0;
          }
        }
        reference = next;
      }

      final expanded = InpaintMaskGeometry.expandBinary(
        mask,
        width: width,
        height: height,
        radius: 3,
      );

      expect(expanded, equals(reference));
    });

    test('clips growth at the canvas edge and keeps an empty mask empty', () {
      const size = 6;
      final corner = Uint8List(size * size);
      corner[0] = 1;

      final expanded = InpaintMaskGeometry.expandBinary(
        corner,
        width: size,
        height: size,
        radius: 2,
      );
      expect(_countMasked(expanded), equals(9));

      final empty = InpaintMaskGeometry.expandBinary(
        Uint8List(size * size),
        width: size,
        height: size,
        radius: 3,
      );
      expect(_countMasked(empty), equals(0));
    });

    test('rejects a mask whose length does not match the dimensions', () {
      expect(
        () => InpaintMaskGeometry.expandBinary(
          Uint8List(10),
          width: 4,
          height: 4,
          radius: 1,
        ),
        throwsA(isA<InpaintMaskGeometryException>()),
      );
    });
  });

  group('InpaintMaskGeometry.rasterizeToPng', () {
    test('encodes an opaque black and white mask at the requested size', () {
      const width = 12;
      const height = 9;
      final png = InpaintMaskGeometry.rasterizeToPng(
        regions: const [
          InpaintMaskRegion.rect(Rect.fromLTRB(0.0, 0.0, 0.5, 1.0)),
        ],
        width: width,
        height: height,
      );
      final decoded = img.decodeImage(png)!;

      expect(decoded.width, equals(width));
      expect(decoded.height, equals(height));
      expect(decoded.getPixel(0, 0).r.toInt(), equals(255));
      expect(decoded.getPixel(0, 0).a.toInt(), equals(255));
      expect(decoded.getPixel(width - 1, 0).r.toInt(), equals(0));
      expect(decoded.getPixel(width - 1, 0).a.toInt(), equals(255));
    });
  });
}
