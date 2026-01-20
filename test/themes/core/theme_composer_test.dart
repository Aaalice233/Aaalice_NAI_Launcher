/// ThemeComposer Tests
///
/// Tests for the ThemeComposer class that combines modules into ThemeData.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

void main() {
  group('ThemeComposer', () {
    late ThemeComposer composer;
    late _TestColorModule colorModule;
    late _TestTypographyModule typographyModule;
    late _TestShapeModule shapeModule;
    late _TestShadowModule shadowModule;
    late _TestEffectModule effectModule;
    late _TestMotionModule motionModule;

    setUp(() {
      colorModule = _TestColorModule();
      typographyModule = _TestTypographyModule();
      shapeModule = _TestShapeModule();
      shadowModule = _TestShadowModule();
      effectModule = _TestEffectModule();
      motionModule = _TestMotionModule();

      composer = ThemeComposer(
        color: colorModule,
        typography: typographyModule,
        shape: shapeModule,
        shadow: shadowModule,
        effect: effectModule,
        motion: motionModule,
      );
    });

    group('construction', () {
      test('should accept all 6 modules', () {
        expect(composer.color, same(colorModule));
        expect(composer.typography, same(typographyModule));
        expect(composer.shape, same(shapeModule));
        expect(composer.shadow, same(shadowModule));
        expect(composer.effect, same(effectModule));
        expect(composer.motion, same(motionModule));
      });
    });

    group('buildTheme', () {
      test('should return valid ThemeData for light mode', () {
        final theme = composer.buildTheme(Brightness.light);

        expect(theme, isA<ThemeData>());
        expect(theme.brightness, Brightness.light);
        expect(theme.colorScheme.brightness, Brightness.light);
      });

      test('should return valid ThemeData for dark mode', () {
        final theme = composer.buildTheme(Brightness.dark);

        expect(theme, isA<ThemeData>());
        expect(theme.brightness, Brightness.dark);
        expect(theme.colorScheme.brightness, Brightness.dark);
      });

      test('should use color module colors', () {
        final theme = composer.buildTheme(Brightness.light);

        expect(theme.colorScheme.primary, colorModule.lightScheme.primary);
        expect(theme.colorScheme.secondary, colorModule.lightScheme.secondary);
      });

      test('should use typography module text theme', () {
        final theme = composer.buildTheme(Brightness.light);

        expect(theme.textTheme.displayLarge?.fontSize, 57);
        expect(theme.textTheme.bodyMedium?.fontSize, 14);
      });

      test('should use shape module for component themes', () {
        final theme = composer.buildTheme(Brightness.light);

        // Card theme should use shape module
        expect(theme.cardTheme.shape, isA<ShapeBorder>());
      });

      test('should enable Material 3', () {
        final theme = composer.buildTheme(Brightness.light);
        expect(theme.useMaterial3, isTrue);
      });
    });

    group('buildExtension', () {
      test('should return valid AppThemeExtension', () {
        final extension = composer.buildExtension(Brightness.light);

        expect(extension, isA<AppThemeExtension>());
      });

      test('should include effect module properties', () {
        final effectComposer = ThemeComposer(
          color: colorModule,
          typography: typographyModule,
          shape: shapeModule,
          shadow: shadowModule,
          effect: _GlassEffectModule(),
          motion: motionModule,
        );

        final extension = effectComposer.buildExtension(Brightness.light);

        expect(extension.blurStrength, 12.0);
      });

      test('should set isLightTheme correctly', () {
        final lightExtension = composer.buildExtension(Brightness.light);
        final darkExtension = composer.buildExtension(Brightness.dark);

        expect(lightExtension.isLightTheme, isTrue);
        expect(darkExtension.isLightTheme, isFalse);
      });
    });

    group('dark mode fallback', () {
      test('should use light scheme when dark mode not supported', () {
        final lightOnlyColor = _LightOnlyColorModule();
        final lightOnlyComposer = ThemeComposer(
          color: lightOnlyColor,
          typography: typographyModule,
          shape: shapeModule,
          shadow: shadowModule,
          effect: effectModule,
          motion: motionModule,
        );

        final theme = lightOnlyComposer.buildTheme(Brightness.dark);

        // Should still build, but use light scheme as fallback
        // Brightness should match the ColorScheme to avoid assertion errors
        expect(theme, isA<ThemeData>());
        expect(theme.brightness, Brightness.light);
        expect(theme.colorScheme.brightness, Brightness.light);
      });
    });
  });
}

// ============================================
// Test Implementations
// ============================================

class _TestColorModule implements ColorSchemeModule {
  @override
  ColorScheme get lightScheme => const ColorScheme.light(
        primary: Color(0xFF6750A4),
        secondary: Color(0xFF625B71),
      );

  @override
  ColorScheme get darkScheme => const ColorScheme.dark(
        primary: Color(0xFFD0BCFF),
        secondary: Color(0xFFCCC2DC),
      );

  @override
  bool get supportsDarkMode => true;
}

class _LightOnlyColorModule implements ColorSchemeModule {
  @override
  ColorScheme get lightScheme => const ColorScheme.light(
        primary: Color(0xFF2D2D2D),
        secondary: Color(0xFFFF4D4D),
      );

  @override
  ColorScheme get darkScheme => lightScheme; // Fallback to light

  @override
  bool get supportsDarkMode => false;
}

class _TestTypographyModule implements TypographyModule {
  @override
  String get displayFontFamily => 'Roboto';

  @override
  String get bodyFontFamily => 'Roboto';

  @override
  TextTheme get textTheme => const TextTheme(
        displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      );
}

class _TestShapeModule implements ShapeModule {
  @override
  double get smallRadius => 4.0;

  @override
  double get mediumRadius => 8.0;

  @override
  double get largeRadius => 16.0;

  @override
  ShapeBorder get cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(mediumRadius),
      );

  @override
  ShapeBorder get buttonShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(smallRadius),
      );

  @override
  ShapeBorder get inputShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(smallRadius),
      );
}

class _TestShadowModule implements ShadowModule {
  @override
  List<BoxShadow> get elevation1 => [];

  @override
  List<BoxShadow> get elevation2 => [];

  @override
  List<BoxShadow> get elevation3 => [];

  @override
  List<BoxShadow> get cardShadow => [];
}

class _TestEffectModule implements EffectModule {
  @override
  bool get enableGlassmorphism => false;

  @override
  bool get enableNeonGlow => false;

  @override
  TextureType get textureType => TextureType.none;

  @override
  Color? get glowColor => null;

  @override
  double get blurStrength => 0.0;
}

class _GlassEffectModule implements EffectModule {
  @override
  bool get enableGlassmorphism => true;

  @override
  bool get enableNeonGlow => false;

  @override
  TextureType get textureType => TextureType.none;

  @override
  Color? get glowColor => null;

  @override
  double get blurStrength => 12.0;
}

class _TestMotionModule implements MotionModule {
  @override
  Duration get fastDuration => const Duration(milliseconds: 150);

  @override
  Duration get normalDuration => const Duration(milliseconds: 200);

  @override
  Duration get slowDuration => const Duration(milliseconds: 300);

  @override
  Curve get enterCurve => Curves.easeOut;

  @override
  Curve get exitCurve => Curves.easeIn;

  @override
  Curve get standardCurve => Curves.easeInOut;
}

// AppThemeExtension is imported from theme_extension.dart via theme_composer.dart
