/// Standard Shapes - Zen-inspired rounded corners
///
/// Design Reference: docs/UI设计提示词合集/默认主题.txt
/// - Cards: rounded-[32px]
/// - Buttons: rounded-full (StadiumBorder / pill shape)
/// - Inputs: rounded-[32px]
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/shape_module.dart';

class StandardShapes extends BaseShapeModule {
  const StandardShapes();

  @override
  double get smallRadius => 16.0;

  @override
  double get mediumRadius => 24.0;

  @override
  double get largeRadius => 32.0;

  @override
  double get menuRadius => 0.0;

  @override
  ShapeBorder get cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(largeRadius),
      );

  @override
  ShapeBorder get buttonShape => const StadiumBorder();

  @override
  ShapeBorder get inputShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(largeRadius),
      );

  @override
  ShapeBorder get menuShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(menuRadius),
      );
}
