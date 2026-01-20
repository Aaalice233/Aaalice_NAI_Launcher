/// Glow Divider - Neon glow effect borders
/// 
/// For themes with cyberpunk/retro-futuristic aesthetics:
/// - RetroWave / Cassette Futurism
library;

import 'package:flutter/material.dart';
import '../../core/divider_module.dart';

/// A divider module with neon glow effects.
/// 
/// Creates borders with a glowing appearance using
/// box shadows and gradient effects.
class GlowDividerModule extends BaseDividerModule {
  final Color _glowColor;
  final double _glowIntensity;

  const GlowDividerModule({
    required Color glowColor,
    double glowIntensity = 1.0,
  }) : _glowColor = glowColor,
       _glowIntensity = glowIntensity;

  /// RetroWave style - orange/pink neon glow
  factory GlowDividerModule.retroWave() {
    return const GlowDividerModule(
      glowColor: Color(0xFFFF6B35), // Warm orange
      glowIntensity: 0.8,
    );
  }

  /// Cyan neon glow variant
  factory GlowDividerModule.cyan() {
    return const GlowDividerModule(
      glowColor: Color(0xFF00FFFF),
      glowIntensity: 0.8,
    );
  }

  @override
  double get thickness => 1.0;

  @override
  Color get dividerColor => _glowColor;

  @override
  BoxDecoration? get horizontalDecoration => BoxDecoration(
    border: Border(
      bottom: BorderSide(
        color: _glowColor.withOpacity(0.8),
        width: thickness,
      ),
    ),
    boxShadow: [
      BoxShadow(
        color: _glowColor.withOpacity(0.3 * _glowIntensity),
        blurRadius: 4,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: _glowColor.withOpacity(0.2 * _glowIntensity),
        blurRadius: 8,
        spreadRadius: 0,
      ),
    ],
  );

  @override
  BoxDecoration? get verticalDecoration => BoxDecoration(
    border: Border(
      right: BorderSide(
        color: _glowColor.withOpacity(0.8),
        width: thickness,
      ),
    ),
    boxShadow: [
      BoxShadow(
        color: _glowColor.withOpacity(0.3 * _glowIntensity),
        blurRadius: 4,
        spreadRadius: 0,
      ),
    ],
  );

  @override
  BoxDecoration panelBorder({
    bool top = false,
    bool right = false,
    bool bottom = false,
    bool left = false,
  }) {
    return BoxDecoration(
      border: Border(
        top: top ? BorderSide(color: _glowColor.withOpacity(0.8), width: thickness) : BorderSide.none,
        right: right ? BorderSide(color: _glowColor.withOpacity(0.8), width: thickness) : BorderSide.none,
        bottom: bottom ? BorderSide(color: _glowColor.withOpacity(0.8), width: thickness) : BorderSide.none,
        left: left ? BorderSide(color: _glowColor.withOpacity(0.8), width: thickness) : BorderSide.none,
      ),
      boxShadow: [
        BoxShadow(
          color: _glowColor.withOpacity(0.2 * _glowIntensity),
          blurRadius: 6,
          spreadRadius: 0,
        ),
      ],
    );
  }
}
