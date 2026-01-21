/// Wobbly Shapes - Hand-drawn irregular borders
///
/// This is a placeholder. The actual WobblyShapeBorder is implemented
/// in Task 8 (painters/wobbly_shape_border.dart).
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/shape_module.dart';

class WobblyShapes extends BaseShapeModule {
  const WobblyShapes();

  @override
  double get smallRadius => 8.0;

  @override
  double get mediumRadius => 12.0;

  @override
  double get largeRadius => 16.0;

  @override
  double get menuRadius => 0.0;

  // Placeholder - will be replaced with WobblyShapeBorder in Task 8
  @override
  ShapeBorder get cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(mediumRadius),
        side: const BorderSide(color: Color(0xFF2D2D2D), width: 2),
      );

  @override
  ShapeBorder get buttonShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(smallRadius),
        side: const BorderSide(color: Color(0xFF2D2D2D), width: 2),
      );

  @override
  ShapeBorder get inputShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(smallRadius),
        side: const BorderSide(color: Color(0xFF2D2D2D), width: 2),
      );

  @override
  ShapeBorder get menuShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(menuRadius),
      );
}
