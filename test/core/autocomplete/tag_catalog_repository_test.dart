import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/completion_models.dart';
import 'package:nai_launcher/core/autocomplete/tag_catalog_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/sqlite3.dart' as native;

void main() {
  late Directory temp;
  late Database database;
  late TagCatalogRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    temp = await Directory.systemTemp.createTemp(
      'tag_catalog_repository_test_',
    );
    final path = p.join(temp.path, 'catalog.db');
    final db = native.sqlite3.open(path);
    db.execute('''
      CREATE TABLE metadata(key TEXT PRIMARY KEY, value TEXT);
      CREATE TABLE tags(id INTEGER PRIMARY KEY, name TEXT, category INTEGER, post_count INTEGER);
      CREATE TABLE aliases(id INTEGER PRIMARY KEY, tag_id INTEGER, alias TEXT);
      CREATE VIRTUAL TABLE tag_search USING fts5(term, search_key, tag_id UNINDEXED, kind UNINDEXED);
      INSERT INTO tags VALUES (1, 'blue_eyes', 0, 1000);
      INSERT INTO tags VALUES (2, 'blue_hair', 0, 2000);
      INSERT INTO tags VALUES (3, 'artist_blue', 1, 500);
      INSERT INTO aliases VALUES (1, 1, 'aqua_eyes');
      INSERT INTO tag_search VALUES ('blue_eyes', 'blue eyes', 1, 0);
      INSERT INTO tag_search VALUES ('aqua_eyes', 'aqua eyes', 1, 1);
      INSERT INTO tag_search VALUES ('blue_hair', 'blue hair', 2, 0);
      INSERT INTO tag_search VALUES ('artist_blue', 'artist blue', 3, 0);
      WITH RECURSIVE seq(i) AS (
        SELECT 1 UNION ALL SELECT i + 1 FROM seq WHERE i < 450
      )
      INSERT INTO tags
      SELECT 1000 + i, 'blue_archive_' || printf('%03d', i), 0, 500 - i
      FROM seq;
      INSERT INTO tag_search(term, search_key, tag_id, kind)
      SELECT name, replace(name, '_', ' '), id, 0 FROM tags WHERE id >= 1000;
    ''');
    db.dispose();
    database = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    repository = TagCatalogRepository(database: database);
  });

  tearDown(() async {
    await repository.dispose();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test(
    'searches canonical tags and aliases without loading the catalog',
    () async {
      final canonical = await repository.search(_query('blue'));
      final alias = await repository.search(_query('aqua'));

      expect(canonical.first.canonicalTag, 'blue_hair');
      expect(alias.single.canonicalTag, 'blue_eyes');
      expect(alias.single.matchedAlias, 'aqua_eyes');
      expect(alias.single.matchKind, CompletionMatchKind.aliasPrefix);
      expect(alias.single.aliases, ['aqua_eyes']);
    },
  );

  test('escapes special input and respects the result limit', () async {
    final special = await repository.search(_query('blue" OR *', limit: 1));
    final limited = await repository.search(_query('blue', limit: 1));

    expect(special, isA<List<CompletionCandidate>>());
    expect(limited, hasLength(1));
    expect(limited.single.canonicalTag, 'blue_hair');
  });

  test('returns exhaustive matches beyond the previous 300-row cap', () async {
    final results = await repository.search(
      _query('blue_archive', limit: CompletionResultLimits.all),
    );

    expect(results, hasLength(450));
    expect(results.first.canonicalTag, 'blue_archive_001');
    expect(results.last.canonicalTag, 'blue_archive_450');
  });
}

CompletionQuery _query(String token, {int limit = 20}) => CompletionQuery(
  fullText: token,
  cursorPosition: token.length,
  token: token,
  replacementRange: TextReplacementRange(start: 0, end: token.length),
  existingTags: const {},
  limit: limit,
  locale: 'en',
);
