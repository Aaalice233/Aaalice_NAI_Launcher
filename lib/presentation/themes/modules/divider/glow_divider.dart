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
  final Color _borderColor;

  const GlowDividerModule({
    required Color glowColor,
    double glowIntensity = 1.0,
    Color? borderColor,
  }) : _glowColor = glowColor,
       _glowIntensity = glowIntensity,
       _borderColor = borderColor ?? const Color(0x0FFFFFFF); // 6% white default

  /// RetroWave style - orange/pink neon glow
  /// Glow effect uses bright orange, but panel borders use subtle white
  static const retroWave = GlowDividerModule(
    glowColor: Color(0xFFFF6B35), // Warm orange for glow effect
    glowIntensity: 0.8,
    borderColor: Color(0x0FFFFFFF), // 6% white for panel borders
  );

  /// Cyan neon glow variant
  static const cyan = GlowDividerModule(
    glowColor: Color(0xFF00FFFF),
    glowIntensity: 0.8,
    borderColor: Color(0x0FFFFFFF), // 6% white for panel borders
  );

  @override
  double get thickness => 1.0;

  /// Returns a subtle border color for Flutter's theme.dividerColor.
  /// The bright glow color is only used in horizontalDecoration/verticalDecoration.
  @override
  Color get dividerColor => _borderColor;

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
