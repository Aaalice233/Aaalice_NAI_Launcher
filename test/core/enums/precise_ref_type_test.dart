import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';

void main() {
  test('Hive indices remain fixed and costume is appended', () {
    expect(PreciseRefType.values, [
      PreciseRefType.character,
      PreciseRefType.style,
      PreciseRefType.characterAndStyle,
      PreciseRefType.costume,
    ]);
    expect(PreciseRefType.values.map((type) => type.index), [0, 1, 2, 3]);
    expect(
      PreciseRefType.selectable(outfit: false),
      PreciseRefType.values.take(3),
    );
    expect(PreciseRefType.selectable(outfit: true), PreciseRefType.values);
  });

  for (final outfit in [false, true]) {
    for (final preference in [null, false, true]) {
      for (final (type, expected) in [
        (
          PreciseRefType.character,
          outfit && preference == true ? 'character_mainoutfit' : 'character',
        ),
        (PreciseRefType.style, 'style'),
        (
          PreciseRefType.characterAndStyle,
          outfit && preference == false
              ? 'character&style_anyoutfit'
              : 'character&style',
        ),
        if (outfit) (PreciseRefType.costume, 'costume'),
      ]) {
        test('description $type outfit=$outfit preference=$preference', () {
          expect(
            preciseReferenceDescription(
              type,
              preferSameOutfit: preference,
              outfitSupported: outfit,
            ),
            expected,
          );
        });
      }
    }
  }

  test('unsupported costume violates the send-filter precondition', () {
    expect(
      () => preciseReferenceDescription(
        PreciseRefType.costume,
        outfitSupported: false,
      ),
      throwsAssertionError,
    );
  });

  for (final (value, type, preference) in [
    ('character', PreciseRefType.character, null),
    ('style', PreciseRefType.style, null),
    ('character&style', PreciseRefType.characterAndStyle, null),
    ('character_and_style', PreciseRefType.characterAndStyle, null),
    ('character and style', PreciseRefType.characterAndStyle, null),
    ('character&style_anyoutfit', PreciseRefType.characterAndStyle, false),
    ('character_mainoutfit', PreciseRefType.character, true),
    ('costume', PreciseRefType.costume, null),
    ('  CHARACTER_MAINOUTFIT  ', PreciseRefType.character, true),
    ('unknown', PreciseRefType.character, null),
    (null, PreciseRefType.character, null),
  ]) {
    test('parses description $value', () {
      expect(parsePreciseReferenceDescription(value), (
        type: type,
        preferSameOutfit: preference,
      ));
    });
  }

  test('localization keys cover all types', () {
    expect(PreciseRefType.values.map((type) => type.displayNameKey), [
      'preciseRef_typeCharacter',
      'preciseRef_typeStyle',
      'preciseRef_typeCharacterAndStyle',
      'preciseRef_typeOutfit',
    ]);
  });
}
