import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/kaomoji_tags.dart';
import 'package:nai_launcher/core/utils/nai_prompt_formatter.dart';
import 'package:nai_launcher/core/utils/novelai_auto_text.dart';
import 'package:nai_launcher/core/utils/prompt_edit_document.dart';

void main() {
  group('rendered text follows the web quote rule', () {
    String? sentBlock(String prompt) =>
        NovelAiAutoText.buildBlock(PromptEditDocument.effectiveText(prompt));

    const prompts = {
      '1.5::"Hello World"::': 'teXt: Hello World',
      'sign:"Hello World"': 'teXt: Hello World',
      "'Don't Stop'": "teXt: Don't Stop",
      '‘Don’t Stop’': 'teXt: Don’t Stop',
      "sign 'Hello World', girl's shirt": 'teXt: Hello World',
      'blue hair, “Hello World”, 「my_friend here」':
          'teXt: Hello World\n\nmy_friend here',
      'sign, "Hello World, my_friend"': 'teXt: Hello World, my_friend',
      'sign, /*disabled:"x*/ "Hello World"': 'teXt: Hello World',
    };

    for (final spaces in [false, true]) {
      for (final MapEntry(key: prompt, value: block) in prompts.entries) {
        test('spaces=$spaces keeps the text block of $prompt', () {
          expect(sentBlock(prompt), block);
          final formatted = NaiPromptFormatter.format(
            prompt,
            replaceUnderscores: spaces,
          );
          expect(sentBlock(formatted), block);
        });
      }
    }

    test('character prompts keep a quote spanning a mix separator', () {
      const prompt = 'girl, "LEFT | RIGHT"';
      final formatted = NaiPromptFormatter.format(prompt);
      expect(formatted, prompt);
      expect(
        NovelAiAutoText.buildBlock(
          'scene',
          characters: [NovelAiAutoTextCharacter(prompt: formatted)],
        ),
        'teXt: LEFT | RIGHT',
      );
    });
  });

  test(
    'manual rendered text stays opaque across disabled-looking fragments',
    () {
      const input = 'blue hair, text: A /*disabled:x_y*/ B C';
      expect(
        NaiPromptFormatter.format(input),
        'blue_hair, text: A /*disabled:x_y*/ B C',
      );
    },
  );

  test('manual text in one mix chunk does not disable formatting the next', () {
    expect(
      NaiPromptFormatter.format('blue hair, text: Hello World | red eyes'),
      'blue_hair, text: Hello World | red_eyes',
    );
    expect(
      NaiPromptFormatter.format('text: A ||x y|z w|| B | red eyes'),
      'text: A ||x y|z w|| B | red_eyes',
    );
  });

  test('spaces preference preserves syntax and opaque payloads', () {
    const input =
        'long hair， blue_eyes, negative(bad_hands), <my_alias>, '
        '"my_text here", /*disabled:red_hair*/';
    const expected =
        'long hair, blue eyes, negative(bad hands), <my_alias>, '
        '"my_text here", /*disabled:red_hair*/';
    final formatted = NaiPromptFormatter.format(
      input,
      replaceUnderscores: true,
    );
    expect(formatted, expected);
    expect(
      NaiPromptFormatter.format(formatted, replaceUnderscores: true),
      expected,
    );
  });

  test('spaces preference collapses repeated separators idempotently', () {
    final formatted = NaiPromptFormatter.format(
      'long__hair, _blue_eyes_',
      replaceUnderscores: true,
    );
    expect(formatted, 'long hair, blue eyes');
    expect(
      NaiPromptFormatter.format(formatted, replaceUnderscores: true),
      formatted,
    );
  });

  test('kaomoji keep their underscores in both styles', () {
    for (final kaomoji in KaomojiTags.values) {
      final prompt = 'smile, $kaomoji, {$kaomoji}, 1.2::$kaomoji::, long hair';
      expect(
        NaiPromptFormatter.format(prompt, replaceUnderscores: true),
        'smile, $kaomoji, {$kaomoji}, 1.2::$kaomoji::, long hair',
        reason: kaomoji,
      );
      expect(
        NaiPromptFormatter.format(prompt),
        'smile, $kaomoji, {$kaomoji}, 1.2::$kaomoji::, long_hair',
        reason: kaomoji,
      );
    }
  });

  test('literal masking cannot collide with user input', () {
    for (final spaces in [false, true]) {
      expect(
        NaiPromptFormatter.format(
          '\uE0000\uE001, "hello world"',
          replaceUnderscores: spaces,
        ),
        '\uE0000\uE001, "hello world"',
      );
      expect(
        NaiPromptFormatter.format(
          '\uE000\uE000"a b"\uE0001\uE001',
          replaceUnderscores: spaces,
        ),
        '\uE000\uE000"a b"\uE0001\uE001',
      );
    }
  });

  test('a space next to a quote keeps the quote boundary', () {
    expect(
      NaiPromptFormatter.format("sign 'Hello World'"),
      "sign 'Hello World'",
    );
    expect(
      NaiPromptFormatter.format('"Hello World" sign'),
      '"Hello World" sign',
    );
  });

  test('formatting preserves quoted text and comma-containing aliases', () {
    const source =
        'blue hair, "Hello  World, my_friend", <my alias, blue_eyes>';
    expect(
      NaiPromptFormatter.format(source),
      'blue_hair, "Hello  World, my_friend", <my alias, blue_eyes>',
    );
  });

  test('formatting preserves manual text rendering payload verbatim', () {
    const source = 'blue hair, text: Hello  World, my_friend\nnext line';
    expect(
      NaiPromptFormatter.format(source),
      'blue_hair, text: Hello  World, my_friend\nnext line',
    );
  });

  test('formatting preserves separators around consecutive disabled tags', () {
    const source = 'cat, /*disabled:long hair*/, /*disabled:blue eyes*/, dog';
    var formatted = source;
    for (var i = 0; i < 5; i++) {
      formatted = NaiPromptFormatter.format(formatted);
      expect(formatted, source);
    }
    expect(
      NaiPromptFormatter.format('/*disabled:cat*/, blue hair'),
      '/*disabled:cat*/, blue_hair',
    );
  });

  group('NaiPromptFormatter.format', () {
    test('格式化标签时保留换行、空行和行首缩进', () {
      const prompt = 'quality   tags， best quality,\n\n  blue hair, red eyes';

      expect(
        NaiPromptFormatter.format(prompt),
        'quality_tags, best_quality,\n\n  blue_hair, red_eyes',
      );
    });

    test('保留 CRLF 与各分组行末逗号', () {
      const prompt = 'subject tag,\r\nclothing tag,\r\nbackground tag';

      expect(
        NaiPromptFormatter.format(prompt),
        'subject_tag,\r\nclothing_tag,\r\nbackground_tag',
      );
    });

    test('纯空白分隔行保持原样', () {
      const prompt = 'first tag\n  \nsecond tag';

      expect(NaiPromptFormatter.format(prompt), 'first_tag\n  \nsecond_tag');
    });

    test('格式化正负标签但不破坏 negative 块边界', () {
      const prompt =
          r'girl, alice \(wonderland\), negative(red hair, 1.2::blue eyes::)';

      expect(
        NaiPromptFormatter.format(prompt),
        r'girl, alice_\(wonderland\), negative(red_hair, 1.2::blue_eyes::)',
      );
    });
  });
}
