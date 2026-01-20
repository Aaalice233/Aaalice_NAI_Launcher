/// Fluid Shapes - Extreme rounded corners (100px+)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/shape_module.dart';

class FluidShapes extends BaseShapeModule {
  const FluidShapes();

  @override
  double get smallRadius => 24.0;

  @override
  double get mediumRadius => 32.0;

  @override
  double get largeRadius => 100.0;

  @override
  ShapeBorder get cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(largeRadius),
      );

  @override
  ShapeBorder get buttonShape => const StadiumBorder();

  @override
  ShapeBorder get inputShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(mediumRadius),
      );
}
