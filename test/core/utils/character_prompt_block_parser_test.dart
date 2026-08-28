import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/character_prompt_block_parser.dart';

void main() {
  group('CharacterPromptBlockParser', () {
    test('splits the approved syntax without changing escaped parentheses', () {
      const source =
          r'girl, alice \(wonderland\), blonde hair, blue eyes, negative(red hair, glasses, hat)';

      final result = CharacterPromptBlockParser.parse(source);

      expect(
        result.positivePrompt,
        r'girl, alice \(wonderland\), blonde hair, blue eyes',
      );
      expect(result.negativePrompt, 'red hair, glasses, hat');
      expect(result.blocks, hasLength(1));
      expect(result.issues, isEmpty);
    });

    test('supports nested and escaped parentheses inside the block', () {
      final result = CharacterPromptBlockParser.parse(
        r'girl, negative(red hair, smile \(evil\), (round face))',
      );

      expect(result.positivePrompt, 'girl');
      expect(result.negativePrompt, r'red hair, smile \(evil\), (round face)');
    });

    test('preserves NovelAI weight syntax in both prompt parts', () {
      final result = CharacterPromptBlockParser.parse(
        'girl, {blue eyes}, 1.2::smile::, '
        'negative([red hair], 0.8::glasses::)',
      );

      expect(result.positivePrompt, 'girl, {blue eyes}, 1.2::smile::');
      expect(result.negativePrompt, '[red hair], 0.8::glasses::');
    });

    test('recognizes a block between positive tags', () {
      final result = CharacterPromptBlockParser.parse(
        'girl, negative(red hair), blue eyes',
      );

      expect(result.positivePrompt, 'girl, blue eyes');
      expect(result.negativePrompt, 'red hair');
    });

    test('supports a negative-only entry', () {
      final result = CharacterPromptBlockParser.parse(
        'negative(red hair, glasses)',
      );

      expect(result.positivePrompt, isEmpty);
      expect(result.negativePrompt, 'red hair, glasses');
      expect(result.isValid, isTrue);
    });

    test('reports an empty block without losing its boundaries', () {
      final result = CharacterPromptBlockParser.parse('girl, negative(  )');

      expect(result.positivePrompt, 'girl');
      expect(result.negativePrompt, isEmpty);
      expect(result.blocks, hasLength(1));
      expect(result.issues, contains(CharacterPromptBlockIssue.emptyBlock));
    });

    test('reports an unclosed reserved block and keeps legacy text intact', () {
      const source = 'girl, negative(red hair, glasses';
      final result = CharacterPromptBlockParser.parse(source);

      expect(result.positivePrompt, source);
      expect(result.negativePrompt, isEmpty);
      expect(result.blocks, isEmpty);
      expect(result.issues, contains(CharacterPromptBlockIssue.unclosedBlock));
    });

    test('reports repeated blocks and safely removes every marker', () {
      final result = CharacterPromptBlockParser.parse(
        'girl, negative(red hair), negative(glasses)',
      );

      expect(result.positivePrompt, 'girl');
      expect(result.negativePrompt, 'red hair, glasses');
      expect(result.blocks, hasLength(2));
      expect(result.issues, contains(CharacterPromptBlockIssue.repeatedBlock));
    });

    test('does not reserve negative text outside a top-level tag boundary', () {
      for (final source in [
        'notnegative(red hair)',
        'some negative(red hair)',
        '{negative(red hair)}',
        '1.2::negative(red hair)::',
        'negative(red hair) suffix',
      ]) {
        final result = CharacterPromptBlockParser.parse(source);
        expect(result.hasNegativeBlock, isFalse, reason: source);
        expect(result.positivePrompt, source, reason: source);
      }
    });

    test('finds content context at the closing-caret boundary', () {
      const source = 'girl, negative(red hair)';
      final result = CharacterPromptBlockParser.parse(source);
      final close = source.lastIndexOf(')');

      expect(result.blockContaining(close, contentOnly: true), isNotNull);
      expect(result.blockContaining(close + 1, contentOnly: true), isNull);
    });

    test('composes separate character fields into one canonical block', () {
      final content = CharacterPromptBlockParser.compose(
        positivePrompt: 'girl, blue eyes',
        negativePrompt: 'red hair, glasses',
      );
      final parsed = CharacterPromptBlockParser.parse(content);

      expect(content, 'girl, blue eyes, negative(red hair, glasses)');
      expect(parsed.positivePrompt, 'girl, blue eyes');
      expect(parsed.negativePrompt, 'red hair, glasses');
      expect(parsed.blocks, hasLength(1));
    });

    test('compose canonicalizes an existing block without duplication', () {
      expect(
        CharacterPromptBlockParser.compose(
          positivePrompt: 'girl, negative(red hair)',
          negativePrompt: 'glasses',
        ),
        'girl, negative(red hair, glasses)',
      );
      expect(
        CharacterPromptBlockParser.compose(
          positivePrompt: '',
          negativePrompt: 'red hair',
        ),
        'negative(red hair)',
      );
    });
  });
}
