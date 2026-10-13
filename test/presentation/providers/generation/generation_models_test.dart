import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_models.dart';

void main() {
  group('ImageComparisonSource.isCompatibleWithDimensions', () {
    final source = _source(832, 1216);

    test('accepts exact ratios and enhance grid rounding', () {
      expect(source.isCompatibleWithDimensions(832, 1216), isTrue);
      expect(source.isCompatibleWithDimensions(1664, 2432), isTrue);
      expect(source.isCompatibleWithDimensions(1280, 1792), isTrue);
      expect(source.isCompatibleWithDimensions(1280, 1856), isTrue);
    });

    test('accepts enhance max results that are off the 64 grid', () {
      expect(source.isCompatibleWithDimensions(1467, 2144), isTrue);
      for (final (width, height) in const [
        (832, 1216),
        (1216, 832),
        (1024, 1024),
        (768, 1280),
        (1280, 768),
        (640, 640),
        (512, 768),
        (1536, 640),
      ]) {
        final target = E2eUpscale.resolveMaxEnhanceTargetSize(width, height);
        expect(
          _source(
            width,
            height,
          ).isCompatibleWithDimensions(target.width, target.height),
          isTrue,
          reason: '$width x $height -> ${target.width} x ${target.height}',
        );
      }
    });

    test('accepts per-edge rounding of local scalers', () {
      expect(source.isCompatibleWithDimensions(1665, 2433), isTrue);
      expect(source.isCompatibleWithDimensions(1663, 2431), isTrue);
      expect(
        _source(1000, 1456).isCompatibleWithDimensions(1504, 2184),
        isTrue,
      );
      expect(
        _source(1300, 1400).isCompatibleWithDimensions(1691, 1860),
        isTrue,
      );
    });

    test('rejects recompositions beyond the rounding drift', () {
      expect(source.isCompatibleWithDimensions(1792, 1792), isFalse);
      expect(source.isCompatibleWithDimensions(1280, 2048), isFalse);
      expect(source.isCompatibleWithDimensions(1408, 1792), isFalse);
      expect(
        _source(1300, 1400).isCompatibleWithDimensions(1000, 1400),
        isFalse,
      );
      expect(source.isCompatibleWithDimensions(0, 1216), isFalse);
      expect(source.isCompatibleWithDimensions(832, -1), isFalse);
    });

    test('drift boundary is four percent of the source ratio', () {
      final square = _source(1000, 1000);
      expect(square.isCompatibleWithDimensions(1039, 1000), isTrue);
      expect(square.isCompatibleWithDimensions(961, 1000), isTrue);
      expect(square.isCompatibleWithDimensions(1041, 1000), isFalse);
      expect(square.isCompatibleWithDimensions(959, 1000), isFalse);
    });

    test('enhance max result keeps the comparison entry', () {
      final target = E2eUpscale.resolveMaxEnhanceTargetSize(832, 1216);
      final result = GeneratedImage.create(
        _pngHeader(target.width, target.height),
        width: 832,
        height: 1216,
        comparisonSource: source,
      );

      expect(result.width, 1467);
      expect(result.height, 2144);
      expect(result.canCompareWithSource, isTrue);
    });
  });
}

ImageComparisonSource _source(int width, int height) =>
    ImageComparisonSource.fromBytes(_pngHeader(width, height))!;

Uint8List _pngHeader(int width, int height) {
  final bytes = Uint8List(33);
  bytes.setAll(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  bytes.setAll(8, const [0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52]);
  ByteData.sublistView(bytes)
    ..setUint32(16, width)
    ..setUint32(20, height);
  return bytes;
}
