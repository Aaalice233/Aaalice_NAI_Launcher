import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Windows 剪贴板 CF_DIB（BITMAPINFO + 像素，无文件头）与 PNG 之间的转换。
abstract final class DibBitmapCodec {
  static const int _fileHeaderSize = 14;
  static const int _infoHeaderSize = 40;
  static const int _biRgb = 0;
  static const int _biBitfields = 3;
  static const int _bitfieldMaskBytes = 12;
  static const Set<int> _supportedBitCounts = {1, 4, 8, 16, 24, 32};
  // 解码按像素分配内存，低位深位图会被放大数十倍，需单独限制像素总数。
  static const int maxPixelCount = 64 * 1024 * 1024;

  /// 只接受系统合成的 BITMAPINFOHEADER 未压缩位图，其它情况抛出 [FormatException]。
  static Uint8List toPng(Uint8List dib) {
    final image = img.decodeBmp(toBmpFile(dib));
    if (image == null) {
      throw const FormatException('CF_DIB could not be decoded');
    }
    return img.encodePng(image);
  }

  /// 补上 BITMAPFILEHEADER；像素偏移必须精确，BI_BITFIELDS 的掩码与调色板都位于像素之前。
  static Uint8List toBmpFile(Uint8List dib) {
    if (dib.length < _infoHeaderSize) {
      throw FormatException('CF_DIB is shorter than its header', dib.length);
    }
    final header = ByteData.sublistView(dib);
    final headerSize = header.getUint32(0, Endian.little);
    final width = header.getInt32(4, Endian.little);
    final height = header.getInt32(8, Endian.little);
    final planes = header.getUint16(12, Endian.little);
    final bitCount = header.getUint16(14, Endian.little);
    final compression = header.getUint32(16, Endian.little);
    final colorsUsed = header.getUint32(32, Endian.little);

    if (headerSize != _infoHeaderSize) {
      throw FormatException('Unsupported CF_DIB header size $headerSize');
    }
    if (width <= 0 || height == 0 || planes != 1) {
      throw FormatException('Invalid CF_DIB geometry ${width}x$height');
    }
    if (width * height.abs() > maxPixelCount) {
      throw const FormatException('CF_DIB exceeds $maxPixelCount pixels');
    }
    if (!_supportedBitCounts.contains(bitCount)) {
      throw FormatException('Unsupported CF_DIB bit count $bitCount');
    }
    final isBitfields = compression == _biBitfields;
    if (compression != _biRgb &&
        !(isBitfields && (bitCount == 16 || bitCount == 32))) {
      throw FormatException('Unsupported CF_DIB compression $compression');
    }

    final paletteEntries = bitCount <= 8 && colorsUsed == 0
        ? 1 << bitCount
        : colorsUsed;
    final pixelOffset =
        _infoHeaderSize +
        (isBitfields ? _bitfieldMaskBytes : 0) +
        paletteEntries * 4;
    final stride = (width * bitCount + 31) ~/ 32 * 4;
    final pixelBytes = stride * height.abs();
    if (dib.length < pixelOffset + pixelBytes) {
      throw FormatException(
        'CF_DIB is truncated: needs ${pixelOffset + pixelBytes} bytes',
        dib.length,
      );
    }

    final fileHeader = ByteData(_fileHeaderSize)
      ..setUint8(0, 0x42)
      ..setUint8(1, 0x4D)
      ..setUint32(2, _fileHeaderSize + dib.length, Endian.little)
      ..setUint32(10, _fileHeaderSize + pixelOffset, Endian.little);
    return Uint8List(_fileHeaderSize + dib.length)
      ..setAll(0, fileHeader.buffer.asUint8List())
      ..setAll(_fileHeaderSize, dib);
  }
}
