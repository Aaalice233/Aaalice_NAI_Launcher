import 'package:flutter/material.dart';
import '../../themes/theme_extension.dart';

/// 主题感知边框工具类 - 提供统一的边框样式
///
/// 用于替代直接使用 BorderSide，确保边框颜色与主题一致
///
/// 使用示例:
/// ```dart
/// // 获取默认边框
/// Border(
///   bottom: ThemedBorder.side(context),
/// )
///
/// // 获取特定方向的边框
/// ThemedBorder.bottom(context)
/// ThemedBorder.top(context)
/// ```
class ThemedBorder {
  ThemedBorder._();

  /// 获取主题感知的边框颜色
  static Color getColor(BuildContext context, {double opacity = 0.3}) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppThemeExtension>();
    final isDark = theme.brightness == Brightness.dark;

    // 优先使用主题扩展中的 dividerColor
    if (extension?.dividerColor != null) {
      return extension!.dividerColor.withOpacity(opacity);
    }

    // 回退到默认颜色
    return isDark
        ? Colors.white.withOpacity(opacity)
        : Colors.black.withOpacity(opacity);
  }

  /// 获取主题感知的 BorderSide
  static BorderSide side(
    BuildContext context, {
    double width = 1.0,
    double opacity = 0.3,
  }) {
    return BorderSide(
      color: getColor(context, opacity: opacity),
      width: width,
    );
  }

  /// 获取底部边框
  static Border bottom(
    BuildContext context, {
    double width = 1.0,
    double opacity = 0.3,
  }) {
    return Border(
      bottom: side(context, width: width, opacity: opacity),
    );
  }

  /// 获取顶部边框
  static Border top(
    BuildContext context, {
    double width = 1.0,
    double opacity = 0.3,
  }) {
    return Border(
      top: side(context, width: width, opacity: opacity),
    );
  }

  /// 获取左侧边框
  static Border left(
    BuildContext context, {
    double width = 1.0,
    double opacity = 0.3,
  }) {
    return Border(
      left: side(context, width: width, opacity: opacity),
    );
  }

  /// 获取右侧边框
  static Border right(
    BuildContext context, {
    double width = 1.0,
    double opacity = 0.3,
  }) {
    return Border(
      right: side(context, width: width, opacity: opacity),
    );
  }

  /// 获取所有方向边框
  static Border all(
    BuildContext context, {
    double width = 1.0,
    double opacity = 0.3,
  }) {
    final borderSide = side(context, width: width, opacity: opacity);
    return Border.fromBorderSide(borderSide);
  }
}

/// BuildContext 扩展，便于快速访问主题边框
extension ThemedBorderContext on BuildContext {
  /// 获取主题边框颜色
  Color get themedBorderColor => ThemedBorder.getColor(this);

  /// 获取主题边框 BorderSide
  BorderSide get themedBorderSide => ThemedBorder.side(this);
}
