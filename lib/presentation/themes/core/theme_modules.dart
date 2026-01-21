/// Modular Theme System - Core Module Interfaces
///
/// This file defines the interfaces for the modular theme system.
/// Each module represents a specific aspect of theming that can be
/// independently configured and combined.
///
/// ## Architecture
///
/// The modular theme system consists of 6 core modules:
/// - [ColorSchemeModule] - Color palette and scheme
/// - [TypographyModule] - Font families and text styles
/// - [ShapeModule] - Border radius and shape definitions
/// - [ShadowModule] - Elevation and shadow styles
/// - [EffectModule] - Special effects (glassmorphism, neon, textures)
/// - [MotionModule] - Animation durations and curves
///
/// These modules can be freely combined using [ThemeComposer] to create
/// unique theme configurations.
library;

import 'package:flutter/material.dart';

// ============================================
// Color Module
// ============================================

/// Defines the color palette for a theme.
///
/// Each color module provides both light and dark color schemes,
/// and indicates whether dark mode is supported.
///
/// Example:
/// ```dart
/// class MyColorModule implements ColorSchemeModule {
///   @override
///   ColorScheme get lightScheme => ColorScheme.light(...);
///
///   @override
///   ColorScheme get darkScheme => ColorScheme.dark(...);
///
///   @override
///   bool get supportsDarkMode => true;
/// }
/// ```
abstract class ColorSchemeModule {
  /// The color scheme for light mode.
  ColorScheme get lightScheme;

  /// The color scheme for dark mode.
  ///
  /// If [supportsDarkMode] is false, this may return a fallback scheme.
  ColorScheme get darkScheme;

  /// Whether this color module supports dark mode.
  ///
  /// Some themes (like Hand-Drawn) only support light mode.
  bool get supportsDarkMode;
}

// ============================================
// Typography Module
// ============================================

/// Defines the typography for a theme.
///
/// Provides font family definitions and a complete text theme.
///
/// Example:
/// ```dart
/// class MyTypographyModule implements TypographyModule {
///   @override
///   String get displayFontFamily => 'Montserrat';
///
///   @override
///   String get bodyFontFamily => 'Open Sans';
///
///   @override
///   TextTheme get textTheme => TextTheme(...);
/// }
/// ```
abstract class TypographyModule {
  /// The font family for display/headline text.
  String get displayFontFamily;

  /// The font family for body text.
  String get bodyFontFamily;

  /// The complete text theme with all text styles defined.
  TextTheme get textTheme;
}

// ============================================
// Shape Module
// ============================================

/// Defines the shape and border radius for a theme.
///
/// Provides standard radius values and shape definitions for
/// common components like cards, buttons, and inputs.
///
/// Example:
/// ```dart
/// class MyShapeModule implements ShapeModule {
///   @override
///   double get smallRadius => 4.0;
///
///   @override
///   ShapeBorder get cardShape => RoundedRectangleBorder(
///     borderRadius: BorderRadius.circular(8.0),
///   );
/// }
/// ```
abstract class ShapeModule {
  /// Small border radius (typically 4-6px).
  double get smallRadius;

  /// Medium border radius (typically 8-12px).
  double get mediumRadius;

  /// Large border radius (typically 16-24px).
  double get largeRadius;

  /// Menu/popup border radius (typically 4px, always small for clean look).
  double get menuRadius;

  /// Shape for card components.
  ShapeBorder get cardShape;

  /// Shape for button components.
  ShapeBorder get buttonShape;

  /// Shape for input components.
  ShapeBorder get inputShape;

  /// Shape for menu/popup components.
  ShapeBorder get menuShape;
}

// ============================================
// Shadow Module
// ============================================

/// Defines the shadow/elevation styles for a theme.
///
/// Provides shadow definitions at different elevation levels.
/// For flat design themes, these can be empty lists.
///
/// Example:
/// ```dart
/// class FlatShadowModule implements ShadowModule {
///   @override
///   List<BoxShadow> get elevation1 => []; // No shadow
/// }
///
/// class SoftShadowModule implements ShadowModule {
///   @override
///   List<BoxShadow> get elevation1 => [
///     BoxShadow(color: Colors.black12, blurRadius: 4),
///   ];
/// }
/// ```
abstract class ShadowModule {
  /// Low elevation shadow (subtle).
  List<BoxShadow> get elevation1;

  /// Medium elevation shadow (standard).
  List<BoxShadow> get elevation2;

  /// High elevation shadow (prominent).
  List<BoxShadow> get elevation3;

  /// Shadow specifically for card components.
  List<BoxShadow> get cardShadow;
}

// ============================================
// Effect Module
// ============================================

/// Defines special visual effects for a theme.
///
/// Controls effects like glassmorphism, neon glow, and texture overlays.
///
/// Example:
/// ```dart
/// class GlassEffectModule implements EffectModule {
///   @override
///   bool get enableGlassmorphism => true;
///   @override
///   double get blurStrength => 12.0;
/// }
/// ```
abstract class EffectModule {
  /// Whether glassmorphism (frosted glass) effect is enabled.
  bool get enableGlassmorphism;

  /// Whether neon glow effect is enabled.
  bool get enableNeonGlow;

  /// The type of texture overlay to apply.
  TextureType get textureType;

  /// The color of the glow effect (for neon themes).
  Color? get glowColor;

  /// The blur strength for glassmorphism effect.
  double get blurStrength;

  /// Whether inset shadow effect is enabled for input areas.
  /// Creates a "sunken" or "carved" appearance for text input fields.
  bool get enableInsetShadow;

  /// The depth/intensity of the inset shadow (0.0-1.0).
  /// Higher values create more pronounced depth effect.
  double get insetShadowDepth;

  /// The blur radius for the inset shadow effect.
  double get insetShadowBlur;
}

/// Types of texture overlays that can be applied to a theme.
enum TextureType {
  /// No texture overlay.
  none,

  /// Paper grain texture (random dots for paper-like appearance).
  paperGrain,

  /// Dot matrix texture (regular grid of dots).
  dotMatrix,

  /// Halftone texture (gradient-sized dots like print media).
  halftone,

  /// Grunge texture (irregular noise for distressed look).
  grunge,
}

// ============================================
// Motion Module
// ============================================

/// Defines animation parameters for a theme.
///
/// Provides standard durations and curves for animations.
///
/// Example:
/// ```dart
/// class SnappyMotionModule implements MotionModule {
///   @override
///   Duration get fastDuration => Duration(milliseconds: 100);
///
///   @override
///   Curve get standardCurve => Curves.easeOutExpo;
/// }
/// ```
abstract class MotionModule {
  /// Fast animation duration (for micro-interactions).
  Duration get fastDuration;

  /// Normal animation duration (for standard transitions).
  Duration get normalDuration;

  /// Slow animation duration (for emphasized transitions).
  Duration get slowDuration;

  /// Curve for enter/appear animations.
  Curve get enterCurve;

  /// Curve for exit/disappear animations.
  Curve get exitCurve;

  /// Standard curve for general animations.
  Curve get standardCurve;
}
