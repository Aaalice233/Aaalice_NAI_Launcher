import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../data/models/watermark/watermark_settings.dart';
import 'watermark_analysis_raster.dart';

/// 亮度统一用 CIE L*（0–100）：感知上等距，「明暗差」滑块的每一档看起来才均匀
abstract final class WatermarkTone {
  static const double _epsilon = 216 / 24389;
  static const double _kappa = 24389 / 27;

  static final Float64List _linearByChannel = Float64List.fromList([
    for (var value = 0; value < 256; value++) _srgbToLinear(value / 255),
  ]);

  static double lightnessOfRgb(int red, int green, int blue) =>
      lightnessFromLinear(
        0.2126 * _linearByChannel[red] +
            0.7152 * _linearByChannel[green] +
            0.0722 * _linearByChannel[blue],
      );

  static double lightnessFromLinear(double luminance) => luminance > _epsilon
      ? 116 * math.pow(luminance, 1 / 3).toDouble() - 16
      : luminance * _kappa;

  static double linearFromLightness(double lightness) =>
      lightness > _kappa * _epsilon
      ? math.pow((lightness + 16) / 116, 3).toDouble()
      : lightness / _kappa;

  /// 与给定 L* 等亮的灰，sRGB 编码值 0–1
  static double grayChannelFor(double lightness) =>
      _linearToSrgb(linearFromLightness(lightness.clamp(0.0, 100.0)));

  static int grayRgb(double lightness) {
    final value = (grayChannelFor(lightness) * 255).round();
    return (value << 16) | (value << 8) | value;
  }

  /// 往离背景更远的一端推：暗背景提亮，亮背景压暗；衬底反向推，0 时三者都与背景等亮
  static WatermarkToneTargets targets({
    required double background,
    required double contrast,
  }) {
    final amount = contrast.clamp(0.0, 1.0);
    if (background <= 50) {
      return WatermarkToneTargets(
        foreground: background + amount * (100 - background),
        halo: background - amount * background,
      );
    }
    return WatermarkToneTargets(
      foreground: background - amount * background,
      halo: background + amount * (100 - background),
    );
  }

  static double _srgbToLinear(double value) => value <= 0.04045
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

  static double _linearToSrgb(double value) => value <= 0.0031308
      ? value * 12.92
      : 1.055 * math.pow(value, 1 / 2.4).toDouble() - 0.055;
}

class WatermarkToneTargets {
  const WatermarkToneTargets({required this.foreground, required this.halo});

  final double foreground;
  final double halo;
}

/// 文字自动灰阶的结果：填充取前景灰，描边和阴影取衬底灰，原有透明度不变
class WatermarkTextTone {
  const WatermarkTextTone({required this.fillRgb, required this.haloRgb});

  factory WatermarkTextTone.forBackground({
    required double background,
    required double contrast,
  }) {
    final targets = WatermarkTone.targets(
      background: background,
      contrast: contrast,
    );
    return WatermarkTextTone(
      fillRgb: WatermarkTone.grayRgb(targets.foreground),
      haloRgb: WatermarkTone.grayRgb(targets.halo),
    );
  }

  final int fillRgb;
  final int haloRgb;

  WatermarkTextStyle applyTo(WatermarkTextStyle style) => style.copyWith(
    colorArgb: _withRgb(style.colorArgb, fillRgb),
    strokeColorArgb: _withRgb(style.strokeColorArgb, haloRgb),
    shadowColorArgb: _withRgb(style.shadowColorArgb, haloRgb),
  );

  static int _withRgb(int argb, int rgb) => (argb & 0xFF000000) | rgb;

  @override
  bool operator ==(Object other) =>
      other is WatermarkTextTone &&
      other.fillRgb == fillRgb &&
      other.haloRgb == haloRgb;

  @override
  int get hashCode => Object.hash(fillRgb, haloRgb);
}

/// Logo 按 alpha 加权的明暗分布；亮度是 sRGB 编码值上的 Rec.709 加权，与颜色矩阵的运算空间一致
class WatermarkLogoLuminance {
  const WatermarkLogoLuminance({
    required this.mean,
    required this.darkest,
    required this.brightest,
  });

  // 抗锯齿边缘的近透明像素颜色不可靠，不参与明暗范围
  static const int _rangeAlphaThreshold = 8;

  final double mean;
  final double darkest;
  final double brightest;

  static Future<WatermarkLogoLuminance?> fromEncoded(Uint8List bytes) async =>
      fromRaster(await WatermarkAnalysisRaster.decode(bytes));

  /// 完全透明的 Logo 没有可调的明暗，返回 null
  static WatermarkLogoLuminance? fromRaster(WatermarkAnalysisRaster raster) {
    final rgba = raster.rgba;
    var weighted = 0.0;
    var weight = 0.0;
    var darkest = double.infinity;
    var brightest = double.negativeInfinity;
    for (var offset = 0; offset + 3 < rgba.length; offset += 4) {
      final alpha = rgba[offset + 3];
      if (alpha == 0) continue;
      final luma =
          (0.2126 * rgba[offset] +
              0.7152 * rgba[offset + 1] +
              0.0722 * rgba[offset + 2]) /
          255;
      weighted += luma * alpha;
      weight += alpha;
      if (alpha >= _rangeAlphaThreshold) {
        darkest = math.min(darkest, luma);
        brightest = math.max(brightest, luma);
      }
    }
    if (weight == 0) return null;
    final mean = weighted / weight;
    return WatermarkLogoLuminance(
      mean: mean,
      darkest: darkest.isFinite ? darkest : mean,
      brightest: brightest.isFinite ? brightest : mean,
    );
  }

  /// 去色后把平均亮度移到目标灰，层次按需压缩以免溢出 0–1；alpha 原样保留
  ui.ColorFilter filterFor(double targetLightness) {
    final target = WatermarkTone.grayChannelFor(targetLightness);
    var gain = 1.0;
    final below = mean - darkest;
    final above = brightest - mean;
    if (below > 0) gain = math.min(gain, target / below);
    if (above > 0) gain = math.min(gain, (1 - target) / above);
    final offset = (target - gain * mean) * 255;
    final row = [gain * 0.2126, gain * 0.7152, gain * 0.0722, 0.0, offset];
    return ui.ColorFilter.matrix([
      ...row,
      ...row,
      ...row,
      0, 0, 0, 1, 0, //
    ]);
  }
}
