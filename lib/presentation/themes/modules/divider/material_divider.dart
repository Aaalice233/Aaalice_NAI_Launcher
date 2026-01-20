/// Material Divider - Standard Material Design dividers
/// 
/// For Material You / Material Design themes
library;

import 'package:flutter/material.dart';
import '../../core/divider_module.dart';

/// A divider module following Material Design guidelines.
/// 
/// Uses the standard outline color from the color scheme
/// for consistent Material appearance.
class MaterialDividerModule extends BaseDividerModule {
  final Color _outlineColor;

  const MaterialDividerModule({
    required Color outlineColor,
  }) : _outlineColor = outlineColor;

  /// Create from a color scheme
  factory MaterialDividerModule.fromColorScheme(ColorScheme scheme) {
    return MaterialDividerModule(
      outlineColor: scheme.outline,
    );
  }

  @override
  double get thickness => 1.0;

  @override
  Color get dividerColor => _outlineColor;
}
