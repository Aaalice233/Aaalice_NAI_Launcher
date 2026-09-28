import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../platform/platform_capabilities.dart';
import '../services/android_asset_copy_service.dart';
import '../utils/app_logger.dart';

class AssetDatabaseManager {
  static final AssetDatabaseManager _instance = AssetDatabaseManager._();
  static AssetDatabaseManager get instance => _instance;

  AssetDatabaseManager._();

  static const String tagCatalogDb = 'tag_catalog.db';
  static const String _manifestAsset = 'assets/databases/manifest.json';
  static const Set<String> _knownLegacyCooccurrenceHashes = {
    '59cb3227183722ca0a6aefbaf74d3cf7c98081707f406c08df3b647ad95d76f8',
    'd23335978b12f0cbbdb526e745e17985943f93fb53caafe7242f4948aa69bae9',
  };

  String? _tagCatalogDbPath;
  static Future<void>? _initialization;
  static bool _initialized = false;

  String get tagCatalogDbPath => _requirePath(_tagCatalogDbPath);

  static Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initialization ??= _initialize()
        .then((_) {
          _initialized = true;
        })
        .whenComplete(() {
          _initialization = null;
        });
  }

  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _initialization = null;
    _instance._tagCatalogDbPath = null;
  }

  static Future<void> _initialize() async {
    final appDir = await getApplicationSupportDirectory();
    final assetDbDir = Directory(p.join(appDir.path, 'asset_databases'));
    await assetDbDir.create(recursive: true);

    final manifest =
        jsonDecode(await rootBundle.loadString(_manifestAsset))
            as Map<String, dynamic>;
    final databases = manifest['databases'] as Map<String, dynamic>;

    final catalogPath = p.join(assetDbDir.path, tagCatalogDb);
    await _install(
      fileName: tagCatalogDb,
      targetPath: catalogPath,
      metadata: Map<String, dynamic>.from(databases[tagCatalogDb] as Map),
      requiredTables: const {
        'metadata': {'key', 'value'},
        'tags': {'id', 'name', 'category', 'post_count'},
        'aliases': {'id', 'tag_id', 'alias'},
        'tag_search': {'term', 'search_key', 'tag_id', 'kind'},
        'zh_translations': {'tag', 'zh_cn', 'mode'},
      },
    );
    await _migrateLegacyAutocompleteData(appDir, assetDbDir);
    await _migrateBundledCooccurrence(assetDbDir);
    await _removeLegacyTranslationDatabase(assetDbDir);
    _instance._tagCatalogDbPath = catalogPath;
    AppLogger.i('Asset databases initialized', 'AssetDatabaseManager');
  }

  static Future<void> _install({
    required String fileName,
    required String targetPath,
    required Map<String, dynamic> metadata,
    required Map<String, Set<String>> requiredTables,
  }) async {
    final expectedHash = metadata['sha256'] as String;
    final target = File(targetPath);
    final state = File('$targetPath.install.json');
    var existingUsable = false;
    if (await target.exists()) {
      try {
        await _validateDatabase(
          target.path,
          requiredTables: requiredTables,
          verifyIntegrity: false,
        );
        existingUsable = true;

        final expectedSize = metadata['size'] as int;
        if (await _stateMatches(
          state,
          target: target,
          hash: expectedHash,
          size: expectedSize,
        )) {
          await _validateDatabase(
            target.path,
            requiredTables: requiredTables,
            expectedSchemaVersion: metadata['schemaVersion'] as int?,
            expectedDataVersion: metadata['dataVersion'] as String?,
            verifyIntegrity: false,
          );
          return;
        }

        if (await target.length() == expectedSize &&
            (await sha256.bind(target.openRead()).first).toString() ==
                expectedHash) {
          await _validateDatabase(
            target.path,
            requiredTables: requiredTables,
            expectedSchemaVersion: metadata['schemaVersion'] as int?,
            expectedDataVersion: metadata['dataVersion'] as String?,
          );
          await _writeInstallState(
            state,
            target: target,
            hash: expectedHash,
            metadata: metadata,
          );
          return;
        }
      } catch (error) {
        AppLogger.w(
          'Existing $fileName is not usable and will be replaced: $error',
          'AssetDatabaseManager',
        );
        existingUsable = false;
      }
    }

    final temp = File('$targetPath.installing');
    final backup = File('$targetPath.backup');
    await temp.deleteIfExists();
    try {
      await _copyBundledDatabase(fileName: fileName, target: temp);
      final actualHash = await sha256.bind(temp.openRead()).first;
      if (actualHash.toString() != expectedHash) {
        throw StateError('$fileName SHA256 mismatch');
      }
      await _validateDatabase(
        temp.path,
        requiredTables: requiredTables,
        expectedSchemaVersion: metadata['schemaVersion'] as int?,
        expectedDataVersion: metadata['dataVersion'] as String?,
      );

      await backup.deleteIfExists();
      if (await target.exists()) await target.rename(backup.path);
      try {
        await temp.rename(target.path);
        await _writeInstallState(
          state,
          target: target,
          hash: expectedHash,
          metadata: metadata,
        );
        await backup.deleteIfExists();
      } catch (_) {
        await target.deleteIfExists();
        if (await backup.exists()) await backup.rename(target.path);
        rethrow;
      }
    } catch (error, stack) {
      AppLogger.e(
        'Failed to install $fileName; keeping previous database',
        error,
        stack,
        'AssetDatabaseManager',
      );
      if (!existingUsable) rethrow;
    } finally {
      await temp.deleteIfExists();
    }
  }

  static Future<void> _copyBundledDatabase({
    required String fileName,
    required File target,
  }) async {
    final assetKey = 'assets/databases/$fileName';
    if (PlatformCapabilities.operatingSystem.isAndroid) {
      await AndroidAssetCopyService.copyAssetToFile(
        assetKey: assetKey,
        target: target,
      );
      return;
    }

    final bytes = await rootBundle.load(assetKey);
    await target.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
  }

  static Future<void> _validateDatabase(
    String path, {
    required Map<String, Set<String>> requiredTables,
    int? expectedSchemaVersion,
    String? expectedDataVersion,
    bool verifyIntegrity = true,
  }) async {
    final file = File(path);
    final header = await file
        .openRead(0, 16)
        .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
    if (!ascii.decode(header).startsWith('SQLite format 3')) {
      throw StateError('Invalid SQLite header: $path');
    }

    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    try {
      for (final entry in requiredTables.entries) {
        final table = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE (type='table' OR type='view') AND name=?",
          [entry.key],
        );
        if (table.isEmpty) throw StateError('Missing table ${entry.key}');
        final columns = await db.rawQuery('PRAGMA table_info("${entry.key}")');
        final names = columns.map((row) => row['name'] as String).toSet();
        if (!names.containsAll(entry.value)) {
          throw StateError('Invalid columns for ${entry.key}: $names');
        }
      }
      if (verifyIntegrity) {
        final quickCheck = await db.rawQuery('PRAGMA quick_check');
        if (quickCheck.first.values.first != 'ok') {
          throw StateError('SQLite quick_check failed: $quickCheck');
        }
      }
      if (expectedSchemaVersion != null &&
          requiredTables.containsKey('metadata')) {
        final metadata = await db.rawQuery(
          'SELECT key, value FROM metadata WHERE key IN (?, ?)',
          ['schema_version', 'data_version'],
        );
        final values = {
          for (final row in metadata)
            row['key'] as String: row['value'] as String,
        };
        if (values['schema_version'] != '$expectedSchemaVersion' ||
            values['data_version'] != expectedDataVersion) {
          throw StateError('Catalog metadata does not match manifest');
        }
      }
    } finally {
      await db.close();
    }
  }

  static Future<bool> _stateMatches(
    File state, {
    required File target,
    required String hash,
    required int size,
  }) async {
    try {
      if (!await state.exists()) return false;
      final data =
          jsonDecode(await state.readAsString()) as Map<String, dynamic>;
      final stat = await target.stat();
      return data['sha256'] == hash &&
          data['size'] == size &&
          data['modifiedMillis'] == stat.modified.millisecondsSinceEpoch &&
          stat.size == size;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _writeInstallState(
    File state, {
    required File target,
    required String hash,
    required Map<String, dynamic> metadata,
  }) async {
    final stat = await target.stat();
    await state.writeAsString(
      jsonEncode({
        'sha256': hash,
        'size': stat.size,
        'modifiedMillis': stat.modified.millisecondsSinceEpoch,
        'schemaVersion': metadata['schemaVersion'],
        'dataVersion': metadata['dataVersion'],
      }),
      encoding: utf8,
      flush: true,
    );
  }

  static Future<void> _removeLegacyTranslationDatabase(Directory dir) async {
    for (final suffix in ['', '.version', '.install.json', '.backup']) {
      await File(p.join(dir.path, 'translation.db$suffix')).deleteIfExists();
    }
  }

  static Future<void> _migrateBundledCooccurrence(Directory dir) async {
    final marker = File(p.join(dir.path, '.cooccurrence-external-v2-migrated'));
    if (await marker.exists()) return;

    final database = File(p.join(dir.path, 'cooccurrence.db'));
    final installMetadata = File('${database.path}.install.json');
    String? recognizedHash;
    if (await installMetadata.exists()) {
      try {
        final metadata =
            jsonDecode(await installMetadata.readAsString())
                as Map<String, dynamic>;
        final hash = metadata['sha256'] as String?;
        if (hash != null && _knownLegacyCooccurrenceHashes.contains(hash)) {
          recognizedHash = hash;
        }
      } catch (error) {
        AppLogger.w(
          'Unable to read legacy co-occurrence metadata: $error',
          'AssetDatabaseManager',
        );
      }
    }
    if (recognizedHash == null && await database.exists()) {
      final hash = (await sha256.bind(database.openRead()).first).toString();
      if (_knownLegacyCooccurrenceHashes.contains(hash)) {
        recognizedHash = hash;
      }
    }

    if (recognizedHash != null) {
      for (final suffix in [
        '',
        '.install.json',
        '.installing',
        '.backup',
        '.version',
      ]) {
        await File('${database.path}$suffix').deleteIfExists();
      }
      AppLogger.i(
        'Removed verified legacy bundled co-occurrence database',
        'AssetDatabaseManager',
      );
    } else if (await database.exists() || await installMetadata.exists()) {
      AppLogger.w(
        'Preserving unknown legacy co-occurrence files in ${dir.path}',
        'AssetDatabaseManager',
      );
    }
    await marker.writeAsString(
      'cooccurrence-external-v2',
      encoding: utf8,
      flush: true,
    );
  }

  static Future<void> _migrateLegacyAutocompleteData(
    Directory appDir,
    Directory assetDbDir,
  ) async {
    final marker = File(p.join(assetDbDir.path, '.autocomplete-v1-migrated'));
    if (await marker.exists()) return;
    await _removeLegacyTranslationDatabase(assetDbDir);
    final runtimeDb = p.join(appDir.path, 'databases', 'danbooru.db');
    final runtimeDbFile = File(runtimeDb);
    if (await runtimeDbFile.exists()) {
      final db = await databaseFactoryFfi.openDatabase(
        runtimeDb,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      try {
        // danbooru.db also stores the local gallery. Only the obsolete tag
        // cache is disposable during the autocomplete migration.
        await db.execute('DROP TABLE IF EXISTS danbooru_tags');
      } finally {
        await db.close();
      }
    }
    await File('$runtimeDb.version').deleteIfExists();
    await marker.writeAsString(
      DateTime.now().toUtc().toIso8601String(),
      encoding: utf8,
      flush: true,
    );
  }

  Future<Database> openTagCatalogDatabase() async {
    await AssetDatabaseManager.initialize();
    return _openReadOnlyDatabase(tagCatalogDbPath, 'tag catalog');
  }

  Future<Database> _openReadOnlyDatabase(String path, String name) async {
    AppLogger.d('Opening $name database (read-only): $path');
    return databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
  }

  Future<bool> checkDatabasesExist() async => File(tagCatalogDbPath).exists();

  Future<Map<String, dynamic>> getDatabaseInfo() async {
    Future<Map<String, dynamic>> info(String path) async {
      final file = File(path);
      return {
        'path': path,
        'exists': await file.exists(),
        'size': await file.exists() ? await file.length() : 0,
      };
    }

    return {'tagCatalog': await info(tagCatalogDbPath)};
  }

  static String _requirePath(String? path) {
    if (path == null) {
      throw StateError('AssetDatabaseManager is not initialized');
    }
    return path;
  }
}

extension on File {
  Future<void> deleteIfExists() async {
    if (await exists()) await delete();
  }
}
