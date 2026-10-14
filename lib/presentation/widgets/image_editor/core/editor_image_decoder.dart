import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// 导入编辑器的外部图片：体积上限与解码
abstract final class EditorImageDecoder {
  static const int maxFileBytes = 50 * 1024 * 1024;

  /// 长边超出时按比例缩小再解码，避免超过 GPU 纹理上限
  static const int maxDimension = 8192;

  /// 解码失败时抛出，调用方负责释放返回的图像
  static Future<ui.Image> decode(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final longest = math.max(descriptor.width, descriptor.height);
      final scale = longest > maxDimension ? maxDimension / longest : 1.0;
      codec = await descriptor.instantiateCodec(
        targetWidth: scale == 1 ? null : (descriptor.width * scale).round(),
        targetHeight: scale == 1 ? null : (descriptor.height * scale).round(),
      );
      return (await codec.getNextFrame()).image;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
