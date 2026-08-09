import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

/// Compatibility facade for callers not yet migrated to the autocomplete
/// orchestrator. It reads the optional user-installed ffdkj database and never
/// falls back to the removed bundled translation database.
class TranslationDataSource {
  TranslationDataSource({Database? database})
    : _database = database,
      _initialized = database != null;

  static const int _maxCacheSize = 2000;
  final LRUCache<String, String> _cache = LRUCache(maxSize: _maxCacheSize);
  Database? _database;
  String? _path;
  bool _initialized = false;

  String get name => 'translation';

  Future<void> initialize() async {
    if (_initialized) return;
    final support = await getApplicationSupportDirectory();
    _path = p.join(support.path, 'autocomplete', 'ffdkj', 'tag.sqlite');
    _initialized = true;
    await _ensureOpen();
  }

  Future<String?> query(String enTag) async {
    final normalized = _normalize(enTag);
    if (normalized.isEmpty) return null;
    final cached = _cache.get(normalized);
    if (cached != null) return cached;
    if (!await _ensureOpen()) return null;
    final rows = await _database!.rawQuery(
      'SELECT cn_name FROM tags WHERE name = ? AND cn_name IS NOT NULL AND TRIM(cn_name) <> \'\' LIMIT 1',
      [normalized],
    );
    if (rows.isEmpty) return null;
    final value = (rows.first['cn_name'] as String).trim();
    _cache.put(normalized, value);
    return value;
  }

  Future<Map<String, String>> queryBatch(List<String> enTags) async {
    if (enTags.isEmpty || !await _ensureOpen()) return const {};
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
      final rows = await _database!.rawQuery(
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
    if (token.isEmpty || !await _ensureOpen()) return const [];
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
    final rows = await _database!.rawQuery(
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
  }

  Future<int> getCount() async {
    if (!await _ensureOpen()) return 0;
    final rows = await _database!.rawQuery(
      'SELECT COUNT(*) AS count FROM tags',
    );
    return (rows.first['count'] as num).toInt();
  }

  Future<int> getTagCount() => getCount();

  Map<String, dynamic> getCacheStatistics() => _cache.statistics;

  Future<DataSourceHealth> checkHealth() async {
    final available = await _ensureOpen();
    return DataSourceHealth(
      status: available ? HealthStatus.healthy : HealthStatus.degraded,
      message: available
          ? 'ffdkj dictionary is available'
          : 'ffdkj dictionary is not installed',
      details: {'translationCount': available ? await getCount() : 0},
      timestamp: DateTime.now(),
    );
  }

  Future<void> clear() async => _cache.clear();

  Future<void> dispose() async {
    _cache.clear();
    await _database?.close();
    _database = null;
    _initialized = false;
  }

  Future<bool> _ensureOpen() async {
    if (!_initialized) await initialize();
    if (_database != null) return true;
    final path = _path;
    if (path == null || !await File(path).exists()) return false;
    try {
      _database = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      final columns = await _database!.rawQuery('PRAGMA table_info(tags)');
      final names = columns.map((row) => row['name'] as String).toSet();
      if (!names.containsAll({'name', 'category', 'cn_name', 'post_count'})) {
        await _database!.close();
        _database = null;
        return false;
      }
      return true;
    } catch (error) {
      AppLogger.w('Unable to open optional ffdkj dictionary: $error');
      _database = null;
      return false;
    }
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(' ', '_');

  static String _escapeLike(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');
}
