import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/window_state_coercion.dart';

void main() {
  group('coerceWindowDimension', () {
    test('accepts finite numeric settings', () {
      expect(coerceWindowDimension(1200, fallback: 1600), 1200);
      expect(coerceWindowDimension(900.5, fallback: 1600), 900.5);
    });

    test('falls back for invalid settings', () {
      expect(coerceWindowDimension(null, fallback: 1600), 1600);
      expect(coerceWindowDimension('1200', fallback: 1600), 1600);
      expect(coerceWindowDimension(double.nan, fallback: 1600), 1600);
      expect(coerceWindowDimension(double.infinity, fallback: 1600), 1600);
    });
  });

  group('coerceWindowPosition', () {
    test('accepts finite numeric settings', () {
      expect(coerceWindowPosition(12), 12);
      expect(coerceWindowPosition(24.5), 24.5);
    });

    test('returns null for invalid optional settings', () {
      expect(coerceWindowPosition(null), isNull);
      expect(coerceWindowPosition('12'), isNull);
      expect(coerceWindowPosition(double.nan), isNull);
      expect(coerceWindowPosition(double.infinity), isNull);
    });
  });
}
