import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'exif_container.dart';
import 'exif_orientation.dart';
import 'isolate_pool.dart';

/// 读取与 [ExifOrientation.decodeUpright] 结果一致的图像宽高，能从编码头确定时不解码像素。
abstract final class DecodedImageSize {
  static const Set<img.ImageFormat> _headerFormats = {
    img.ImageFormat.png,
    img.ImageFormat.webp,
  };
  // image 包只解码基线、扩展与渐进帧，其它帧类型留给整图解码给出同样的结果
  static const Set<int> _decodableJpegFrames = {0xC0, 0xC1, 0xC2};

  /// 只解析 PNG/JPEG/WebP 编码头；其它格式或头部异常返回 null。
  static (int, int)? readHeader(Uint8List bytes) {
    try {
      final size = ExifContainer.isJpeg(bytes)
          ? _jpegFrameSize(bytes)
          : _decoderHeaderSize(bytes);
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

  static (int, int)? _decoderHeaderSize(Uint8List bytes) {
    final decoder = img.findDecoderForData(bytes);
    if (decoder == null || !_headerFormats.contains(decoder.format)) {
      return null;
    }
    final info = decoder.startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) return null;
    return (info.width, info.height);
  }

  // 逐段跳到 SOS：image 包识别 JPEG 时会扫完全部熵编码数据，大图要数百毫秒
  static (int, int)? _jpegFrameSize(Uint8List bytes) {
    (int, int)? size;
    for (final (:marker, :payload) in ExifContainer.jpegHeaderSegments(bytes)) {
      if (marker == ExifContainer.jpegStartOfScan) return size;
      if (!_decodableJpegFrames.contains(marker)) continue;
      // image 包遇到第二个帧头会拒绝解码
      if (size != null || payload == null || payload.length < 5) return null;
      final frame = ByteData.sublistView(payload);
      final height = frame.getUint16(1);
      final width = frame.getUint16(3);
      if (width == 0 || height == 0) return null;
      size = (width, height);
    }
    return null;
  }

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
