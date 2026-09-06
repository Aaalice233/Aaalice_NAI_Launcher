import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Linear-light RGBA float32 transport for the isolated Windows worker.
/// The source and final NR result cross this boundary once; NR evaluations stay
/// in GPU float16 textures and never pass through an 8-bit image codec.
class DlssFloatFrame {
  const DlssFloatFrame(this.width, this.height, this.pixels);
  final int width;
  final int height;
  final Float32List pixels;
  static const _magic = 0x31464141;

  factory DlssFloatFrame.fromImage(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) throw const FormatException('Invalid DLSS source image');
    final pixels = Float32List(image.width * image.height * 4);
    var offset = 0;
    for (final pixel in image) {
      pixels[offset++] = srgbToLinear(pixel.rNormalized.toDouble());
      pixels[offset++] = srgbToLinear(pixel.gNormalized.toDouble());
      pixels[offset++] = srgbToLinear(pixel.bNormalized.toDouble());
      pixels[offset++] = pixel.aNormalized.toDouble();
    }
    return DlssFloatFrame(image.width, image.height, pixels);
  }

  factory DlssFloatFrame.decode(Uint8List bytes) {
    if (bytes.length < 16) {
      throw const FormatException('Missing DLSS frame header');
    }
    final data = ByteData.sublistView(bytes);
    final width = data.getUint32(4, Endian.little);
    final height = data.getUint32(8, Endian.little);
    if (data.getUint32(0, Endian.little) != _magic ||
        data.getUint32(12, Endian.little) != 4 ||
        width < 1 ||
        height < 1 ||
        width > 16384 ||
        height > 16384 ||
        bytes.length != 16 + width * height * 16) {
      throw const FormatException('Invalid DLSS float frame');
    }
    final pixels = Float32List(width * height * 4);
    for (var i = 0; i < pixels.length; i++) {
      final value = data.getFloat32(16 + i * 4, Endian.little);
      if (!value.isFinite) {
        throw const FormatException('Non-finite DLSS output pixel');
      }
      pixels[i] = value;
    }
    return DlssFloatFrame(width, height, pixels);
  }

  Uint8List encode() {
    if (pixels.length != width * height * 4) {
      throw const FormatException('Invalid DLSS frame channel count');
    }
    final bytes = Uint8List(16 + pixels.length * 4);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, _magic, Endian.little);
    data.setUint32(4, width, Endian.little);
    data.setUint32(8, height, Endian.little);
    data.setUint32(12, 4, Endian.little);
    for (var i = 0; i < pixels.length; i++) {
      data.setFloat32(16 + i * 4, pixels[i], Endian.little);
    }
    return bytes;
  }

  /// Compose once against the untouched SR/input baseline after all NR passes.
  img.Image composite(
    DlssFloatFrame neural, {
    required double detail,
    required double color,
  }) {
    if (width != neural.width || height != neural.height) {
      throw const FormatException('DLSS baseline and neural dimensions differ');
    }
    final image = img.Image(width: width, height: height, numChannels: 4);
    for (final pixel in image) {
      final offset = (pixel.y * width + pixel.x) * 4;
      final originalLuma = _luma(pixels, offset);
      final neuralLuma = _luma(neural.pixels, offset);
      final ratio = neuralLuma / math.max(originalLuma, 0.0001);
      int channel(int channel) {
        final original = pixels[offset + channel];
        final lumaOnly = original * ratio;
        final colored =
            lumaOnly + (neural.pixels[offset + channel] - lumaOnly) * color;
        final linear = original + (colored - original) * detail;
        return (linearToSrgb(linear).clamp(0.0, 1.0) * 255).round();
      }

      pixel.setRgba(
        channel(0),
        channel(1),
        channel(2),
        (pixels[offset + 3].clamp(0.0, 1.0) * 255).round(),
      );
    }
    return image;
  }

  static double _luma(Float32List pixels, int offset) =>
      pixels[offset] * 0.2126 +
      pixels[offset + 1] * 0.7152 +
      pixels[offset + 2] * 0.0722;
  static double srgbToLinear(double value) => value <= 0.04045
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  static double linearToSrgb(double value) => value <= 0.0031308
      ? value * 12.92
      : 1.055 * math.pow(value, 1 / 2.4) - 0.055;
}
