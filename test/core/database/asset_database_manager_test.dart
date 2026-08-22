import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/asset_database_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory appSupportDir;
  late Map<String, int> assetLoadCounts;
  late Map<String, Uint8List> assets;
  late Map<String, dynamic> manifest;

  setUp(() async {
    AssetDatabaseManager.resetForTesting();
    tempDir = await Directory.systemTemp.createTemp(
      'asset_database_manager_test_',
    );
    appSupportDir = await Directory(
      p.join(tempDir.path, 'app_support'),
    ).create(recursive: true);
    PathProviderPlatform.instance = _TestPathProviderPlatform(
      appSupportPath: appSupportDir.path,
    );

    final catalog = await _createCatalogFixture(tempDir.path);
    final catalogBytes = await catalog.readAsBytes();
    manifest = {
      'databases': {
        AssetDatabaseManager.tagCatalogDb: {
          'schemaVersion': 1,
          'dataVersion': 'test-data',
          'sha256': sha256.convert(catalogBytes).toString(),
          'size': catalogBytes.length,
        },
      },
    };
    assets = {
      'assets/databases/manifest.json': Uint8List.fromList(
        utf8.encode(jsonEncode(manifest)),
      ),
      'assets/databases/${AssetDatabaseManager.tagCatalogDb}': catalogBytes,
    };
    assetLoadCounts = <String, int>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(
            message!.buffer.asUint8List(
              message.offsetInBytes,
              message.lengthInBytes,
            ),
          );
          assetLoadCounts[key] = (assetLoadCounts[key] ?? 0) + 1;
          final value = assets[key];
          if (value == null) return null;
          return ByteData.sublistView(value);
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('reuses a validated local database matching the manifest', () async {
    final dbDir = await Directory(
      p.join(appSupportDir.path, 'asset_databases'),
    ).create(recursive: true);
    final databases = manifest['databases'] as Map<String, dynamic>;
    const name = AssetDatabaseManager.tagCatalogDb;
    final target = File(p.join(dbDir.path, name));
    await target.writeAsBytes(assets['assets/databases/$name']!);
    await File(
      '${target.path}.install.json',
    ).writeAsString(jsonEncode({'sha256': databases[name]['sha256']}));

    await AssetDatabaseManager.initialize();

    expect(assetLoadCounts['assets/databases/manifest.json'], 1);
    expect(
      assetLoadCounts['assets/databases/${AssetDatabaseManager.tagCatalogDb}'],
      isNull,
    );
  });

  test('installs missing assets atomically with manifest state', () async {
    await AssetDatabaseManager.initialize();

    final dbDir = Directory(p.join(appSupportDir.path, 'asset_databases'));
    const name = AssetDatabaseManager.tagCatalogDb;
    final target = File(p.join(dbDir.path, name));
    expect(await target.exists(), isTrue);
    expect(await File('${target.path}.install.json').exists(), isTrue);
    expect(assetLoadCounts['assets/databases/$name'], 1);
    expect(await File(p.join(dbDir.path, 'translation.db')).exists(), isFalse);
  });

  test(
    'removes only a legacy co-occurrence install with a known hash',
    () async {
      final dbDir = await Directory(
        p.join(appSupportDir.path, 'asset_databases'),
      ).create(recursive: true);
      final legacy = File(p.join(dbDir.path, 'cooccurrence.db'));
      await legacy.writeAsString('legacy payload');
      await File('${legacy.path}.install.json').writeAsString(
        jsonEncode({
          'sha256':
              'd23335978b12f0cbbdb526e745e17985943f93fb53caafe7242f4948aa69bae9',
        }),
      );
      for (final suffix in ['.installing', '.backup', '.version']) {
        await File('${legacy.path}$suffix').writeAsString('legacy temporary');
      }
      final unrelatedFiles = [
        await File(
          p.join(dbDir.path, AssetDatabaseManager.tagCatalogDb),
        ).writeAsString('catalog placeholder'),
        await File(p.join(dbDir.path, 'tag.sqlite')).writeAsString('ffdkj'),
        await File(
          p.join(
            appSupportDir.path,
            'autocomplete',
            'cooccurrence',
            'cooccurrence-v2.db',
          ),
        ).create(recursive: true),
      ];

      await AssetDatabaseManager.initialize();

      expect(await legacy.exists(), isFalse);
      for (final suffix in [
        '.install.json',
        '.installing',
        '.backup',
        '.version',
      ]) {
        expect(await File('${legacy.path}$suffix').exists(), isFalse);
      }
      for (final file in unrelatedFiles) {
        expect(await file.exists(), isTrue);
      }
      expect(
        await File(
          p.join(dbDir.path, '.cooccurrence-external-v2-migrated'),
        ).exists(),
        isTrue,
      );
    },
  );

  test('preserves an unknown legacy co-occurrence file permanently', () async {
    final dbDir = await Directory(
      p.join(appSupportDir.path, 'asset_databases'),
    ).create(recursive: true);
    final unknown = File(p.join(dbDir.path, 'cooccurrence.db'));
    final metadata = File('${unknown.path}.install.json');
    await unknown.writeAsString('user-owned unknown data');
    await metadata.writeAsString(jsonEncode({'sha256': 'unknown'}));

    await AssetDatabaseManager.initialize();

    expect(await unknown.exists(), isTrue);
    expect(await metadata.exists(), isTrue);
    final marker = File(
      p.join(dbDir.path, '.cooccurrence-external-v2-migrated'),
    );
    expect(await marker.exists(), isTrue);

    await metadata.writeAsString(
      jsonEncode({
        'sha256':
            'd23335978b12f0cbbdb526e745e17985943f93fb53caafe7242f4948aa69bae9',
      }),
    );
    AssetDatabaseManager.resetForTesting();
    await AssetDatabaseManager.initialize();

    expect(await unknown.exists(), isTrue);
    expect(await metadata.exists(), isTrue);
  });

  test('legacy autocomplete migration preserves local gallery data', () async {
    final runtimeDir = await Directory(
      p.join(appSupportDir.path, 'databases'),
    ).create(recursive: true);
    final runtimePath = p.join(runtimeDir.path, 'danbooru.db');
    final runtimeDb = sqlite3.open(runtimePath);
    runtimeDb.execute('''
      CREATE TABLE gallery_images(id INTEGER PRIMARY KEY, file_path TEXT);
      INSERT INTO gallery_images(file_path) VALUES ('C:/gallery/image.png');
      CREATE TABLE gallery_favorites(image_id INTEGER PRIMARY KEY);
      INSERT INTO gallery_favorites(image_id) VALUES (1);
      CREATE TABLE danbooru_tags(tag TEXT PRIMARY KEY);
      INSERT INTO danbooru_tags(tag) VALUES ('legacy_tag');
    ''');
    runtimeDb.dispose();

    await AssetDatabaseManager.initialize();

    final migratedDb = sqlite3.open(runtimePath);
    try {
      expect(
        migratedDb
            .select('SELECT file_path FROM gallery_images')
            .single['file_path'],
        'C:/gallery/image.png',
      );
      expect(
        migratedDb
            .select('SELECT image_id FROM gallery_favorites')
            .single['image_id'],
        1,
      );
      expect(
        migratedDb.select(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'danbooru_tags'",
        ),
        isEmpty,
      );
    } finally {
      migratedDb.dispose();
    }
    expect(
      await File(
        p.join(
          appSupportDir.path,
          'asset_databases',
          '.autocomplete-v1-migrated',
        ),
      ).exists(),
      isTrue,
    );
  });
}

Future<File> _createCatalogFixture(String directory) async {
  final file = File(p.join(directory, 'catalog-fixture.db'));
  final db = sqlite3.open(file.path);
  db.execute('''
    CREATE TABLE metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL);
    INSERT INTO metadata VALUES ('schema_version', '1');
    INSERT INTO metadata VALUES ('data_version', 'test-data');
    CREATE TABLE tags(id INTEGER PRIMARY KEY, name TEXT, category INTEGER, post_count INTEGER);
    CREATE TABLE aliases(id INTEGER PRIMARY KEY, tag_id INTEGER, alias TEXT);
    CREATE VIRTUAL TABLE tag_search USING fts5(term, search_key, tag_id UNINDEXED, kind UNINDEXED);
  ''');
  db.dispose();
  return file;
}

class _TestPathProviderPlatform extends PathProviderPlatform {
  _TestPathProviderPlatform({required this.appSupportPath});

  final String appSupportPath;

  @override
  Future<String?> getApplicationSupportPath() async => appSupportPath;
}
