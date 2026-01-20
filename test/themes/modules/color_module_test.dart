/// Color Module Tests
///
/// Tests for color palette implementations.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

void main() {
  group('RetroPalette', () {
    const palette = RetroPalette();

    test('should have valid light scheme', () {
      expect(palette.lightScheme.brightness, Brightness.light);
      expect(palette.lightScheme.primary, const Color(0xFFBC2C2C));
    });

    test('should not support dark mode', () {
      expect(palette.supportsDarkMode, isFalse);
    });
  });

  group('GrungePalette', () {
    const palette = GrungePalette();

    test('should support dark mode', () {
      expect(palette.supportsDarkMode, isTrue);
    });

    test('should have valid light and dark schemes', () {
      expect(palette.lightScheme.brightness, Brightness.light);
      expect(palette.darkScheme.brightness, Brightness.dark);
    });
  });

  group('FluidPalette', () {
    const palette = FluidPalette();

    test('should have bright yellow primary in dark mode', () {
      expect(palette.darkScheme.primary, const Color(0xFFFDE047));
    });

    test('should support dark mode', () {
      expect(palette.supportsDarkMode, isTrue);
    });
  });

  group('MaterialYouPalette', () {
    const palette = MaterialYouPalette();

    test('should have MD3 purple primary', () {
      expect(palette.lightScheme.primary, const Color(0xFF6750A4));
    });

    test('should have proper container colors', () {
      expect(palette.lightScheme.primaryContainer, isNotNull);
      expect(palette.darkScheme.primaryContainer, isNotNull);
    });
  });

  group('FlatPalette', () {
    const palette = FlatPalette();

    test('should have blue primary', () {
      expect(palette.lightScheme.primary, const Color(0xFF3B82F6));
    });

    test('should support dark mode', () {
      expect(palette.supportsDarkMode, isTrue);
    });
  });

  group('HandDrawnPalette', () {
    const palette = HandDrawnPalette();

    test('should have warm paper surface', () {
      expect(palette.lightScheme.surface, const Color(0xFFFDFBF7));
    });

    test('should not support dark mode', () {
      expect(palette.supportsDarkMode, isFalse);
    });
  });

  group('EditorialPalette', () {
    const palette = EditorialPalette();

    test('should have coral accent', () {
      expect(palette.darkScheme.primary, const Color(0xFFFF6B50));
    });

    test('should have very dark background', () {
      expect(
        palette.darkScheme.surfaceContainerHighest,
        const Color(0xFF050505),
      );
    });
  });

  group('ZenPalette', () {
    const palette = ZenPalette();

    test('should have soft blue primary', () {
      expect(palette.darkScheme.primary, const Color(0xFF60A5FA));
    });

    test('should support dark mode', () {
      expect(palette.supportsDarkMode, isTrue);
    });
  });

  group('All palettes contrast check', () {
    final palettes = [
      const RetroPalette(),
      const GrungePalette(),
      const FluidPalette(),
      const MaterialYouPalette(),
      const FlatPalette(),
      const HandDrawnPalette(),
      const EditorialPalette(),
      const ZenPalette(),
    ];

    for (final palette in palettes) {
      test('${palette.runtimeType} light scheme should have valid brightness', () {
        expect(palette.lightScheme.brightness, Brightness.light);
      });

      if (palette.supportsDarkMode) {
        test('${palette.runtimeType} dark scheme should have valid brightness', () {
          expect(palette.darkScheme.brightness, Brightness.dark);
        });
      }
    }
  });
}
