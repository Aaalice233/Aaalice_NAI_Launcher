import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/completion_models.dart';
import 'package:nai_launcher/core/autocomplete/prompt_token_parser.dart';

void main() {
  group('PromptTokenParser.parse', () {
    test('extracts the token under a cursor in the middle', () {
      final query = PromptTokenParser.parse(
        text: 'masterpiece, long hair, blue eyes',
        cursorPosition: 20,
        limit: 20,
        locale: 'en',
      );

      expect(query.token, 'long_hair');
      expect(
        query.fullText.substring(
          query.replacementRange.start,
          query.replacementRange.end,
        ),
        'long hair',
      );
      expect(query.existingTags, containsAll(['masterpiece', 'blue_eyes']));
    });

    test('preserves NovelAI braces and numeric weight suffixes', () {
      final braced = PromptTokenParser.parse(
        text: '{{long hair}}',
        cursorPosition: 7,
        limit: 20,
        locale: 'en',
      );
      final weighted = PromptTokenParser.parse(
        text: '(long hair:1.25)',
        cursorPosition: 6,
        limit: 20,
        locale: 'en',
      );

      expect(braced.token, 'long_hair');
      expect(weighted.token, 'long_hair');
      expect(
        PromptTokenParser.apply(
          text: braced.fullText,
          query: braced,
          canonicalTag: 'very_long_hair',
          autoInsertComma: true,
          replaceUnderscores: false,
        ).text,
        '{{very_long_hair}}, ',
      );
      expect(
        PromptTokenParser.apply(
          text: weighted.fullText,
          query: weighted,
          canonicalTag: 'very_long_hair',
          autoInsertComma: true,
          replaceUnderscores: false,
        ).text,
        '(very_long_hair:1.25), ',
      );
    });

    test('supports space-separated tag search when explicitly enabled', () {
      final query = PromptTokenParser.parse(
        text: 'foot_focus lo',
        cursorPosition: 13,
        limit: 20,
        locale: 'en',
        splitOnSpaces: true,
      );

      expect(query.token, 'lo');
      expect(query.existingTags, contains('foot_focus'));
      expect(query.replacementRange.start, 11);
    });

    test('supports Chinese input and requires explicit related-tag mode', () {
      final chinese = PromptTokenParser.parse(
        text: '杰作, 蓝色眼睛',
        cursorPosition: 8,
        limit: 20,
        locale: 'zh-CN',
      );
      final normal = PromptTokenParser.parse(
        text: 'blue_eyes,',
        cursorPosition: 10,
        limit: 20,
        locale: 'en',
      );
      final related = PromptTokenParser.parseRelated(
        text: 'blue_eyes,',
        cursorPosition: 10,
        limit: 20,
        locale: 'en',
      );

      expect(chinese.token, '蓝色眼睛');
      expect(chinese.isChinese, isTrue);
      expect(normal.token, isEmpty);
      expect(normal.relatedTag, isNull);
      expect(related?.relatedTag, 'blue_eyes');
    });

    test('detects and applies a tag library alias completion', () {
      final query = PromptTokenParser.parse(
        text: 'masterpiece, <角色',
        cursorPosition: 'masterpiece, <角色'.length,
        limit: 20,
        locale: 'zh-CN',
      );

      expect(query.kind, CompletionQueryKind.libraryAlias);
      expect(query.token, '角色');
      expect(
        query.fullText.substring(
          query.replacementRange.start,
          query.replacementRange.end,
        ),
        '<角色',
      );

      final result = PromptTokenParser.apply(
        text: query.fullText,
        query: query,
        canonicalTag: '角色立绘',
        autoInsertComma: true,
        replaceUnderscores: true,
      );
      expect(result.text, 'masterpiece, <角色立绘>, ');
      expect(result.cursorPosition, result.text.length);
    });

    test('replaces the closing bracket when completing inside an alias', () {
      final query = PromptTokenParser.parse(
        text: '<character preset>',
        cursorPosition: 5,
        limit: 20,
        locale: 'en',
      );
      final result = PromptTokenParser.apply(
        text: query.fullText,
        query: query,
        canonicalTag: 'character sheet',
        autoInsertComma: false,
        replaceUnderscores: false,
      );

      expect(query.kind, CompletionQueryKind.libraryAlias);
      expect(result.text, '<character sheet>');
    });

    test('does not duplicate an existing comma', () {
      final query = PromptTokenParser.parse(
        text: '{{long hair}}, next_tag',
        cursorPosition: 7,
        limit: 20,
        locale: 'en',
      );
      final result = PromptTokenParser.apply(
        text: query.fullText,
        query: query,
        canonicalTag: 'very_long_hair',
        autoInsertComma: true,
        replaceUnderscores: true,
      );

      expect(result.text, '{{very long hair}}, next_tag');
      expect(result.cursorPosition, '{{very long hair}}, '.length);
    });

    test(
      'creates a related insertion query without replacing weighted syntax',
      () {
        final query = PromptTokenParser.parseRelated(
          text: '{{blue_archive:1.2}}, solo',
          cursorPosition: 8,
          limit: 20,
          locale: 'en',
        );

        expect(query, isNotNull);
        expect(query!.relatedTag, 'blue_archive');
        expect(query.token, isEmpty);
        expect(query.replacementRange.start, '{{blue_archive:1.2}}, '.length);
        final result = PromptTokenParser.apply(
          text: query.fullText,
          query: query,
          canonicalTag: 'halo',
          autoInsertComma: true,
          replaceUnderscores: false,
        );
        expect(result.text, '{{blue_archive:1.2}}, halo, solo');
      },
    );

    test(
      'separates related insertion even when automatic trailing comma is off',
      () {
        final query = PromptTokenParser.parseRelated(
          text: 'blue_archive',
          cursorPosition: 5,
          limit: 20,
          locale: 'en',
        )!;
        final result = PromptTokenParser.apply(
          text: query.fullText,
          query: query,
          canonicalTag: 'halo',
          autoInsertComma: false,
          replaceUnderscores: false,
        );

        expect(result.text, 'blue_archive, halo');
        expect(result.cursorPosition, result.text.length);
      },
    );
  });
}
