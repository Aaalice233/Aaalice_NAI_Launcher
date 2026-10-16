import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'exif_container.dart';
import 'exif_orientation.dart';
import 'isolate_pool.dart';

/// 读取与 [ExifOrientation.decodeUpright] 结果一致的图像宽高，能从编码头确定时不解码像素。
abstract final class DecodedImageSize {
  // image 包只解码基线、扩展与渐进帧，其它帧类型留给整图解码给出同样的结果
  static const Set<int> _decodableJpegFrames = {0xC0, 0xC1, 0xC2};
  static const List<int> _pngSignature = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  ];

  /// 只解析 PNG/JPEG/WebP 编码头；其它格式或头部异常返回 null。
  static (int, int)? readHeader(Uint8List bytes) {
    try {
      final size = _encodedSize(bytes);
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

  /// PNG/JPEG/WebP 同 [readHeader]；其它格式取编码头声明的画布尺寸，
  /// 可能与整图解码结果不同（如 GIF 的逻辑屏幕大于帧）。
  static (int, int)? readDeclaredSize(Uint8List bytes) {
    if (_hasHeaderFormat(bytes)) return readHeader(bytes);
    try {
      final info = img.findDecoderForData(bytes)?.startDecode(bytes);
      if (info == null || info.width <= 0 || info.height <= 0) return null;
      return (info.width, info.height);
    } catch (_) {
      return null;
    }
  }

  /// 编码头读不出时在后台 isolate 完整解码；解码异常与 `img.decodeImage` 一样原样抛出。
  static Future<(int, int)?> read(Uint8List bytes, {ComputeGate? gate}) async {
    return readHeader(bytes) ?? await decode(bytes, gate: gate);
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

  /// 不看编码头，总在后台 isolate 解码全部像素；校验截断等像素层损坏时用它。
  static Future<(int, int)?> decode(Uint8List bytes, {ComputeGate? gate}) {
    return (gate ?? ComputeGate()).runIsolate(() => _decodeSize(bytes));
  }

  static (int, int)? _decodeSize(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    return decoded == null ? null : ExifOrientation.uprightSize(bytes, decoded);
  }

  static bool _hasHeaderFormat(Uint8List bytes) =>
      ExifContainer.isJpeg(bytes) ||
      _isPng(bytes) ||
      ExifContainer.isWebp(bytes);

  static (int, int)? _encodedSize(Uint8List bytes) {
    if (ExifContainer.isJpeg(bytes)) return _jpegFrameSize(bytes);
    if (_isPng(bytes)) return _pngHeaderSize(bytes);
    if (ExifContainer.isWebp(bytes)) return _webpHeaderSize(bytes);
    return null;
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

  static bool _isPng(Uint8List bytes) {
    if (bytes.length < _pngSignature.length) return false;
    for (var index = 0; index < _pngSignature.length; index++) {
      if (bytes[index] != _pngSignature[index]) return false;
    }
    return true;
  }

  // 规范要求 IHDR 紧跟签名：签名 8 字节、块长 4 字节、类型 4 字节后是宽高
  static (int, int)? _pngHeaderSize(Uint8List bytes) {
    if (bytes.length < 24 || String.fromCharCodes(bytes, 12, 16) != 'IHDR') {
      return null;
    }
    final header = ByteData.sublistView(bytes);
    final width = header.getUint32(16);
    final height = header.getUint32(20);
    return width > 0 && height > 0 ? (width, height) : null;
  }

  static (int, int)? _webpHeaderSize(Uint8List bytes) {
    final info = img.WebPDecoder().startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) return null;
    return (info.width, info.height);
  }
}
