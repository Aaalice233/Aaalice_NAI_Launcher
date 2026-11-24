import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synchronized/synchronized.dart';

import '../../utils/app_logger.dart';
import '../data_source.dart';
import '../utils/lru_cache.dart';

class TranslationRecord {
  const TranslationRecord({
    required this.enTag,
    required this.zhTranslation,
    this.source = 'ffdkj',
    this.lastAccessed,
  });

  final String enTag;
  final String zhTranslation;
  final String source;
  final int? lastAccessed;
}

class TranslationMatch {
  const TranslationMatch({
    required this.tag,
    required this.translation,
    required this.score,
    this.category = 0,
    this.count = 0,
  });

  final String tag;
  final String translation;
  final int score;
  final int category;
  final int count;
}

/// Reads the optional user-installed ffdkj translation database.
class TranslationDataSource {
  TranslationDataSource({
    Database? database,
    Future<Directory> Function()? applicationSupportDirectory,
  }) : _database = database,
       _supportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory;

  static const int _maxCacheSize = 2000;
  final LRUCache<String, String> _cache = LRUCache(maxSize: _maxCacheSize);
  final _access = Lock();
  final Future<Directory> Function() _supportDirectory;
  Database? _database;
  File? _file;

  String get name => 'translation';

  Future<File> get databaseFile async => _file ??= File(
    p.join(
      (await _supportDirectory()).path,
      'autocomplete',
      'ffdkj',
      'tag.sqlite',
    ),
  );

  Future<T> read<T>(T unavailable, Future<T> Function(Database) query) =>
      _access.synchronized(() async {
        final database = _database ??= await _open();
        if (database == null) return unavailable;
        return query(database);
      });

  Future<void> withDatabaseClosed(
    Future<void> Function() changeFiles,
  ) => _access.synchronized(() async {
    // Readers must finish populating the old cache before the file can move.
    await _close();
    await changeFiles();
  });

  Future<String?> query(String enTag) async {
    final normalized = _normalize(enTag);
    if (normalized.isEmpty) return null;
    return read<String?>(null, (database) async {
      final cached = _cache.get(normalized);
      if (cached != null) return cached;
      final rows = await database.rawQuery(
        'SELECT cn_name FROM tags WHERE name = ? AND cn_name IS NOT NULL AND TRIM(cn_name) <> \'\' LIMIT 1',
        [normalized],
      );
      if (rows.isEmpty) return null;
      final value = (rows.first['cn_name'] as String).trim();
      _cache.put(normalized, value);
      return value;
    });
  }

  Future<Map<String, String>> queryBatch(List<String> enTags) async {
    if (enTags.isEmpty) return const {};
    return read(const {}, (database) => _queryBatch(database, enTags));
  }

  Future<Map<String, String>> _queryBatch(
    Database database,
    List<String> enTags,
  ) async {
    final result = <String, String>{};
    final missing = <String>[];
    for (final tag in enTags) {
      final normalized = _normalize(tag);
      final cached = _cache.get(normalized);
      if (cached == null) {
        missing.add(normalized);
      } else {
        result[normalized] = cached;
      }
    }
    for (var offset = 0; offset < missing.length; offset += 400) {
      final chunk = missing.skip(offset).take(400).toList();
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await database.rawQuery(
        'SELECT name, cn_name FROM tags WHERE name IN ($placeholders) AND cn_name IS NOT NULL AND TRIM(cn_name) <> \'\'',
        chunk,
      );
      for (final row in rows) {
        final tag = row['name'] as String;
        final value = (row['cn_name'] as String).trim();
        result[tag] = value;
        _cache.put(tag, value);
      }
    }
    return result;
  }

  Future<List<TranslationMatch>> search(
    String query, {
    int limit = 20,
    bool matchTag = true,
    bool matchTranslation = true,
  }) async {
    final token = query.trim().toLowerCase();
    if (token.isEmpty) return const [];
    final conditions = <String>[];
    final args = <Object?>[];
    final escaped = _escapeLike(token);
    if (matchTag) {
      conditions.add('name LIKE ? ESCAPE \'\\\'');
      args.add('%$escaped%');
    }
    if (matchTranslation) {
      conditions.add('cn_name LIKE ? ESCAPE \'\\\'');
      args.add('%$escaped%');
    }
    if (conditions.isEmpty) return const [];
    return read(const [], (database) async {
      final rows = await database.rawQuery(
        '''
      SELECT name, category, cn_name, post_count FROM tags
      WHERE ${conditions.join(' OR ')}
      ORDER BY
        CASE WHEN name = ? OR cn_name = ? THEN 0
             WHEN name LIKE ? ESCAPE '\\' OR cn_name LIKE ? ESCAPE '\\' THEN 1
             ELSE 2 END,
        post_count DESC, name ASC
      LIMIT ?
      ''',
        [...args, token, token, '$escaped%', '$escaped%', limit.clamp(1, 100)],
      );
      return rows
          .map((row) {
            final name = row['name'] as String;
            final translation = (row['cn_name'] as String? ?? '').trim();
            return TranslationMatch(
              tag: name,
              translation: translation,
              score: name == token || translation == token
                  ? 100
                  : name.startsWith(token) || translation.startsWith(token)
                  ? 50
                  : 25,
              category: (row['category'] as num?)?.toInt() ?? 0,
              count: (row['post_count'] as num?)?.toInt() ?? 0,
            );
          })
          .toList(growable: false);
    });
  }

  Future<int> getCount() => read(0, _getCount);

  Future<int> _getCount(Database database) async {
    final rows = await database.rawQuery('SELECT COUNT(*) AS count FROM tags');
    return (rows.first['count'] as num).toInt();
  }

  Future<int> getTagCount() => getCount();

  Map<String, dynamic> getCacheStatistics() => _cache.statistics;

  Future<DataSourceHealth> checkHealth() async {
    final count = await read<int?>(null, _getCount);
    return DataSourceHealth(
      status: count != null ? HealthStatus.healthy : HealthStatus.degraded,
      message: count != null
          ? 'ffdkj dictionary is available'
          : 'ffdkj dictionary is not installed',
      details: {'translationCount': count ?? 0},
      timestamp: DateTime.now(),
    );
  }

  Future<void> clear() async => _cache.clear();

  Future<void> dispose() => _access.synchronized(_close);

  Future<void> _close() async {
    _cache.clear();
    await _database?.close();
    _database = null;
  }

  Future<Database?> _open() async {
    final file = await databaseFile;
    if (!await file.exists()) return null;
    Database? database;
    try {
      database = await databaseFactoryFfi.openDatabase(
        file.path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      if (await supportsSchema(database)) return database;
    } on DatabaseException catch (error) {
      AppLogger.w('Unable to open optional ffdkj dictionary: $error');
    }
    await database?.close();
    return null;
  }

  static Future<bool> supportsSchema(Database database) async {
    final columns = await database.rawQuery('PRAGMA table_info(tags)');
    final names = columns.map((row) => row['name'] as String).toSet();
    return names.containsAll({'name', 'category', 'cn_name', 'post_count'});
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(' ', '_');

  static String _escapeLike(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');
}
