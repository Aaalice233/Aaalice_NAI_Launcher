import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/cooccurrence_completion_source.dart';
import 'package:nai_launcher/core/autocomplete/completion_models.dart';
import 'package:nai_launcher/core/autocomplete/tag_catalog_repository.dart';
import 'package:nai_launcher/core/database/datasources/cooccurrence_data_source.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'enriches CSV intersections and ranks them by Jaccard similarity',
    () async {
      final dataSource = _FakeCooccurrenceDataSource([
        const RelatedTag(tag: 'long_hair', count: 193346),
        const RelatedTag(tag: 'halo', count: 221957),
        const RelatedTag(tag: 'solo', count: 170374),
      ]);
      final source = CooccurrenceCompletionSource(
        dataSource,
        catalog: _FakeCatalog({
          'blue_archive': const TagCatalogRecord(
            canonicalTag: 'blue_archive',
            category: TagCategory.copyright,
            postCount: 244929,
          ),
          'halo': const TagCatalogRecord(
            canonicalTag: 'halo',
            category: TagCategory.general,
            postCount: 265497,
          ),
          'long_hair': const TagCatalogRecord(
            canonicalTag: 'long_hair',
            category: TagCategory.general,
            postCount: 4350743,
          ),
          'solo': const TagCatalogRecord(
            canonicalTag: 'solo',
            category: TagCategory.meta,
            postCount: 5000954,
          ),
        }),
      );

      final results = await source.search(
        _query(existingTags: const {'blue_archive', 'solo'}),
      );

      expect(results.map((candidate) => candidate.canonicalTag), [
        'halo',
        'long_hair',
      ]);
      expect(results.first.category, TagCategory.general);
      expect(results.first.postCount, 265497);
      expect(results.first.cooccurrenceCount, 221957);
      expect(results.first.relatedScore, closeTo(0.769, 0.001));
      expect(results.first.sources, {CompletionSourceKind.cooccurrence});
      expect(dataSource.requestedLimit, CompletionResultLimits.maxRelatedTags);
    },
  );

  test(
    'bundled CSV database returns enriched blue_archive relations',
    () async {
      sqfliteFfiInit();
      final cooccurrenceDatabase = await databaseFactoryFfi.openDatabase(
        File('assets/databases/cooccurrence.db').absolute.path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      final catalogDatabase = await databaseFactoryFfi.openDatabase(
        File('assets/databases/tag_catalog.db').absolute.path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      final dataSource = CooccurrenceDataSource(database: cooccurrenceDatabase);
      final catalog = TagCatalogRepository(database: catalogDatabase);
      final source = CooccurrenceCompletionSource(dataSource, catalog: catalog);
      addTearDown(dataSource.dispose);
      addTearDown(catalog.dispose);

      final results = await source.search(_query(limit: 50));

      expect(results, hasLength(50));
      final halo = results.firstWhere(
        (candidate) => candidate.canonicalTag == 'halo',
      );
      expect(halo.relatedScore, greaterThan(0.7));
      expect(halo.cooccurrenceCount, greaterThan(200000));
      expect(halo.postCount, greaterThan(200000));

      // The source CSV stores unordered pairs once. `1girl,solo` has `solo`
      // in tag2 and was invisible when the datasource queried tag1 only.
      final soloRelations = await dataSource.getRelatedTags('solo', limit: 100);
      expect(soloRelations.map((relation) => relation.tag), contains('1girl'));
      expect(await dataSource.getRelatedTagCount('solo'), greaterThan(20000));
    },
  );

  test(
    'awaits the managed datasource instead of dropping related tags during startup',
    () async {
      final completer = Future<CooccurrenceDataSource>.delayed(
        const Duration(milliseconds: 1),
        () => _FakeCooccurrenceDataSource([
          const RelatedTag(tag: 'smile', count: 50),
        ]),
      );
      final source = CooccurrenceCompletionSource.withLoader(
        () => completer,
        catalog: _FakeCatalog({
          '1girl': const TagCatalogRecord(
            canonicalTag: '1girl',
            category: TagCategory.general,
            postCount: 1000,
          ),
          'smile': const TagCatalogRecord(
            canonicalTag: 'smile',
            category: TagCategory.general,
            postCount: 500,
          ),
        }),
      );

      final results = await source.search(
        _query(relatedTag: '1girl', limit: 20),
      );

      expect(results.single.canonicalTag, 'smile');
      expect(results.single.relatedScore, closeTo(50 / 1450, 0.0001));
    },
  );
}

CompletionQuery _query({
  String relatedTag = 'blue_archive',
  int limit = CompletionResultLimits.all,
  Set<String> existingTags = const {'blue_archive'},
}) => CompletionQuery(
  fullText: '$relatedTag, ',
  cursorPosition: relatedTag.length + 2,
  token: '',
  replacementRange: TextReplacementRange(
    start: relatedTag.length + 2,
    end: relatedTag.length + 2,
  ),
  existingTags: existingTags,
  limit: limit,
  locale: 'en',
  relatedTag: relatedTag,
);

class _FakeCooccurrenceDataSource extends CooccurrenceDataSource {
  _FakeCooccurrenceDataSource(this.rows);

  final List<RelatedTag> rows;
  int? requestedLimit;

  @override
  Future<List<RelatedTag>> getRelatedTags(
    String tag, {
    int limit = 20,
    int minCount = 1,
  }) async {
    requestedLimit = limit;
    return rows.take(limit).toList(growable: false);
  }
}

class _FakeCatalog extends TagCatalogRepository {
  _FakeCatalog(this.records);

  final Map<String, TagCatalogRecord> records;

  @override
  Future<Map<String, TagCatalogRecord>> recordsByCanonicalTag(
    Iterable<String> canonicalTags,
  ) async => {
    for (final tag in canonicalTags)
      if (records[tag] case final record?) tag: record,
  };
}
