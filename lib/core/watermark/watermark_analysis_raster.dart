import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// 自动调整用的低分辨率像素；同一份字节总解码出同一结果，预览与原尺寸输出据此判定一致
class WatermarkAnalysisRaster {
  const WatermarkAnalysisRaster({
    required this.width,
    required this.height,
    required this.rgba,
    required this.sourceSize,
  });

  static const int _longEdge = 256;

  final int width;
  final int height;

  /// 行优先的非预乘 RGBA
  final Uint8List rgba;

  /// 已按 EXIF 方向摆正的原图尺寸
  final ui.Size sourceSize;

  static Future<WatermarkAnalysisRaster> decode(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final sourceWidth = descriptor.width;
      final sourceHeight = descriptor.height;
      if (sourceWidth <= 0 || sourceHeight <= 0) {
        throw const FormatException('The image size is invalid.');
      }
      final scale = math.min(
        1.0,
        _longEdge / math.max(sourceWidth, sourceHeight),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (sourceWidth * scale).round()),
        targetHeight: math.max(1, (sourceHeight * scale).round()),
      );
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) {
        throw const FormatException('The image pixels could not be read.');
      }
      // 解码器按 EXIF 摆正后宽高可能对调，原图尺寸跟随实际像素方向
      final swapped =
          sourceWidth != sourceHeight &&
          (image.width > image.height) != (sourceWidth > sourceHeight);
      return WatermarkAnalysisRaster(
        width: image.width,
        height: image.height,
        rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        sourceSize: swapped
            ? ui.Size(sourceHeight.toDouble(), sourceWidth.toDouble())
            : ui.Size(sourceWidth.toDouble(), sourceHeight.toDouble()),
      );
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
