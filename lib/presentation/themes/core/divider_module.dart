/// Divider Module - Theme-aware divider and border styles
///
/// This module defines the divider and panel border styles for each theme.
/// Different themes have different divider aesthetics:
/// - Flat Design: No dividers (uses whitespace)
/// - Hand-Drawn: Dashed lines
/// - Zen Minimalist: Ultra-subtle (6% opacity)
/// - Brutalist: Thick solid black lines
/// - RetroWave: Neon glow borders
library;

import 'package:flutter/material.dart';

/// Defines the divider and border styles for a theme.
///
/// Each divider module provides decorations for horizontal/vertical dividers
/// and panel borders, plus configuration for whether dividers should be shown.
///
/// Example:
/// ```dart
/// class NoDividerModule implements DividerModule {
///   @override
///   bool get useDivider => false;
///   // ... other properties return empty/null
/// }
///
/// class SoftDividerModule implements DividerModule {
///   @override
///   BoxDecoration get horizontalDecoration => BoxDecoration(
///     border: Border(
///       bottom: BorderSide(
///         color: Colors.white.withOpacity(0.1),
///         width: 1,
///       ),
///     ),
///   );
/// }
/// ```
abstract class DividerModule {
  /// Whether this theme uses visible dividers.
  ///
  /// If false, ThemedDivider will render nothing (SizedBox.shrink).
  /// Themes like Flat Design use whitespace instead of lines.
  bool get useDivider;

  /// The thickness of the divider line.
  ///
  /// For themes without dividers, this can return 0.
  double get thickness;

  /// Decoration for horizontal dividers.
  ///
  /// Used for separating vertical sections (e.g., between list items).
  /// Returns null if no decoration is needed.
  BoxDecoration? get horizontalDecoration;

  /// Decoration for vertical dividers.
  ///
  /// Used for separating horizontal sections (e.g., between columns).
  /// Returns null if no decoration is needed.
  BoxDecoration? get verticalDecoration;

  /// Decoration for panel borders.
  ///
  /// Used for the borders of major UI panels (sidebar, main content, etc.).
  /// This can be more elaborate than simple dividers (e.g., glow effects).
  ///
  /// [sides] indicates which sides should have borders:
  /// - top, right, bottom, left
  BoxDecoration panelBorder({
    bool top = false,
    bool right = false,
    bool bottom = false,
    bool left = false,
  });

  /// The color of the divider/border.
  ///
  /// This is a convenience getter for simple border styling.
  Color get dividerColor;
}

/// Base implementation of DividerModule with common functionality.
///
/// Provides default implementations that can be overridden by specific presets.
abstract class BaseDividerModule implements DividerModule {
  const BaseDividerModule();

  @override
  bool get useDivider => true;

  @override
  double get thickness => 1.0;

  @override
  BoxDecoration? get horizontalDecoration => BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: dividerColor,
            width: thickness,
          ),
        ),
      );

  @override
  BoxDecoration? get verticalDecoration => BoxDecoration(
        border: Border(
          right: BorderSide(
            color: dividerColor,
            width: thickness,
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
        top: top
            ? BorderSide(color: dividerColor, width: thickness)
            : BorderSide.none,
        right: right
            ? BorderSide(color: dividerColor, width: thickness)
            : BorderSide.none,
        bottom: bottom
            ? BorderSide(color: dividerColor, width: thickness)
            : BorderSide.none,
        left: left
            ? BorderSide(color: dividerColor, width: thickness)
            : BorderSide.none,
      ),
    );
  }
}
