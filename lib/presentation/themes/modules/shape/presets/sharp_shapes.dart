/// Sharp Shapes - Flat Design minimal corners
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/shape_module.dart';

class SharpShapes extends BaseShapeModule {
  const SharpShapes();

  @override
  double get smallRadius => 4.0;

  @override
  double get mediumRadius => 6.0;

  @override
  double get largeRadius => 8.0;

  @override
  ShapeBorder get cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(mediumRadius),
      );

  @override
  ShapeBorder get buttonShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(smallRadius),
      );

  @override
  ShapeBorder get inputShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(smallRadius),
      );
}
