import 'dart:typed_data';

/// 重新编码的像素由哪种解码器从源图得来；决定源图的 EXIF 方向是否已经转进像素。
enum SourcePixelDecoder {
  /// Flutter 引擎：JPEG 与 WebP 按 EXIF 方向转正，PNG 的 eXIf 不处理。
  flutterEngine,

  /// image 包的 decodeImage：只有 JPEG 按 EXIF 方向转正。
  imagePackage,
}

/// 像素已按方向转正后，随像素复制的 EXIF 必须把方向改回 1，否则查看器会再转一次。
abstract final class ExifOrientationMetadata {
  static const int _orientationTag = 0x0112;
  static const int _typeShort = 3;
  static const int _typeLong = 4;

  /// 把 TIFF IFD0 的方向值改为 1，其余字节原样保留；没有方向标签时返回原数组。
  static Uint8List withUprightOrientation(Uint8List tiff) {
    if (tiff.length < 8) return tiff;
    final endian = tiff[0] == 0x49 ? Endian.little : Endian.big;
    final view = ByteData.sublistView(tiff);
    final ifdOffset = view.getUint32(4, endian);
    if (ifdOffset + 2 > tiff.length) return tiff;
    final entryCount = view.getUint16(ifdOffset, endian);
    for (var index = 0; index < entryCount; index++) {
      final entry = ifdOffset + 2 + index * 12;
      if (entry + 12 > tiff.length) return tiff;
      if (view.getUint16(entry, endian) != _orientationTag) continue;
      final type = view.getUint16(entry + 2, endian);
      final count = view.getUint32(entry + 4, endian);
      if (count != 1 || (type != _typeShort && type != _typeLong)) {
        return tiff;
      }
      final upright = Uint8List.fromList(tiff);
      final uprightView = ByteData.sublistView(upright);
      if (type == _typeShort) {
        uprightView.setUint16(entry + 8, 1, endian);
      } else {
        uprightView.setUint32(entry + 8, 1, endian);
      }
      return upright;
    }
    return tiff;
  }
}
