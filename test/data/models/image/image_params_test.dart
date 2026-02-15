import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';

void main() {
  group('ImageParams preciseReference getters', () {
    test('preciseReferenceCount should return 0 when no references', () {
      const params = ImageParams();

      expect(params.preciseReferences, isEmpty);
      expect(params.preciseReferenceCount, equals(0));
    });

    test('preciseReferenceCount should return 1 with single reference', () {
      final imageData = Uint8List.fromList([1, 2, 3]);
      final params = ImageParams(
        preciseReferences: [
          PreciseReference(
            image: imageData,
            type: PreciseRefType.character,
          ),
        ],
      );

      expect(params.preciseReferences.length, equals(1));
      expect(params.preciseReferenceCount, equals(1));
    });

    test(
        'preciseReferenceCount should return correct count with multiple references',
        () {
      final imageData = Uint8List.fromList([1, 2, 3]);
      final params = ImageParams(
        preciseReferences: [
          PreciseReference(
            image: imageData,
            type: PreciseRefType.character,
          ),
          PreciseReference(
            image: imageData,
            type: PreciseRefType.style,
          ),
          PreciseReference(
            image: imageData,
            type: PreciseRefType.characterAndStyle,
          ),
        ],
      );

      expect(params.preciseReferenceCount, equals(3));
    });

    test('preciseReferenceCost should return 0 when no references', () {
      const params = ImageParams();

      expect(params.preciseReferenceCost, equals(0));
    });

    test('preciseReferenceCost should return 5 with single reference', () {
      final imageData = Uint8List.fromList([1, 2, 3]);
      final params = ImageParams(
        preciseReferences: [
          PreciseReference(
            image: imageData,
            type: PreciseRefType.character,
          ),
        ],
      );

      expect(params.preciseReferenceCost, equals(5));
    });

    test(
        'preciseReferenceCost should return correct cost with multiple references',
        () {
      final imageData = Uint8List.fromList([1, 2, 3]);
      final params = ImageParams(
        preciseReferences: [
          PreciseReference(
            image: imageData,
            type: PreciseRefType.character,
          ),
          PreciseReference(
            image: imageData,
            type: PreciseRefType.style,
          ),
        ],
      );

      expect(params.preciseReferenceCost, equals(10));
    });

    test('preciseReferenceCost should be proportional to count', () {
      final imageData = Uint8List.fromList([1, 2, 3]);

      for (var count = 0; count <= 5; count++) {
        final references = List.generate(
          count,
          (_) => PreciseReference(
            image: imageData,
            type: PreciseRefType.character,
          ),
        );
        final params = ImageParams(preciseReferences: references);

        expect(params.preciseReferenceCount, equals(count));
        expect(params.preciseReferenceCost, equals(count * 5));
      }
    });

    test('hasPreciseReferences should be false when empty', () {
      const params = ImageParams();

      expect(params.hasPreciseReferences, isFalse);
    });

    test('hasPreciseReferences should be true when has references', () {
      final imageData = Uint8List.fromList([1, 2, 3]);
      final params = ImageParams(
        preciseReferences: [
          PreciseReference(
            image: imageData,
            type: PreciseRefType.character,
          ),
        ],
      );

      expect(params.hasPreciseReferences, isTrue);
    });

    test('cost calculation should work with all PreciseRefType values', () {
      final imageData = Uint8List.fromList([1, 2, 3]);

      for (final type in PreciseRefType.values) {
        final params = ImageParams(
          preciseReferences: [
            PreciseReference(
              image: imageData,
              type: type,
              strength: 0.5,
              fidelity: 0.5,
            ),
          ],
        );

        expect(params.preciseReferenceCount, equals(1));
        expect(params.preciseReferenceCost, equals(5));
      }
    });

    test('should handle adding references via copyWith', () {
      final imageData = Uint8List.fromList([1, 2, 3]);
      const params1 = ImageParams();

      expect(params1.preciseReferenceCount, equals(0));

      final params2 = params1.copyWith(
        preciseReferences: [
          PreciseReference(
            image: imageData,
            type: PreciseRefType.character,
          ),
        ],
      );

      expect(params2.preciseReferenceCount, equals(1));
      expect(params2.preciseReferenceCost, equals(5));
    });

    test('should handle clearing references', () {
      final imageData = Uint8List.fromList([1, 2, 3]);
      final params1 = ImageParams(
        preciseReferences: [
          PreciseReference(
            image: imageData,
            type: PreciseRefType.character,
          ),
        ],
      );

      expect(params1.preciseReferenceCount, equals(1));

      final params2 = params1.copyWith(preciseReferences: []);

      expect(params2.preciseReferenceCount, equals(0));
      expect(params2.preciseReferenceCost, equals(0));
      expect(params2.hasPreciseReferences, isFalse);
    });
  });
}
