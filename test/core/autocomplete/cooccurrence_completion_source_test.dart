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

  test('compact database returns stable bidirectional relations', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp(
      'cooccurrence_data_source_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = File('${directory.path}/cooccurrence-v2.db').path;
    final writer = await databaseFactoryFfi.openDatabase(path);
    await writer.execute('''
        CREATE TABLE metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE tags(
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL COLLATE NOCASE UNIQUE
        );
        CREATE TABLE edges(
          source_tag_id INTEGER NOT NULL,
          target_tag_id INTEGER NOT NULL,
          count INTEGER NOT NULL CHECK(count > 0),
          PRIMARY KEY(source_tag_id, count DESC, target_tag_id)
        ) WITHOUT ROWID;
        INSERT INTO metadata VALUES ('source_pair_count', '2');
        INSERT INTO tags VALUES (1, 'alpha'), (2, 'beta'), (3, 'gamma');
        INSERT INTO edges VALUES
          (1, 2, 50), (2, 1, 50), (1, 3, 10), (3, 1, 10);
      ''');
    await writer.close();
    final database = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    final dataSource = CooccurrenceDataSource(database: database);
    addTearDown(dataSource.dispose);

    final alpha = await dataSource.getRelatedTags('ALPHA', limit: 10);
    expect(alpha.map((relation) => relation.tag), ['beta', 'gamma']);
    expect(alpha.map((relation) => relation.count), [50, 10]);
    expect(
      (await dataSource.getRelatedTags('beta', limit: 10)).single.tag,
      'alpha',
    );
    expect(await dataSource.getRelatedTagCount('alpha'), 2);
    expect(await dataSource.getCount(), 2);
    expect(
      await dataSource.calculateCooccurrenceScore('alpha', 'beta'),
      closeTo(50 / 60, 0.0001),
    );
  });

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
