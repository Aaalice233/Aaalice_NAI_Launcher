import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';
import '../utils/file_hash_utils.dart';
import '../../data/models/cache/data_source_cache_meta.dart';
import 'unified_tag_database.dart';

part 'cooccurrence_service.g.dart';

/// 共现标签数据（热标签缓存）
class CooccurrenceData {
  final Map<String, Map<String, int>> _cooccurrenceMap = {};

  final Set<String> _hotTags = {
    '1girl', 'solo', '1boy', '2girls', 'multiple_girls',
    '2boys', 'multiple_boys', '3girls', '1other', '3boys',
    'shirt', 'dress', 'skirt', 'pants', 'jacket',
    'long_hair', 'short_hair', 'blonde_hair', 'brown_hair', 'black_hair',
    'blue_eyes', 'red_eyes', 'green_eyes', 'brown_eyes', 'purple_eyes',
    'looking_at_viewer', 'smile', 'open_mouth', 'blush',
    'breasts', 'thighhighs', 'gloves', 'bow', 'ribbon',
    'white_background', 'simple_background', 'outdoors', 'indoors',
    'day', 'night', 'sunlight', 'rain',
  };

  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  int get hotTagCount => _hotTags.length;

  List<RelatedTag> getRelatedTags(String tag, {int limit = 20}) {
    final normalizedTag = tag.toLowerCase().trim();

    final related = _cooccurrenceMap[normalizedTag];

    if (related == null || related.isEmpty) {
      return [];
    }

    final sortedEntries = related.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries
        .take(limit)
        .map((e) => RelatedTag(tag: e.key, count: e.value))
        .toList();
  }

  List<RelatedTag> getRelatedTagsForMultiple(
    List<String> tags, {
    int limit = 20,
  }) {
    if (tags.isEmpty) return [];
    if (tags.length == 1) return getRelatedTags(tags.first, limit: limit);

    final allRelated = <String, int>{};

    for (final tag in tags) {
      final related = getRelatedTags(tag, limit: limit * 2);
      for (final r in related) {
        if (tags.contains(r.tag)) continue;

        allRelated[r.tag] = (allRelated[r.tag] ?? 0) + r.count;
      }
    }

    final sortedEntries = allRelated.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries
        .take(limit)
        .map((e) => RelatedTag(tag: e.key, count: e.value))
        .toList();
  }

  void addCooccurrence(String tag1, String tag2, int count) {
    final t1 = tag1.toLowerCase().trim();
    final t2 = tag2.toLowerCase().trim();

    _cooccurrenceMap.putIfAbsent(t1, () => {})[t2] = count;
    _cooccurrenceMap.putIfAbsent(t2, () => {})[t1] = count;
  }

  void markLoaded() {
    _isLoaded = true;
  }

  int get mapSize => _cooccurrenceMap.length;

  void clear() {
    _cooccurrenceMap.clear();
    _isLoaded = false;
  }
}

/// 相关标签
class RelatedTag {
  final String tag;
  final int count;
  final double cooccurrenceScore;

  const RelatedTag({
    required this.tag,
    required this.count,
    this.cooccurrenceScore = 0.0,
  });

  String get formattedCount {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

/// 共现标签服务
class CooccurrenceService {
  final CooccurrenceData _data = CooccurrenceData();
  UnifiedTagDatabase? _unifiedDb;

  DateTime? _lastUpdate;
  AutoRefreshInterval _refreshInterval = AutoRefreshInterval.days30;

  CooccurrenceService();

  bool get isInitialized => _data.isLoaded;
  bool get isLoaded => _data.isLoaded;

  /// 检查是否有共现数据（异步，实时查询数据库）
  Future<bool> hasDataAsync() async {
    if (_unifiedDb == null || !_unifiedDb!.isInitialized) return false;
    try {
      final counts = await _unifiedDb!.getRecordCounts();
      return counts.cooccurrences > 0;
    } catch (e) {
      return false;
    }
  }

  /// 同步检查数据库是否初始化（快速检查）
  bool get hasData => _unifiedDb?.isInitialized == true;
  DateTime? get lastUpdate => _lastUpdate;
  AutoRefreshInterval get refreshInterval => _refreshInterval;

  Future<List<RelatedTag>> getRelatedTags(String tag, {int limit = 20}) async {
    if (_unifiedDb != null && _unifiedDb!.isInitialized) {
      final results = await _unifiedDb!.getRelatedTags(tag, limit: limit);
      return results
          .map(
            (r) => RelatedTag(
              tag: r.tag,
              count: r.count,
              cooccurrenceScore: r.cooccurrenceScore,
            ),
          )
          .toList();
    }
    return [];
  }

  Future<List<RelatedTag>> getRelatedTagsForMultiple(
    List<String> tags, {
    int limit = 20,
  }) async {
    if (_unifiedDb != null && _unifiedDb!.isInitialized) {
      final results = await _unifiedDb!.getRelatedTagsForMultiple(tags, limit: limit);
      return results
          .map(
            (r) => RelatedTag(
              tag: r.tag,
              count: r.count,
              cooccurrenceScore: r.cooccurrenceScore,
            ),
          )
          .toList();
    }
    return [];
  }

  Future<void> clearCache() async {
    try {
      if (_unifiedDb != null) {
        await _unifiedDb!.clearCooccurrences();
        _unifiedDb = null;
      }

      _data.clear();
      _lastUpdate = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.cooccurrenceLastUpdate);

      AppLogger.i('Cooccurrence cache cleared', 'Cooccurrence');
    } catch (e) {
      AppLogger.w('Failed to clear cooccurrence cache: $e', 'Cooccurrence');
    }
  }

  Future<AutoRefreshInterval> getRefreshInterval() async {
    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getInt(StorageKeys.cooccurrenceRefreshInterval);
    if (days != null) {
      _refreshInterval = AutoRefreshInterval.fromDays(days);
    }
    return _refreshInterval;
  }

  Future<void> setRefreshInterval(AutoRefreshInterval interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.cooccurrenceRefreshInterval, interval.days);
    _refreshInterval = interval;
  }

  /// 设置外部 UnifiedTagDatabase 实例（避免重复初始化）
  void setUnifiedDatabase(UnifiedTagDatabase db) {
    _unifiedDb = db;
  }

  // ===========================================================================
  // 统一初始化流程 (SQLite 为主存储)
  // ===========================================================================

  /// 统一的初始化流程：检查 → 导入 → 完成
  ///
  /// 返回: true 表示数据已就绪，false 表示需要后台导入
  Future<bool> initializeUnified() async {
    AppLogger.i('Initializing cooccurrence (unified)...', 'Cooccurrence');
    final stopwatch = Stopwatch()..start();

    try {
      // 1. 确保数据库已初始化
      if (_unifiedDb == null) {
        throw StateError('UnifiedTagDatabase not initialized');
      }
      if (!_unifiedDb!.isInitialized) {
        await _unifiedDb!.initialize();
      }

      // 2. 检查 SQLite 中是否已有数据
      final counts = await _unifiedDb!.getRecordCounts();
      if (counts.cooccurrences > 0) {
        // 预构建数据库检测：如果有足够的数据（>300万条），视为预构建数据库，跳过版本检查
        const prebuiltThreshold = 1500000;
        final isPrebuiltDatabase = counts.cooccurrences >= prebuiltThreshold;

        // 检查数据完整性（共现数据是否达到完整水平 300万+）
        const fullDatasetThreshold = 3000000;
        final isCompleteDataset = counts.cooccurrences >= fullDatasetThreshold;

        if (isPrebuiltDatabase && isCompleteDataset) {
          AppLogger.i(
            'Detected complete prebuilt database with ${counts.cooccurrences} cooccurrence records, skipping import',
            'Cooccurrence',
          );
          _data.markLoaded();
          _lastUpdate = DateTime.now();
          stopwatch.stop();
          AppLogger.i(
            'Complete cooccurrence data ready (${counts.cooccurrences} records) in ${stopwatch.elapsedMilliseconds}ms',
            'Cooccurrence',
          );
          return true;
        } else if (isPrebuiltDatabase && !isCompleteDataset) {
          // 预构建数据不完整，需要补充导入剩余数据
          AppLogger.i(
            'Prebuilt database has ${counts.cooccurrences} records (incomplete), need to import remaining ${fullDatasetThreshold - counts.cooccurrences} records',
            'Cooccurrence',
          );
          // 标记已加载，让用户可以立即使用，但返回 false 让后台补充剩余数据
          _data.markLoaded();
          _lastUpdate = DateTime.now();
          return false;
        }

        // 有数据，检查版本
        final csvHash = await FileHashUtils.calculateAssetHash(
          'assets/translations/hf_danbooru_cooccurrence.csv',
        );

        final needsUpdate = await _unifiedDb!.needsCooccurrenceUpdate(csvHash);

        if (!needsUpdate) {
          // 数据最新，直接使用
          _data.markLoaded();
          // 从数据库读取上次更新时间（毫秒时间戳）
          final versionInfo = await _unifiedDb!.getDataSourceVersion('cooccurrences');
          if (versionInfo != null && versionInfo['lastUpdated'] != null) {
            final timestamp = int.tryParse(versionInfo['lastUpdated'] as String);
            if (timestamp != null) {
              _lastUpdate = DateTime.fromMillisecondsSinceEpoch(timestamp);
            }
          }
          stopwatch.stop();
          AppLogger.i(
            'Cooccurrence data up to date, using SQLite (${counts.cooccurrences} records) in ${stopwatch.elapsedMilliseconds}ms',
            'Cooccurrence',
          );
          return true;
        } else {
          // 需要更新，标记后后台处理
          AppLogger.i('Cooccurrence data needs update', 'Cooccurrence');
          _data.markLoaded();
          // 从数据库读取上次更新时间（毫秒时间戳）
          final versionInfo = await _unifiedDb!.getDataSourceVersion('cooccurrences');
          if (versionInfo != null && versionInfo['lastUpdated'] != null) {
            final timestamp = int.tryParse(versionInfo['lastUpdated'] as String);
            if (timestamp != null) {
              _lastUpdate = DateTime.fromMillisecondsSinceEpoch(timestamp);
            }
          }
          return false; // 需要后台更新
        }
      }

      // 3. 数据库为空，需要首次导入
      AppLogger.i('Cooccurrence database empty, needs initial import', 'Cooccurrence');
      return false; // 需要后台导入
    } catch (e, stack) {
      AppLogger.e('Cooccurrence unified init failed', e, stack, 'Cooccurrence');
      _data.markLoaded();
      return false;
    }
  }

  /// 将 Assets 中的 CSV 导入 SQLite（分批处理，避免阻塞）
  ///
  /// [skipExisting] 如果为 true，则跳过已存在的记录（增量导入）
  /// 返回: 导入的记录数，-1 表示失败
  Future<int> importCsvToSQLite({
    void Function(double progress, String message)? onProgress,
    bool skipExisting = false,
  }) async {
    if (_unifiedDb == null) {
      throw StateError('UnifiedTagDatabase not initialized');
    }

    final stopwatch = Stopwatch()..start();
    onProgress?.call(0.0, '读取 CSV 文件...');

    try {
      // 1. 读取 CSV 内容
      final csvContent = await rootBundle.loadString(
        'assets/translations/hf_danbooru_cooccurrence.csv',
      );

      onProgress?.call(0.1, '读取共现标签数据...');

      // 2. 解析 CSV（直接解析，避免 Isolate 跨边界问题）
      final lines = csvContent.split('\n');

      onProgress?.call(0.2, '准备导入共现标签...');

      // 3. 如果不跳过已存在，则清空旧数据
      if (!skipExisting) {
        await _unifiedDb!.clearCooccurrences();
      }

      // 4. 解析所有记录到内存（一次性）
      onProgress?.call(0.25, '解析共现标签数据...');
      final records = <CooccurrenceRecord>[];

      // 如果增量导入，获取已存在的记录数用于计算偏移
      final existingCount = skipExisting
          ? (await _unifiedDb!.getRecordCounts()).cooccurrences
          : 0;

      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.isEmpty) continue;

        // 跳过表头
        if (i == 0 && line.contains(',')) continue;

        // 去除引号
        if (line.startsWith('"') && line.endsWith('"')) {
          line = line.substring(1, line.length - 1);
        }

        final parts = line.split(',');
        if (parts.length >= 3) {
          final tag1 = parts[0].trim().toLowerCase();
          final tag2 = parts[1].trim().toLowerCase();
          final countStr = parts[2].trim();
          final count = double.tryParse(countStr)?.toInt() ?? 0;

          if (tag1.isNotEmpty && tag2.isNotEmpty && count > 0) {
            // 增量导入：跳过前 existingCount 条（CSV 按 count 降序）
            if (skipExisting && records.length < existingCount) {
              records.add(
                CooccurrenceRecord(
                  tag1: tag1,
                  tag2: tag2,
                  count: count,
                  cooccurrenceScore: 0.0,
                ),
              );
              continue;
            }

            records.add(
              CooccurrenceRecord(
                tag1: tag1,
                tag2: tag2,
                count: count,
                cooccurrenceScore: 0.0,
              ),
            );
          }
        }
      }

      // 增量导入：只取需要补充的部分
      final recordsToImport = skipExisting && records.length > existingCount
          ? records.sublist(existingCount)
          : records;

      if (recordsToImport.isEmpty) {
        AppLogger.i('No new cooccurrence records to import', 'Cooccurrence');
        return 0;
      }

      AppLogger.i(
        'Importing ${recordsToImport.length} cooccurrence records (existing: $existingCount)',
        'Cooccurrence',
      );

      // 5. 高速批量导入（删除索引→插入→重建索引）
      onProgress?.call(0.3, '导入数据...');
      var importedCount = 0;
      await _unifiedDb!.insertCooccurrences(
        recordsToImport,
        onProgress: (processed, total) {
          importedCount = processed;
          // 每5%更新一次进度
          final progress = 0.3 + (processed / total) * 0.65;
          if ((progress * 100).toInt() % 5 == 0) {
            onProgress?.call(
              progress,
              '导入中... ${(progress * 100).toInt()}% (${processed ~/ 10000}万/${total ~/ 10000}万)',
            );
          }
        },
      );

      onProgress?.call(1.0, '共现标签数据导入完成');

      stopwatch.stop();
      AppLogger.i(
        'Cooccurrence CSV imported: $importedCount records in ${stopwatch.elapsedMilliseconds}ms',
        'Cooccurrence',
      );

      return importedCount;
    } catch (e, stack) {
      AppLogger.e('Failed to import CSV to SQLite', e, stack, 'Cooccurrence');
      onProgress?.call(1.0, '共现标签数据导入失败');
      return -1;
    }
  }

  /// 后台执行 CSV 导入（带版本更新，支持增量导入）
  Future<void> performBackgroundImport({
    void Function(double progress, String message)? onProgress,
    bool incremental = true, // 默认增量导入
  }) async {
    try {
      // 1. 检查当前数据量
      final currentCount = (await _unifiedDb!.getRecordCounts()).cooccurrences;
      const targetCount = 3236960; // 完整数据集约 323万条

      if (currentCount >= targetCount) {
        AppLogger.i(
          'Cooccurrence data already complete ($currentCount records), skipping import',
          'Cooccurrence',
        );
        return;
      }

      AppLogger.i(
        'Starting ${incremental ? "incremental" : "full"} cooccurrence import (current: $currentCount, target: $targetCount)',
        'Cooccurrence',
      );

      // 2. 执行导入
      final imported = await importCsvToSQLite(
        onProgress: onProgress,
        skipExisting: incremental,
      );

      if (imported > 0) {
        // 3. 更新版本信息
        await _unifiedDb!.updateDataSourceVersion(
          'cooccurrences',
          1, // 版本号
        );

        _data.markLoaded();
        _lastUpdate = DateTime.now(); // 设置上次更新时间，避免重复导入
        AppLogger.i(
          'Cooccurrence background import completed, imported $imported records',
          'Cooccurrence',
        );
      }
    } catch (e, stack) {
      AppLogger.e('Background import failed', e, stack, 'Cooccurrence');
    }
  }

  /// 检查是否需要刷新数据
  Future<bool> shouldRefresh() async {
    return _refreshInterval.shouldRefresh(_lastUpdate);
  }

  /// 刷新数据（重新导入 CSV 到 SQLite）
  Future<void> refresh() async {
    try {
      await performBackgroundImport();
    } catch (e) {
      AppLogger.e('Failed to refresh cooccurrence data', e, null, 'Cooccurrence');
      rethrow;
    }
  }
}

/// CooccurrenceService Provider
@Riverpod(keepAlive: true)
CooccurrenceService cooccurrenceService(Ref ref) {
  return CooccurrenceService();
}
