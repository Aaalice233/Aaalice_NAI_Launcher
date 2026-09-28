import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// 应用级语义设计 token。
///
/// ThemeData 负责 Material 组件样式；此扩展只保留 Flutter ThemeData 尚未统一
/// 表达、且项目组件确实消费的尺寸、分隔与动效 token。
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    this.borderColor,
    this.dividerColor = const Color(0x1AFFFFFF),
    this.dividerThickness = 1,
    this.useDivider = true,
    this.controlRadius = 8,
    this.cardRadius = 14,
    this.dialogRadius = 18,
    this.menuRadius = 8,
    this.fastDuration = const Duration(milliseconds: 100),
    this.normalDuration = const Duration(milliseconds: 180),
    this.slowDuration = const Duration(milliseconds: 280),
    this.standardCurve = Curves.easeOutCubic,
    this.enterCurve = Curves.easeOutCubic,
    this.exitCurve = Curves.easeInCubic,
  });

  /// 兼容尚在迁移的统计页；新代码应直接使用 `ColorScheme.outlineVariant`。
  final Color? borderColor;
  final Color dividerColor;
  final double dividerThickness;
  final bool useDivider;
  final double controlRadius;
  final double cardRadius;
  final double dialogRadius;
  final double menuRadius;
  final Duration fastDuration;
  final Duration normalDuration;
  final Duration slowDuration;
  final Curve standardCurve;
  final Curve enterCurve;
  final Curve exitCurve;

  @override
  AppThemeExtension copyWith({
    Color? borderColor,
    Color? dividerColor,
    double? dividerThickness,
    bool? useDivider,
    double? controlRadius,
    double? cardRadius,
    double? dialogRadius,
    double? menuRadius,
    Duration? fastDuration,
    Duration? normalDuration,
    Duration? slowDuration,
    Curve? standardCurve,
    Curve? enterCurve,
    Curve? exitCurve,
  }) {
    return AppThemeExtension(
      borderColor: borderColor ?? this.borderColor,
      dividerColor: dividerColor ?? this.dividerColor,
      dividerThickness: dividerThickness ?? this.dividerThickness,
      useDivider: useDivider ?? this.useDivider,
      controlRadius: controlRadius ?? this.controlRadius,
      cardRadius: cardRadius ?? this.cardRadius,
      dialogRadius: dialogRadius ?? this.dialogRadius,
      menuRadius: menuRadius ?? this.menuRadius,
      fastDuration: fastDuration ?? this.fastDuration,
      normalDuration: normalDuration ?? this.normalDuration,
      slowDuration: slowDuration ?? this.slowDuration,
      standardCurve: standardCurve ?? this.standardCurve,
      enterCurve: enterCurve ?? this.enterCurve,
      exitCurve: exitCurve ?? this.exitCurve,
    );
  }

  @override
  AppThemeExtension lerp(AppThemeExtension? other, double t) {
    if (other == null) return this;
    return AppThemeExtension(
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      dividerColor:
          Color.lerp(dividerColor, other.dividerColor, t) ?? dividerColor,
      dividerThickness:
          lerpDouble(dividerThickness, other.dividerThickness, t) ??
          dividerThickness,
      useDivider: t < 0.5 ? useDivider : other.useDivider,
      controlRadius:
          lerpDouble(controlRadius, other.controlRadius, t) ?? controlRadius,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t) ?? cardRadius,
      dialogRadius:
          lerpDouble(dialogRadius, other.dialogRadius, t) ?? dialogRadius,
      menuRadius: lerpDouble(menuRadius, other.menuRadius, t) ?? menuRadius,
      fastDuration: t < 0.5 ? fastDuration : other.fastDuration,
      normalDuration: t < 0.5 ? normalDuration : other.normalDuration,
      slowDuration: t < 0.5 ? slowDuration : other.slowDuration,
      standardCurve: t < 0.5 ? standardCurve : other.standardCurve,
      enterCurve: t < 0.5 ? enterCurve : other.enterCurve,
      exitCurve: t < 0.5 ? exitCurve : other.exitCurve,
    );
  }
}

extension AppThemeContext on ThemeData {
  AppThemeExtension get appTheme =>
      extension<AppThemeExtension>() ?? const AppThemeExtension();
}
