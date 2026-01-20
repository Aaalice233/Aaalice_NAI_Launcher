/// Theme Modules Interface Tests
///
/// Tests for the modular theme system interfaces.
/// Validates that all module interfaces have the required properties.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';

void main() {
  group('ColorSchemeModule', () {
    test('should have required color properties', () {
      // Create a test implementation
      final module = _TestColorSchemeModule();

      expect(module.lightScheme, isA<ColorScheme>());
      expect(module.darkScheme, isA<ColorScheme>());
      expect(module.supportsDarkMode, isA<bool>());
    });

    test('lightScheme should have light brightness', () {
      final module = _TestColorSchemeModule();
      expect(module.lightScheme.brightness, Brightness.light);
    });

    test('darkScheme should have dark brightness', () {
      final module = _TestColorSchemeModule();
      expect(module.darkScheme.brightness, Brightness.dark);
    });
  });

  group('TypographyModule', () {
    test('should have required typography properties', () {
      final module = _TestTypographyModule();

      expect(module.displayFontFamily, isA<String>());
      expect(module.bodyFontFamily, isA<String>());
      expect(module.textTheme, isA<TextTheme>());
    });

    test('textTheme should have standard text styles', () {
      final module = _TestTypographyModule();
      final textTheme = module.textTheme;

      expect(textTheme.displayLarge, isNotNull);
      expect(textTheme.bodyMedium, isNotNull);
      expect(textTheme.labelSmall, isNotNull);
    });
  });

  group('ShapeModule', () {
    test('should have required shape properties', () {
      final module = _TestShapeModule();

      expect(module.smallRadius, isA<double>());
      expect(module.mediumRadius, isA<double>());
      expect(module.largeRadius, isA<double>());
      expect(module.cardShape, isA<ShapeBorder>());
      expect(module.buttonShape, isA<ShapeBorder>());
      expect(module.inputShape, isA<ShapeBorder>());
    });

    test('radius values should be non-negative', () {
      final module = _TestShapeModule();

      expect(module.smallRadius, greaterThanOrEqualTo(0));
      expect(module.mediumRadius, greaterThanOrEqualTo(0));
      expect(module.largeRadius, greaterThanOrEqualTo(0));
    });
  });

  group('ShadowModule', () {
    test('should have required shadow properties', () {
      final module = _TestShadowModule();

      expect(module.elevation1, isA<List<BoxShadow>>());
      expect(module.elevation2, isA<List<BoxShadow>>());
      expect(module.elevation3, isA<List<BoxShadow>>());
      expect(module.cardShadow, isA<List<BoxShadow>>());
    });

    test('elevation lists can be empty for flat design', () {
      final module = _TestShadowModule();
      // Empty lists are valid for flat/no-shadow designs
      expect(module.elevation1, isA<List<BoxShadow>>());
    });
  });

  group('EffectModule', () {
    test('should have required effect properties', () {
      final module = _TestEffectModule();

      expect(module.enableGlassmorphism, isA<bool>());
      expect(module.enableNeonGlow, isA<bool>());
      expect(module.textureType, isA<TextureType>());
      expect(module.glowColor, isA<Color?>());
      expect(module.blurStrength, isA<double>());
    });

    test('blurStrength should be non-negative', () {
      final module = _TestEffectModule();
      expect(module.blurStrength, greaterThanOrEqualTo(0));
    });
  });

  group('MotionModule', () {
    test('should have required motion properties', () {
      final module = _TestMotionModule();

      expect(module.fastDuration, isA<Duration>());
      expect(module.normalDuration, isA<Duration>());
      expect(module.slowDuration, isA<Duration>());
      expect(module.enterCurve, isA<Curve>());
      expect(module.exitCurve, isA<Curve>());
      expect(module.standardCurve, isA<Curve>());
    });

    test('durations should be positive', () {
      final module = _TestMotionModule();

      expect(module.fastDuration.inMilliseconds, greaterThan(0));
      expect(module.normalDuration.inMilliseconds, greaterThan(0));
      expect(module.slowDuration.inMilliseconds, greaterThan(0));
    });

    test('fast should be shorter than normal, normal shorter than slow', () {
      final module = _TestMotionModule();

      expect(
        module.fastDuration.inMilliseconds,
        lessThan(module.normalDuration.inMilliseconds),
      );
      expect(
        module.normalDuration.inMilliseconds,
        lessThan(module.slowDuration.inMilliseconds),
      );
    });
  });

  group('TextureType', () {
    test('should have all required texture types', () {
      expect(TextureType.values, contains(TextureType.none));
      expect(TextureType.values, contains(TextureType.paperGrain));
      expect(TextureType.values, contains(TextureType.dotMatrix));
      expect(TextureType.values, contains(TextureType.halftone));
      expect(TextureType.values, contains(TextureType.grunge));
    });
  });
}

// ============================================
// Test Implementations
// ============================================

class _TestColorSchemeModule implements ColorSchemeModule {
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
  List<BoxShadow> get elevation1 => [
        const BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ];

  @override
  List<BoxShadow> get elevation2 => [
        const BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ];

  @override
  List<BoxShadow> get elevation3 => [
        const BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ];

  @override
  List<BoxShadow> get cardShadow => elevation2;
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
