/// Shape Module - Base Implementation
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';

export 'presets/standard_shapes.dart';
export 'presets/pill_shapes.dart';
export 'presets/sharp_shapes.dart';
export 'presets/fluid_shapes.dart';
export 'presets/wobbly_shapes.dart';
export 'presets/layered_shapes.dart';

/// Base implementation of [ShapeModule].
abstract class BaseShapeModule implements ShapeModule {
  const BaseShapeModule();

  /// Helper to create RoundedRectangleBorder.
  static ShapeBorder roundedShape(double radius) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
  }
}
