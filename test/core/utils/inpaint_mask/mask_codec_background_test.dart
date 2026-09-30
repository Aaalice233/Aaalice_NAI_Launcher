import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';

void main() {
  group('InpaintMaskUtils background mask codec', () {
    test('normalizeMaskBytesAsync matches the synchronous bytes', () async {
      final source = _softEdgedMask();

      expect(
        await InpaintMaskUtils.normalizeMaskBytesAsync(source),
        orderedEquals(InpaintMaskUtils.normalizeMaskBytes(source)),
      );
    });

    test('decodeBinaryMaskAsync matches the synchronous fields', () async {
      final source = _softEdgedMask();
      final expected = InpaintMaskUtils.decodeBinaryMask(source)!;

      final decoded = (await InpaintMaskUtils.decodeBinaryMaskAsync(source))!;

      expect(decoded.width, expected.width);
      expect(decoded.height, expected.height);
      expect(decoded.mask, orderedEquals(expected.mask));
    });

    test('normalizing before decoding does not change the binary mask', () {
      final source = _softEdgedMask();
      final direct = InpaintMaskUtils.decodeBinaryMask(source)!;

      final normalized = InpaintMaskUtils.decodeBinaryMask(
        InpaintMaskUtils.normalizeMaskBytes(source),
      )!;

      expect(normalized.width, direct.width);
      expect(normalized.height, direct.height);
      expect(normalized.mask, orderedEquals(direct.mask));
    });

    test('undecodable bytes keep the synchronous fallbacks', () async {
      final broken = Uint8List.fromList(const [9, 8, 7, 6]);

      expect(
        await InpaintMaskUtils.normalizeMaskBytesAsync(broken),
        orderedEquals(InpaintMaskUtils.normalizeMaskBytes(broken)),
      );
      expect(await InpaintMaskUtils.decodeBinaryMaskAsync(broken), isNull);
      expect(InpaintMaskUtils.decodeBinaryMask(broken), isNull);
    });
  });
}

Uint8List _softEdgedMask() {
  final image = img.Image(width: 5, height: 2, numChannels: 4);
  const pixels = [
    [0, 0, 0, 0],
    [255, 255, 255, 8],
    [255, 255, 255, 9],
    [31, 31, 31, 255],
    [32, 0, 0, 255],
    [80, 180, 255, 96],
    [12, 200, 12, 40],
    [255, 255, 255, 255],
    [0, 0, 0, 255],
    [128, 128, 128, 128],
  ];
  for (var index = 0; index < pixels.length; index++) {
    final [r, g, b, a] = pixels[index];
    image.setPixelRgba(index % 5, index ~/ 5, r, g, b, a);
  }
  return Uint8List.fromList(img.encodePng(image));
}
