import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/local/random_tag_library_data_source.dart';
import 'package:nai_launcher/data/models/prompt/weighted_tag.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/sqlite3.dart' as native;

void main() {
  late Directory temp;
  late String databasePath;

  setUp(() async {
    sqfliteFfiInit();
    temp = await Directory.systemTemp.createTemp('random_tag_library_test_');
    databasePath = p.join(temp.path, 'catalog.db');
    final database = native.sqlite3.open(databasePath);
    database.execute('''
      CREATE TABLE metadata(key TEXT PRIMARY KEY, value TEXT);
      CREATE TABLE tags(
        id INTEGER PRIMARY KEY,
        name TEXT,
        category INTEGER,
        post_count INTEGER
      );
      INSERT INTO metadata VALUES ('data_version', 'test-v1');
      INSERT INTO metadata VALUES ('source_commit', 'abc123');
      INSERT INTO metadata VALUES ('source_sha256', 'deadbeef');
      INSERT INTO metadata VALUES ('tag_count', '4');
      INSERT INTO metadata VALUES ('alias_count', '1');
      INSERT INTO tags VALUES (1, 'blue_eyes', 0, 1000);
      INSERT INTO tags VALUES (2, 'red_eyes', 0, 100);
      INSERT INTO tags VALUES (3, 'blue_eyeshadow', 0, 5000);
      INSERT INTO tags VALUES (4, 'artist_eyes', 1, 9000);
    ''');
    database.dispose();
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test(
    'validates provenance and resolves complete deterministic categories',
    () async {
      final source = RandomTagLibraryDataSource(
        assetBundle: _StringAssetBundle(_manifest()),
        openDatabase: () => databaseFactoryFfi.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
        ),
      );

      final first = await source.loadData();
      final second = await source.loadData();

      expect(identical(first, second), isTrue);
      expect(first.manifest.dataVersion, 'test-v1');
      expect(first.categories['eyes']!.map((tag) => tag.tag), [
        'blue eyes',
        'red eyes',
      ]);
      expect(
        first.categories['eyes']!.every(
          (tag) => tag.source == TagSource.catalog && tag.weight > 0,
        ),
        isTrue,
      );
    },
  );

  test('coalesces concurrent loads into one database read', () async {
    final gate = Completer<void>();
    var openCount = 0;
    final source = RandomTagLibraryDataSource(
      assetBundle: _StringAssetBundle(_manifest()),
      openDatabase: () async {
        openCount++;
        await gate.future;
        return databaseFactoryFfi.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
        );
      },
    );

    final first = source.loadData();
    final second = source.loadData();
    expect(identical(first, second), isTrue);

    gate.complete();
    expect(identical(await first, await second), isTrue);
    expect(openCount, 1);
  });

  test('clearCache cancels a stale in-flight load', () async {
    final gate = Completer<void>();
    var openCount = 0;
    final source = RandomTagLibraryDataSource(
      assetBundle: _StringAssetBundle(_manifest()),
      openDatabase: () async {
        openCount++;
        if (openCount == 1) await gate.future;
        return databaseFactoryFfi.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
        );
      },
    );

    final staleLoad = source.loadData();
    await Future<void>.delayed(Duration.zero);
    source.clearCache();
    gate.complete();

    await expectLater(staleLoad, throwsA(isA<RandomTagLibraryLoadCancelled>()));
    expect((await source.loadData()).totalTagCount, 2);
    expect(openCount, 2);
  });

  test('clearCache forces a fresh validated database read', () async {
    var openCount = 0;
    final source = RandomTagLibraryDataSource(
      assetBundle: _StringAssetBundle(_manifest()),
      openDatabase: () {
        openCount++;
        return databaseFactoryFfi.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
        );
      },
    );

    await source.loadData();
    source.clearCache();
    await source.loadData();

    expect(openCount, 2);
  });

  test('rejects a catalog whose locked metadata does not match', () async {
    final source = RandomTagLibraryDataSource(
      assetBundle: _StringAssetBundle(_manifest(commit: 'wrong')),
      openDatabase: () => databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      ),
    );

    await expectLater(source.loadData(), throwsStateError);
  });
}

String _manifest({String commit = 'abc123'}) => jsonEncode({
  'schemaVersion': 1,
  'libraryId': 'catalog-random-tags',
  'libraryName': 'Catalog Random Tags',
  'dataVersion': 'test-v1',
  'source': {
    'name': 'Test catalog',
    'url': 'https://example.com/catalog.csv',
    'commit': commit,
    'versionDate': '2026-01-01',
    'sha256': 'deadbeef',
    'license': 'Unlicense',
    'catalogTagCount': 4,
    'catalogAliasCount': 1,
  },
  'categories': {
    'eyes': {
      'name': 'Eyes',
      'includeGlobs': ['*_eyes'],
      'includeTokens': ['eyes'],
      'excludeTokens': [],
    },
  },
});

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.content);

  final String content;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    return ByteData.sublistView(bytes);
  }
}
