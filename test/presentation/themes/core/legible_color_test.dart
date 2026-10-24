import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/core/legible_color.dart';

void main() {
  test('contrastRatio follows the WCAG relative luminance formula', () {
    expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.001));
    expect(contrastRatio(Colors.white, Colors.black), closeTo(21, 0.001));
    expect(contrastRatio(Colors.red, Colors.red), closeTo(1, 0.001));
  });

  test('keeps an already legible foreground untouched', () {
    const foreground = Color(0xFF1A237E);
    const background = Color(0xFFFFFDF5);

    expect(legibleForeground(foreground, background), foreground);
  });

  test('applies the smallest tonal correction on light and dark surfaces', () {
    for (final (foreground, background) in const [
      (Color(0xFFFCD758), Color(0xFFFFFDF5)),
      (Color(0xFFF59E0B), Color(0xFFF8FAFC)),
      (Color(0xFF1E293B), Color(0xFF0F172A)),
    ]) {
      final corrected = legibleForeground(foreground, background);
      final ratio = contrastRatio(corrected, background);

      expect(ratio, greaterThanOrEqualTo(minimumTextContrast));
      expect(ratio, lessThan(minimumTextContrast + 0.1));
    }
  });

  test('measures translucent foregrounds as painted on the background', () {
    const background = Color(0xFFFFFFFF);
    final corrected = legibleForeground(
      Colors.black.withValues(alpha: 0.2),
      background,
    );

    expect(corrected.a, 1);
    expect(
      contrastRatio(corrected, background),
      greaterThanOrEqualTo(minimumTextContrast),
    );
  });
}
