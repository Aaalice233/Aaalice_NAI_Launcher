/// Thick Divider - Bold, prominent dividers
/// 
/// For themes with strong visual separation:
/// - Brutalist / Motorola Beeper (thick black lines)
/// - Grunge Collage (rough texture effect)
library;

import 'package:flutter/material.dart';
import '../../core/divider_module.dart';

/// A divider module with thick, prominent dividers.
/// 
/// Used for brutalist and industrial design aesthetics
/// where bold lines are a key visual element.
class ThickDividerModule extends BaseDividerModule {
  final Color _dividerColor;
  final double _thickness;

  const ThickDividerModule({
    required Color color,
    double thickness = 2.0,
  }) : _dividerColor = color,
       _thickness = thickness;

  /// Brutalist style - thick black lines
  factory ThickDividerModule.brutalist() {
    return const ThickDividerModule(
      color: Colors.black,
      thickness: 3.0,
    );
  }

  /// Grunge style - slightly thinner, dark gray
  factory ThickDividerModule.grunge() {
    return ThickDividerModule(
      color: Colors.grey.shade800,
      thickness: 2.0,
    );
  }

  @override
  double get thickness => _thickness;

  @override
  Color get dividerColor => _dividerColor;
}
