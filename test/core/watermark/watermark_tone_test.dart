import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/watermark/watermark_analysis_raster.dart';
import 'package:nai_launcher/core/watermark/watermark_tone.dart';
import 'package:nai_launcher/data/models/watermark/watermark_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lightness conversions round-trip through sRGB gray', () {
    for (final lightness in [0.0, 5.0, 18.0, 50.0, 73.5, 100.0]) {
      final channel = (WatermarkTone.grayChannelFor(lightness) * 255).round();
      expect(
        WatermarkTone.lightnessOfRgb(channel, channel, channel),
        closeTo(lightness, 0.5),
        reason: 'L*=$lightness',
      );
    }
    expect(WatermarkTone.grayRgb(0), 0x000000);
    expect(WatermarkTone.grayRgb(100), 0xFFFFFF);
  });

  test('tone difference pushes away from the background', () {
    final dark = WatermarkTone.targets(background: 30, contrast: 0.4);
    expect(dark.foreground, closeTo(58, 1e-9));
    expect(dark.halo, closeTo(18, 1e-9));

    final light = WatermarkTone.targets(background: 80, contrast: 0.5);
    expect(light.foreground, closeTo(40, 1e-9));
    expect(light.halo, closeTo(90, 1e-9));
  });

  test('zero difference blends and full difference reaches the extremes', () {
    final blended = WatermarkTone.targets(background: 64, contrast: 0);
    expect(blended.foreground, 64);
    expect(blended.halo, 64);

    final darkMax = WatermarkTone.targets(background: 20, contrast: 1);
    expect(darkMax.foreground, 100);
    expect(darkMax.halo, 0);

    final lightMax = WatermarkTone.targets(background: 90, contrast: 1);
    expect(lightMax.foreground, 0);
    expect(lightMax.halo, 100);
  });

  test('text tone keeps each color alpha and only replaces the gray', () {
    const style = WatermarkTextStyle(
      colorArgb: 0xCC3366FF,
      strokeColorArgb: 0x99112233,
      shadowColorArgb: 0x80445566,
    );
    final tone = WatermarkTextTone.forBackground(background: 20, contrast: 1);

    final toned = tone.applyTo(style);

    expect(toned.colorArgb, 0xCCFFFFFF);
    expect(toned.strokeColorArgb, 0x99000000);
    expect(toned.shadowColorArgb, 0x80000000);
    expect(toned.text, style.text);
    expect(toned.opacity, style.opacity);
  });

  test('logo luminance ignores transparent pixels', () {
    final luminance = WatermarkLogoLuminance.fromRaster(
      _raster([
        (0, 0, 0, 0),
        (255, 255, 255, 0),
        (51, 51, 51, 255),
        (204, 204, 204, 255),
      ]),
    )!;

    expect(luminance.mean, closeTo(0.5, 1e-9));
    expect(luminance.darkest, closeTo(0.2, 1e-9));
    expect(luminance.brightest, closeTo(0.8, 1e-9));
    expect(
      WatermarkLogoLuminance.fromRaster(_raster([(10, 20, 30, 0)])),
      isNull,
    );
  });

  test('logo filter moves the mean to the target and keeps shading', () async {
    const luminance = WatermarkLogoLuminance(
      mean: 0.5,
      darkest: 0.2,
      brightest: 0.8,
    );
    const targetLightness = 30.0;
    final target = WatermarkTone.grayChannelFor(targetLightness);

    final pixels = await _filtered(luminance.filterFor(targetLightness), [
      const Color(0xFF333333),
      const Color(0xFF808080),
      const Color(0x80CCCCCC),
    ]);

    final dark = pixels[0];
    final middle = pixels[1];
    final light = pixels[2];
    expect(middle.$1, closeTo(target * 255, 2));
    expect(dark.$1, lessThan(middle.$1));
    expect(light.$1, greaterThan(middle.$1));
    expect(dark.$1, closeTo(0, 2));
    for (final pixel in pixels) {
      expect(pixel.$1, pixel.$2);
      expect(pixel.$2, pixel.$3);
    }
    expect(light.$4, closeTo(0x80, 1));
  });

  test('logo filter compresses shading instead of clipping it', () async {
    const luminance = WatermarkLogoLuminance(
      mean: 0.5,
      darkest: 0.1,
      brightest: 0.9,
    );

    final pixels = await _filtered(luminance.filterFor(95), [
      const Color(0xFF1A1A1A),
      const Color(0xFFE6E6E6),
    ]);

    expect(pixels[0].$1, lessThan(pixels[1].$1));
    expect(pixels[1].$1, lessThanOrEqualTo(255));
    expect(pixels[1].$1 - pixels[0].$1, greaterThan(0));
  });
}

WatermarkAnalysisRaster _raster(List<(int, int, int, int)> pixels) {
  final rgba = Uint8List(pixels.length * 4);
  for (var index = 0; index < pixels.length; index++) {
    final (r, g, b, a) = pixels[index];
    rgba.setAll(index * 4, [r, g, b, a]);
  }
  return WatermarkAnalysisRaster(
    width: pixels.length,
    height: 1,
    rgba: rgba,
    sourceSize: Size(pixels.length.toDouble(), 1),
  );
}

Future<List<(int, int, int, int)>> _filtered(
  ColorFilter filter,
  List<Color> colors,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  for (var index = 0; index < colors.length; index++) {
    canvas.drawRect(
      Rect.fromLTWH(index.toDouble(), 0, 1, 1),
      Paint()
        ..color = colors[index]
        ..colorFilter = filter,
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(colors.length, 1);
  picture.dispose();
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  image.dispose();
  final bytes = data!.buffer.asUint8List();
  return [
    for (var index = 0; index < colors.length; index++)
      (
        bytes[index * 4],
        bytes[index * 4 + 1],
        bytes[index * 4 + 2],
        bytes[index * 4 + 3],
      ),
  ];
}
