import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/save_naming/save_name_template.dart';

class _Values implements SaveNameValues {
  _Values(this.values, {this.characters = const []});

  final Map<SaveNameToken, String> values;

  @override
  final List<SaveNameCharacter> characters;

  @override
  String valueOf(SaveNameToken token) => values[token] ?? '';
}

String render(
  String template,
  Map<SaveNameToken, String> values, {
  List<SaveNameCharacter> characters = const [],
}) => SaveNameTemplate.parse(
  template,
).render(_Values(values, characters: characters));

SaveNameTemplateErrorKind? errorOf(String template) =>
    SaveNameTemplate.validate(template)?.kind;

void main() {
  group('parse', () {
    test('accepts every token and escaped braces', () {
      for (final token in SaveNameToken.values) {
        expect(SaveNameTemplate.validate('{${token.id}}'), isNull);
      }
      expect(render('{{seed}', {SaveNameToken.seed: '1'}), '{seed}');
      expect(render('a}b', const {}), 'a}b');
    });

    test('reports each syntax error with its subject', () {
      final unclosed = SaveNameTemplate.validate('ab{seed');
      expect(unclosed?.kind, SaveNameTemplateErrorKind.unclosedBrace);
      expect(unclosed?.position, 3);

      final unknown = SaveNameTemplate.validate('{sampler}');
      expect(unknown?.kind, SaveNameTemplateErrorKind.unknownToken);
      expect(unknown?.subject, 'sampler');

      expect(
        errorOf('{seed|reverse}'),
        SaveNameTemplateErrorKind.unknownFilter,
      );
      expect(
        errorOf('{prompt|max:2}'),
        SaveNameTemplateErrorKind.filterOnlyForCharacters,
      );
      expect(
        errorOf('{characters|pre:x|max:2}'),
        SaveNameTemplateErrorKind.characterFilterAfterTextFilter,
      );
      expect(
        errorOf('{seed|lower:1}'),
        SaveNameTemplateErrorKind.filterTakesNoValue,
      );
      expect(errorOf('{seed|pre}'), SaveNameTemplateErrorKind.filterNeedsValue);
      expect(
        errorOf('{seed|first:0}'),
        SaveNameTemplateErrorKind.filterNeedsPositiveNumber,
      );
      expect(
        errorOf('{seed|first:x}'),
        SaveNameTemplateErrorKind.filterNeedsPositiveNumber,
      );
      expect(
        errorOf('{prompt|tags:0}'),
        SaveNameTemplateErrorKind.filterNeedsNonZeroNumber,
      );
    });

    test('reports which fields a template reads', () {
      final template = SaveNameTemplate.parse('{date}/{resolution}_{seed}');
      expect(template.readsDate, isTrue);
      expect(template.readsDimensions, isTrue);
      expect(template.readsMetadata, isTrue);
      expect(SaveNameTemplate.parse('{time}-{index}').readsMetadata, isFalse);
    });
  });

  group('render', () {
    test('skips pre and suf around empty values', () {
      expect(
        render('{time}{seed|pre:-}', {SaveNameToken.time: '01-02-03'}),
        '01-02-03',
      );
      expect(
        render('{time}{seed|pre:-}', {
          SaveNameToken.time: '01-02-03',
          SaveNameToken.seed: '42',
        }),
        '01-02-03-42',
      );
      expect(render('{model|suf:_}x', const {}), 'x');
    });

    test(
      'limits the prompt to 80 code points unless a length filter is set',
      () {
        final prompt = List.filled(100, '字').join();
        expect(
          render('{prompt}', {SaveNameToken.prompt: prompt}).runes.length,
          80,
        );
        expect(
          render('{prompt|first:90}', {
            SaveNameToken.prompt: prompt,
          }).runes.length,
          90,
        );
      },
    );

    test('applies text filters from left to right', () {
      const values = {
        SaveNameToken.prompt: '1girl, solo, silver hair, blue eyes',
        SaveNameToken.seed: '7',
        SaveNameToken.model: 'Nai-Diffusion',
      };
      expect(render('{prompt|tags:2}', values), '1girl, solo');
      expect(render('{prompt|tags:-1}', values), 'blue eyes');
      expect(render('{prompt|words:3}', values), '1girl, solo, silver');
      expect(render('{prompt|words:-2}', values), 'blue eyes');
      expect(render('{prompt|first:5|upper}', values), '1GIRL');
      expect(render('{prompt|last:4}', values), 'eyes');
      expect(render('{seed|pad:4}', values), '0007');
      expect(render('{model|pad:4}', values), 'Nai-Diffusion');
      expect(render('{model|lower}', values), 'nai-diffusion');
    });

    test('names characters by their distinguishing tag', () {
      const characters = [
        SaveNameCharacter(prompt: '1girl, hatsune miku, twintails'),
        SaveNameCharacter(prompt: 'kagamine rin, short hair'),
        SaveNameCharacter(prompt: 'boy'),
        SaveNameCharacter(prompt: 'megurine luka'),
      ];
      expect(
        render('{characters}', const {}, characters: characters),
        'hatsune miku+kagamine rin+boy',
      );
      expect(
        render('{characters|max:5|join:_}', const {}, characters: characters),
        'hatsune miku_kagamine rin_boy_megurine luka',
      );
      expect(
        render('{characters|at:2|each:4}', const {}, characters: characters),
        'kaga',
      );
      expect(
        render('{characters|at:9|pre:x}', const {}, characters: characters),
        '',
      );
      expect(
        render(
          '{characters|at:1|full|upper}',
          const {},
          characters: characters,
        ),
        '1GIRL, HATSUNE MIKU, TWINTAILS',
      );
    });

    test('splits folders only on separators written in the template', () {
      final segments = SaveNameTemplate.parse('{model}/{date}\\x')
          .renderSegments(
            _Values({
              SaveNameToken.model: 'a/b',
              SaveNameToken.date: '2026-10-12',
            }),
          );
      expect(segments, ['a/b', '2026-10-12', 'x']);
      expect(
        SaveNameTemplate.parse(
          '{seed|pre:/}',
        ).renderSegments(_Values({SaveNameToken.seed: '5'})),
        ['/5'],
      );
    });
  });
}
