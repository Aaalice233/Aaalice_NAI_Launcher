/// Accent Divider - Colored accent dividers
///
/// For themes with prominent accent colors:
/// - Herding (gold accent bar)
library;

import 'package:flutter/material.dart';
import '../../core/divider_module.dart';

/// A divider module with colored accent dividers.
///
/// Uses a prominent accent color for dividers,
/// creating a distinctive visual style.
class AccentDividerModule extends BaseDividerModule {
  final Color _accentColor;
  final Color _subtleColor;

  const AccentDividerModule({
    required Color accentColor,
    required Color subtleColor,
  })  : _accentColor = accentColor,
        _subtleColor = subtleColor;

  /// Herding style - gold accent with subtle background
  factory AccentDividerModule.herding() {
    return const AccentDividerModule(
      accentColor: Color(0xFFE5B94E), // Gold
      subtleColor: Color(0xFF2A3A4A), // Dark teal
    );
  }

  @override
  double get thickness => 2.0;

  @override
  Color get dividerColor => _accentColor;

  @override
  BoxDecoration? get horizontalDecoration => BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accentColor.withOpacity(0.0),
            _accentColor,
            _accentColor,
            _accentColor.withOpacity(0.0),
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      );

  @override
  BoxDecoration panelBorder({
    bool top = false,
    bool right = false,
    bool bottom = false,
    bool left = false,
  }) {
    // For panels, use subtle color instead of accent
    return BoxDecoration(
      border: Border(
        top: top ? BorderSide(color: _subtleColor, width: 1) : BorderSide.none,
        right:
            right ? BorderSide(color: _subtleColor, width: 1) : BorderSide.none,
        bottom: bottom
            ? BorderSide(color: _subtleColor, width: 1)
            : BorderSide.none,
        left:
            left ? BorderSide(color: _subtleColor, width: 1) : BorderSide.none,
      ),
    );
  }
}
