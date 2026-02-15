import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';

void main() {
  group('PreciseRefType', () {
    const expectedValues = {
      PreciseRefType.character: ('character', 'preciseRef_typeCharacter'),
      PreciseRefType.style: ('style', 'preciseRef_typeStyle'),
      PreciseRefType.characterAndStyle: (
        'character&style',
        'preciseRef_typeCharacterAndStyle'
      ),
    };

    test('should have exactly three values', () {
      expect(PreciseRefType.values, hasLength(3));
    });

    test('all values should be present', () {
      for (final type in expectedValues.keys) {
        expect(PreciseRefType.values, contains(type));
      }
    });

    test('toApiString() should return correct values', () {
      for (final entry in expectedValues.entries) {
        expect(entry.key.toApiString(), equals(entry.value.$1));
      }
    });

    test('displayNameKey should return correct values', () {
      for (final entry in expectedValues.entries) {
        expect(entry.key.displayNameKey, equals(entry.value.$2));
      }
    });

    test('all API strings should be unique', () {
      final apiStrings =
          PreciseRefType.values.map((t) => t.toApiString()).toList();
      expect(apiStrings.toSet().length, equals(apiStrings.length));
    });

    test('enum values should be distinct', () {
      const values = PreciseRefType.values;
      for (var i = 0; i < values.length; i++) {
        for (var j = i + 1; j < values.length; j++) {
          expect(values[i], isNot(equals(values[j])));
          expect(values[i].hashCode, isNot(equals(values[j].hashCode)));
        }
      }
    });
  });
}
