/// Pill Shapes - Material You rounded-full style
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/shape_module.dart';

class PillShapes extends BaseShapeModule {
  const PillShapes();

  @override
  double get smallRadius => 20.0;

  @override
  double get mediumRadius => 24.0;

  @override
  double get largeRadius => 28.0;

  @override
  double get menuRadius => 0.0;

  @override
  ShapeBorder get cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(largeRadius),
      );

  @override
  ShapeBorder get buttonShape => const StadiumBorder(); // Pill shape

  @override
  ShapeBorder get inputShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(smallRadius),
      );

  @override
  ShapeBorder get menuShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(menuRadius),
      );
}
