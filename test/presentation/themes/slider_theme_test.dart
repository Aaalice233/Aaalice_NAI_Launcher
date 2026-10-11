import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nai_launcher/presentation/themes/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // testWidgets keeps the theme's async GoogleFonts loads inside FakeAsync, so
  // their offline failure cannot land after the test has completed.
  testWidgets('all app themes hide slider tick marks', (tester) async {
    for (final style in AppStyle.values) {
      for (final brightness in Brightness.values) {
        final theme = AppTheme.getTheme(style, brightness);

        expect(
          theme.sliderTheme.tickMarkShape,
          SliderTickMarkShape.noTickMark,
          reason: '${style.name} ${brightness.name}',
        );
      }
    }
  });
}
