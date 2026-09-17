import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/request_builders/reference_strength_normalization.dart';

void main() {
  group('normalizeReferenceStrengths', () {
    test('scales every strength by the absolute sum once it exceeds one', () {
      const total = 0.6 + 0.7;

      expect(
        normalizeReferenceStrengths([0.6, 0.7], enabled: true),
        equals([0.6 / total, 0.7 / total]),
      );
    });

    test('keeps signs while summing absolute values', () {
      const total = 0.8 + 0.6;

      expect(
        normalizeReferenceStrengths([-0.8, 0.6], enabled: true),
        equals([-0.8 / total, 0.6 / total]),
      );
    });

    test('leaves strengths alone when the absolute sum stays within one', () {
      expect(
        normalizeReferenceStrengths([0.3, 0.5], enabled: true),
        equals([0.3, 0.5]),
      );
      expect(
        normalizeReferenceStrengths([0.5, 0.5], enabled: true),
        equals([0.5, 0.5]),
      );
      expect(
        normalizeReferenceStrengths([0.0, 0.0], enabled: true),
        equals([0.0, 0.0]),
      );
    });

    test('never scales a single strength', () {
      expect(
        normalizeReferenceStrengths([3.25], enabled: true),
        equals([3.25]),
      );
    });

    test('does nothing while disabled', () {
      expect(
        normalizeReferenceStrengths([0.6, 0.7], enabled: false),
        equals([0.6, 0.7]),
      );
    });

    test('returns an empty list untouched', () {
      expect(normalizeReferenceStrengths(const [], enabled: true), isEmpty);
    });
  });
}
