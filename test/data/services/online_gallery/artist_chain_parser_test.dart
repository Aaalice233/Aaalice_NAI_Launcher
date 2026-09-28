import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/online_gallery/artist_chain_parser.dart';

void main() {
  group('ArtistChainParser.parse', () {
    test('extracts plain tags in order and normalizes prefix spacing', () {
      final result = ArtistChainParser.parse(
        '1girl, Artist:  Foo_Bar, artist:山田 太郎\nartist:baz (artist)',
      );

      expect(
        result.formattedText,
        'artist:Foo_Bar, artist:山田 太郎, artist:baz (artist)',
      );
      expect(result.artistNames, ['Foo_Bar', '山田 太郎', 'baz (artist)']);
      expect(result.artistCount, 3);
      expect(result.rawFragments, [
        'Artist:  Foo_Bar',
        'artist:山田 太郎',
        'artist:baz (artist)',
      ]);
    });

    test('preserves brace, bracket and nested numeric weight semantics', () {
      final result = ArtistChainParser.parse(
        'foo, {{artist:alpha}}, [artist:beta], '
        '1.4::quality, artist:gamma, 0.7::artist:delta::, scenery::',
      );

      expect(
        result.formattedText,
        '{{artist:alpha}}, [artist:beta], '
        '1.4::artist:gamma, 0.7::artist:delta::::',
      );
      expect(result.artistNames, ['alpha', 'beta', 'gamma', 'delta']);
    });

    test('supports fractional and negative numeric weights', () {
      final result = ArtistChainParser.parse(
        '.5::artist:small::, -.5::artist:inverse::, 1.::artist:full::',
      );

      expect(
        result.formattedText,
        [
          '.5::artist:small::',
          '-.5::artist:inverse::',
          '1.::artist:full::',
        ].join(', '),
      );
      expect(result.artistNames, ['small', 'inverse', 'full']);
    });

    test('keeps a mixed group around only its extracted artist tags', () {
      final result = ArtistChainParser.parse(
        '2::blue archive, official art, artist:doremi, '
        'artist:yutokamizu::, best quality',
      );

      expect(result.formattedText, '2::artist:doremi, artist:yutokamizu::');
    });

    test('handles nested weighted groups and multilingual names', () {
      final result = ArtistChainParser.parse(
        '1.2::{artist: 山田_太郎, [artist: Иван (artist)]}::',
      );

      expect(
        result.formattedText,
        '1.2::{artist:山田_太郎, [artist:Иван (artist)]}::',
      );
      expect(result.artistNames, ['山田_太郎', 'Иван (artist)']);
    });

    test(
      'removes identical fragments but keeps differently weighted names',
      () {
        final result = ArtistChainParser.parse(
          'artist:foo, artist: foo, {artist:foo}, 1.2::artist:foo::',
        );

        expect(
          result.formattedText,
          'artist:foo, {artist:foo}, 1.2::artist:foo::',
        );
        expect(result.artistNames, ['foo']);
      },
    );

    test('rejects prose, collaboration prose and empty tags', () {
      final result = ArtistChainParser.parse(
        'by famous artist, artist collaboration, artist:, ARTIST:   , '
        'foo artist:bar, artist',
      );

      expect(result, same(ArtistChainExtraction.empty));
    });

    test('degrades an unclosed numeric weight at a safe item boundary', () {
      final result = ArtistChainParser.parse(
        '1.3::artist:first, scenery, artist:second, best quality',
      );

      expect(result.formattedText, 'artist:first, artist:second');
      expect(result.rawFragments, ['artist:first', 'artist:second']);
    });

    test(
      'degrades an unclosed emphasis wrapper without swallowing later tags',
      () {
        final result = ArtistChainParser.parse(
          '{artist:first, scenery, artist:second',
        );

        expect(result.formattedText, 'artist:first, artist:second');
      },
    );

    test('consumes stray closing delimiters and continues parsing', () {
      final result = ArtistChainParser.parse(
        'artist:first}, scenery, ] artist:second, artist:third]',
      );

      expect(result.formattedText, 'artist:first, artist:second, artist:third');
      expect(result.artistNames, ['first', 'second', 'third']);
      expect(ArtistChainParser.parse(']}').isEmpty, isTrue);
    });

    test('does not inspect a separately supplied negative prompt', () {
      const positive = '1girl, best quality';
      const negative = 'artist:negative_only';

      expect(ArtistChainParser.parse(positive).isEmpty, isTrue);
      expect(negative, contains('artist:'));
    });
  });

  group('ArtistChainParser.deduplicationKey', () {
    test('ignores casing and insignificant Prompt syntax spacing', () {
      final first = ArtistChainParser.parse(
        '1girl, 1.2::artist:Foo Bar::, {detailed eyes}',
      );
      final second = ArtistChainParser.parse(
        '  1GIRL , 1.2 :: ARTIST : foo bar :: , { detailed eyes } ',
      );

      expect(
        ArtistChainParser.deduplicationKey(
          '1girl, 1.2::artist:Foo Bar::, {detailed eyes}',
          first,
        ),
        ArtistChainParser.deduplicationKey(
          '  1GIRL , 1.2 :: ARTIST : foo bar :: , { detailed eyes } ',
          second,
        ),
      );
    });

    test('keeps different Prompts and artist weights distinct', () {
      final plain = ArtistChainParser.parse('1girl, artist:foo');
      final weighted = ArtistChainParser.parse('1girl, {artist:foo}');

      expect(
        ArtistChainParser.deduplicationKey('1girl, artist:foo', plain),
        isNot(
          ArtistChainParser.deduplicationKey('landscape, artist:foo', plain),
        ),
      );
      expect(
        ArtistChainParser.deduplicationKey('1girl, artist:foo', plain),
        isNot(
          ArtistChainParser.deduplicationKey('1girl, {artist:foo}', weighted),
        ),
      );
    });
  });

  group('ArtistChainParser.withArtistConstraint', () {
    test('adds the constraint without rewriting the original query', () {
      const query = '1girl blue hair';

      expect(
        ArtistChainParser.withArtistConstraint(query),
        '1girl blue hair artist:',
      );
      expect(query, '1girl blue hair');
    });

    test('uses only the constraint for an empty query', () {
      expect(ArtistChainParser.withArtistConstraint('  '), 'artist:');
    });

    test('does not duplicate an existing case-insensitive constraint', () {
      expect(
        ArtistChainParser.withArtistConstraint('1girl ARTIST:foo'),
        '1girl ARTIST:foo',
      );
      expect(
        ArtistChainParser.withArtistConstraint('1girl, artist: foo'),
        '1girl, artist: foo',
      );
      expect(
        ArtistChainParser.withArtistConstraint('1.2::artist:foo::'),
        '1.2::artist:foo::',
      );
    });
  });
}
