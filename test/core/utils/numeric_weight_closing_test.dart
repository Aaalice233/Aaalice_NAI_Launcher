import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/nai_prompt_formatter.dart';
import 'package:nai_launcher/core/utils/numeric_weight_closing.dart';
import 'package:nai_launcher/core/utils/prompt_edit_document.dart';
import 'package:nai_launcher/core/utils/sd_to_nai_converter.dart';

void main() {
  group('NumericWeightClosing.endsAmbiguously', () {
    test(
      'digits, dots and dashes are read as a weight by the official parser',
      () {
        for (final content in [
          'year_2025',
          ':3',
          'ver1.5',
          '...',
          '-_-',
          '69',
        ]) {
          expect(
            NumericWeightClosing.endsAmbiguously(content),
            isTrue,
            reason: content,
          );
        }
      },
    );

    test('letters, brackets and existing whitespace are safe', () {
      for (final content in ['cat', 'year_2025 ', '{year_2025}', 'a\n', '']) {
        expect(
          NumericWeightClosing.endsAmbiguously(content),
          isFalse,
          reason: content,
        );
      }
    });

    test('trailing disabled tags are judged by what is actually sent', () {
      expect(
        NumericWeightClosing.endsAmbiguously(
          'cat, year_2025, /*disabled:dog*/',
        ),
        isTrue,
      );
      expect(
        NumericWeightClosing.endsAmbiguously(
          'year_2025, /*disabled:dog*/, cat',
        ),
        isFalse,
      );
      expect(
        NumericWeightClosing.endsAmbiguously('/*disabled:year_2025*/'),
        isFalse,
      );
    });
  });

  group('NumericWeightClosing.closingFor', () {
    test('separates only when enabled and the content is ambiguous', () {
      expect(
        NumericWeightClosing.closingFor('year_2025', separate: true),
        ' ::',
      );
      expect(
        NumericWeightClosing.closingFor('year_2025', separate: false),
        '::',
      );
      expect(NumericWeightClosing.closingFor('cat', separate: true), '::');
    });

    test('recognises a closing the user already separated', () {
      expect(
        NumericWeightClosing.hasSeparatedClosing('1.05::year_2025 ::'),
        isTrue,
      );
      expect(
        NumericWeightClosing.hasSeparatedClosing('/*disabled:1.05::a1 ::*/'),
        isTrue,
      );
      expect(
        NumericWeightClosing.hasSeparatedClosing('1.05::year_2025::'),
        isFalse,
      );
      expect(NumericWeightClosing.hasSeparatedClosing('year_2025'), isFalse);
    });
  });

  group('NumericWeightClosing.separate', () {
    test('the issue examples close before the number instead of opening', () {
      expect(
        NumericWeightClosing.separate('1.05::year_2025::, other_tags'),
        '1.05::year_2025 ::, other_tags',
      );
      expect(
        NumericWeightClosing.separate('1:::3::, 1girl, solo'),
        '1:::3 ::, 1girl, solo',
      );
    });

    test('every ambiguous closing in a prompt is separated once', () {
      const source =
          '1.2::a1::, 0.8::b2::, {1.1::...::}, 1.3::-_-::, 0.9::cat::';
      const expected =
          '1.2::a1 ::, 0.8::b2 ::, {1.1::... ::}, 1.3::-_- ::, 0.9::cat::';
      expect(NumericWeightClosing.separate(source), expected);
      expect(NumericWeightClosing.separate(expected), expected);
    });

    test('stacked and following openings are left as weights', () {
      for (final source in [
        '0.9::1.05::iu::::',
        '1.05::cat, 2::dog::',
        '1.05::cat,2::dog::',
        'year_2025::, foo',
        '1.05::year_2025 ::',
      ]) {
        expect(NumericWeightClosing.separate(source), source, reason: source);
      }
    });

    test('a disabled trailing tag keeps the sent prompt separated', () {
      const source = '1.2::cat, year_2025, /*disabled:dog*/::, bird';
      final separated = NumericWeightClosing.separate(source);
      expect(separated, '1.2::cat, year_2025, /*disabled:dog*/ ::, bird');
      expect(
        PromptEditDocument.effectiveText(separated),
        '1.2::cat, year_2025 ::, bird',
      );
    });

    test('disabled payloads and opaque literals are not rewritten', () {
      for (final source in [
        '/*disabled:1.2::year_2025::*/, cat',
        '"1.2::a1::", cat',
        '||1.2::a1::|b||',
      ]) {
        expect(NumericWeightClosing.separate(source), source, reason: source);
      }
    });
  });

  group('integration with existing prompt rewriting', () {
    test('auto format keeps the spaces around numeric weight boundaries', () {
      expect(
        NaiPromptFormatter.format('1.05::year_2025 ::, other tags'),
        '1.05::year_2025 ::, other_tags',
      );
      expect(NaiPromptFormatter.format('1.5:: rain ::'), '1.5:: rain ::');
      expect(NaiPromptFormatter.format('artist: foo bar'), 'artist:_foo_bar');
    });

    test('SD conversion separates its closings only when asked', () {
      const source = '(year 2025:1.2), (cat:0.8), (ver 1.5:1.1)';
      expect(
        SdToNaiConverter.convert(source),
        '1.2::year 2025::, 0.8::cat::, 1.1::ver 1.5::',
      );
      expect(
        SdToNaiConverter.convert(source, separateNumericWeightClosing: true),
        '1.2::year 2025 ::, 0.8::cat::, 1.1::ver 1.5 ::',
      );
    });
  });
}
