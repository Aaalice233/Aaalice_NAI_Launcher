import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/watermark/watermark_analysis_raster.dart';
import 'package:nai_launcher/core/watermark/watermark_source_analysis.dart';

import '../../helpers/exif_orientation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('flat regions have no detail and report their lightness', () {
    final analysis = _analysis(
      40,
      20,
      (x, y) => x < 20 ? (0, 0, 0, 255) : (255, 255, 255, 255),
    );

    final dark = analysis.regionStats(const Rect.fromLTRB(0, 0, 0.25, 1));
    final light = analysis.regionStats(const Rect.fromLTRB(0.75, 0, 1, 1));
    final edge = analysis.regionStats(const Rect.fromLTRB(0.45, 0, 0.55, 1));

    expect(dark.coverage, closeTo(1, 1e-9));
    expect(dark.meanLightness, closeTo(0, 1e-6));
    expect(dark.meanDetail, 0);
    expect(light.meanLightness, closeTo(100, 1e-6));
    expect(light.meanDetail, 0);
    expect(edge.meanDetail, greaterThan(10));
    expect(edge.rmsDetail, greaterThanOrEqualTo(edge.meanDetail));
    expect(edge.lightnessDeviation, closeTo(50, 1e-6));
  });

  test('fractional rectangles integrate pixels exactly', () {
    final analysis = _analysis(
      2,
      1,
      (x, y) => x == 0 ? (0, 0, 0, 255) : (255, 255, 255, 255),
    );

    final halves = analysis.regionStats(const Rect.fromLTRB(0.25, 0, 0.75, 1));
    final mostlyDark = analysis.regionStats(const Rect.fromLTRB(0, 0, 0.75, 1));

    expect(halves.meanLightness, closeTo(50, 1e-9));
    expect(mostlyDark.meanLightness, closeTo(100 / 3, 1e-9));
  });

  test('transparent areas carry no lightness but cutout edges are detail', () {
    final analysis = _analysis(
      40,
      20,
      (x, y) => x < 20 ? (0, 0, 0, 0) : (255, 255, 255, 255),
    );

    final transparent = analysis.regionStats(
      const Rect.fromLTRB(0, 0, 0.25, 1),
    );
    final edge = analysis.regionStats(const Rect.fromLTRB(0.45, 0, 0.55, 1));
    final opaqueHalf = analysis.regionStats(const Rect.fromLTRB(0.4, 0, 1, 1));

    expect(transparent.coverage, 0);
    expect(transparent.meanLightness, isNull);
    expect(transparent.meanDetail, 0);
    expect(edge.meanDetail, greaterThan(0));
    expect(opaqueHalf.meanLightness, closeTo(100, 1e-6));
    expect(opaqueHalf.coverage, closeTo(20 / 24, 1e-9));
  });

  test('regions are clipped to the image', () {
    final analysis = _analysis(
      10,
      10,
      (x, y) => ((x * 25) % 256, (y * 25) % 256, 80, 255),
    );

    final outside = analysis.regionStats(const Rect.fromLTRB(-1, -1, 0, 0));
    final clipped = analysis.regionStats(const Rect.fromLTRB(-0.5, 0, 0.5, 1));
    final inside = analysis.regionStats(const Rect.fromLTRB(0, 0, 0.5, 1));

    expect(outside.coverage, 0);
    expect(outside.meanLightness, isNull);
    expect(clipped.meanLightness, closeTo(inside.meanLightness!, 1e-9));
    expect(clipped.meanDetail, closeTo(inside.meanDetail, 1e-9));
  });

  test('large sources are analyzed at the fixed long edge', () async {
    final source = img.Image(width: 600, height: 300);
    img.fill(source, color: img.ColorRgb8(30, 60, 90));

    final raster = await WatermarkAnalysisRaster.decode(
      Uint8List.fromList(img.encodePng(source)),
    );

    expect((raster.width, raster.height), (256, 128));
    expect(raster.sourceSize, const Size(600, 300));
    expect(raster.rgba.length, 256 * 128 * 4);
  });

  test('analysis follows EXIF orientation like the renderer', () async {
    final raster = await WatermarkAnalysisRaster.decode(
      orientedCameraJpeg(width: 60, height: 40, orientation: 6),
    );

    expect(raster.sourceSize, const Size(40, 60));
    expect(raster.width, lessThan(raster.height));
  });

  test('the same bytes always produce the same statistics', () async {
    final source = img.Image(width: 300, height: 200);
    for (final pixel in source) {
      pixel.setRgb((pixel.x * 7) % 256, (pixel.y * 11) % 256, 120);
    }
    final bytes = Uint8List.fromList(img.encodePng(source));

    final first = await WatermarkSourceAnalysis.fromEncoded(bytes);
    final second = await WatermarkSourceAnalysis.fromEncoded(bytes);
    const region = Rect.fromLTRB(0.6, 0.7, 0.97, 0.95);

    expect(
      second.regionStats(region).meanDetail,
      first.regionStats(region).meanDetail,
    );
    expect(
      second.regionStats(region).meanLightness,
      first.regionStats(region).meanLightness,
    );
  });
}

WatermarkSourceAnalysis _analysis(
  int width,
  int height,
  (int, int, int, int) Function(int x, int y) pixel,
) {
  final rgba = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final (r, g, b, a) = pixel(x, y);
      final offset = (y * width + x) * 4;
      rgba
        ..[offset] = r
        ..[offset + 1] = g
        ..[offset + 2] = b
        ..[offset + 3] = a;
    }
  }
  return WatermarkSourceAnalysis.fromRaster(
    WatermarkAnalysisRaster(
      width: width,
      height: height,
      rgba: rgba,
      sourceSize: Size(width.toDouble(), height.toDouble()),
    ),
  );
}
