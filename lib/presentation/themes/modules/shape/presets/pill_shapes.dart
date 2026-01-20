/// Pill Shapes - Material You rounded-full style
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/shape_module.dart';

class PillShapes extends BaseShapeModule {
  const PillShapes();

  @override
  double get smallRadius => 20.0;

  @override
  double get mediumRadius => 28.0;

  @override
  double get largeRadius => 100.0; // Fully rounded

  @override
  ShapeBorder get cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(mediumRadius),
      );

  @override
  ShapeBorder get buttonShape => const StadiumBorder(); // Pill shape

  @override
  ShapeBorder get inputShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(smallRadius),
      );
}
