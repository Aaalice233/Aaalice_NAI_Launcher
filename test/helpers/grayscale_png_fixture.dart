import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// 单通道 8 位灰度 PNG，漫画扫描与线稿常用；[alpha] 非空时写成灰度+透明。
Uint8List grayscalePng({
  required int width,
  required int height,
  int gray = 160,
  int? alpha,
}) {
  final channels = alpha == null ? 1 : 2;
  final samples = Uint8List(width * height * channels);
  for (var index = 0; index < width * height; index++) {
    samples[index * channels] = gray;
    if (alpha != null) samples[index * channels + 1] = alpha;
  }
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: samples.buffer,
    numChannels: channels,
  );
  return Uint8List.fromList(img.encodePng(image));
}

/// 每个像素三通道彼此接近，不要求具体灰阶；用于插值会改变边缘亮度的流程。
void expectNeutralGray(img.Image image, {int tolerance = 2}) {
  var worst = 0;
  var worstDescription = '';
  for (final pixel in image) {
    final rgb = [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
    final spread =
        rgb.reduce((a, b) => a > b ? a : b) -
        rgb.reduce((a, b) => a < b ? a : b);
    if (spread > worst) {
      worst = spread;
      worstDescription = 'at ${pixel.x},${pixel.y} is $rgb';
    }
  }
  expect(
    worst,
    lessThanOrEqualTo(tolerance),
    reason: 'expected neutral gray, worst pixel $worstDescription',
  );
}

/// 每个像素的 RGB 都接近 [gray]；单通道被误读时会是 (gray, 0, 0)。
void expectUniformGray(img.Image image, int gray, {int tolerance = 3}) {
  var worst = 0;
  var worstDescription = '';
  for (final pixel in image) {
    final rgb = [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
    for (final channel in rgb) {
      final delta = (channel - gray).abs();
      if (delta > worst) {
        worst = delta;
        worstDescription = 'at ${pixel.x},${pixel.y} is $rgb';
      }
    }
  }
  expect(
    worst,
    lessThanOrEqualTo(tolerance),
    reason: 'expected gray $gray, worst pixel $worstDescription',
  );
}
