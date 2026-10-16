import 'dart:typed_data';
import 'dart:ui';

import 'package:nai_launcher/core/watermark/watermark_analysis_raster.dart';
import 'package:nai_launcher/core/watermark/watermark_source_analysis.dart';

/// 按逐像素 RGBA 直接构造分析结果，原图尺寸等于分析尺寸。
WatermarkSourceAnalysis watermarkAnalysisOf(
  int width,
  int height,
  (int, int, int, int) Function(int x, int y) pixel,
) {
  final rgba = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final (r, g, b, a) = pixel(x, y);
      rgba.setAll((y * width + x) * 4, [r, g, b, a]);
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
