/// Standard Shapes - 深度层叠风格：小圆角
///
/// 设计理念：小圆角（4-8px）+ 阴影层次 > 大圆角 + 边框
/// - Cards: 8px
/// - Buttons: 6px
/// - Inputs: 6px
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/shape_module.dart';

class StandardShapes extends BaseShapeModule {
  const StandardShapes();

  @override
  double get smallRadius => 4.0;

  @override
  double get mediumRadius => 6.0;

  @override
  double get largeRadius => 8.0;

  @override
  double get menuRadius => 4.0;

  @override
  ShapeBorder get cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(largeRadius),
      );

  @override
  ShapeBorder get buttonShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(mediumRadius),
      );

  @override
  ShapeBorder get inputShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(mediumRadius),
      );

  @override
  ShapeBorder get menuShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(menuRadius),
      );
}
