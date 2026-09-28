import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/online_gallery/gallery_tag_query.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';

void main() {
  group('GalleryTagQueryParser', () {
    test('counts positive and negative ordinary tags together', () {
      final query = GalleryTagQueryParser.parse(
        'cat_girl, blue-hair smile -watermark rating:safe order:score',
      );

      expect(query.isValid, isTrue);
      expect(query.ordinaryTagCount, 4);
      expect(query.ordinaryClauses.map((clause) => clause.value), [
        'cat_girl',
        'blue-hair',
        'smile',
        'watermark',
      ]);
      expect(query.negativeClauses.single.value, 'watermark');
      expect(query.metatags.map((clause) => clause.value), [
        'rating:safe',
        'order:score',
      ]);
    });

    test('rejects a seventh ordinary tag including negative tags', () {
      final query = GalleryTagQueryParser.parse(
        'a b c d e f rating:g -watermark',
      );

      expect(query.ordinaryTagCount, 7);
      expect(query.isValid, isFalse);
    });

    test('recognizes category, relationship, and source metatags', () {
      final query = GalleryTagQueryParser.parse(
        'cat tagcount:3 child:none has:source source:https://example.com sort:score:desc',
      );

      expect(query.ordinaryClauses.single.value, 'cat');
      expect(query.metatags.map((clause) => clause.value), [
        'tagcount:3',
        'child:none',
        'has:source',
        'source:https://example.com',
        'sort:score:desc',
      ]);
    });

    test('does not misclassify a legal colon tag as an unknown metatag', () {
      final query = GalleryTagQueryParser.parse('artist:name status:active');

      expect(query.ordinaryClauses.single.value, 'artist:name');
      expect(query.metatags.single.value, 'status:active');
    });
  });

  group('GalleryTagQueryPlanner', () {
    test('uses the rarest supported combination and filters the residual', () {
      final query = GalleryTagQueryParser.parse(
        'common rare medium extra -watermark rating:g',
      );
      final plan = GalleryTagQueryPlanner.plan(
        query,
        serverTagLimit: 2,
        postCounts: const {
          'common': 1000000,
          'rare': 10,
          'medium': 1000,
          'extra': 100,
          'watermark': 500000,
        },
      );

      expect(plan.seedClauses.map((clause) => clause.value), ['rare', 'extra']);
      expect(plan.serverQuery, 'rare extra rating:g');
      expect(plan.residualClauses.map((clause) => clause.value), [
        'common',
        'medium',
        'watermark',
      ]);
      expect(plan.matchesTags(['rare', 'extra', 'common', 'medium']), isTrue);
      expect(
        plan.matchesTags(['rare', 'extra', 'common', 'medium', 'watermark']),
        isFalse,
      );
    });

    test('canonicalizes aliases before planning and matching', () {
      final query = GalleryTagQueryParser.parse('kitty blue_hair');
      final canonical = query.canonicalized(const {'kitty': 'cat'});
      final plan = GalleryTagQueryPlanner.plan(
        canonical,
        serverTagLimit: 1,
        postCounts: const {'cat': 20, 'blue_hair': 100},
      );

      expect(plan.serverQuery, 'cat');
      expect(plan.matchesTags(['CAT', 'blue hair']), isTrue);
    });

    test('deduplicates aliases that resolve to the same canonical tag', () {
      final query = GalleryTagQueryParser.parse('kitty cat blue_hair');
      final canonical = query.canonicalized(const {'kitty': 'cat'});
      final plan = GalleryTagQueryPlanner.plan(canonical, serverTagLimit: 2);

      expect(canonical.ordinaryTagCount, 2);
      expect(plan.serverQuery.split(' '), containsAll(['cat', 'blue_hair']));
      expect(plan.requiresLocalFiltering, isFalse);
    });

    test(
      'keeps negative clauses local when a source cannot push them down',
      () {
        final plan = GalleryTagQueryPlanner.plan(
          GalleryTagQueryParser.parse('cat -watermark'),
          serverTagLimit: 1,
          allowNegativePushdown: false,
        );

        expect(plan.serverQuery, 'cat');
        expect(plan.residualClauses.map((clause) => clause.searchToken), [
          '-watermark',
        ]);
        expect(plan.matchesTags(['cat']), isTrue);
        expect(plan.matchesTags(['cat', 'watermark']), isFalse);
      },
    );

    test('supports fuzzy positive predicates without quadratic matching', () {
      const query = GalleryTagQuery(
        raw: 'hair smile',
        clauses: [
          GalleryTagClause(
            kind: GalleryTagClauseKind.positive,
            raw: 'hair',
            value: '*hair*',
          ),
          GalleryTagClause(
            kind: GalleryTagClauseKind.positive,
            raw: 'smile',
            value: 'smile',
          ),
        ],
      );
      final plan = GalleryTagQueryPlanner.plan(query, serverTagLimit: 1);

      expect(plan.matchesTags(['long_hair', 'smile']), isTrue);
      expect(plan.matchesTags(['long_hair']), isFalse);
    });
  });

  group('performance', () {
    test('compiled six-tag predicate scans 100k normalized works linearly', () {
      final plan = GalleryTagQueryPlanner.plan(
        GalleryTagQueryParser.parse('a b c d e -blocked'),
        serverTagLimit: 2,
      );
      final matching = <String>{'a', 'b', 'c', 'd', 'e'};
      final nonMatching = <String>{'a', 'b', 'c', 'd'};
      final stopwatch = Stopwatch()..start();
      var matches = 0;
      for (var index = 0; index < 100000; index++) {
        if (plan.matchesNormalizedTags(index.isEven ? matching : nonMatching)) {
          matches++;
        }
      }
      stopwatch.stop();

      expect(matches, 50000);
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 2)),
        reason: 'elapsed=${stopwatch.elapsedMicroseconds}µs',
      );
    });
  });

  group('source capability matrix', () {
    test('every source exposes a complete six-tag execution strategy', () {
      for (final source in GallerySourceId.values) {
        final capability = gallerySourceCapabilities[source]!.tagSearch;
        expect(capability.strategy, isNotNull, reason: source.key);
        expect(capability.anonymousLimit, inInclusiveRange(0, 6));
        expect(
          capability.listTagsComplete,
          source != GallerySourceId.aiTag,
          reason: source.key,
        );
      }
    });

    test('Danbooru follows anonymous, Basic, Gold and Platinum limits', () {
      final capability =
          gallerySourceCapabilities[GallerySourceId.danbooru]!.tagSearch;

      expect(capability.serverLimit(authenticated: false), 2);
      expect(capability.serverLimit(authenticated: true, accountLevel: 20), 2);
      expect(capability.serverLimit(authenticated: true, accountLevel: 30), 6);
      expect(capability.serverLimit(authenticated: true, accountLevel: 31), 6);
    });

    test('metatag and ranking query support is explicit per feed', () {
      final danbooru =
          gallerySourceCapabilities[GallerySourceId.danbooru]!.tagSearch;
      final aiTag = gallerySourceCapabilities[GallerySourceId.aiTag]!.tagSearch;

      expect(
        danbooru.metatagPrefixes(GalleryFeedKind.search),
        contains('order'),
      );
      expect(danbooru.metatagPrefixes(GalleryFeedKind.ranking), isEmpty);
      expect(danbooru.appliesOrdinaryQuery(GalleryFeedKind.ranking), isFalse);
      expect(aiTag.metatagPrefixes(GalleryFeedKind.search), isEmpty);
      expect(aiTag.appliesOrdinaryQuery(GalleryFeedKind.ranking), isTrue);
      expect(aiTag.validatesPushdownLocally, isTrue);
    });

    test('other source limits select their native or residual strategy', () {
      expect(
        gallerySourceCapabilities[GallerySourceId.safebooru]!.tagSearch
            .serverLimit(authenticated: false),
        2,
      );
      expect(
        gallerySourceCapabilities[GallerySourceId.gelbooru]!.tagSearch
            .serverLimit(authenticated: false),
        6,
      );
      expect(
        gallerySourceCapabilities[GallerySourceId.gelbooru]!.tagSearch
            .serverLimit(authenticated: true),
        6,
      );
      expect(
        gallerySourceCapabilities[GallerySourceId.aiTag]!.tagSearch.serverLimit(
          authenticated: false,
        ),
        6,
      );
      expect(
        gallerySourceCapabilities[GallerySourceId.quickTagCloud]!.tagSearch
            .serverLimit(authenticated: false),
        6,
      );
    });
  });
}
