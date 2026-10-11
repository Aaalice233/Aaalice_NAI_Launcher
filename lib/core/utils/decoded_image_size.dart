import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'exif_orientation.dart';
import 'isolate_pool.dart';

/// 读取与 [ExifOrientation.decodeUpright] 结果一致的图像宽高，能从编码头确定时不解码像素。
abstract final class DecodedImageSize {
  static const Set<img.ImageFormat> _headerFormats = {
    img.ImageFormat.png,
    img.ImageFormat.jpg,
    img.ImageFormat.webp,
  };

  /// 只解析 PNG/JPEG/WebP 编码头；其它格式或头部异常返回 null。
  static (int, int)? readHeader(Uint8List bytes) {
    try {
      final decoder = img.findDecoderForData(bytes);
      if (decoder == null || !_headerFormats.contains(decoder.format)) {
        return null;
      }
      final size = decoder.format == img.ImageFormat.jpg
          ? _jpegFrameSize(bytes)
          : _decoderHeaderSize(decoder, bytes);
      if (size == null) return null;
      final (width, height) = size;
      if (ExifOrientation.swapsAxes(bytes)) {
        return (height, width);
      }
      return (width, height);
    } catch (_) {
      return null;
    }
  }

  static (int, int)? _decoderHeaderSize(img.Decoder decoder, Uint8List bytes) {
    final info = decoder.startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) return null;
    return (info.width, info.height);
  }

  // 逐段跳到帧头：image 包的 JPEG startDecode 会扫完全部熵编码数据，大图要数百毫秒
  static (int, int)? _jpegFrameSize(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    var offset = 2;
    while (offset < bytes.length) {
      if (bytes[offset] != 0xFF) return null;
      while (offset < bytes.length && bytes[offset] == 0xFF) {
        offset++;
      }
      if (offset >= bytes.length) return null;
      final marker = bytes[offset++];
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8)) continue;
      if (marker == 0xD9 || marker == 0xDA) return null;
      if (offset + 2 > bytes.length) return null;
      final length = data.getUint16(offset);
      if (length < 2 || offset + length > bytes.length) return null;
      if (_isStartOfFrame(marker)) {
        if (length < 7) return null;
        final height = data.getUint16(offset + 3);
        final width = data.getUint16(offset + 5);
        return width > 0 && height > 0 ? (width, height) : null;
      }
      offset += length;
    }
    return null;
  }

  static bool _isStartOfFrame(int marker) =>
      marker >= 0xC0 &&
      marker <= 0xCF &&
      marker != 0xC4 &&
      marker != 0xC8 &&
      marker != 0xCC;

  /// 编码头读不出时在后台 isolate 完整解码；解码异常与 `img.decodeImage` 一样原样抛出。
  static Future<(int, int)?> read(Uint8List bytes, {ComputeGate? gate}) async {
    final size = readHeader(bytes);
    if (size != null) {
      return size;
    }
    return (gate ?? ComputeGate()).runIsolate(() => _decodeSize(bytes));
  }

  /// 同 [read]，但无法解码时返回 null 而不是抛出。
  static Future<(int, int)?> tryRead(
    Uint8List bytes, {
    ComputeGate? gate,
  }) async {
    try {
      return await read(bytes, gate: gate);
    } catch (_) {
      return null;
    }
  }

  static (int, int)? _decodeSize(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    return decoded == null ? null : ExifOrientation.uprightSize(bytes, decoded);
  }
}
