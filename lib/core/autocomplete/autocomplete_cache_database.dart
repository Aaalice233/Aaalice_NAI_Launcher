import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CachedAutocompletePayload {
  const CachedAutocompletePayload({
    required this.payload,
    required this.fetchedAt,
  });

  final List<dynamic> payload;
  final DateTime fetchedAt;
}

class AutocompleteCacheDatabase {
  Database? _database;
  Future<void>? _initialization;

  Future<void> initialize() {
    if (_database != null) return Future.value();
    return _initialization ??= _open().whenComplete(() {
      _initialization = null;
    });
  }

  Future<void> _open() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'autocomplete'));
    await directory.create(recursive: true);
    _database = await databaseFactoryFfi.openDatabase(
      p.join(directory.path, 'autocomplete_cache.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE remote_queries(
              query_key TEXT PRIMARY KEY,
              payload TEXT NOT NULL,
              fetched_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE ai_translations(
              locale TEXT NOT NULL,
              canonical_tag TEXT NOT NULL,
              route_fingerprint TEXT NOT NULL,
              prompt_version INTEGER NOT NULL,
              translation TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              PRIMARY KEY(locale, canonical_tag, route_fingerprint, prompt_version)
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_remote_fetched_at ON remote_queries(fetched_at)',
          );
        },
      ),
    );
  }

  Future<CachedAutocompletePayload?> getRemote(String key) async {
    await initialize();
    final rows = await _database!.query(
      'remote_queries',
      where: 'query_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CachedAutocompletePayload(
      payload: jsonDecode(rows.first['payload'] as String) as List<dynamic>,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        rows.first['fetched_at'] as int,
        isUtc: true,
      ),
    );
  }

  Future<void> putRemote(String key, List<Map<String, dynamic>> payload) async {
    await initialize();
    await _database!.insert('remote_queries', {
      'query_key': key,
      'payload': jsonEncode(payload),
      'fetched_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> getAiTranslations({
    required List<String> tags,
    required String locale,
    required String routeFingerprint,
    required int promptVersion,
  }) async {
    if (tags.isEmpty) return const {};
    await initialize();
    final result = <String, String>{};
    for (var offset = 0; offset < tags.length; offset += 400) {
      final chunk = tags.skip(offset).take(400).toList();
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _database!.rawQuery(
        '''
        SELECT canonical_tag, translation FROM ai_translations
        WHERE locale = ? AND route_fingerprint = ? AND prompt_version = ?
          AND canonical_tag IN ($placeholders)
        ''',
        [locale, routeFingerprint, promptVersion, ...chunk],
      );
      for (final row in rows) {
        result[row['canonical_tag'] as String] = row['translation'] as String;
      }
    }
    return result;
  }

  Future<void> putAiTranslations({
    required Map<String, String> translations,
    required String locale,
    required String routeFingerprint,
    required int promptVersion,
  }) async {
    if (translations.isEmpty) return;
    await initialize();
    final batch = _database!.batch();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final entry in translations.entries) {
      batch.insert('ai_translations', {
        'locale': locale,
        'canonical_tag': entry.key,
        'route_fingerprint': routeFingerprint,
        'prompt_version': promptVersion,
        'translation': entry.value,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<int> clearDanbooruCache() async {
    await initialize();
    return _database!.delete('remote_queries');
  }

  Future<int> clearAiTranslationCache() async {
    await initialize();
    return _database!.delete('ai_translations');
  }

  Future<int> aiTranslationCount() async {
    await initialize();
    final rows = await _database!.rawQuery(
      'SELECT COUNT(*) AS count FROM ai_translations',
    );
    return (rows.first['count'] as num).toInt();
  }

  Future<Map<String, int>> statistics() async {
    await initialize();
    Future<int> count(String table) async {
      final rows = await _database!.rawQuery(
        'SELECT COUNT(*) AS count FROM $table',
      );
      return (rows.first['count'] as num).toInt();
    }

    return {
      'danbooruCache': await count('remote_queries'),
      'aiTranslations': await aiTranslationCount(),
    };
  }

  Future<void> prune() async {
    await initialize();
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    await _database!.delete(
      'remote_queries',
      where: 'fetched_at < ?',
      whereArgs: [cutoff],
    );
  }

  Future<void> dispose() async {
    await _initialization;
    await _database?.close();
    _database = null;
  }
}
