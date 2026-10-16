import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/dib_bitmap_codec.dart';

const int _biRgb = 0;
const int _biRle8 = 1;
const int _biBitfields = 3;

void main() {
  group('DibBitmapCodec.toPng', () {
    test('decodes 32-bit BI_BITFIELDS restored from clipboard history', () {
      // 剪贴板历史实测结构：40 字节头 + 12 字节 RGB 掩码，第 4 字节为 0。
      final dib = _dib(
        width: 2,
        height: 2,
        bitCount: 32,
        compression: _biBitfields,
        masks: const [0x00ff0000, 0x0000ff00, 0x000000ff],
        rows: [
          [..._bgrx(0, 0, 255), ..._bgrx(255, 255, 255)],
          [..._bgrx(255, 0, 0), ..._bgrx(0, 255, 0)],
        ],
      );

      final image = _decode(DibBitmapCodec.toPng(dib));

      expect(_rgba(image, 0, 0), (255, 0, 0, 255));
      expect(_rgba(image, 1, 0), (0, 255, 0, 255));
      expect(_rgba(image, 0, 1), (0, 0, 255, 255));
      expect(_rgba(image, 1, 1), (255, 255, 255, 255));
    });

    test('honours row padding of 24-bit bitmaps', () {
      final dib = _dib(
        width: 3,
        height: 1,
        bitCount: 24,
        rows: [
          [
            ..._bgr(10, 20, 30),
            ..._bgr(40, 50, 60),
            ..._bgr(70, 80, 90),
            0,
            0,
            0,
          ],
        ],
      );

      final image = _decode(DibBitmapCodec.toPng(dib));

      expect(_rgba(image, 0, 0), (10, 20, 30, 255));
      expect(_rgba(image, 2, 0), (70, 80, 90, 255));
    });

    test('keeps top-down bitmaps upright', () {
      final dib = _dib(
        width: 1,
        height: -2,
        bitCount: 32,
        rows: [_bgrx(255, 0, 0), _bgrx(0, 0, 255)],
      );

      final image = _decode(DibBitmapCodec.toPng(dib));

      expect(_rgba(image, 0, 0), (255, 0, 0, 255));
      expect(_rgba(image, 0, 1), (0, 0, 255, 255));
    });

    test('skips the full palette of 8-bit bitmaps', () {
      final palette = List<int>.filled(256 * 4, 0);
      palette.setAll(7 * 4, _bgrx(12, 34, 56));
      final dib = _dib(
        width: 1,
        height: 1,
        bitCount: 8,
        palette: palette,
        rows: [
          [7, 0, 0, 0],
        ],
      );

      final image = _decode(DibBitmapCodec.toPng(dib));

      expect(_rgba(image, 0, 0), (12, 34, 56, 255));
    });
  });

  group('DibBitmapCodec.toBmpFile', () {
    test('points the pixel offset past the bitfield masks', () {
      final dib = _dib(
        width: 1,
        height: 1,
        bitCount: 32,
        compression: _biBitfields,
        masks: const [0x00ff0000, 0x0000ff00, 0x000000ff],
        rows: [_bgrx(1, 2, 3)],
      );

      final bmp = ByteData.sublistView(DibBitmapCodec.toBmpFile(dib));

      expect(bmp.getUint16(0, Endian.big), 0x424D);
      expect(bmp.getUint32(2, Endian.little), 14 + dib.length);
      expect(bmp.getUint32(10, Endian.little), 14 + 40 + 12);
    });

    test('rejects headers other than BITMAPINFOHEADER', () {
      final dib = _dib(
        width: 1,
        height: 1,
        bitCount: 32,
        rows: [_bgrx(0, 0, 0)],
      );
      ByteData.sublistView(dib).setUint32(0, 124, Endian.little);

      expect(() => DibBitmapCodec.toBmpFile(dib), throwsFormatException);
    });

    test('rejects truncated pixel data', () {
      final dib = _dib(
        width: 2,
        height: 2,
        bitCount: 32,
        rows: [_bgrx(0, 0, 0)],
      );

      expect(() => DibBitmapCodec.toBmpFile(dib), throwsFormatException);
    });

    test('rejects compressed and unsupported bitmaps', () {
      final rle = _dib(
        width: 1,
        height: 1,
        bitCount: 8,
        compression: _biRle8,
        palette: List<int>.filled(256 * 4, 0),
        rows: [
          [0, 0, 0, 0],
        ],
      );
      final twoBit = _dib(
        width: 1,
        height: 1,
        bitCount: 2,
        rows: [
          [0, 0, 0, 0],
        ],
      );

      expect(
        () => DibBitmapCodec.toBmpFile(rle),
        _throwsFormatMessage('Unsupported CF_DIB compression'),
      );
      expect(
        () => DibBitmapCodec.toBmpFile(twoBit),
        _throwsFormatMessage('Unsupported CF_DIB bit count'),
      );
    });

    test('rejects geometry beyond the pixel budget before decoding', () {
      final dib = _dib(
        width: 1,
        height: 1,
        bitCount: 1,
        rows: [
          [0, 0, 0, 0],
        ],
      );
      ByteData.sublistView(dib)
        ..setInt32(4, 1 << 16, Endian.little)
        ..setInt32(8, 1 << 16, Endian.little);

      expect(
        () => DibBitmapCodec.toBmpFile(dib),
        _throwsFormatMessage('exceeds ${DibBitmapCodec.maxPixelCount} pixels'),
      );
    });

    test('rejects data shorter than the header', () {
      expect(
        () => DibBitmapCodec.toBmpFile(Uint8List(12)),
        throwsFormatException,
      );
    });
  });
}

// rows 按 DIB 存储顺序给出：高度为正时首行是图像最底一行。
Uint8List _dib({
  required int width,
  required int height,
  required int bitCount,
  int compression = _biRgb,
  List<int> masks = const [],
  List<int> palette = const [],
  required List<List<int>> rows,
}) {
  final pixels = rows.expand((row) => row).toList();
  final header = ByteData(40)
    ..setUint32(0, 40, Endian.little)
    ..setInt32(4, width, Endian.little)
    ..setInt32(8, height, Endian.little)
    ..setUint16(12, 1, Endian.little)
    ..setUint16(14, bitCount, Endian.little)
    ..setUint32(16, compression, Endian.little)
    ..setUint32(20, pixels.length, Endian.little);
  final maskBytes = ByteData(masks.length * 4);
  for (var i = 0; i < masks.length; i++) {
    maskBytes.setUint32(i * 4, masks[i], Endian.little);
  }
  return Uint8List.fromList([
    ...header.buffer.asUint8List(),
    ...maskBytes.buffer.asUint8List(),
    ...palette,
    ...pixels,
  ]);
}

// 后续校验也会因同一份数据抛 FormatException，按消息区分是哪一项拒绝。
Matcher _throwsFormatMessage(String reason) => throwsA(
  isA<FormatException>().having((e) => e.message, 'message', contains(reason)),
);

List<int> _bgrx(int r, int g, int b) => [b, g, r, 0];

List<int> _bgr(int r, int g, int b) => [b, g, r];

img.Image _decode(Uint8List png) {
  expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  return img.decodePng(png)!;
}

(num, num, num, num) _rgba(img.Image image, int x, int y) {
  final pixel = image.getPixel(x, y);
  return (pixel.r, pixel.g, pixel.b, image.numChannels == 4 ? pixel.a : 255);
}
