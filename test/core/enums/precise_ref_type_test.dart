import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';

void main() {
  group('PreciseRefType', () {
    test('should have exactly three values', () {
      expect(PreciseRefType.values, hasLength(3));
    });

    test('should contain character value', () {
      expect(PreciseRefType.values, contains(PreciseRefType.character));
    });

    test('should contain style value', () {
      expect(PreciseRefType.values, contains(PreciseRefType.style));
    });

    test('should contain characterAndStyle value', () {
      expect(PreciseRefType.values, contains(PreciseRefType.characterAndStyle));
    });
  });

  group('PreciseRefTypeExtension.toApiString()', () {
    test('character should return "character"', () {
      expect(
        PreciseRefType.character.toApiString(),
        equals('character'),
      );
    });

    test('style should return "style"', () {
      expect(
        PreciseRefType.style.toApiString(),
        equals('style'),
      );
    });

    test('characterAndStyle should return "character&style"', () {
      expect(
        PreciseRefType.characterAndStyle.toApiString(),
        equals('character&style'),
      );
    });

    test('all values should have unique API strings', () {
      final apiStrings = PreciseRefType.values
          .map((type) => type.toApiString())
          .toList();
      final uniqueStrings = apiStrings.toSet();

      expect(uniqueStrings.length, equals(apiStrings.length));
    });
  });

  group('PreciseRefTypeExtension.displayName', () {
    test('character should return "Character"', () {
      expect(
        PreciseRefType.character.displayName,
        equals('Character'),
      );
    });

    test('style should return "Style"', () {
      expect(
        PreciseRefType.style.displayName,
        equals('Style'),
      );
    });

    test('characterAndStyle should return "Character & Style"', () {
      expect(
        PreciseRefType.characterAndStyle.displayName,
        equals('Character & Style'),
      );
    });

    test('all values should have unique display names', () {
      final displayNames = PreciseRefType.values
          .map((type) => type.displayName)
          .toList();
      final uniqueNames = displayNames.toSet();

      expect(uniqueNames.length, equals(displayNames.length));
    });
  });

  group('PreciseRefType enum index values', () {
    test('character should have index 0', () {
      expect(PreciseRefType.character.index, equals(0));
    });

    test('style should have index 1', () {
      expect(PreciseRefType.style.index, equals(1));
    });

    test('characterAndStyle should have index 2', () {
      expect(PreciseRefType.characterAndStyle.index, equals(2));
    });

    test('should be able to lookup by index', () {
      expect(PreciseRefType.values[0], equals(PreciseRefType.character));
      expect(PreciseRefType.values[1], equals(PreciseRefType.style));
      expect(PreciseRefType.values[2], equals(PreciseRefType.characterAndStyle));
    });
  });

  group('PreciseRefType name property', () {
    test('character should have name "character"', () {
      expect(PreciseRefType.character.name, equals('character'));
    });

    test('style should have name "style"', () {
      expect(PreciseRefType.style.name, equals('style'));
    });

    test('characterAndStyle should have name "characterAndStyle"', () {
      expect(PreciseRefType.characterAndStyle.name, equals('characterAndStyle'));
    });
  });

  group('PreciseRefType comparisons', () {
    test('character should not equal style', () {
      expect(PreciseRefType.character, isNot(equals(PreciseRefType.style)));
    });

    test('character should not equal characterAndStyle', () {
      expect(
        PreciseRefType.character,
        isNot(equals(PreciseRefType.characterAndStyle)),
      );
    });

    test('style should not equal characterAndStyle', () {
      expect(
        PreciseRefType.style,
        isNot(equals(PreciseRefType.characterAndStyle)),
      );
    });

    test('same values should be equal', () {
      expect(PreciseRefType.character, equals(PreciseRefType.character));
      expect(PreciseRefType.style, equals(PreciseRefType.style));
      expect(PreciseRefType.characterAndStyle, equals(PreciseRefType.characterAndStyle));
    });
  });

  group('PreciseRefType hashCode', () {
    test('same values should have same hashCode', () {
      expect(
        PreciseRefType.character.hashCode,
        equals(PreciseRefType.character.hashCode),
      );
    });

    test('different values should have different hashCodes', () {
      expect(
        PreciseRefType.character.hashCode,
        isNot(equals(PreciseRefType.style.hashCode)),
      );
    });
  });
}
