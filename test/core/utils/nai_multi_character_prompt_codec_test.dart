import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/nai_multi_character_prompt_codec.dart';

void main() {
  group('NaiMultiCharacterPromptCodec', () {
    test('decodes NovelAI prompt chunks into base and characters', () {
      final result = NaiMultiCharacterPromptCodec.tryDecode(
        '2girls, outdoors\n\n| alice, blonde hair\n\n| bob, black hair',
      );

      expect(result, isNotNull);
      expect(result!.basePrompt, '2girls, outdoors');
      expect(result.characterPrompts, [
        'alice, blonde hair',
        'bob, black hair',
      ]);
    });

    test('accepts inline chunks and Discord code fences', () {
      final inline = NaiMultiCharacterPromptCodec.tryDecode(
        'scene | first character | second character',
      );
      final fenced = NaiMultiCharacterPromptCodec.tryDecode(
        '```text\nscene | character\n```',
      );

      expect(inline?.characterPrompts, ['first character', 'second character']);
      expect(fenced?.basePrompt, 'scene');
      expect(fenced?.characterPrompts, ['character']);
    });

    test('does not treat double pipes or incomplete chunks as characters', () {
      expect(NaiMultiCharacterPromptCodec.tryDecode('tag || other'), isNull);
      expect(NaiMultiCharacterPromptCodec.tryDecode('scene |  '), isNull);
      expect(NaiMultiCharacterPromptCodec.tryDecode('plain prompt'), isNull);
    });

    test('rejects more than six characters', () {
      expect(
        NaiMultiCharacterPromptCodec.tryDecode(
          'base | one | two | three | four | five | six | seven',
        ),
        isNull,
      );
    });

    test('supports a role-only prompt with an empty base chunk', () {
      expect(
        NaiMultiCharacterPromptCodec.tryDecode('| alice')?.characterPrompts,
        ['alice'],
      );
      expect(
        NaiMultiCharacterPromptCodec.encode(
          basePrompt: '',
          characterPrompts: const ['alice'],
        ),
        '| alice',
      );
    });

    test('encodes using NovelAI-compatible paragraph separators', () {
      expect(
        NaiMultiCharacterPromptCodec.encode(
          basePrompt: 'scene',
          characterPrompts: ['alice', '', 'bob'],
        ),
        'scene\n\n| alice\n\n| bob',
      );
    });
  });
}
