import 'package:flutter/material.dart';

/// 颜色管理器
/// 负责前景色、背景色的管理和通知
class ColorManager extends ChangeNotifier {
  /// 前景色
  Color _foregroundColor = const Color(0xFF000000);
  Color get foregroundColor => _foregroundColor;

  /// 背景色
  Color _backgroundColor = const Color(0xFFFFFFFF);
  Color get backgroundColor => _backgroundColor;

  /// 精确通知器（用于仅监听特定颜色变化的场景）
  final ValueNotifier<Color> foregroundNotifier =
      ValueNotifier(const Color(0xFF000000));
  final ValueNotifier<Color> backgroundNotifier =
      ValueNotifier(const Color(0xFFFFFFFF));

  /// 设置前景色
  void setForegroundColor(Color color) {
    if (_foregroundColor != color) {
      _foregroundColor = color;
      foregroundNotifier.value = color;
      notifyListeners();
    }
  }

  /// 设置背景色
  void setBackgroundColor(Color color) {
    if (_backgroundColor != color) {
      _backgroundColor = color;
      backgroundNotifier.value = color;
      notifyListeners();
    }
  }

  /// 交换前景色和背景色
  void swapColors() {
    final temp = _foregroundColor;
    _foregroundColor = _backgroundColor;
    _backgroundColor = temp;
    foregroundNotifier.value = _foregroundColor;
    backgroundNotifier.value = _backgroundColor;
    notifyListeners();
  }

  /// 重置为默认颜色
  void reset() {
    _foregroundColor = const Color(0xFF000000);
    _backgroundColor = const Color(0xFFFFFFFF);
    foregroundNotifier.value = _foregroundColor;
    backgroundNotifier.value = _backgroundColor;
    notifyListeners();
  }

  @override
  void dispose() {
    foregroundNotifier.dispose();
    backgroundNotifier.dispose();
    super.dispose();
  }
}
