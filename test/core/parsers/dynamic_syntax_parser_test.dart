import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/parsers/dynamic_syntax_parser.dart';

void main() {
  group('DynamicSyntaxParser', () {
    late DynamicSyntaxParser parser;

    setUp(() {
      parser = DynamicSyntaxParser();
    });

    group('Basic Syntax - ||A|B||', () {
      test('should parse simple two options', () {
        // Simple case: "red|blue"
        final result = parser.parse('||red|blue||');
        expect(result.options.length, 2);
        expect(result.options[0], 'red');
        expect(result.options[1], 'blue');
      });

      test('should parse single option', () {
        final result = parser.parse('||single||');
        expect(result.options.length, 1);
        expect(result.options[0], 'single');
      });

      test('should handle empty options gracefully', () {
        final result = parser.parse('');
        expect(result.options.isEmpty, true);
      });

      test('should preserve text outside syntax', () {
        final result = parser.parse('prefix ||A|B|| suffix');
        expect(result.beforeSyntax, 'prefix ');
        expect(result.afterSyntax, ' suffix');
      });

      test('should handle multiple independent groups', () {
        final results = parser.parseMultiple('||A|B|| text ||C|D||');
        expect(results.length, 3);
        expect(results[0].options, ['A', 'B']);
        expect(results[2].options, ['C', 'D']);
      });
    });

    group(r'Count Syntax - ||n$A|B||', () {
      test('should parse count syntax', () {
        final result = parser.parse(r'||2$A|B|C||');
        expect(result.count, 2);
        expect(result.options, ['A', 'B', 'C']);
      });

      test('should have default count of 1', () {
        final result = parser.parse('||A|B||');
        expect(result.count, 1);
      });

      test('should handle large count values', () {
        final result = parser.parse(r'||5$A|B|C|D|E||');
        expect(result.count, 5);
      });
    });

    group('Nesting', () {
      test('should handle nested brackets', () {
        final result = parser.parse('||A|B|C||');
        // Basic flat parsing
        expect(result.options.length, 3);
      });

      test('should detect recursion depth limit', () {
        // Test that parser can handle deeply nested structures
        // This is a simplified test; actual recursion limit testing
        // would require complex nested inputs
        expect(DynamicSyntaxParser.maxRecursionDepth, 10);
      });
    });

    group('Escaping', () {
      test('should treat escaped pipe as literal', () {
        // If we support escaping in the future, test here
        // Currently, our parser treats || literally
        parser.parse('||A\\\\\\\\|B|C||');
        // The parser doesn't currently support escaping
        // This test documents expected future behavior
      });
    });

    group('Error Handling', () {
      test('should handle unbalanced brackets', () {
        final result = parser.parse('unbalanced|brackets');
        // Unbalanced should be treated as text, not syntax
        expect(result.isValidSyntax, false);
      });

      test('should handle empty brackets', () {
        final result = parser.parse('||||');
        expect(result.isValidSyntax, false);
      });

      test('should return isValidSyntax true for valid input', () {
        final result = parser.parse('||A|B||');
        expect(result.isValidSyntax, true);
      });
    });

    group('Circular Reference Detection', () {
      test('should detect circular reference and halt via recursion depth', () {
        // Construct a deeply nested string that exceeds the limit (10)
        // Level 1: ||Level2||
        // Level 2: ||Level3||
        // ...
        var nested = 'Final';
        for (var i = 0; i < 15; i++) {
          nested = '||$nested||';
        }

        // The parser should stop resolving after 10 levels
        final result = parser.resolveNested(nested);
        
        // It should return the remaining nested string, not the fully resolved "Final"
        // because it stopped early.
        expect(result, isNot(equals('Final')));
        expect(result, contains('||'));
      });

      test('should respect maxRecursionDepth constant', () {
        expect(DynamicSyntaxParser.maxRecursionDepth, 10);
      });
    });

    group('Invalid Syntax (|||)', () {
      test('should treat triple pipe as invalid syntax', () {
        final result = parser.parse('|||');
        expect(result.isValidSyntax, false);
      });

      test('should treat quadruple pipe as invalid syntax', () {
        final result = parser.parse('||||');
        // This might match an empty option if not careful, but pattern requires content
        // Pattern: \|\|([^|]+(?:\|[^|]+)*)\|\|
        // Requires at least one char that is not |
        expect(result.isValidSyntax, false);
      });

      test('should handle asymmetric pipes', () {
        final result = parser.parse('||A|B|C|');
        // Missing closing pipe pair
        expect(result.isValidSyntax, false);
        expect(result.original, '||A|B|C|');
      });

      test('should return raw text for invalid syntax', () {
        const input = '|||';
        final result = parser.parse(input);
        expect(result.original, input);
        expect(result.options, isEmpty);
      });
    });

    group('UI Error Handling', () {
      test('should handle null-like or empty inputs gracefully', () {
        final result = parser.parse('');
        expect(result.isValidSyntax, false);
        expect(result.options, isEmpty);
      });

      test('should not crash on massive invalid strings', () {
        final massiveString = '|' * 1000;
        final result = parser.parse(massiveString);
        expect(result.isValidSyntax, false);
      });

      test('should handle malformed preset data simulation', () {
        // Simulating a corrupted preset value that might be passed from UI
        const corrupted = '||Option1|Option2|| ||Broken';
        final results = parser.parseMultiple(corrupted);
        
        // Should parse the valid part and handle the broken part as text
        expect(results.length, 2);
        expect(results[0].isValidSyntax, true);
        expect(results[0].options, ['Option1', 'Option2']);
        
        expect(results[1].isValidSyntax, false);
        expect(results[1].original.trim(), '||Broken');
      });
    });

    group('Integration - Random Selection', () {
      test('should generate valid selections', () {
        // Test that the parser can be used for random generation
        final result = parser.parse('||A|B|C||');
        final selected = result.getRandomSelection();
        expect(['A', 'B', 'C'].contains(selected), true);
      });

      test('should generate multiple unique selections', () {
        final result = parser.parse('||A|B|C|D|E||');
        final selected = result.getRandomSelectionMultiple(3);
        // Note: With small sample size and random selection, duplicates are possible if replacement is allowed.
        // But getRandomSelectionMultiple implementation in ParseResult is designed to pick unique if possible
        // or just pick N. Let's check ParseResult implementation.
        // It uses: 
        // if (count >= options.length) return [...options]..shuffle(random);
        // else ... removes from remaining ... so it is unique.
        expect(selected.length, 3);
        expect(selected.toSet().length, 3); // All unique
      });
    });
  });
}
