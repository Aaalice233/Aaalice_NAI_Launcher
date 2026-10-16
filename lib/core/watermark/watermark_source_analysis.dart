import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'watermark_analysis_raster.dart';
import 'watermark_tone.dart';

/// 原图的亮度与细节分布，区域按归一化坐标查询，与预览或输出的画布尺寸无关
class WatermarkSourceAnalysis {
  WatermarkSourceAnalysis._({
    required this.sourceSize,
    required int width,
    required int height,
    required Float64List coverage,
    required Float64List lightness,
    required Float64List detailSquared,
  }) : _width = width,
       _height = height,
       _coverage = coverage,
       _lightness = lightness,
       _detailSquared = detailSquared;

  // 透明处按中灰合成后再求细节：主体抠图的轮廓算作内容，透明区本身是平的
  static const double _transparentLightness = 50;

  final ui.Size sourceSize;
  final int _width;
  final int _height;

  // 各量的积分图，尺寸 (宽+1)×(高+1)，任意矩形求和 O(1)
  final Float64List _coverage;
  final Float64List _lightness;
  final Float64List _detailSquared;

  static Future<WatermarkSourceAnalysis> fromEncoded(Uint8List bytes) async =>
      WatermarkSourceAnalysis.fromRaster(
        await WatermarkAnalysisRaster.decode(bytes),
      );

  factory WatermarkSourceAnalysis.fromRaster(WatermarkAnalysisRaster raster) {
    final width = raster.width;
    final height = raster.height;
    final rgba = raster.rgba;
    final count = width * height;
    final alpha = Float64List(count);
    final lightness = Float64List(count);
    final composite = Float64List(count);
    for (var index = 0; index < count; index++) {
      final offset = index * 4;
      final a = rgba[offset + 3] / 255;
      final l = WatermarkTone.lightnessOfRgb(
        rgba[offset],
        rgba[offset + 1],
        rgba[offset + 2],
      );
      alpha[index] = a;
      lightness[index] = l;
      composite[index] = a * l + (1 - a) * _transparentLightness;
    }

    final stride = width + 1;
    final size = stride * (height + 1);
    final coverageSum = Float64List(size);
    final lightnessSum = Float64List(size);
    final detailSquaredSum = Float64List(size);
    double at(int x, int y) => composite[y * width + x];
    for (var y = 0; y < height; y++) {
      final up = math.max(0, y - 1);
      final down = math.min(height - 1, y + 1);
      for (var x = 0; x < width; x++) {
        final index = y * width + x;
        final gx =
            (at(math.min(width - 1, x + 1), y) - at(math.max(0, x - 1), y)) / 2;
        final gy = (at(x, down) - at(x, up)) / 2;
        final a = alpha[index];
        final l = lightness[index];
        final cell = (y + 1) * stride + x + 1;
        final left = cell - 1;
        final above = cell - stride;
        final corner = above - 1;
        void accumulate(Float64List table, double value) {
          table[cell] = value + table[left] + table[above] - table[corner];
        }

        accumulate(coverageSum, a);
        accumulate(lightnessSum, a * l);
        accumulate(detailSquaredSum, gx * gx + gy * gy);
      }
    }
    return WatermarkSourceAnalysis._(
      sourceSize: raster.sourceSize,
      width: width,
      height: height,
      coverage: coverageSum,
      lightness: lightnessSum,
      detailSquared: detailSquaredSum,
    );
  }

  /// [normalized] 以 0–1 表示在原图中的位置；越出画面的部分不计入
  WatermarkRegionStats regionStats(ui.Rect normalized) {
    final left = (normalized.left * _width).clamp(0.0, _width.toDouble());
    final right = (normalized.right * _width).clamp(0.0, _width.toDouble());
    final top = (normalized.top * _height).clamp(0.0, _height.toDouble());
    final bottom = (normalized.bottom * _height).clamp(0.0, _height.toDouble());
    final area = (right - left) * (bottom - top);
    if (!(area > 0)) return WatermarkRegionStats.empty;
    double sum(Float64List table) =>
        _sample(table, right, bottom) -
        _sample(table, left, bottom) -
        _sample(table, right, top) +
        _sample(table, left, top);

    final coverage = sum(_coverage);
    return WatermarkRegionStats(
      meanLightness: coverage > 1e-9
          ? (sum(_lightness) / coverage).clamp(0.0, 100.0)
          : null,
      rmsDetail: math.sqrt(math.max(0, sum(_detailSquared) / area)),
    );
  }

  // 像素内取值恒定，积分图在格内恰为双线性，插值即精确积分；矩形随画布缩放连续变化，得分也连续
  double _sample(Float64List table, double x, double y) {
    final stride = _width + 1;
    final column = math.min(x.floor(), _width - 1);
    final row = math.min(y.floor(), _height - 1);
    final fx = x - column;
    final fy = y - row;
    final topLeft = table[row * stride + column];
    final topRight = table[row * stride + column + 1];
    final bottomLeft = table[(row + 1) * stride + column];
    final bottomRight = table[(row + 1) * stride + column + 1];
    return topLeft * (1 - fx) * (1 - fy) +
        topRight * fx * (1 - fy) +
        bottomLeft * (1 - fx) * fy +
        bottomRight * fx * fy;
  }
}

class WatermarkRegionStats {
  const WatermarkRegionStats({
    required this.meanLightness,
    required this.rmsDetail,
  });

  static const empty = WatermarkRegionStats(meanLightness: null, rmsDetail: 0);

  /// 不透明部分按 alpha 加权的平均 L*；区域完全透明时为 null
  final double? meanLightness;

  /// 梯度的均方根：少量强边缘（眼睛、线稿）比平均值更能拉高它
  final double rmsDetail;
}
