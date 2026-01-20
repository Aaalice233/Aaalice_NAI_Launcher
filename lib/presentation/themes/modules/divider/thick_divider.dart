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
/// 
/// Note: The thick line effect is preserved in ThemedDivider component,
/// while Flutter's theme.dividerColor uses a subtler variant for panel borders.
class ThickDividerModule extends BaseDividerModule {
  final Color _dividerColor;
  final double _thickness;
  final Color _borderColor;

  const ThickDividerModule({
    required Color color,
    double thickness = 2.0,
    Color? borderColor,
  }) : _dividerColor = color,
       _thickness = thickness,
       _borderColor = borderColor ?? color;

  /// Brutalist style - thick black lines for ThemedDivider
  /// Panel borders use a more subtle dark gray
  static const brutalist = ThickDividerModule(
    color: Colors.black,
    thickness: 3.0,
    borderColor: Color(0x1A000000), // 10% black for panel borders
  );

  /// Grunge style - dark gray lines for ThemedDivider
  /// Panel borders use a subtler version
  static const grunge = ThickDividerModule(
    color: Color(0xFF424242),
    thickness: 2.0,
    borderColor: Color(0x14FFFFFF), // 8% white for panel borders
  );

  @override
  double get thickness => _thickness;

  /// Returns a subtle border color for Flutter's theme.dividerColor.
  /// The thick/bold lines are preserved in horizontalDecoration/verticalDecoration.
  @override
  Color get dividerColor => _borderColor;

  /// The actual thick divider color used in decorations.
  Color get thickDividerColor => _dividerColor;

  @override
  BoxDecoration? get horizontalDecoration => BoxDecoration(
    border: Border(
      bottom: BorderSide(
        color: _dividerColor,
        width: _thickness,
      ),
    ),
  );

  @override
  BoxDecoration? get verticalDecoration => BoxDecoration(
    border: Border(
      right: BorderSide(
        color: _dividerColor,
        width: _thickness,
      ),
    ),
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
        top: top ? BorderSide(color: _dividerColor, width: _thickness) : BorderSide.none,
        right: right ? BorderSide(color: _dividerColor, width: _thickness) : BorderSide.none,
        bottom: bottom ? BorderSide(color: _dividerColor, width: _thickness) : BorderSide.none,
        left: left ? BorderSide(color: _dividerColor, width: _thickness) : BorderSide.none,
      ),
    );
  }
}
