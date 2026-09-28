import 'dart:ui';

/// 蒙版图层上的笔迹外观；导出蒙版时任何非透明像素都算作蒙版，颜色只用于显示
abstract final class MaskPaintStyle {
  static const Color color = Color(0xFF60AAFF);

  /// 半透明才能看清蒙版下的画面
  static const double opacity = 0.55;

  static const double hardness = 1.0;
}
