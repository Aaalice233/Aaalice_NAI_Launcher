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
      final unlabeledFence = NaiMultiCharacterPromptCodec.tryDecode(
        '```\nmasterpiece | character\n```',
      );

      expect(inline?.characterPrompts, ['first character', 'second character']);
      expect(fenced?.basePrompt, 'scene');
      expect(fenced?.characterPrompts, ['character']);
      expect(unlabeledFence?.basePrompt, 'masterpiece');
    });

    test('does not treat double pipes or incomplete chunks as characters', () {
      expect(NaiMultiCharacterPromptCodec.tryDecode('tag || other'), isNull);
      expect(NaiMultiCharacterPromptCodec.tryDecode('scene |  '), isNull);
      expect(NaiMultiCharacterPromptCodec.tryDecode('plain prompt'), isNull);
    });

    test('keeps pipes inside random choice blocks as options', () {
      expect(
        NaiMultiCharacterPromptCodec.tryDecode(
          'The scene shows a girl in a red sweater and blue shorts '
          '||standing|sitting|waving|jumping|crouching down|saluting|'
          'staring into the distance|| on the beach.',
        ),
        isNull,
      );

      final result = NaiMultiCharacterPromptCodec.tryDecode(
        'scene, ||day|night|| | alice, ||red|blue|| hair | bob',
      );
      expect(result?.basePrompt, 'scene, ||day|night||');
      expect(result?.characterPrompts, ['alice, ||red|blue|| hair', 'bob']);
    });

    test('pairs random block fences like the web client', () {
      expect(
        NaiMultiCharacterPromptCodec.tryDecode(
          'scene ||a|b||| alice',
        )?.characterPrompts,
        ['alice'],
      );
      expect(
        NaiMultiCharacterPromptCodec.tryDecode('scene || unclosed | alice'),
        isNull,
      );
    });

    test('round-trips inline exports that contain random blocks', () {
      final encoded = NaiMultiCharacterPromptCodec.encodeInline(
        basePrompt: 'scene, ||day|night||',
        characterPrompts: const ['alice, ||red|blue|| hair'],
      );
      final decoded = NaiMultiCharacterPromptCodec.tryDecode(encoded);

      expect(decoded?.basePrompt, 'scene, ||day|night||');
      expect(decoded?.characterPrompts, ['alice, ||red|blue|| hair']);
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
