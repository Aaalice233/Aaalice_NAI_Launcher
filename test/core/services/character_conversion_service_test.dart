import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/character_conversion_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart'
    as ui_character;

void main() {
  group('CharacterPromptConfig.addCharacter', () {
    test('preserves the legacy default UC when no block was supplied', () {
      const config = ui_character.CharacterPromptConfig();

      final character = config
          .addCharacter(prompt: 'girl, blue eyes')
          .characters
          .single;

      expect(character.prompt, 'girl, blue eyes');
      expect(character.negativePrompt, 'lowres, aliasing, ');
    });

    test('stores an explicitly parsed independent UC', () {
      const config = ui_character.CharacterPromptConfig();

      final character = config
          .addCharacter(
            prompt: 'girl, blue eyes',
            negativePrompt: 'red hair, glasses',
          )
          .characters
          .single;

      expect(character.prompt, 'girl, blue eyes');
      expect(character.negativePrompt, 'red hair, glasses');
    });

    test('uses AI placement by default and custom only in manual layout', () {
      final automatic = const ui_character.CharacterPromptConfig()
          .addCharacter(prompt: 'girl')
          .characters
          .single;
      final manual = const ui_character.CharacterPromptConfig(
        globalAiChoice: false,
      ).addCharacter(prompt: 'girl').characters.single;

      expect(
        automatic.positionMode,
        ui_character.CharacterPositionMode.aiChoice,
      );
      expect(automatic.customPosition, isNull);
      expect(manual.positionMode, ui_character.CharacterPositionMode.custom);
      expect(manual.customPosition, isNotNull);
    });

    test('serializes AI/custom enums and defaults missing mode to AI', () {
      const automatic = ui_character.CharacterPrompt(
        id: 'automatic',
        name: 'Automatic',
      );
      const manual = ui_character.CharacterPrompt(
        id: 'manual',
        name: 'Manual',
        positionMode: ui_character.CharacterPositionMode.custom,
        customPosition: ui_character.CharacterPosition(
          mode: ui_character.CharacterPositionMode.custom,
          row: 0.25,
          column: 0.75,
        ),
      );

      final automaticJson =
          jsonDecode(jsonEncode(automatic)) as Map<String, dynamic>;
      final manualJson = jsonDecode(jsonEncode(manual)) as Map<String, dynamic>;
      expect(automaticJson['positionMode'], 'aiChoice');
      expect(manualJson['positionMode'], 'custom');
      final withoutMode = Map<String, dynamic>.from(automaticJson)
        ..remove('positionMode');
      expect(
        ui_character.CharacterPrompt.fromJson(withoutMode).positionMode,
        ui_character.CharacterPositionMode.aiChoice,
      );
      expect(ui_character.CharacterPrompt.fromJson(manualJson), manual);
    });
  });

  group('CharacterConversionService', () {
    test('custom mode resolves all six missing positions continuously', () {
      final characters = List<ui_character.CharacterPrompt>.generate(
        6,
        (index) => ui_character.CharacterPrompt(
          id: 'character-$index',
          name: 'Character ${index + 1}',
          prompt: 'character $index',
          negativePrompt: 'negative $index',
        ),
      );
      final config = ui_character.CharacterPromptConfig(
        characters: characters,
        globalAiChoice: false,
      );

      final result = CharacterConversionService().convert(config);

      expect(result.useCoords, isTrue);
      expect(result.characters, hasLength(6));
      for (final character in result.characters) {
        expect(character.positionX, isNotNull);
        expect(character.positionY, isNotNull);
        expect(character.positionX, inInclusiveRange(0.0, 1.0));
        expect(character.positionY, inInclusiveRange(0.0, 1.0));
      }
      expect(result.characters.first.positionX, 0.2);
      expect(result.characters.first.positionY, 0.25);
      expect(result.characters.last.positionX, 0.8);
      expect(result.characters.last.positionY, 0.75);
    });

    test('uses the shared clamped position and resolves aliases', () {
      const character = ui_character.CharacterPrompt(
        id: 'character',
        name: 'Character 1',
        prompt: 'alias',
        negativePrompt: 'negative alias',
        positionMode: ui_character.CharacterPositionMode.custom,
        customPosition: ui_character.CharacterPosition(
          mode: ui_character.CharacterPositionMode.custom,
          row: 1.5,
          column: -0.5,
        ),
      );
      const config = ui_character.CharacterPromptConfig(
        characters: [character],
        globalAiChoice: false,
      );

      final result = CharacterConversionService(
        aliasResolver: (text) => text.replaceAll('alias', 'resolved'),
      ).convert(config);

      expect(result.characters.single.prompt, 'resolved');
      expect(result.characters.single.negativePrompt, 'negative resolved');
      expect(result.characters.single.positionX, 0.0);
      expect(result.characters.single.positionY, 1.0);
      expect(result.aliasesResolved, isTrue);
    });

    test('maps a library negative block to independent character UC', () {
      const config = ui_character.CharacterPromptConfig(
        characters: [
          ui_character.CharacterPrompt(
            id: 'alice',
            name: 'Alice',
            prompt:
                r'girl, alice \(wonderland\), blue eyes, negative(red hair, glasses)',
            negativePrompt: '',
          ),
        ],
      );

      final result = CharacterConversionService().convert(config);
      final character = result.characters.single;

      expect(character.prompt, r'girl, alice \(wonderland\), blue eyes');
      expect(character.negativePrompt, 'red hair, glasses');
      expect(character.prompt, isNot(contains('negative(')));
      expect(character.negativePrompt, isNot(contains('negative(')));
    });

    test('splits negative syntax after resolving a library alias', () {
      const config = ui_character.CharacterPromptConfig(
        characters: [
          ui_character.CharacterPrompt(
            id: 'alice',
            name: 'Alice',
            prompt: '<alice>',
            negativePrompt: 'lowres',
          ),
        ],
      );

      final result = CharacterConversionService(
        aliasResolver: (text) => text == '<alice>'
            ? 'girl, blue eyes, negative(red hair, glasses)'
            : text,
      ).convert(config);
      final character = result.characters.single;

      expect(character.prompt, 'girl, blue eyes');
      expect(character.negativePrompt, 'red hair, glasses, lowres');
      expect(result.aliasesResolved, isTrue);
    });

    test('does not duplicate UC already projected from the same alias', () {
      const config = ui_character.CharacterPromptConfig(
        characters: [
          ui_character.CharacterPrompt(
            id: 'alice',
            name: 'Alice',
            prompt: '<alice>',
            negativePrompt: 'red hair, glasses',
          ),
        ],
      );

      final character = CharacterConversionService(
        aliasResolver: (text) =>
            text == '<alice>' ? 'girl, negative(red hair, glasses)' : text,
      ).convert(config).characters.single;

      expect(character.prompt, 'girl');
      expect(character.negativePrompt, 'red hair, glasses');
    });

    test('keeps negative-only characters in the API mapping', () {
      const config = ui_character.CharacterPromptConfig(
        characters: [
          ui_character.CharacterPrompt(
            id: 'negative-only',
            name: 'Negative only',
            prompt: 'negative(red hair)',
            negativePrompt: '',
          ),
        ],
      );

      final service = CharacterConversionService();
      final result = service.convert(config);

      expect(result.characters.single.prompt, isEmpty);
      expect(result.characters.single.negativePrompt, 'red hair');
      expect(service.hasEnabledCharacters(config), isTrue);
      expect(service.getEnabledCharacterCount(config), 1);
    });
  });
}
