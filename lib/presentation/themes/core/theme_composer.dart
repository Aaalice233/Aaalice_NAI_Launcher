/// ThemeComposer - Modular Theme Composition
///
/// The ThemeComposer takes 7 independent modules and combines them into
/// a complete [ThemeData] and [AppThemeExtension].
///
/// ## Usage
///
/// ```dart
/// final composer = ThemeComposer(
///   color: RetroPalette(),
///   typography: RetroTypography(),
///   shape: StandardShapes(),
///   shadow: SoftShadow(),
///   effect: NoneEffect(),
///   motion: SnappyMotion(),
///   divider: SoftDividerModule.standard(Colors.white),
/// );
///
/// final lightTheme = composer.buildTheme(Brightness.light);
/// final extension = composer.buildExtension(Brightness.light);
/// ```
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/divider_module.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

/// Composes multiple theme modules into a complete [ThemeData].
///
/// Each module handles a specific aspect of theming:
/// - [color] - Color palette (ColorScheme)
/// - [typography] - Font families and text styles
/// - [shape] - Border radius and component shapes
/// - [shadow] - Elevation and shadow styles
/// - [effect] - Special visual effects
/// - [motion] - Animation parameters
/// - [divider] - Divider and border styles
class ThemeComposer {
  /// The color module providing ColorScheme.
  final ColorSchemeModule color;

  /// The typography module providing TextTheme and font families.
  final TypographyModule typography;

  /// The shape module providing border radius and ShapeBorder.
  final ShapeModule shape;

  /// The shadow module providing BoxShadow lists.
  final ShadowModule shadow;

  /// The effect module providing special visual effects.
  final EffectModule effect;

  /// The motion module providing animation parameters.
  final MotionModule motion;

  /// The divider module providing divider and border styles.
  final DividerModule divider;

  /// Creates a ThemeComposer with all required modules.
  const ThemeComposer({
    required this.color,
    required this.typography,
    required this.shape,
    required this.shadow,
    required this.effect,
    required this.motion,
    required this.divider,
  });

  /// Builds a complete [ThemeData] for the given brightness.
  ///
  /// If dark mode is requested but not supported by the color module,
  /// the light scheme will be used as a fallback, and brightness will
  /// match the fallback scheme to avoid assertion errors.
  ThemeData buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    
    // Get the appropriate color scheme and effective brightness
    ColorScheme colorScheme;
    Brightness effectiveBrightness;
    
    if (isDark && color.supportsDarkMode) {
      colorScheme = color.darkScheme;
      effectiveBrightness = Brightness.dark;
    } else if (isDark && !color.supportsDarkMode) {
      // Fallback: use light scheme - brightness MUST match the ColorScheme
      colorScheme = color.lightScheme;
      effectiveBrightness = colorScheme.brightness;
    } else {
      colorScheme = color.lightScheme;
      // Use the actual brightness from ColorScheme to avoid mismatch
      // (some dark-only themes return darkScheme for lightScheme)
      effectiveBrightness = colorScheme.brightness;
    }

    // Build text theme with proper colors applied
    final textTheme = _applyColorToTextTheme(
      typography.textTheme,
      colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: effectiveBrightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      
      // Apply divider module colors to Flutter's built-in divider
      dividerColor: divider.dividerColor,
      dividerTheme: DividerThemeData(
        color: divider.dividerColor,
        thickness: divider.thickness,
        space: divider.thickness,
      ),
      
      // Apply shape module to component themes
      cardTheme: CardTheme(
        shape: shape.cardShape,
        elevation: 0, // We handle shadows manually via BoxShadow
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: shape.buttonShape as OutlinedBorder?,
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape.buttonShape as OutlinedBorder?,
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: shape.buttonShape as OutlinedBorder?,
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: _extractBorderRadius(shape.inputShape),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _extractBorderRadius(shape.inputShape),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _extractBorderRadius(shape.inputShape),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      
      // Apply motion to page transitions
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _ModularPageTransitionBuilder(motion),
          TargetPlatform.iOS: _ModularPageTransitionBuilder(motion),
          TargetPlatform.windows: _ModularPageTransitionBuilder(motion),
          TargetPlatform.macOS: _ModularPageTransitionBuilder(motion),
          TargetPlatform.linux: _ModularPageTransitionBuilder(motion),
        },
      ),
    );
  }

  /// Builds an [AppThemeExtension] for the given brightness.
  ///
  /// The extension contains additional theme properties not covered
  /// by standard [ThemeData].
  AppThemeExtension buildExtension(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    
    // Determine container decoration based on shadow module
    final containerDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(shape.mediumRadius),
      boxShadow: shadow.cardShadow,
    );

    return AppThemeExtension(
      containerDecoration: containerDecoration,
      blurStrength: effect.blurStrength,
      isLightTheme: isLight,
      enableNeonGlow: effect.enableNeonGlow,
      glowColor: effect.glowColor,
      shadowIntensity: shadow.cardShadow.isNotEmpty ? 1.0 : 0.0,
      // Divider module properties
      dividerColor: divider.dividerColor,
      dividerThickness: divider.thickness,
      useDivider: divider.useDivider,
    );
  }

  /// Applies the given color to all text styles in the theme.
  TextTheme _applyColorToTextTheme(TextTheme textTheme, Color color) {
    return textTheme.apply(
      bodyColor: color,
      displayColor: color,
    );
  }

  /// Extracts BorderRadius from a ShapeBorder.
  BorderRadius _extractBorderRadius(ShapeBorder shapeBorder) {
    if (shapeBorder is RoundedRectangleBorder) {
      return shapeBorder.borderRadius as BorderRadius;
    }
    // Default fallback
    return BorderRadius.circular(shape.smallRadius);
  }
}

/// Custom page transition builder that uses motion module parameters.
class _ModularPageTransitionBuilder extends PageTransitionsBuilder {
  final MotionModule motion;

  const _ModularPageTransitionBuilder(this.motion);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: motion.enterCurve,
      reverseCurve: motion.exitCurve,
    );

    return FadeTransition(
      opacity: curvedAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}
