import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';
import '../utils/file_hash_utils.dart';
import '../../data/models/cache/data_source_cache_meta.dart';
import 'lazy_data_source_service.dart';
import 'unified_tag_database.dart';

part 'cooccurrence_service.g.dart';

// =============================================================================
// 新方案：Isolate.spawn 参数类和入口函数
// =============================================================================

/// 虚拟 SendPort，用于不需要进度报告的 Isolate 解析
class _DummySendPort implements SendPort {
  @override
  void send(Object? message) {
    // 忽略进度消息
  }

  @override
  int get hashCode => 0;

  @override
  bool operator ==(Object other) => other is _DummySendPort;
}

/// 在 Isolate 中解析共现数据（带进度报告）
Map<String, Map<String, int>> _parseCooccurrenceDataWithProgressIsolate(
  String content,
  SendPort sendPort, {
  int progressInterval = 100000,
}) {
  final result = <String, Map<String, int>>{};
  final lines = content.split('\n');
  final totalLines = lines.length;

  final startIndex = lines.isNotEmpty && lines[0].contains(',') ? 1 : 0;

  for (var i = startIndex; i < lines.length; i++) {
    var line = lines[i].trim();
    if (line.isEmpty) continue;

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
        result.putIfAbsent(tag1, () => {})[tag2] = count;
        result.putIfAbsent(tag2, () => {})[tag1] = count;
      }
    }

    if ((i - startIndex) % progressInterval == 0 && i > startIndex) {
      final progress = (i - startIndex) / (totalLines - startIndex);
      sendPort.send({
        'type': 'progress',
        'stage': 'parsing',
        'progress': progress,
        'count': i - startIndex,
      });
    }
  }

  sendPort.send({
    'type': 'progress',
    'stage': 'parsing',
    'progress': 1.0,
    'count': totalLines - startIndex,
  });

  return result;
}

/// 共现标签数据（支持懒加载）
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

  final Set<String> _loadedTags = {};

  bool _isLoaded = false;
  bool _isLoading = false;

  Future<List<RelatedTag>> Function(String tag)? _lazyLoader;

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  int get loadedTagCount => _loadedTags.length;
  int get hotTagCount => _hotTags.length;

  void setLazyLoader(Future<List<RelatedTag>> Function(String tag) loader) {
    _lazyLoader = loader;
  }

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

  Future<List<RelatedTag>> getRelatedTagsAsync(String tag, {int limit = 20}) async {
    final normalizedTag = tag.toLowerCase().trim();

    if (_cooccurrenceMap.containsKey(normalizedTag)) {
      return getRelatedTags(tag, limit: limit);
    }

    if (_lazyLoader != null && !_isLoading) {
      try {
        await _lazyLoadTag(normalizedTag);
        return getRelatedTags(tag, limit: limit);
      } catch (e) {
        // Ignore lazy load errors
      }
    }

    return [];
  }

  Future<void> _lazyLoadTag(String tag) async {
    if (_lazyLoader == null || _loadedTags.contains(tag)) return;

    _isLoading = true;
    try {
      final related = await _lazyLoader!(tag);

      for (final r in related) {
        addCooccurrence(tag, r.tag, r.count);
      }

      _loadedTags.add(tag);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> preloadHotData() async {
    if (_lazyLoader == null) return;

    var loadedCount = 0;

    for (final tag in _hotTags) {
      if (!_loadedTags.contains(tag)) {
        try {
          await _lazyLoadTag(tag);
          loadedCount++;

          if (loadedCount % 10 == 0) {
            await Future.delayed(Duration.zero);
          }
        } catch (e) {
          // Ignore preload errors
        }
      }
    }
  }

  bool isHotTag(String tag) {
    return _hotTags.contains(tag.toLowerCase().trim());
  }

  Set<String> get hotTags => Set.unmodifiable(_hotTags);

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

  void replaceAllData(Map<String, Map<String, int>> newData) {
    _cooccurrenceMap.clear();
    _cooccurrenceMap.addAll(newData);
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

/// 加载阶段
enum CooccurrenceLoadStage {
  reading,
  parsing,
  merging,
  complete,
  error,
}

/// 加载进度回调
typedef CooccurrenceLoadCallback = void Function(
  CooccurrenceLoadStage stage,
  double progress,
  double? stageProgress,
  String? message,
);

/// 加载模式
enum CooccurrenceLoadMode {
  full,
  lazy,
  sqlite,
}

/// 共现标签服务
class CooccurrenceService implements LazyDataSourceServiceV2<List<RelatedTag>> {
  @override
  String get serviceName => 'cooccurrence';

  @override
  Set<String> get hotKeys => _data.hotTags;

  @override
  bool get isInitialized => _data.isLoaded;

  @override
  bool get isRefreshing => false;

  @override
  DataSourceProgressCallback? onProgress;

  final CooccurrenceData _data = CooccurrenceData();
  UnifiedTagDatabase? _unifiedDb;

  CooccurrenceLoadMode _loadMode = CooccurrenceLoadMode.full;
  CooccurrenceLoadCallback? onLoadProgress;
  DateTime? _lastUpdate;
  AutoRefreshInterval _refreshInterval = AutoRefreshInterval.days30;

  CooccurrenceService();

  CooccurrenceLoadMode get loadMode => _loadMode;
  bool get isUsingUnifiedDb => _unifiedDb != null;
  bool get isLoaded => _data.isLoaded;
  bool get hasData => _data.mapSize > 0;
  bool get isDownloading => false;
  DateTime? get lastUpdate => _lastUpdate;
  AutoRefreshInterval get refreshInterval => _refreshInterval;

  Future<List<RelatedTag>> getRelatedTags(String tag, {int limit = 20}) async {
    switch (_loadMode) {
      case CooccurrenceLoadMode.full:
        return _data.getRelatedTags(tag, limit: limit);

      case CooccurrenceLoadMode.lazy:
        return _data.getRelatedTagsAsync(tag, limit: limit);

      case CooccurrenceLoadMode.sqlite:
        if (_unifiedDb != null) {
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
        return _data.getRelatedTags(tag, limit: limit);
    }
  }

  Future<List<RelatedTag>> getRelatedTagsForMultiple(
    List<String> tags, {
    int limit = 20,
  }) async {
    switch (_loadMode) {
      case CooccurrenceLoadMode.full:
        return _data.getRelatedTagsForMultiple(tags, limit: limit);

      case CooccurrenceLoadMode.lazy:
        for (final tag in tags) {
          await _data.getRelatedTagsAsync(tag, limit: limit * 2);
        }
        return _data.getRelatedTagsForMultiple(tags, limit: limit);

      case CooccurrenceLoadMode.sqlite:
        if (_unifiedDb != null) {
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
        return _data.getRelatedTagsForMultiple(tags, limit: limit);
    }
  }

  @override
  Future<bool> initialize({Duration timeout = const Duration(seconds: 30)}) async {
    try {
      return await _initializeInternal().timeout(timeout);
    } on TimeoutException {
      AppLogger.w('Cooccurrence data loading timed out after ${timeout.inSeconds}s', 'Cooccurrence');
      _data.markLoaded();
      return false;
    } catch (e) {
      AppLogger.w('Failed to load cooccurrence cache: $e', 'Cooccurrence');
      _data.markLoaded();
      return false;
    }
  }

  Future<bool> _initializeInternal() async {
    // 旧的二进制缓存已废弃，直接返回 false
    return false;
  }

  @override
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

  Future<void> setLoadMode(
    CooccurrenceLoadMode mode, {
    UnifiedTagDatabase? unifiedDb,
  }) async {
    _loadMode = mode;

    if (mode == CooccurrenceLoadMode.lazy || mode == CooccurrenceLoadMode.sqlite) {
      if (unifiedDb != null) {
        _unifiedDb = unifiedDb;

        _data.setLazyLoader((tag) async {
          final results = await unifiedDb.getRelatedTags(tag, limit: 50);
          return results
              .map(
                (r) => RelatedTag(
                  tag: r.tag,
                  count: r.count,
                  cooccurrenceScore: r.cooccurrenceScore,
                ),
              )
              .toList();
        });

        if (mode == CooccurrenceLoadMode.lazy) {
          await _data.preloadHotData();
          _data.markLoaded();
        }
      }
    }

    AppLogger.i('Cooccurrence load mode set to: $mode', 'Cooccurrence');
  }

  /// 从本地 assets 加载共现数据
  Future<bool> _loadFromAssets() async {
    try {
      onLoadProgress?.call(
        CooccurrenceLoadStage.reading,
        0.0,
        0.0,
        '从本地资源加载共现数据...',
      );

      final csvContent = await rootBundle.loadString(
        'assets/translations/hf_danbooru_cooccurrence.csv',
      );

      onLoadProgress?.call(
        CooccurrenceLoadStage.parsing,
        0.3,
        0.0,
        '解析共现数据...',
      );

      final result = await Isolate.run(
        () => _parseCooccurrenceDataWithProgressIsolate(
          csvContent,
          _DummySendPort(),
        ),
      );

      onLoadProgress?.call(
        CooccurrenceLoadStage.merging,
        0.7,
        0.0,
        '合并数据...',
      );

      _data.replaceAllData(result);

      onLoadProgress?.call(
        CooccurrenceLoadStage.complete,
        1.0,
        1.0,
        '共现数据加载完成: ${result.length} 个标签',
      );

      AppLogger.i('Loaded cooccurrence data from assets: ${result.length} tags', 'Cooccurrence');
      return true;
    } catch (e, stack) {
      AppLogger.w('Failed to load cooccurrence from assets: $e\n$stack', 'Cooccurrence');
      return false;
    }
  }

  Future<void> initializeLazy({UnifiedTagDatabase? existingDb}) async {
    if (_data.isLoaded) return;

    try {
      onProgress?.call(0.0, '初始化共现数据...');

      // 使用传入的数据库实例，或自己的实例
      final unifiedDb = existingDb ?? (_unifiedDb ?? UnifiedTagDatabase());
      _unifiedDb = unifiedDb;

      if (!unifiedDb.isInitialized) {
        await unifiedDb.initialize();
      }

      final counts = await unifiedDb.getRecordCounts();
      final hasData = counts.cooccurrences > 0;
      if (!hasData) {
        AppLogger.i('Cooccurrence database is empty, needs import', 'Cooccurrence');
        _unifiedDb = unifiedDb;
        _loadMode = CooccurrenceLoadMode.lazy;
        onProgress?.call(1.0, '需要导入共现数据');
        _lastUpdate = null;
        return;
      }

      await setLoadMode(CooccurrenceLoadMode.lazy, unifiedDb: unifiedDb);

      _data.markLoaded();

      onProgress?.call(1.0, '共现数据初始化完成');
      AppLogger.i('Cooccurrence lazy initialization completed (hot data loading deferred)', 'Cooccurrence');
    } catch (e, stack) {
      AppLogger.e('Cooccurrence lazy initialization failed', e, stack, 'Cooccurrence');
      _data.markLoaded();
      onProgress?.call(1.0, '初始化失败，使用空数据');
    }
  }

  /// V2: 轻量级初始化（仅检查状态，不加载大量数据）
  @override
  Future<void> initializeLightweight() async {
    if (_data.isLoaded) return;

    try {
      onProgress?.call(0.0, '检查共现数据状态...');

      // 复用已初始化的 UnifiedTagDatabase
      // 注意：外部需要传入已初始化的实例
      final unifiedDb = _unifiedDb;
      if (unifiedDb == null) {
        // 如果没有外部传入的实例，标记为需要后续初始化
        _loadMode = CooccurrenceLoadMode.lazy;
        onProgress?.call(1.0, '等待数据库连接...');
        return;
      }

      // 只检查数据库中是否有数据，不加载
      final counts = await unifiedDb.getRecordCounts();
      final hasData = counts.cooccurrences > 0;

      if (hasData) {
        _loadMode = CooccurrenceLoadMode.lazy;
        _data.markLoaded(); // 标记为已加载（实际数据按需加载）
        onProgress?.call(1.0, '共现数据已就绪');
      } else {
        // 数据库为空，需要后续从 assets 或下载加载
        _loadMode = CooccurrenceLoadMode.lazy;
        _lastUpdate = null;
        onProgress?.call(1.0, '需要加载共现数据');
      }
    } catch (e, stack) {
      AppLogger.e('Cooccurrence lightweight init failed', e, stack, 'Cooccurrence');
      _data.markLoaded();
    }
  }

  /// V2: 后台预加载热数据
  @override
  Future<void> preloadHotDataInBackground() async {
    if (_data.isLoaded && _data.mapSize > 0) return;

    try {
      onProgress?.call(0.0, '开始加载共现数据...');

      // 尝试从本地 assets 加载
      final loaded = await _loadFromAssets();

      if (loaded) {
        onProgress?.call(0.5, '加载热标签数据...');
        await _data.preloadHotData(); // 预加载热标签
        onProgress?.call(1.0, '共现数据加载完成');
      } else {
        // 本地无数据，需要导入
        onProgress?.call(1.0, '需要导入共现数据');
        _lastUpdate = null;
      }
    } catch (e, stack) {
      AppLogger.e('Cooccurrence hot data preload failed', e, stack, 'Cooccurrence');
      onProgress?.call(1.0, '加载失败');
    }
  }

  /// 设置外部 UnifiedTagDatabase 实例（避免重复初始化）
  void setUnifiedDatabase(UnifiedTagDatabase db) {
    _unifiedDb = db;
  }

  // ===========================================================================
  // 新的统一初始化流程 (SQLite 为主存储)
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
        // 有数据，检查版本
        final csvHash = await FileHashUtils.calculateAssetHash(
          'assets/translations/hf_danbooru_cooccurrence.csv',
        );

        final needsUpdate = await _unifiedDb!.needsCooccurrenceUpdate(csvHash);

        if (!needsUpdate) {
          // 数据最新，直接使用
          _loadMode = CooccurrenceLoadMode.sqlite;
          _data.markLoaded();
          stopwatch.stop();
          AppLogger.i(
            'Cooccurrence data up to date, using SQLite (${counts.cooccurrences} records) in ${stopwatch.elapsedMilliseconds}ms',
            'Cooccurrence',
          );
          return true;
        } else {
          // 需要更新，标记后后台处理
          AppLogger.i('Cooccurrence data needs update', 'Cooccurrence');
          _loadMode = CooccurrenceLoadMode.sqlite;
          _data.markLoaded();
          return false; // 需要后台更新
        }
      }

      // 3. 数据库为空，需要首次导入
      AppLogger.i('Cooccurrence database empty, needs initial import', 'Cooccurrence');
      _loadMode = CooccurrenceLoadMode.sqlite;
      return false; // 需要后台导入
    } catch (e, stack) {
      AppLogger.e('Cooccurrence unified init failed', e, stack, 'Cooccurrence');
      _data.markLoaded();
      return false;
    }
  }

  /// 将 Assets 中的 CSV 导入 SQLite（分批处理，避免阻塞）
  ///
  /// 返回: 导入的记录数，-1 表示失败
  Future<int> importCsvToSQLite({
    void Function(double progress, String message)? onProgress,
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

      onProgress?.call(0.1, '解析数据...');

      // 2. 解析 CSV（在 Isolate 中）
      final lines = await Isolate.run(() => csvContent.split('\n'));
      final totalLines = lines.length;

      onProgress?.call(0.2, '准备导入...');

      // 3. 清空旧数据
      await _unifiedDb!.clearCooccurrences();

      // 4. 分批导入
      const batchSize = 5000;
      var importedCount = 0;
      final records = <CooccurrenceRecord>[];

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

        // 达到批次大小，执行导入
        if (records.length >= batchSize) {
          await _unifiedDb!.insertCooccurrences(records);
          importedCount += records.length;
          records.clear();

          // 更新进度
          final progress = 0.2 + (i / totalLines) * 0.7;
          onProgress?.call(
            progress,
            '导入中... ${(progress * 100).toInt()}%',
          );

          // 让出时间片，避免阻塞 UI
          await Future.delayed(Duration.zero);
        }
      }

      // 导入剩余记录
      if (records.isNotEmpty) {
        await _unifiedDb!.insertCooccurrences(records);
        importedCount += records.length;
      }

      onProgress?.call(1.0, '导入完成');

      stopwatch.stop();
      AppLogger.i(
        'Cooccurrence CSV imported: $importedCount records in ${stopwatch.elapsedMilliseconds}ms',
        'Cooccurrence',
      );

      return importedCount;
    } catch (e, stack) {
      AppLogger.e('Failed to import CSV to SQLite', e, stack, 'Cooccurrence');
      onProgress?.call(1.0, '导入失败');
      return -1;
    }
  }

  /// 后台执行 CSV 导入（带版本更新）
  Future<void> performBackgroundImport({
    void Function(double progress, String message)? onProgress,
  }) async {
    try {
      // 1. 执行导入
      final imported = await importCsvToSQLite(onProgress: onProgress);

      if (imported > 0) {
        // 2. 更新版本信息
        final csvHash = await FileHashUtils.calculateAssetHash(
          'assets/translations/hf_danbooru_cooccurrence.csv',
        );

        await _unifiedDb!.updateDataSourceVersion(
          'cooccurrence_csv',
          1, // 版本号
          hash: csvHash,
          extraData: {
            'importedAt': DateTime.now().toIso8601String(),
            'recordCount': imported,
          },
        );

        _data.markLoaded();
        AppLogger.i('Cooccurrence background import completed', 'Cooccurrence');
      }
    } catch (e, stack) {
      AppLogger.e('Background import failed', e, stack, 'Cooccurrence');
    }
  }

  @override
  Future<List<RelatedTag>?> get(String key) async {
    return await getRelatedTags(key, limit: 20);
  }

  @override
  Future<List<List<RelatedTag>>> getMultiple(List<String> keys) async {
    final results = <List<RelatedTag>>[];
    for (final key in keys) {
      final tags = await getRelatedTags(key, limit: 20);
      results.add(tags);
    }
    return results;
  }

  @override
  Future<bool> shouldRefresh() async {
    return _refreshInterval.shouldRefresh(_lastUpdate);
  }

  @override
  Future<void> refresh() async {
    // 重新导入 CSV 到 SQLite
    onProgress?.call(0.0, '开始重新导入共现数据...');

    try {
      await performBackgroundImport(onProgress: onProgress);
      onProgress?.call(1.0, '共现数据刷新完成');
    } catch (e) {
      AppLogger.e('Failed to refresh cooccurrence data', e, null, 'Cooccurrence');
      onProgress?.call(1.0, '刷新失败: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // V2: LazyDataSourceServiceV2 接口实现
  // ===========================================================================

  @override
  Future<bool> shouldRefreshInBackground() async {
    return _refreshInterval.shouldRefresh(_lastUpdate);
  }

  @override
  set onBackgroundProgress(DataSourceProgressCallback? callback) {
    onProgress = callback;
  }

  @override
  void cancelBackgroundOperation() {
    // 取消后台操作
  }
}

/// CooccurrenceService Provider
@Riverpod(keepAlive: true)
CooccurrenceService cooccurrenceService(Ref ref) {
  return CooccurrenceService();
}
