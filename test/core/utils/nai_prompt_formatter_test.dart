import 'package:nai_launcher/core/utils/novelai_auto_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/nai_prompt_formatter.dart';

void main() {
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
    const input = 'blue hair, text: Hello World | red eyes';
    expect(
      NaiPromptFormatter.format(input),
      'blue_hair, text: Hello World | red_eyes',
    );
  });

  test('spaces preference preserves syntax and opaque payloads', () {
    const input =
        'long hair， blue_eyes, negative(bad_hands), <my_alias>, "my_text here", /*disabled:red_hair*/';
    const expected =
        'long hair, blue eyes, negative(bad hands), <my_alias>, "my_text here", /*disabled:red_hair*/';
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

  test('formatting leaves V5 rendered words unchanged', () {
    for (final spaces in [false, true]) {
      final formatted = NaiPromptFormatter.format(
        'sign, "Hello World, my_friend"',
        replaceUnderscores: spaces,
      );
      expect(
        NovelAiAutoText.buildBlock(formatted),
        'teXt: Hello World, my_friend',
      );
    }
  });

  test('literal masking cannot collide with user input', () {
    expect(
      NaiPromptFormatter.format('\uE0000\uE001, "hello world"'),
      '\uE0000\uE001, "hello world"',
    );
  });

  test('adjacent quoted words retain the quote boundary', () {
    expect(
      NaiPromptFormatter.format("sign 'Hello World'"),
      "sign 'Hello World'",
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

  test('formatting preserves V5 typographic quotes', () {
    expect(
      NaiPromptFormatter.format('blue hair, “Hello World”, 「my_friend」'),
      'blue_hair, “Hello World”, 「my_friend」',
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
