/// Module Composition Integration Tests
///
/// Tests that verify different module combinations work correctly together.
/// Uses mock typography modules to avoid google_fonts runtime fetching issues.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/shape_module.dart';
import 'package:nai_launcher/presentation/themes/modules/shadow/shadow_module.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/effect_module.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/motion_module.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Module Composition', () {
    // Use mock typography to avoid google_fonts issues in tests
    const mockTypography = _MockTypographyModule();

    // Define test combinations with mock typography
    final combinations = <String, ThemeComposer>{
      'Retro + Snappy': ThemeComposer(
        color: const RetroPalette(),
        typography: mockTypography,
        shape: const StandardShapes(),
        shadow: const SoftShadow(),
        effect: const NoneEffect(),
        motion: const SnappyMotion(),
      ),
      'Grunge + Jitter + Texture': ThemeComposer(
        color: const GrungePalette(),
        typography: mockTypography,
        shape: const StandardShapes(),
        shadow: const HardOffsetShadow(),
        effect: const TextureEffect.grunge(),
        motion: const JitterMotion(),
      ),
      'Fluid + Glass': ThemeComposer(
        color: const FluidPalette(),
        typography: mockTypography,
        shape: const FluidShapes(),
        shadow: const SoftShadow(),
        effect: const GlassmorphismEffect(),
        motion: const ZenMotion(),
      ),
      'Material You + MD3 Motion': ThemeComposer(
        color: const MaterialYouPalette(),
        typography: mockTypography,
        shape: const PillShapes(),
        shadow: const SoftShadow(),
        effect: const NoneEffect(),
        motion: const MaterialMotion(),
      ),
      'Flat + None Shadow': ThemeComposer(
        color: const FlatPalette(),
        typography: mockTypography,
        shape: const SharpShapes(),
        shadow: const NoneShadow(),
        effect: const NoneEffect(),
        motion: const SnappyMotion(),
      ),
      'Hand-Drawn + Paper Texture': ThemeComposer(
        color: const HandDrawnPalette(),
        typography: mockTypography,
        shape: const WobblyShapes(),
        shadow: const HardOffsetShadow(),
        effect: const TextureEffect.paper(),
        motion: const JitterMotion(),
      ),
      'Editorial + Zen': ThemeComposer(
        color: const EditorialPalette(),
        typography: mockTypography,
        shape: const StandardShapes(),
        shadow: const SoftShadow(),
        effect: const NoneEffect(),
        motion: const ZenMotion(),
      ),
      'Zen + Minimal': ThemeComposer(
        color: const ZenPalette(),
        typography: mockTypography,
        shape: const StandardShapes(),
        shadow: const SoftShadow(),
        effect: const NoneEffect(),
        motion: const ZenMotion(),
      ),
      'Neon Cyberpunk': ThemeComposer(
        color: const FluidPalette(),
        typography: mockTypography,
        shape: const StandardShapes(),
        shadow: const GlowShadow(),
        effect: const NeonGlowEffect(),
        motion: const SnappyMotion(),
      ),
      'Mixed: Editorial Color + Hand-Drawn Typography': ThemeComposer(
        color: const EditorialPalette(),
        typography: mockTypography,
        shape: const PillShapes(),
        shadow: const NoneShadow(),
        effect: const GlassmorphismEffect(),
        motion: const MaterialMotion(),
      ),
    };

    for (final entry in combinations.entries) {
      group('Combination: ${entry.key}', () {
        final composer = entry.value;

        test('should build valid light ThemeData', () {
          final theme = composer.buildTheme(Brightness.light);
          expect(theme, isA<ThemeData>());
          expect(theme.brightness, Brightness.light);
          expect(theme.useMaterial3, isTrue);
        });

        test('should build valid dark ThemeData', () {
          final theme = composer.buildTheme(Brightness.dark);
          expect(theme, isA<ThemeData>());
          // Note: some themes don't support dark mode, will fallback to light
        });

        test('should build valid extension for light mode', () {
          final extension = composer.buildExtension(Brightness.light);
          expect(extension.isLightTheme, isTrue);
        });

        test('should build valid extension for dark mode', () {
          final extension = composer.buildExtension(Brightness.dark);
          expect(extension.isLightTheme, isFalse);
        });

        test('theme should have valid color scheme', () {
          final theme = composer.buildTheme(Brightness.light);
          expect(theme.colorScheme.primary, isNotNull);
          expect(theme.colorScheme.secondary, isNotNull);
          expect(theme.colorScheme.surface, isNotNull);
        });

        test('theme should have valid text theme', () {
          final theme = composer.buildTheme(Brightness.light);
          expect(theme.textTheme.displayLarge, isNotNull);
          expect(theme.textTheme.bodyMedium, isNotNull);
        });

        test('theme should have valid card theme', () {
          final theme = composer.buildTheme(Brightness.light);
          expect(theme.cardTheme.shape, isNotNull);
        });
      });
    }
  });

  group('Dark mode fallback', () {
    const mockTypography = _MockTypographyModule();

    test('light-only theme should handle dark mode request gracefully', () {
      final composer = ThemeComposer(
        color: const RetroPalette(), // Light only
        typography: mockTypography,
        shape: const StandardShapes(),
        shadow: const SoftShadow(),
        effect: const NoneEffect(),
        motion: const SnappyMotion(),
      );

      // Should not throw
      expect(() => composer.buildTheme(Brightness.dark), returnsNormally);
    });

    test('HandDrawnPalette dark mode should fallback to light colors', () {
      const palette = HandDrawnPalette();
      expect(palette.supportsDarkMode, isFalse);
      // Dark scheme should return same as light scheme
      expect(palette.darkScheme.surface, palette.lightScheme.surface);
    });
  });

  group('Effect propagation', () {
    const mockTypography = _MockTypographyModule();

    test('glassmorphism blur should be in extension', () {
      final composer = ThemeComposer(
        color: const FluidPalette(),
        typography: mockTypography,
        shape: const FluidShapes(),
        shadow: const SoftShadow(),
        effect: const GlassmorphismEffect(),
        motion: const ZenMotion(),
      );

      final extension = composer.buildExtension(Brightness.light);
      expect(extension.blurStrength, 12.0);
    });

    test('neon glow color should be in extension', () {
      final composer = ThemeComposer(
        color: const FluidPalette(),
        typography: mockTypography,
        shape: const StandardShapes(),
        shadow: const GlowShadow(),
        effect: const NeonGlowEffect(glowColor: Colors.cyan),
        motion: const SnappyMotion(),
      );

      final extension = composer.buildExtension(Brightness.dark);
      expect(extension.enableNeonGlow, isTrue);
      expect(extension.glowColor, Colors.cyan);
    });
  });
}

/// Mock typography module that doesn't use google_fonts
/// Uses default system fonts to avoid runtime fetching issues in tests
class _MockTypographyModule implements TypographyModule {
  const _MockTypographyModule();

  @override
  String get displayFontFamily => 'Roboto';

  @override
  String get bodyFontFamily => 'Roboto';

  @override
  TextTheme get textTheme => const TextTheme(
        displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400),
        displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
        displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400),
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      );
}
