import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

    tempDir = await Directory.systemTemp.createTemp('database_providers_test_');
    appSupportDir = await Directory(
      p.join(tempDir.path, 'app_support'),
    ).create(recursive: true);
    PathProviderPlatform.instance = _TestPathProviderPlatform(
      appSupportPath: appSupportDir.path,
    );

    assetBytes = {
      'assets/databases/translation.db': await _buildTranslationDatabaseBytes(
        tempDir,
      ),
      'assets/databases/cooccurrence.db': await _buildCooccurrenceDatabaseBytes(
        tempDir,
      ),
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
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'asset data source providers reuse DatabaseManager owned sources',
    () async {
      final container = ProviderContainer();
      try {
        final manager = await container.read(databaseManagerProvider.future);
        final translation = await container.read(
          translationDataSourceProvider.future,
        );
        final cooccurrence = await container.read(
          cooccurrenceDataSourceProvider.future,
        );

        expect(identical(translation, manager.translationDataSource), isTrue);
        expect(identical(cooccurrence, manager.cooccurrenceDataSource), isTrue);
      } finally {
        container.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    },
  );

  test(
    'disposing provider container closes manager owned asset sources',
    () async {
      final container = ProviderContainer();

      final translation = await container.read(
        translationDataSourceProvider.future,
      );
      expect((await translation.checkHealth()).status, HealthStatus.healthy);

      container.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect((await translation.checkHealth()).status, HealthStatus.corrupted);
    },
  );
}

Future<void> _disposeDatabaseManagerIfNeeded() async {
  try {
    await DatabaseManager.instance.dispose();
  } catch (_) {}
}

Future<Uint8List> _buildTranslationDatabaseBytes(Directory tempDir) async {
  final dbPath = p.join(tempDir.path, 'source_translation.db');
  final db = await databaseFactoryFfi.openDatabase(dbPath);
  try {
    await db.execute(
      'CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT, type INTEGER, count INTEGER)',
    );
    await db.execute(
      'CREATE TABLE translations (tag_id INTEGER, language TEXT, translation TEXT)',
    );
    await db.insert('tags', {'id': 1, 'name': 'solo', 'type': 0, 'count': 10});
    await db.insert('translations', {
      'tag_id': 1,
      'language': 'zh',
      'translation': '单人',
    });
  } finally {
    await db.close();
  }
  return File(dbPath).readAsBytes();
}

Future<Uint8List> _buildCooccurrenceDatabaseBytes(Directory tempDir) async {
  final dbPath = p.join(tempDir.path, 'source_cooccurrence.db');
  final db = await databaseFactoryFfi.openDatabase(dbPath);
  try {
    await db.execute(
      'CREATE TABLE cooccurrences (tag1 TEXT, tag2 TEXT, count INTEGER, cooccurrence_score REAL)',
    );
    await db.insert('cooccurrences', {
      'tag1': 'solo',
      'tag2': '1girl',
      'count': 5,
      'cooccurrence_score': 0.5,
    });
  } finally {
    await db.close();
  }
  return File(dbPath).readAsBytes();
}

class _TestPathProviderPlatform extends PathProviderPlatform {
  _TestPathProviderPlatform({required this.appSupportPath});

  final String appSupportPath;

  @override
  Future<String?> getApplicationSupportPath() async => appSupportPath;
}
