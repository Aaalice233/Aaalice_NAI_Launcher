import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/novelai_auto_text.dart';

void main() {
  group('NovelAiAutoText.apply', () {
    test('matches the production V5 quoted Chinese transformation', () {
      expect(
        NovelAiAutoText.apply('chinese text, "圣女"'),
        'chinese text, "圣女", teXt: 圣女',
      );
    });

    test('supports every quote pair used by the web client', () {
      expect(
        NovelAiAutoText.apply(
          'signs "double", “curly”, 「corner」, \'single\', ‘curved’',
        ),
        'signs "double", “curly”, 「corner」, \'single\', ‘curved’, '
        'teXt: double\n\ncurly\n\ncorner\n\nsingle\n\ncurved',
      );
    });

    test('does not parse apostrophes inside words as quoted text', () {
      expect(
        NovelAiAutoText.apply("girl's shirt, 'HELLO'"),
        "girl's shirt, 'HELLO', teXt: HELLO",
      );
    });

    test('leaves prompts with a manual text block unchanged', () {
      for (final prompt in [
        'scene, Text: manual',
        'scene, text: manual',
        'scene, teXt: manual',
      ]) {
        expect(NovelAiAutoText.apply(prompt), prompt, reason: prompt);
      }

      expect(
        NovelAiAutoText.apply(
          'scene "base"',
          characters: const [
            NovelAiAutoTextCharacter(prompt: 'character, Text: manual'),
          ],
        ),
        'scene "base"',
      );
    });

    test('treats text:: as escaped ordinary prompt text', () {
      expect(
        NovelAiAutoText.apply('scene, text::escaped, "HELLO"'),
        'scene, text::escaped, "HELLO", teXt: HELLO',
      );
    });

    test('only modifies the first prompt-mix chunk', () {
      expect(
        NovelAiAutoText.apply('scene "FIRST" | alternate "SECOND"'),
        'scene "FIRST", teXt: FIRST| alternate "SECOND"',
      );
      expect(
        NovelAiAutoText.apply('scene ||red "A"|blue|| | alternate'),
        'scene ||red "A"|blue||, teXt: A| alternate',
      );
    });

    test('orders positioned character text in visual reading order', () {
      const characters = [
        NovelAiAutoTextCharacter(
          prompt: 'bottom "BOTTOM"',
          centerX: 0.2,
          centerY: 0.8,
        ),
        NovelAiAutoTextCharacter(
          prompt: 'top right "RIGHT"',
          centerX: 0.8,
          centerY: 0.2,
        ),
        NovelAiAutoTextCharacter(
          prompt: 'top left "LEFT"',
          centerX: 0.2,
          centerY: 0.2,
        ),
      ];

      expect(
        NovelAiAutoText.apply(
          'three characters',
          characters: characters,
          useCoords: true,
        ),
        'three characters, teXt: LEFT\n\nRIGHT\n\nBOTTOM',
      );
      expect(
        NovelAiAutoText.apply('three characters', characters: characters),
        'three characters, teXt: BOTTOM\n\nRIGHT\n\nLEFT',
      );
    });

    test('reverses quote order within each prompt for CJK text', () {
      expect(
        NovelAiAutoText.apply(
          'base "甲" then "乙"',
          characters: const [
            NovelAiAutoTextCharacter(prompt: 'character "丙" then "丁"'),
          ],
        ),
        'base "甲" then "乙", teXt: 乙\n\n甲\n\n丁\n\n丙',
      );
    });
  });

  group('NovelAiAutoText.stripGeneratedBlock', () {
    test('restores the user-facing quoted prompt', () {
      expect(
        NovelAiAutoText.stripGeneratedBlock('chinese text, "圣女", teXt: 圣女'),
        'chinese text, "圣女"',
      );
    });

    test('keeps manual or stale blocks verbatim', () {
      expect(
        NovelAiAutoText.stripGeneratedBlock('scene "A", Text: A'),
        'scene "A", Text: A',
      );
      expect(
        NovelAiAutoText.stripGeneratedBlock('scene "A", teXt: B'),
        'scene "A", teXt: B',
      );
    });

    test('round-trips positioned character text', () {
      const characters = [
        NovelAiAutoTextCharacter(
          prompt: 'right "RIGHT"',
          centerX: 0.8,
          centerY: 0.2,
        ),
        NovelAiAutoTextCharacter(
          prompt: 'left "LEFT"',
          centerX: 0.2,
          centerY: 0.2,
        ),
      ];
      const prompt = 'two characters';
      final effective = NovelAiAutoText.apply(
        prompt,
        characters: characters,
        useCoords: true,
      );

      expect(
        NovelAiAutoText.stripGeneratedBlock(
          effective,
          characters: characters,
          useCoords: true,
        ),
        prompt,
      );
    });
  });
}
