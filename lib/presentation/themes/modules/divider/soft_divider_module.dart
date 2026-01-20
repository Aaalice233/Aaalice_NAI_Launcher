/// Soft Divider - Subtle, low-opacity dividers
/// 
/// For themes with minimal, understated dividers:
/// - Zen Minimalist (6% opacity)
/// - MinimalGlass / Herding
/// - NeoDark / Linear  
/// - ProAi / Invoke
/// - AppleLight / PureLight
/// - System
library;

import 'package:flutter/material.dart';
import '../../core/divider_module.dart';

/// A divider module with soft, subtle dividers.
/// 
/// Uses low opacity borders that blend into the background
/// while still providing visual separation.
class SoftDividerModule extends BaseDividerModule {
  final Color _dividerColor;
  final double _opacity;

  const SoftDividerModule({
    required Color color,
    double opacity = 0.1,
  }) : _dividerColor = color,
       _opacity = opacity;

  /// Zen style - ultra subtle (6% opacity)
  factory SoftDividerModule.zen(Color baseColor) {
    return SoftDividerModule(color: baseColor, opacity: 0.06);
  }

  /// Standard soft divider (10% opacity)
  factory SoftDividerModule.standard(Color baseColor) {
    return SoftDividerModule(color: baseColor, opacity: 0.10);
  }

  /// Light theme soft divider (darker, 15% opacity)
  factory SoftDividerModule.light(Color baseColor) {
    return SoftDividerModule(color: baseColor, opacity: 0.15);
  }

  @override
  double get thickness => 1.0;

  @override
  Color get dividerColor => _dividerColor.withOpacity(_opacity);
}
