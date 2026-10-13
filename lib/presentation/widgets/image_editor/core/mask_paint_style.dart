import 'dart:ui';

/// 蒙版图层上的笔迹外观；导出蒙版时任何非透明像素都算作蒙版，颜色只用于显示
abstract final class MaskPaintStyle {
  static const Color color = Color(0xFF60AAFF);

  /// 半透明才能看清蒙版下的画面
  static const double opacity = 0.55;

  static const double hardness = 1.0;

  /// 放大到看得清单个像素时用：只要有覆盖就按满覆盖显示，与导出的判定一致
  static final ColorFilter exactCoverage = _coverage(255);

  /// 缩小查看时用：按笔迹自身透明度还原满覆盖，保留边缘抗锯齿
  static final ColorFilter smoothCoverage = _coverage(1 / opacity);

  /// 不论笔迹各自的透明度和重叠，统一成蒙版色，透明度留给图层一次施加
  static ColorFilter _coverage(double alphaGain) => ColorFilter.matrix([
    0, 0, 0, 0, color.r * 255, //
    0, 0, 0, 0, color.g * 255,
    0, 0, 0, 0, color.b * 255,
    0, 0, 0, alphaGain, 0,
  ]);
}
