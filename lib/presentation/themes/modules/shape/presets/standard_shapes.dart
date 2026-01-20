/// Standard Shapes - Default rounded corners
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/shape_module.dart';

class StandardShapes extends BaseShapeModule {
  const StandardShapes();

  @override
  double get smallRadius => 8.0;

  @override
  double get mediumRadius => 12.0;

  @override
  double get largeRadius => 16.0;

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
