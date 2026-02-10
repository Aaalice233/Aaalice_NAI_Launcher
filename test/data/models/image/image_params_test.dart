import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';

void main() {
  group('ImageParams characterReference getters', () {
    test('characterReferenceCount should return 0 when no references', () {
      final params = ImageParams();

      expect(params.characterReferences, isEmpty);
      expect(params.characterReferenceCount, equals(0));
    });

    test('characterReferenceCount should return 1 with single reference', () {
      final imageData = Uint8List.fromList([1, 2, 3]);
      final params = ImageParams(
        characterReferences: [
          CharacterReference(
            image: imageData,
            type: PreciseRefType.character,
          ),
        ],
      );

      expect(params.characterReferences.length, equals(1));
      expect(params.characterReferenceCount, equals(1));
    });

    test('characterReferenceCount should return correct count with multiple references', () {
      final imageData = Uint8List.fromList([1, 2, 3]);
      final params = ImageParams(
        characterReferences: [
          CharacterReference(
            image: imageData,
            type: PreciseRefType.character,
          ),
          CharacterReference(
            image: imageData,
            type: PreciseRefType.style,
          ),
          CharacterReference(
            image: imageData,
            type: PreciseRefType.characterAndStyle,
          ),
        ],
      );

      expect(params.characterReferenceCount, equals(3));
    });

    test('characterReferenceCost should return 0 when no references', () {
      final params = ImageParams();

      expect(params.characterReferenceCost, equals(0));
    });

    test('characterReferenceCost should return 5 with single reference', () {
      final imageData = Uint8List.fromList([1, 2, 3]);
      final params = ImageParams(
        characterReferences: [
          CharacterReference(
            image: imageData,
            type: PreciseRefType.character,
          ),
        ],
      );

      expect(params.characterReferenceCost, equals(5));
    });

    test('characterReferenceCost should return correct cost with multiple references', () {
      final imageData = Uint8List.fromList([1, 2, 3]);
      final params = ImageParams(
        characterReferences: [
          CharacterReference(
            image: imageData,
            type: PreciseRefType.character,
          ),
          CharacterReference(
            image: imageData,
            type: PreciseRefType.style,
          ),
        ],
      );

      expect(params.characterReferenceCost, equals(10));
    });

    test('characterReferenceCost should be proportional to count', () {
      final imageData = Uint8List.fromList([1, 2, 3]);

      for (var count = 0; count <= 5; count++) {
        final references = List.generate(
          count,
          (_) => CharacterReference(
            image: imageData,
            type: PreciseRefType.character,
          ),
        );
        final params = ImageParams(characterReferences: references);

        expect(params.characterReferenceCount, equals(count));
        expect(params.characterReferenceCost, equals(count * 5));
      }
    });

    test('hasCharacterReferences should be false when empty', () {
      final params = ImageParams();

      expect(params.hasCharacterReferences, isFalse);
    });

    test('hasCharacterReferences should be true when has references', () {
      final imageData = Uint8List.fromList([1, 2, 3]);
      final params = ImageParams(
        characterReferences: [
          CharacterReference(
            image: imageData,
            type: PreciseRefType.character,
          ),
        ],
      );

      expect(params.hasCharacterReferences, isTrue);
    });

    test('cost calculation should work with all PreciseRefType values', () {
      final imageData = Uint8List.fromList([1, 2, 3]);

      for (final type in PreciseRefType.values) {
        final params = ImageParams(
          characterReferences: [
            CharacterReference(
              image: imageData,
              type: type,
              strength: 0.5,
              fidelity: 0.5,
            ),
          ],
        );

        expect(params.characterReferenceCount, equals(1));
        expect(params.characterReferenceCost, equals(5));
      }
    });

    test('should handle adding references via copyWith', () {
      final imageData = Uint8List.fromList([1, 2, 3]);
      final params1 = ImageParams();

      expect(params1.characterReferenceCount, equals(0));

      final params2 = params1.copyWith(
        characterReferences: [
          CharacterReference(
            image: imageData,
            type: PreciseRefType.character,
          ),
        ],
      );

      expect(params2.characterReferenceCount, equals(1));
      expect(params2.characterReferenceCost, equals(5));
    });

    test('should handle clearing references', () {
      final imageData = Uint8List.fromList([1, 2, 3]);
      final params1 = ImageParams(
        characterReferences: [
          CharacterReference(
            image: imageData,
            type: PreciseRefType.character,
          ),
        ],
      );

      expect(params1.characterReferenceCount, equals(1));

      final params2 = params1.copyWith(characterReferences: []);

      expect(params2.characterReferenceCount, equals(0));
      expect(params2.characterReferenceCost, equals(0));
      expect(params2.hasCharacterReferences, isFalse);
    });
  });
}
