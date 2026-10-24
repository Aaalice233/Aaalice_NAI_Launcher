import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/raster_cache/raster_cache_geometry.dart';

void main() {
  group('DevicePixelTransform.fromMatrix', () {
    test('accepts uniform scale with translation', () {
      final matrix = Matrix4.diagonal3Values(2, 2, 1)
        ..setTranslationRaw(10.5, 3.25, 0);

      final transform = DevicePixelTransform.fromMatrix(matrix)!;

      expect(transform.scale, 2);
      expect(transform.translation, const Offset(10.5, 3.25));
    });

    test('rejects rotation, skew, perspective and non-uniform scale', () {
      expect(DevicePixelTransform.fromMatrix(Matrix4.rotationZ(0.1)), isNull);
      expect(
        DevicePixelTransform.fromMatrix(Matrix4.skewX(math.pi / 16)),
        isNull,
      );
      expect(
        DevicePixelTransform.fromMatrix(
          Matrix4.identity()..setEntry(3, 0, 0.01),
        ),
        isNull,
      );
      expect(
        DevicePixelTransform.fromMatrix(Matrix4.diagonal3Values(2, 3, 1)),
        isNull,
      );
      expect(
        DevicePixelTransform.fromMatrix(Matrix4.diagonal3Values(-1, -1, 1)),
        isNull,
      );
    });
  });

  group('DevicePixelTransform.isWholePixelShiftOf', () {
    const snapshot = DevicePixelTransform(
      scale: 3,
      translation: Offset(30.9, 23.1),
    );

    test('accepts whole device pixel shifts and float noise', () {
      expect(
        const DevicePixelTransform(
          scale: 3,
          translation: Offset(33.9, 20.1),
        ).isWholePixelShiftOf(snapshot),
        isTrue,
      );
      expect(
        const DevicePixelTransform(
          scale: 3,
          translation: Offset(30.9000000001, 23.0999999999),
        ).isWholePixelShiftOf(snapshot),
        isTrue,
      );
    });

    test('rejects sub-pixel shifts and scale changes', () {
      expect(
        const DevicePixelTransform(
          scale: 3,
          translation: Offset(31.4, 23.1),
        ).isWholePixelShiftOf(snapshot),
        isFalse,
      );
      expect(
        const DevicePixelTransform(
          scale: 2,
          translation: Offset(30.9, 23.1),
        ).isWholePixelShiftOf(snapshot),
        isFalse,
      );
    });
  });

  group('RasterCacheGeometry.tryCreate', () {
    test('rounds outward, aligns the origin to the dither grid and keeps the '
        'sub-pixel phase', () {
      const transform = DevicePixelTransform(
        scale: 3,
        translation: Offset(30.9, 23.1),
      );

      final geometry = RasterCacheGeometry.tryCreate(
        contentBounds: const Rect.fromLTWH(0, 0, 100, 50),
        transform: transform,
        maxDimension: 8192,
        maxPixels: 1 << 24,
      )!;

      expect(geometry.pixelRect, const Rect.fromLTRB(24, 16, 331, 174));
      expect(geometry.width, 307);
      expect(geometry.height, 158);
      expect(
        transform.toDevice(geometry.destination),
        rectMoreOrLessEquals(geometry.pixelRect, epsilon: 1e-9),
      );
      final snapshotOrigin = MatrixUtils.transformPoint(
        geometry.snapshotTransform,
        Offset.zero,
      );
      expect(snapshotOrigin.dx, moreOrLessEquals(6.9, epsilon: 1e-9));
      expect(snapshotOrigin.dy, moreOrLessEquals(7.1, epsilon: 1e-9));
    });

    test('does not add a pixel column for float noise on whole edges', () {
      final geometry = RasterCacheGeometry.tryCreate(
        contentBounds: const Rect.fromLTWH(0, 0, 100, 50),
        transform: const DevicePixelTransform(
          scale: 2,
          translation: Offset(20.0000000001, 9.9999999999),
        ),
        maxDimension: 8192,
        maxPixels: 1 << 24,
      )!;

      expect(geometry.pixelRect, const Rect.fromLTRB(16, 8, 220, 110));
    });

    test('returns null for empty or oversized content', () {
      const transform = DevicePixelTransform(
        scale: 1,
        translation: Offset.zero,
      );
      expect(
        RasterCacheGeometry.tryCreate(
          contentBounds: Rect.zero,
          transform: transform,
          maxDimension: 8192,
          maxPixels: 1 << 24,
        ),
        isNull,
      );
      expect(
        RasterCacheGeometry.tryCreate(
          contentBounds: const Rect.fromLTWH(0, 0, 9000, 10),
          transform: transform,
          maxDimension: 8192,
          maxPixels: 1 << 24,
        ),
        isNull,
      );
      expect(
        RasterCacheGeometry.tryCreate(
          contentBounds: const Rect.fromLTWH(0, 0, 5000, 5000),
          transform: transform,
          maxDimension: 8192,
          maxPixels: 1 << 24,
        ),
        isNull,
      );
    });
  });
}
