import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/fast_tag_service_provider.dart';
import 'package:nai_launcher/core/database/asset_database_manager.dart';
import 'package:nai_launcher/core/database/database_manager.dart';
import 'package:nai_launcher/core/database/database_providers.dart';
import 'package:nai_launcher/core/database/data_source.dart';
import 'package:nai_launcher/core/database/services/service_providers.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory appSupportDir;
  late Map<String, Uint8List> assetBytes;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppLogger.initialize(isTestEnvironment: true);
  });

  setUp(() async {
    await _disposeDatabaseManagerIfNeeded();
    AssetDatabaseManager.resetForTesting();

    tempDir = await Directory.systemTemp.createTemp('database_providers_test_');
    appSupportDir = await Directory(
      p.join(tempDir.path, 'app_support'),
    ).create(recursive: true);
    PathProviderPlatform.instance = _TestPathProviderPlatform(
      appSupportPath: appSupportDir.path,
    );

    assetBytes = {
      'assets/databases/manifest.json': await File(
        'assets/databases/manifest.json',
      ).readAsBytes(),
      'assets/databases/tag_catalog.db': await File(
        'assets/databases/tag_catalog.db',
      ).readAsBytes(),
      'assets/data/cooccurrence_data_pack_manifest.json': await File(
        'assets/data/cooccurrence_data_pack_manifest.json',
      ).readAsBytes(),
    };

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(
            message!.buffer.asUint8List(
              message.offsetInBytes,
              message.lengthInBytes,
            ),
          );
          final bytes = assetBytes[key];
          if (bytes == null) {
            throw StateError('Unexpected asset request: $key');
          }
          return ByteData.sublistView(bytes);
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    await _disposeDatabaseManagerIfNeeded();
    await _deleteDirectoryWhenReleased(tempDir);
  });

  test(
    'optional co-occurrence provider is independent from DatabaseManager',
    () async {
      final container = ProviderContainer();
      try {
        final manager = await container.read(databaseManagerProvider.future);
        final cooccurrence = await container.read(
          cooccurrenceDataSourceProvider.future,
        );

        expect(manager.isInitialized, isTrue);
        expect(await cooccurrence.getRelatedTags('1girl'), isEmpty);
        expect(
          (await cooccurrence.checkHealth()).status,
          HealthStatus.degraded,
        );
      } finally {
        container.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    },
  );

  test(
    'provider container does not own the global database lifecycle',
    () async {
      final container = ProviderContainer();

      final cooccurrence = await container.read(
        cooccurrenceDataSourceProvider.future,
      );
      expect((await cooccurrence.checkHealth()).status, HealthStatus.degraded);

      container.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect((await cooccurrence.checkHealth()).status, HealthStatus.degraded);
    },
  );

  test(
    'settings can remove the dictionary already read by the translation service',
    () async {
      final directory = await Directory(
        p.join(appSupportDir.path, 'autocomplete', 'ffdkj'),
      ).create(recursive: true);
      final target = File(p.join(directory.path, 'tag.sqlite'));
      final db = await databaseFactoryFfi.openDatabase(target.path);
      try {
        await db.execute(
          'CREATE TABLE tags(name TEXT PRIMARY KEY, category INTEGER, cn_name TEXT, post_count INTEGER)',
        );
        await db.execute('''
        WITH RECURSIVE numbers(n) AS (
          VALUES(1) UNION ALL SELECT n + 1 FROM numbers WHERE n < 1000
        )
        INSERT INTO tags SELECT 'tag_' || n, 0, '标签' || n, n FROM numbers
      ''');
      } finally {
        await db.close();
      }
      await File(p.join(directory.path, 'metadata.json')).writeAsString(
        jsonEncode({'lastCheckedAt': DateTime.now().toUtc().toIso8601String()}),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(databaseManagerProvider.future);
      final translations = await container.read(
        translationServiceProvider.future,
      );
      expect(await translations.translate('tag_1'), '标签1');

      final dictionary = container.read(zhDictionaryServiceProvider);
      await dictionary.initialize();
      await dictionary.remove();

      expect(await target.exists(), isFalse);
      expect(await translations.translate('tag_1'), isNull);
    },
  );

  test(
    'concurrent DatabaseManager initialization shares one instance',
    () async {
      final results = await Future.wait([
        DatabaseManager.initialize(),
        DatabaseManager.initialize(),
        DatabaseManager.initialize(),
      ]);

      expect(identical(results[0], results[1]), isTrue);
      expect(identical(results[1], results[2]), isTrue);
    },
  );

  test(
    'failed DatabaseManager initialization can retry with a fresh instance',
    () async {
      final blockedPath = p.join(tempDir.path, 'not_a_directory');
      await File(blockedPath).writeAsString('blocked');
      PathProviderPlatform.instance = _TestPathProviderPlatform(
        appSupportPath: blockedPath,
      );

      await expectLater(
        DatabaseManager.initialize(),
        throwsA(isA<FileSystemException>()),
      );
      expect(() => DatabaseManager.instance, throwsStateError);

      PathProviderPlatform.instance = _TestPathProviderPlatform(
        appSupportPath: appSupportDir.path,
      );
      final manager = await DatabaseManager.initialize();

      expect(manager.isInitialized, isTrue);
      expect(identical(DatabaseManager.instance, manager), isTrue);
    },
  );
}

Future<void> _disposeDatabaseManagerIfNeeded() async {
  try {
    await DatabaseManager.instance.dispose();
  } catch (_) {}
}

Future<void> _deleteDirectoryWhenReleased(Directory directory) async {
  const attempts = 50;
  for (var attempt = 1; attempt <= attempts; attempt++) {
    if (!await directory.exists()) return;
    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      if (attempt == attempts) {
        // ConnectionPool.dispose marks in-use connections for eviction instead
        // of closing them, so SQLite can still hold the file. Hosted runners
        // are ephemeral, so leave it for the operating system to reclaim.
        if (Platform.isWindows) return;
        rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}

class _TestPathProviderPlatform extends PathProviderPlatform {
  _TestPathProviderPlatform({required this.appSupportPath});

  final String appSupportPath;

  @override
  Future<String?> getApplicationSupportPath() async => appSupportPath;
}
