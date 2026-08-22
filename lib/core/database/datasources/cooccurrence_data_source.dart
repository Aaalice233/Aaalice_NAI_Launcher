import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../autocomplete/cooccurrence_data_pack_service.dart';
import '../data_source.dart';

class RelatedTag {
  const RelatedTag({
    required this.tag,
    required this.count,
    this.cooccurrenceScore = 0.0,
  });

  final String tag;
  final int count;
  final double cooccurrenceScore;

  String get formattedCount {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class CooccurrenceRecord {
  const CooccurrenceRecord({
    required this.tag1,
    required this.tag2,
    required this.count,
    required this.cooccurrenceScore,
  });

  final String tag1;
  final String tag2;
  final int count;
  final double cooccurrenceScore;
}

/// Read-only optional co-occurrence source backed by the managed data pack.
///
/// Unavailable, downloading, failed, or opted-out packs intentionally return
/// empty results so Danbooru online related tags remain independently usable.
class CooccurrenceDataSource {
  CooccurrenceDataSource({
    Database? database,
    CooccurrenceDataPackService? dataPackService,
  }) : _database = database,
       _dataPackService = dataPackService,
       _initialized = database != null;

  static const int _maxCacheSize = 1000;

  final CooccurrenceDataPackService? _dataPackService;
  final Map<String, List<RelatedTag>> _relatedCache = {};
  Database? _database;
  bool _initialized;

  String get name => 'cooccurrence';
  bool get isInitialized => _initialized;
  bool get isAvailable =>
      _database != null || (_dataPackService?.isQueryReady ?? false);

  Future<void> initialize() async {
    if (_initialized) return;
    await _dataPackService?.initialize();
    _initialized = true;
  }

  Future<List<RelatedTag>> getRelatedTags(
    String tag, {
    int limit = 20,
    int minCount = 1,
  }) async {
    if (tag.trim().isEmpty || limit <= 0) return const [];
    if (!_initialized) await initialize();
    final normalizedTag = tag.toLowerCase().trim();
    final dataVersion = _dataPackService?.activeDataVersion;
    final cacheKey = _buildCacheKey(
      tag: normalizedTag,
      minCount: minCount,
      limit: limit,
      dataVersion: dataVersion,
    );
    final mayUseCache =
        _dataPackService == null ||
        (_dataPackService.isQueryReady && dataVersion != null);
    final cached = mayUseCache ? _relatedCache[cacheKey] : null;
    if (cached != null) return cached;

    final rows = _dataPackService != null
        ? await _dataPackService.queryRelatedTags(
            normalizedTag,
            limit: limit,
            minCount: minCount,
          )
        : await _queryDatabaseRelated(
            normalizedTag,
            limit: limit,
            minCount: minCount,
          );
    final related = rows
        .map(
          (row) => RelatedTag(
            tag: '${row['related_tag']}',
            count: (row['count'] as num?)?.toInt() ?? 0,
          ),
        )
        .where((entry) => entry.tag != normalizedTag)
        .toList(growable: false);
    if (mayUseCache) _addToCache(cacheKey, related);
    return related;
  }

  Future<Map<String, List<RelatedTag>>> getRelatedTagsBatch(
    List<String> tags, {
    int limit = 10,
  }) async {
    final result = <String, List<RelatedTag>>{};
    for (final value in tags) {
      final tag = value.toLowerCase().trim();
      if (tag.isEmpty || result.containsKey(tag)) continue;
      result[tag] = await getRelatedTags(tag, limit: limit);
    }
    return result;
  }

  Future<double> calculateCooccurrenceScore(String tag1, String tag2) async {
    final first = tag1.toLowerCase().trim();
    final second = tag2.toLowerCase().trim();
    if (first.isEmpty || second.isEmpty) return 0;
    if (!_initialized) await initialize();
    final occurrence = _dataPackService != null
        ? await _dataPackService.queryPairCooccurrence(first, second)
        : await _directPairCount(first, second);
    if (occurrence <= 0) return 0;
    final count1 = _dataPackService != null
        ? await _dataPackService.querySummedCooccurrence(first)
        : await _directSummedCount(first);
    final count2 = _dataPackService != null
        ? await _dataPackService.querySummedCooccurrence(second)
        : await _directSummedCount(second);
    final union = count1 + count2 - occurrence;
    return union <= 0 ? 0 : occurrence / union;
  }

  Future<int> getCount() async {
    if (!_initialized) await initialize();
    if (_dataPackService != null) return _dataPackService.queryPairCount();
    final database = _database;
    if (database == null) return 0;
    final rows = await database.rawQuery(
      "SELECT value FROM metadata WHERE key = 'source_pair_count'",
    );
    return rows.isEmpty ? 0 : int.tryParse('${rows.single['value']}') ?? 0;
  }

  Future<int> getRelatedTagCount(String tag) async {
    final normalized = tag.toLowerCase().trim();
    if (normalized.isEmpty) return 0;
    if (!_initialized) await initialize();
    if (_dataPackService != null) {
      return _dataPackService.queryRelatedTagCount(normalized);
    }
    final database = _database;
    if (database == null) return 0;
    final rows = await database.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM tags source
      JOIN edges edge ON edge.source_tag_id = source.id
      WHERE source.name = ? COLLATE NOCASE
      ''',
      [normalized],
    );
    return (rows.single['count'] as num?)?.toInt() ?? 0;
  }

  Future<DataSourceHealth> checkHealth() async {
    if (!_initialized) await initialize();
    final available = isAvailable;
    return DataSourceHealth(
      status: available ? HealthStatus.healthy : HealthStatus.degraded,
      message: available
          ? 'Co-occurrence data pack is ready'
          : 'Optional co-occurrence data pack is unavailable',
      details: {
        'recordCount': available ? await getCount() : 0,
        'cacheSize': _relatedCache.length,
      },
      timestamp: DateTime.now(),
    );
  }

  Future<void> clear() async {
    _relatedCache.clear();
  }

  Future<void> dispose() async {
    _relatedCache.clear();
    final database = _database;
    _database = null;
    if (database != null) await database.close();
    _initialized = false;
  }

  Map<String, dynamic> getCacheStatistics() => {
    'cacheSize': _relatedCache.length,
    'maxCacheSize': _maxCacheSize,
    'available': isAvailable,
  };

  Future<List<Map<String, Object?>>> _queryDatabaseRelated(
    String tag, {
    required int limit,
    required int minCount,
  }) async {
    final database = _database;
    if (database == null) return const [];
    return database.rawQuery(
      '''
      SELECT target.name AS related_tag, edge.count AS count
      FROM tags source
      JOIN edges edge ON edge.source_tag_id = source.id
      JOIN tags target ON target.id = edge.target_tag_id
      WHERE source.name = ? COLLATE NOCASE AND edge.count >= ?
      ORDER BY edge.count DESC, edge.target_tag_id ASC
      LIMIT ?
      ''',
      [tag, minCount, limit],
    );
  }

  Future<int> _directPairCount(String first, String second) async {
    final database = _database;
    if (database == null) return 0;
    final rows = await database.rawQuery(
      '''
      SELECT edge.count AS count
      FROM tags source
      JOIN edges edge ON edge.source_tag_id = source.id
      JOIN tags target ON target.id = edge.target_tag_id
      WHERE source.name = ? COLLATE NOCASE
        AND target.name = ? COLLATE NOCASE
      LIMIT 1
      ''',
      [first, second],
    );
    return rows.isEmpty ? 0 : (rows.single['count'] as num?)?.toInt() ?? 0;
  }

  Future<int> _directSummedCount(String tag) async {
    final database = _database;
    if (database == null) return 0;
    final rows = await database.rawQuery(
      '''
      SELECT COALESCE(SUM(edge.count), 0) AS total
      FROM tags source
      JOIN edges edge ON edge.source_tag_id = source.id
      WHERE source.name = ? COLLATE NOCASE
      ''',
      [tag],
    );
    return (rows.single['total'] as num?)?.toInt() ?? 0;
  }

  void _addToCache(String key, List<RelatedTag> value) {
    if (_relatedCache.length >= _maxCacheSize) {
      _relatedCache.remove(_relatedCache.keys.first);
    }
    _relatedCache[key] = value;
  }

  String _buildCacheKey({
    required String tag,
    required int minCount,
    required int limit,
    String? dataVersion,
  }) => '${dataVersion ?? 'direct'}|$tag|$minCount|$limit';
}
