import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';

void main() {
  group('PreciseReference', () {
    test('should create PreciseReference with default values', () {
      final imageData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final reference = PreciseReference(
        image: imageData,
        type: PreciseRefType.character,
      );

      expect(reference.image, equals(imageData));
      expect(reference.type, equals(PreciseRefType.character));
      expect(reference.strength, equals(1.0));
      expect(reference.fidelity, equals(1.0));
    });

    test('should create PreciseReference with custom values', () {
      final imageData = Uint8List.fromList([1, 2, 3]);
      final reference = PreciseReference(
        image: imageData,
        type: PreciseRefType.style,
        strength: 0.7,
        fidelity: 0.8,
      );

      expect(reference.image, equals(imageData));
      expect(reference.type, equals(PreciseRefType.style));
      expect(reference.strength, equals(0.7));
      expect(reference.fidelity, equals(0.8));
    });

    test('should create PreciseReference with characterAndStyle type', () {
      final imageData = Uint8List.fromList([10, 20, 30]);
      final reference = PreciseReference(
        image: imageData,
        type: PreciseRefType.characterAndStyle,
        strength: 0.5,
        fidelity: 0.6,
      );

      expect(reference.type, equals(PreciseRefType.characterAndStyle));
      expect(reference.strength, equals(0.5));
      expect(reference.fidelity, equals(0.6));
    });

    test('should support different strength values', () {
      final imageData = Uint8List.fromList([1, 2, 3]);

      final reference1 = PreciseReference(
        image: imageData,
        type: PreciseRefType.character,
        strength: 0.0,
      );
      expect(reference1.strength, equals(0.0));

      final reference2 = PreciseReference(
        image: imageData,
        type: PreciseRefType.character,
        strength: 1.0,
      );
      expect(reference2.strength, equals(1.0));

      final reference3 = PreciseReference(
        image: imageData,
        type: PreciseRefType.character,
        strength: 0.5,
      );
      expect(reference3.strength, equals(0.5));
    });

    test('should support different fidelity values', () {
      final imageData = Uint8List.fromList([1, 2, 3]);

      final reference1 = PreciseReference(
        image: imageData,
        type: PreciseRefType.character,
        fidelity: 0.0,
      );
      expect(reference1.fidelity, equals(0.0));

      final reference2 = PreciseReference(
        image: imageData,
        type: PreciseRefType.character,
        fidelity: 1.0,
      );
      expect(reference2.fidelity, equals(1.0));

      final reference3 = PreciseReference(
        image: imageData,
        type: PreciseRefType.character,
        fidelity: 0.75,
      );
      expect(reference3.fidelity, equals(0.75));
    });

    test('should have equality based on all fields', () {
      final imageData = Uint8List.fromList([1, 2, 3]);
      final imageData2 = Uint8List.fromList([1, 2, 3]);

      final reference1 = PreciseReference(
        image: imageData,
        type: PreciseRefType.character,
        strength: 0.7,
        fidelity: 0.8,
      );

      final reference2 = PreciseReference(
        image: imageData2,
        type: PreciseRefType.character,
        strength: 0.7,
        fidelity: 0.8,
      );

      expect(reference1, equals(reference2));
    });

    test('should have inequality when fields differ', () {
      final imageData = Uint8List.fromList([1, 2, 3]);

      final reference1 = PreciseReference(
        image: imageData,
        type: PreciseRefType.character,
        strength: 0.7,
        fidelity: 0.8,
      );

      final reference2 = PreciseReference(
        image: imageData,
        type: PreciseRefType.style,
        strength: 0.7,
        fidelity: 0.8,
      );

      final reference3 = PreciseReference(
        image: imageData,
        type: PreciseRefType.character,
        strength: 0.8,
        fidelity: 0.8,
      );

      final reference4 = PreciseReference(
        image: imageData,
        type: PreciseRefType.character,
        strength: 0.7,
        fidelity: 0.9,
      );

      expect(reference1, isNot(equals(reference2)));
      expect(reference1, isNot(equals(reference3)));
      expect(reference1, isNot(equals(reference4)));
    });

    test('should support copyWith to modify fields', () {
      final imageData = Uint8List.fromList([1, 2, 3]);
      final original = PreciseReference(
        image: imageData,
        type: PreciseRefType.character,
        strength: 0.7,
        fidelity: 0.8,
      );

      final modified = original.copyWith(
        type: PreciseRefType.style,
        strength: 0.9,
      );

      expect(modified.type, equals(PreciseRefType.style));
      expect(modified.strength, equals(0.9));
      expect(modified.fidelity, equals(0.8)); // unchanged
      expect(modified.image, equals(imageData)); // unchanged
    });

    test('should support all PreciseRefType values', () {
      final imageData = Uint8List.fromList([1, 2, 3]);

      for (final type in PreciseRefType.values) {
        final reference = PreciseReference(
          image: imageData,
          type: type,
        );
        expect(reference.type, equals(type));
      }
    });

    test('should handle empty image data', () {
      final emptyImage = Uint8List(0);
      final reference = PreciseReference(
        image: emptyImage,
        type: PreciseRefType.character,
      );

      expect(reference.image, isEmpty);
      expect(reference.image.length, equals(0));
    });

    test('should handle large image data', () {
      final largeImage = Uint8List(1024 * 1024); // 1MB of zeros
      final reference = PreciseReference(
        image: largeImage,
        type: PreciseRefType.characterAndStyle,
        strength: 0.5,
        fidelity: 0.5,
      );

      expect(reference.image.length, equals(1024 * 1024));
      expect(reference.type, equals(PreciseRefType.characterAndStyle));
    });
  });
}
