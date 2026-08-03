import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/character_conversion_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart'
    as ui_character;

void main() {
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
  });
}
