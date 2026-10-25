/// 测试侧独立的 WCAG 对比度算法，不依赖被测的生产实现。
library;

import 'dart:math' as math;
import 'dart:ui';

const double wcagAA = 4.5;

/// WCAG 相对亮度。
double relativeLuminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// WCAG 对比度，取值 1.0（同色）到 21.0（黑白）。
double contrastRatio(Color a, Color b) {
  final x = relativeLuminance(a);
  final y = relativeLuminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

String hexOf(Color color) {
  final rgb =
      (color.r * 255).round() << 16 |
      (color.g * 255).round() << 8 |
      (color.b * 255).round();
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
