import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';
import '../utils/download_message_keys.dart';
import '../../data/models/cache/data_source_cache_meta.dart';
import 'lazy_data_source_service.dart';
import 'unified_tag_database.dart' show UnifiedTagDatabase, CooccurrenceRecord, RelatedTag;

part 'cooccurrence_service_v2.g.dart';

/// 共现标签服务 V2
///
/// 重构版本：使用 UnifiedTagDatabase 替代 CSV/二进制缓存
/// 保留内存热缓存用于高频查询
class CooccurrenceService implements LazyDataSourceService<RelatedTag> {
  @override
  String get serviceName => 'cooccurrence';

  @override
  Set<String> get hotKeys => _hotTags;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isRefreshing => _isDownloading;

  @override
  DataSourceProgressCallback? onProgress;

  /// HuggingFace 数据集 URL
  static const String _baseUrl =
      'https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv/resolve/main';

  /// 共现标签文件名
  static const String _fileName = 'danbooru_tags_cooccurrence.csv';

  /// 热标签集合
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

  /// HTTP 客户端
  final Dio _dio;

  /// 统一标签数据库
  final UnifiedTagDatabase _unifiedDb;

  /// 内存热缓存
  final Map<String, List<RelatedTag>> _hotCache = {};

  /// 最大热缓存条目数
  static const int _maxHotCacheSize = 1000;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 是否正在下载
  bool _isDownloading = false;

  /// 下载进度回调
  void Function(double progress, String? message)? onDownloadProgress;

  /// 上次更新时间
  DateTime? _lastUpdate;

  /// 当前刷新间隔
  AutoRefreshInterval _refreshInterval = AutoRefreshInterval.days30;

  /// 元数据文件名
  static const String _metaFileName = 'cooccurrence_meta.json';

  CooccurrenceService(this._dio, this._unifiedDb) {
    // 异步加载元数据
    unawaited(_loadMeta());
  }

  /// 数据是否已加载
  bool get isLoaded => _isInitialized;

  /// 是否正在下载
  bool get isDownloading => _isDownloading;

  /// 获取上次更新时间
  DateTime? get lastUpdate => _lastUpdate;

  /// 获取当前刷新间隔
  AutoRefreshInterval get refreshInterval => _refreshInterval;

  /// 获取相关标签
  Future<List<RelatedTag>> getRelatedTags(String tag, {int limit = 20}) async {
    final normalizedTag = tag.toLowerCase().trim();

    // 1. 检查热缓存
    if (_hotCache.containsKey(normalizedTag)) {
      return _hotCache[normalizedTag]!.take(limit).toList();
    }

    // 2. 从统一数据库查询
    final results = await _unifiedDb.getRelatedTags(normalizedTag, limit: limit);

    // 3. 添加到热缓存
    if (results.isNotEmpty) {
      _addToHotCache(normalizedTag, results);
    }

    return results;
  }

  /// 获取多个标签的相关标签（交集优先）
  Future<List<RelatedTag>> getRelatedTagsForMultiple(
    List<String> tags, {
    int limit = 20,
  }) async {
    if (tags.isEmpty) return [];
    if (tags.length == 1) return getRelatedTags(tags.first, limit: limit);

    return await _unifiedDb.getRelatedTagsForMultiple(tags, limit: limit);
  }

  /// 初始化服务
  @override
  Future<bool> initialize({Duration timeout = const Duration(seconds: 30)}) async {
    if (_isInitialized) return true;

    try {
      // 确保统一数据库已初始化
      if (!_unifiedDb.isInitialized) {
        await _unifiedDb.initialize();
      }

      _isInitialized = true;
      AppLogger.i('Cooccurrence service V2 initialized', 'CooccurrenceV2');
      return true;
    } catch (e, stack) {
      AppLogger.e('Failed to initialize cooccurrence service V2', e, stack, 'CooccurrenceV2');
      return false;
    }
  }

  /// 懒加载初始化（预热阶段调用）
  Future<void> initializeLazy() async {
    if (_isInitialized) return;

    try {
      onProgress?.call(0.0, '初始化共现数据...');

      // 确保统一数据库已初始化
      if (!_unifiedDb.isInitialized) {
        await _unifiedDb.initialize();
      }

      // 检查数据库是否有数据
      final counts = await _unifiedDb.getRecordCounts();
      final hasData = counts.cooccurrences > 0;

      if (!hasData) {
        AppLogger.i(
          'Cooccurrence database is empty, will download after entering main screen',
          'CooccurrenceV2',
        );
        onProgress?.call(1.0, '需要下载共现数据');
        // 重要：不标记为已加载，这样后台刷新机制会触发下载
        _lastUpdate = null;
        return;
      }

      // 预加载热标签到缓存
      await _preloadHotTags();

      _isInitialized = true;
      onProgress?.call(1.0, '共现数据初始化完成');
      AppLogger.i(
        'Cooccurrence lazy initialization completed: ${counts.cooccurrences} records',
        'CooccurrenceV2',
      );
    } catch (e, stack) {
      AppLogger.e('Cooccurrence lazy initialization failed', e, stack, 'CooccurrenceV2');
      // 即使失败也标记为已初始化，避免阻塞启动
      _isInitialized = true;
      onProgress?.call(1.0, '初始化失败，使用空数据');
    }
  }

  /// 预加载热标签
  Future<void> _preloadHotTags() async {
    try {
      var loadedCount = 0;
      for (final tag in _hotTags) {
        final related = await _unifiedDb.getRelatedTags(tag, limit: 20);
        if (related.isNotEmpty) {
          _hotCache[tag] = related;
          loadedCount++;
        }
      }
      AppLogger.i('Preloaded $loadedCount hot tags into cache', 'CooccurrenceV2');
    } catch (e) {
      AppLogger.w('Failed to preload hot tags: $e', 'CooccurrenceV2');
    }
  }

  /// 添加数据到热缓存（LRU 策略）
  void _addToHotCache(String tag, List<RelatedTag> tags) {
    if (_hotCache.length >= _maxHotCacheSize) {
      // 移除最早的条目（简单 LRU）
      final firstKey = _hotCache.keys.first;
      _hotCache.remove(firstKey);
    }
    _hotCache[tag] = tags;
  }

  /// 下载共现数据
  Future<bool> download() async {
    if (_isDownloading) return false;
    _isDownloading = true;

    try {
      onDownloadProgress?.call(0, DownloadMessageKeys.downloadingCooccurrence);

      final cacheFile = await _getCacheFile();

      await _dio.download(
        '$_baseUrl/$_fileName',
        cacheFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            onDownloadProgress?.call(progress, null);
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
        ),
      );

      // 解析并导入到数据库
      onDownloadProgress?.call(1.0, '导入数据库...');
      await _importFromCsv(cacheFile);

      // 保存元数据
      await _saveMeta();

      // 重新预加载热标签
      _hotCache.clear();
      await _preloadHotTags();

      AppLogger.i('Cooccurrence data downloaded and imported', 'CooccurrenceV2');
      return true;
    } catch (e, stack) {
      AppLogger.e('Failed to download cooccurrence data', e, stack, 'CooccurrenceV2');
      onDownloadProgress?.call(0.0, '下载失败: $e');
      return false;
    } finally {
      _isDownloading = false;
    }
  }

  /// 从 CSV 导入到统一数据库
  Future<void> _importFromCsv(File file) async {
    try {
      AppLogger.i('Importing cooccurrence data from CSV...', 'CooccurrenceV2');

      final content = await file.readAsString();
      final lines = content.split('\n');

      // 跳过标题行
      final startIndex = lines.isNotEmpty && lines[0].contains(',') ? 1 : 0;

      final records = <CooccurrenceRecord>[];
      const batchSize = 5000;
      var processed = 0;

      for (var i = startIndex; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.isEmpty) continue;

        // 移除可能的引号包裹
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
            records.add(CooccurrenceRecord(
              tag1: tag1,
              tag2: tag2,
              count: count,
              cooccurrenceScore: 0.0,
            ),);
          }
        }

        processed++;

        // 批量插入
        if (records.length >= batchSize) {
          await _unifiedDb.insertCooccurrences(records);
          records.clear();

          // 报告进度
          if (processed % 50000 == 0) {
            final progress = processed / (lines.length - startIndex);
            onDownloadProgress?.call(1.0, '导入 ${(progress * 100).toInt()}%');
          }
        }
      }

      // 插入剩余记录
      if (records.isNotEmpty) {
        await _unifiedDb.insertCooccurrences(records);
      }

      AppLogger.i('Imported $processed cooccurrence records', 'CooccurrenceV2');
    } catch (e, stack) {
      AppLogger.e('Failed to import cooccurrence data', e, stack, 'CooccurrenceV2');
      rethrow;
    }
  }

  /// 获取缓存目录
  Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appDir.path}/tag_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// 获取缓存文件
  Future<File> _getCacheFile() async {
    final cacheDir = await _getCacheDir();
    return File('${cacheDir.path}/$_fileName');
  }

  /// 清除缓存
  @override
  Future<void> clearCache() async {
    try {
      // 清除内存缓存
      _hotCache.clear();
      _lastUpdate = null;
      _isInitialized = false;

      // 清除数据库中的共现数据
      // 注意：这里我们只清除数据，不删除数据库文件
      // 因为 UnifiedTagDatabase 可能被其他服务使用

      // 删除元数据文件
      try {
        final cacheDir = await _getCacheDir();
        final metaFile = File('${cacheDir.path}/$_metaFileName');
        if (await metaFile.exists()) {
          await metaFile.delete();
        }
      } catch (e) {
        AppLogger.w('Failed to delete meta file: $e', 'CooccurrenceV2');
      }

      // 清除 SharedPreferences 中的元数据
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.cooccurrenceLastUpdate);

      AppLogger.i('Cooccurrence cache cleared', 'CooccurrenceV2');
    } catch (e) {
      AppLogger.w('Failed to clear cooccurrence cache: $e', 'CooccurrenceV2');
    }
  }

  /// 加载元数据
  Future<void> _loadMeta() async {
    try {
      final cacheDir = await _getCacheDir();
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _lastUpdate = DateTime.parse(json['lastUpdate'] as String);
      }

      // 加载刷新间隔设置
      final prefs = await SharedPreferences.getInstance();
      final intervalDays = prefs.getInt(StorageKeys.cooccurrenceRefreshInterval);
      if (intervalDays != null) {
        _refreshInterval = AutoRefreshInterval.fromDays(intervalDays);
      }
    } catch (e) {
      AppLogger.w('Failed to load cooccurrence meta: $e', 'CooccurrenceV2');
    }
  }

  /// 保存元数据
  Future<void> _saveMeta() async {
    try {
      final cacheDir = await _getCacheDir();
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      final now = DateTime.now();
      final json = {
        'lastUpdate': now.toIso8601String(),
        'version': 2,
      };

      await metaFile.writeAsString(jsonEncode(json));
      _lastUpdate = now;

      // 同时保存到 SharedPreferences 以便快速访问
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        StorageKeys.cooccurrenceLastUpdate,
        now.toIso8601String(),
      );
    } catch (e) {
      AppLogger.w('Failed to save cooccurrence meta: $e', 'CooccurrenceV2');
    }
  }

  /// 获取刷新间隔
  Future<AutoRefreshInterval> getRefreshInterval() async {
    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getInt(StorageKeys.cooccurrenceRefreshInterval);
    if (days != null) {
      _refreshInterval = AutoRefreshInterval.fromDays(days);
    }
    return _refreshInterval;
  }

  /// 设置刷新间隔
  Future<void> setRefreshInterval(AutoRefreshInterval interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.cooccurrenceRefreshInterval, interval.days);
    _refreshInterval = interval;
  }

  // ========== LazyDataSourceService 接口实现 ==========

  @override
  Future<RelatedTag?> get(String key) async {
    final results = await getRelatedTags(key, limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  @override
  Future<List<RelatedTag>> getMultiple(List<String> keys) async {
    final results = <RelatedTag>[];
    for (final key in keys) {
      final tags = await getRelatedTags(key, limit: 20);
      results.addAll(tags);
    }
    return results;
  }

  @override
  Future<bool> shouldRefresh() async {
    if (_lastUpdate == null) {
      await _loadMeta();
    }
    return _refreshInterval.shouldRefresh(_lastUpdate);
  }

  @override
  Future<void> refresh() async {
    if (_isDownloading) return;

    _isDownloading = true;
    onProgress?.call(0.0, '开始下载共现数据...');

    try {
      // 将 download 的进度映射到 0-1.0 范围
      onDownloadProgress = (progress, message) {
        onProgress?.call(progress.clamp(0.0, 1.0), message ?? '下载中...');
      };

      final success = await download();
      if (success) {
        onProgress?.call(1.0, '共现数据刷新完成');
      } else {
        onProgress?.call(1.0, '共现数据刷新失败');
      }
    } catch (e) {
      AppLogger.e('Failed to refresh cooccurrence data', e, null, 'CooccurrenceV2');
      onProgress?.call(1.0, '刷新失败: $e');
      rethrow;
    } finally {
      _isDownloading = false;
      onDownloadProgress = null;
    }
  }
}

/// CooccurrenceServiceV2 Provider
@Riverpod(keepAlive: true)
CooccurrenceService cooccurrenceService(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(seconds: 30),
    ),
  );
  final unifiedDb = ref.watch(unifiedTagDatabaseProvider);

  return CooccurrenceService(dio, unifiedDb);
}

/// UnifiedTagDatabase Provider（如果不存在）
@Riverpod(keepAlive: true)
UnifiedTagDatabase unifiedTagDatabase(Ref ref) {
  return UnifiedTagDatabase();
}
