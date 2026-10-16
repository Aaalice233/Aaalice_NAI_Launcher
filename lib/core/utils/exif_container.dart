import 'dart:typed_data';

/// 只遍历 JPEG 标记段与 WebP RIFF 块头定位 EXIF 载荷，不触碰图像数据；结构损坏时抛 [FormatException]。
abstract final class ExifContainer {
  static const int jpegStartOfScan = 0xDA;
  static const int jpegEndOfImage = 0xD9;

  static bool isJpeg(Uint8List bytes) =>
      bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

  static bool isWebp(Uint8List bytes) =>
      bytes.length >= 12 &&
      _asciiAt(bytes, 0, 'RIFF') &&
      _asciiAt(bytes, 8, 'WEBP');

  /// 每个 `Exif\0\0` APP1 段去掉标识后的 TIFF 载荷；读到 SOS 或 EOI 即停止，不扫描熵编码数据。
  static Iterable<Uint8List> jpegExifPayloads(Uint8List bytes) sync* {
    for (final (:marker, :payload) in jpegHeaderSegments(bytes)) {
      if (marker == 0xE1 &&
          payload != null &&
          _asciiAt(payload, 0, 'Exif\u0000\u0000')) {
        yield Uint8List.sublistView(payload, 6);
      }
    }
  }

  /// SOI 之后逐个标记段按段长跳过载荷；以 [jpegStartOfScan] 或 [jpegEndOfImage] 结尾时
  /// 给出该标记（[payload] 为 null）后停止，不扫描熵编码数据。
  static Iterable<({int marker, Uint8List? payload})> jpegHeaderSegments(
    Uint8List bytes,
  ) sync* {
    if (!isJpeg(bytes)) return;
    var offset = 2;
    while (offset + 4 <= bytes.length) {
      if (bytes[offset] != 0xFF) {
        throw const FormatException('Malformed JPEG markers');
      }
      while (offset < bytes.length && bytes[offset] == 0xFF) {
        offset++;
      }
      if (offset >= bytes.length) return;
      final marker = bytes[offset++];
      if (marker == jpegEndOfImage || marker == jpegStartOfScan) {
        yield (marker: marker, payload: null);
        return;
      }
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) continue;
      if (offset + 2 > bytes.length) {
        throw const FormatException('Truncated JPEG segment');
      }
      final segmentLength = (bytes[offset] << 8) | bytes[offset + 1];
      if (segmentLength < 2 || offset + segmentLength > bytes.length) {
        throw const FormatException('Invalid JPEG segment length');
      }
      yield (
        marker: marker,
        payload: Uint8List.sublistView(
          bytes,
          offset + 2,
          offset + segmentLength,
        ),
      );
      offset += segmentLength;
    }
  }

  /// 每个 EXIF 块的原始载荷：规范上是裸 TIFF，部分编码器会多加 `Exif\0\0` 前缀，由调用方决定是否认它。
  /// 按 RIFF 头声明的长度遍历，块越过声明的结尾即视为损坏。
  static Iterable<Uint8List> webpExifChunks(Uint8List bytes) sync* {
    if (!isWebp(bytes)) return;
    final view = ByteData.sublistView(bytes);
    final declaredEnd = view.getUint32(4, Endian.little) + 8;
    if (declaredEnd < 12) {
      throw const FormatException('Invalid WebP RIFF size');
    }
    if (declaredEnd > bytes.length) {
      throw FormatException(
        'Truncated WebP RIFF container: declared $declaredEnd bytes, '
        'received ${bytes.length}',
      );
    }
    var offset = 12;
    while (offset < declaredEnd) {
      if (offset + 8 > declaredEnd) {
        throw const FormatException('Truncated WebP chunk header');
      }
      final type = String.fromCharCodes(bytes, offset, offset + 4);
      final size = view.getUint32(offset + 4, Endian.little);
      final dataStart = offset + 8;
      final dataEnd = dataStart + size;
      final paddedEnd = dataEnd + (size.isOdd ? 1 : 0);
      if (paddedEnd > declaredEnd) {
        throw FormatException('Truncated WebP $type chunk');
      }
      if (type == 'EXIF') {
        yield Uint8List.sublistView(bytes, dataStart, dataEnd);
      }
      offset = paddedEnd;
    }
  }

  /// 去掉 WebP EXIF 块前非标准的 `Exif\0\0` 前缀。
  static Uint8List withoutExifHeader(Uint8List payload) =>
      payload.length >= 6 && _asciiAt(payload, 0, 'Exif\u0000\u0000')
      ? Uint8List.sublistView(payload, 6)
      : payload;

  static bool _asciiAt(Uint8List bytes, int offset, String value) {
    if (offset + value.length > bytes.length) return false;
    for (var index = 0; index < value.length; index++) {
      if (bytes[offset + index] != value.codeUnitAt(index)) return false;
    }
    return true;
  }
}
