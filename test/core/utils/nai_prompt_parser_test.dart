import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/nai_prompt_parser.dart';

void main() {
  group('NaiPromptParser.splitSegments', () {
    test('keeps nested weighted syntax in one segment', () {
      expect(NaiPromptParser.splitSegments('{a, [b, (c, d)]}, tail'), [
        '{a, [b, (c, d)]}',
        'tail',
      ]);
    });

    test('handles unmatched delimiters without corrupting later depth', () {
      expect(NaiPromptParser.splitSegments('a}, b], c), d'), [
        'a}',
        'b]',
        'c)',
        'd',
      ]);
      expect(NaiPromptParser.splitSegments('{a, b, c'), ['{a, b, c']);
    });

    test('protects commas inside paired double pipes', () {
      expect(NaiPromptParser.splitSegments('||a, b||, c'), ['||a, b||', 'c']);
      expect(NaiPromptParser.splitSegments(r'\|\|a,b, c'), [
        r'\|\|a',
        'b',
        'c',
      ]);
    });

    test('escaped syntax characters do not split or change depth', () {
      expect(
        NaiPromptParser.splitSegments(
          r'a\,b, \{c\,d\}, \[e\,f\], \(g\,h\), i\|j',
        ),
        [r'a\,b', r'\{c\,d\}', r'\[e\,f\]', r'\(g\,h\)', r'i\|j'],
      );
    });

    test('continuous backslashes use odd-even escaping semantics', () {
      expect(NaiPromptParser.splitSegments(r'a\\,b'), [r'a\\', 'b']);
      expect(NaiPromptParser.splitSegments(r'a\\\,b, c'), [r'a\\\,b', 'c']);
    });
  });

  group('NaiPromptParser.containsFragment', () {
    test('matches complete consecutive fragments', () {
      expect(
        NaiPromptParser.containsFragment(
          'head, {{{masterpiece, best quality}}}, tail',
          '{{{masterpiece, best quality}}}',
        ),
        isTrue,
      );
      expect(
        NaiPromptParser.containsFragment('head, blue eyes, tail', 'blue eyes'),
        isTrue,
      );
    });

    test('does not match substrings or non-consecutive fragments', () {
      expect(
        NaiPromptParser.containsFragment('masterpiece portrait', 'masterpiece'),
        isFalse,
      );
      expect(NaiPromptParser.containsFragment('a, middle, b', 'a, b'), isFalse);
    });
  });
}
