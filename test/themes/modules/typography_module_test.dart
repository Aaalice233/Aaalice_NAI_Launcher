/// Typography Module Tests
///
/// Tests for typography module implementations.
/// Note: Tests that require actual font loading are skipped to avoid
/// google_fonts runtime fetching issues in CI/test environment.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/typography_module.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Typography Modules - Font Family Properties', () {
    // These tests don't trigger google_fonts because they only access
    // the displayFontFamily and bodyFontFamily string properties
    final modules = <String, TypographyModule>{
      'RetroTypography': const RetroTypography(),
      'GrungeTypography': const GrungeTypography(),
      'FluidTypography': const FluidTypography(),
      'MaterialTypography': const MaterialTypography(),
      'FlatTypography': const FlatTypography(),
      'HandDrawnTypography': const HandDrawnTypography(),
      'EditorialTypography': const EditorialTypography(),
      'ZenTypography': const ZenTypography(),
    };

    for (final entry in modules.entries) {
      group(entry.key, () {
        final module = entry.value;

        test('should have non-empty display font family', () {
          expect(module.displayFontFamily, isNotEmpty);
        });

        test('should have non-empty body font family', () {
          expect(module.bodyFontFamily, isNotEmpty);
        });
      });
    }
  });

  group('Font family assignments', () {
    test('RetroTypography uses Montserrat and Open Sans', () {
      const typography = RetroTypography();
      expect(typography.displayFontFamily, 'Montserrat');
      expect(typography.bodyFontFamily, 'Open Sans');
    });

    test('HandDrawnTypography uses Kalam and Patrick Hand', () {
      const typography = HandDrawnTypography();
      expect(typography.displayFontFamily, 'Kalam');
      expect(typography.bodyFontFamily, 'Patrick Hand');
    });

    test('ZenTypography uses Plus Jakarta Sans', () {
      const typography = ZenTypography();
      expect(typography.displayFontFamily, 'Plus Jakarta Sans');
      expect(typography.bodyFontFamily, 'Plus Jakarta Sans');
    });

    test('MaterialTypography uses Roboto', () {
      const typography = MaterialTypography();
      expect(typography.displayFontFamily, 'Roboto');
      expect(typography.bodyFontFamily, 'Roboto');
    });

    test('GrungeTypography uses Oswald and Courier Prime', () {
      const typography = GrungeTypography();
      expect(typography.displayFontFamily, 'Oswald');
      expect(typography.bodyFontFamily, 'Courier Prime');
    });

    test('FluidTypography uses Inter', () {
      const typography = FluidTypography();
      expect(typography.displayFontFamily, 'Inter');
      expect(typography.bodyFontFamily, 'Inter');
    });

    test('FlatTypography uses Outfit', () {
      const typography = FlatTypography();
      expect(typography.displayFontFamily, 'Outfit');
      expect(typography.bodyFontFamily, 'Outfit');
    });

    test('EditorialTypography uses Inter', () {
      const typography = EditorialTypography();
      expect(typography.displayFontFamily, 'Inter');
      expect(typography.bodyFontFamily, 'Inter');
    });
  });
}
