import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/cache/data_source_cache_meta.dart';
import '../../data/models/tag/local_tag.dart';
import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';
import 'lazy_data_source_service.dart';
import 'unified_tag_database.dart';

part 'danbooru_tags_lazy_service.g.dart';

/// Danbooru 标签懒加载服务 V2
/// 
/// 使用新的 UnifiedTagDatabase API，简化连接管理。
class DanbooruTagsLazyService implements LazyDataSourceService<LocalTag> {
  static const String _baseUrl = 'https://danbooru.donmai.us';
  static const String _tagsEndpoint = '/tags.json';
  static const int _pageSize = 1000;
  static const int _maxPages = 200;
  static const int _concurrentRequests = 4;
  static const int _requestIntervalMs = 100;
  static const String _cacheDirName = 'tag_cache';
  static const String _metaFileName = 'danbooru_tags_meta.json';

  final UnifiedTagDatabase _unifiedDb;
  final Dio _dio;

  final Map<String, LocalTag> _hotDataCache = {};
  bool _isInitialized = false;
  bool _isRefreshing = false;
  DataSourceProgressCallback? _onProgress;
  DateTime? _lastUpdate;
  int _currentThreshold = 1000;
  AutoRefreshInterval _refreshInterval = AutoRefreshInterval.days30;
  bool _isCancelled = false;

  @override
  DataSourceProgressCallback? get onProgress => _onProgress;

  DanbooruTagsLazyService(this._unifiedDb, this._dio) {
    unawaited(_loadMeta());
  }

  @override
  String get serviceName => 'danbooru_tags';

  @override
  Set<String> get hotKeys => const {
    '1girl', 'solo', '1boy', '2girls', 'multiple_girls',
    '2boys', 'multiple_boys', '3girls', '1other', '3boys',
    'long_hair', 'short_hair', 'blonde_hair', 'brown_hair', 'black_hair',
    'blue_eyes', 'red_eyes', 'green_eyes', 'brown_eyes', 'purple_eyes',
    'looking_at_viewer', 'smile', 'open_mouth', 'blush',
    'breasts', 'thighhighs', 'gloves', 'bow', 'ribbon',
  };

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isRefreshing => _isRefreshing;

  @override
  set onProgress(DataSourceProgressCallback? callback) {
    _onProgress = callback;
  }

  DateTime? get lastUpdate => _lastUpdate;
  int get currentThreshold => _currentThreshold;
  AutoRefreshInterval get refreshInterval => _refreshInterval;

  @override
  Future<void> initialize() async {
    if (_isInitialized && _hotDataCache.isNotEmpty) {
      return;
    }

    try {
      _onProgress?.call(0.0, '初始化标签数据...');

      // 确保数据库已初始化
      await _unifiedDb.initialize();
      _onProgress?.call(0.2, '数据库已就绪');

      // 检查数据库中实际有多少记录
      final tagCount = await _unifiedDb.getDanbooruTagCount();
      AppLogger.i('Danbooru tag count in database: $tagCount', 'DanbooruTagsLazy');

      // 如果数据库为空，强制下载
      var needsDownload = await shouldRefresh();
      if (tagCount == 0) {
        AppLogger.w('Database is empty, forcing download', 'DanbooruTagsLazy');
        needsDownload = true;
        _lastUpdate = null;
      }

      AppLogger.i(
        'Danbooru tags shouldRefresh: $needsDownload, lastUpdate: $_lastUpdate',
        'DanbooruTagsLazy',
      );

      if (needsDownload) {
        _onProgress?.call(0.3, '需要下载标签数据...');
        AppLogger.i('Danbooru tags need download, starting...', 'DanbooruTagsLazy');
        await refresh();
        _onProgress?.call(0.9, '标签数据下载完成');
      } else {
        _onProgress?.call(0.5, '使用本地缓存数据');
      }

      await _loadHotData();

      // 如果热数据为空，再次尝试下载
      if (_hotDataCache.isEmpty && tagCount == 0) {
        AppLogger.w('Hot data is empty, triggering download...', 'DanbooruTagsLazy');
        _onProgress?.call(0.3, '数据库为空，需要下载标签数据...');
        await refresh();
        await _loadHotData();
      }

      _onProgress?.call(1.0, '标签数据初始化完成');
      _isInitialized = true;

      AppLogger.i(
        'Danbooru tags lazy service initialized with ${_hotDataCache.length} hot tags',
        'DanbooruTagsLazy',
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to initialize Danbooru tags lazy service',
        e,
        stack,
        'DanbooruTagsLazy',
      );
      _isInitialized = true;
    }
  }

  Future<void> _loadHotData() async {
    _onProgress?.call(0.0, '加载热数据...');

    final records = await _unifiedDb.getDanbooruTags(hotKeys.toList());
    final tags = records
        .map(
          (r) => LocalTag(
            tag: r.tag,
            category: r.category,
            count: r.postCount,
          ),
        )
        .toList();

    for (final tag in tags) {
      _hotDataCache[tag.tag] = tag;
    }

    _onProgress?.call(1.0, '热数据加载完成');
    AppLogger.i(
      'Loaded ${_hotDataCache.length} hot Danbooru tags into memory',
      'DanbooruTagsLazy',
    );
  }

  @override
  Future<LocalTag?> get(String key) async {
    final normalizedKey = key.toLowerCase().trim();

    if (_hotDataCache.containsKey(normalizedKey)) {
      return _hotDataCache[normalizedKey];
    }

    final record = await _unifiedDb.getDanbooruTag(normalizedKey);
    if (record != null) {
      return LocalTag(
        tag: record.tag,
        category: record.category,
        count: record.postCount,
      );
    }

    return null;
  }

  Future<List<LocalTag>> search(
    String query, {
    int? category,
    int limit = 20,
  }) async {
    final records = await _unifiedDb.searchDanbooruTags(
      query,
      category: category,
      limit: limit,
    );
    return records
        .map(
          (r) => LocalTag(
            tag: r.tag,
            category: r.category,
            count: r.postCount,
          ),
        )
        .toList();
  }

  Future<List<LocalTag>> getHotTags({
    int? category,
    int minCount = 1000,
    int limit = 100,
  }) async {
    final records = await _unifiedDb.getHotDanbooruTags(
      category: category,
      minCount: minCount,
      limit: limit,
    );
    return records
        .map(
          (r) => LocalTag(
            tag: r.tag,
            category: r.category,
            count: r.postCount,
          ),
        )
        .toList();
  }

  @override
  Future<bool> shouldRefresh() async {
    if (_lastUpdate == null) {
      await _loadMeta();
    }

    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getInt(StorageKeys.danbooruTagsRefreshIntervalDays);
    final interval = AutoRefreshInterval.fromDays(days ?? 30);

    return interval.shouldRefresh(_lastUpdate);
  }

  @override
  Future<void> refresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _isCancelled = false;
    _onProgress?.call(0.0, '开始同步标签...');

    try {
      final allTags = <LocalTag>[];
      var currentPage = 1;
      var consecutiveEmpty = 0;
      var estimatedTotalTags = _estimateTotalTags(_currentThreshold);

      while (currentPage <= _maxPages && !_isCancelled) {
        const batchSize = _concurrentRequests;
        final remainingPages = _maxPages - currentPage + 1;
        final actualBatchSize = batchSize < remainingPages ? batchSize : remainingPages;

        final futures = List.generate(actualBatchSize, (i) {
          final page = currentPage + i;
          return _fetchTagsPage(page, _currentThreshold);
        });

        final results = await Future.wait(futures);

        var batchHasData = false;
        for (var i = 0; i < results.length; i++) {
          final tags = results[i];

          if (tags == null) {
            AppLogger.w('Failed to fetch page, stopping', 'DanbooruTagsLazy');
            _isCancelled = true;
            break;
          }

          if (tags.isEmpty) {
            consecutiveEmpty++;
            if (consecutiveEmpty >= 2) {
              AppLogger.i('No more tags available', 'DanbooruTagsLazy');
              _isCancelled = true;
              break;
            }
          } else {
            consecutiveEmpty = 0;
            batchHasData = true;
            allTags.addAll(tags);
          }
        }

        if (_isCancelled) break;

        if (allTags.length >= estimatedTotalTags && batchHasData) {
          estimatedTotalTags = allTags.length + _pageSize * 2;
        }

        final progress = (allTags.length / estimatedTotalTags).clamp(0.0, 0.95);
        final percent = (progress * 100).toInt();
        _onProgress?.call(progress, '拉取标签... $percent% (${allTags.length})');

        currentPage += actualBatchSize;

        if (currentPage <= _maxPages && !_isCancelled && batchHasData) {
          await Future.delayed(
            const Duration(milliseconds: _requestIntervalMs),
          );
        }
      }

      _onProgress?.call(0.95, '导入数据库...');

      // 导入数据 - UnifiedTagDatabase 会自动处理连接问题
      final records = allTags
          .map(
            (t) => DanbooruTagRecord(
              tag: t.tag,
              category: t.category,
              postCount: t.count,
              lastUpdated: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          )
          .toList();

      AppLogger.i('Preparing to import ${records.length} tags...', 'DanbooruTagsLazy');
      await _unifiedDb.insertDanbooruTags(records);
      AppLogger.i('Successfully imported ${records.length} tags', 'DanbooruTagsLazy');

      _onProgress?.call(0.99, '更新热数据...');
      await _loadHotData();
      await _saveMeta(allTags.length);

      _lastUpdate = DateTime.now();

      _onProgress?.call(1.0, '完成');
      AppLogger.i(
        'Danbooru tags refreshed: ${allTags.length} tags',
        'DanbooruTagsLazy',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to refresh Danbooru tags', e, stack, 'DanbooruTagsLazy');
      _onProgress?.call(1.0, '刷新失败: $e');
      rethrow;
    } finally {
      _isRefreshing = false;
      _isCancelled = false;
    }
  }

  void cancelRefresh() {
    _isCancelled = true;
  }

  int _estimateTotalTags(int minPostCount) {
    if (minPostCount >= 10000) return 5000;
    if (minPostCount >= 5000) return 10000;
    if (minPostCount >= 1000) return 50000;
    if (minPostCount >= 100) return 200000;
    return 500000;
  }

  Future<List<LocalTag>?> _fetchTagsPage(int page, int minPostCount) async {
    try {
      final queryParams = <String, dynamic>{
        'search[order]': 'count',
        'search[hide_empty]': 'true',
        'limit': _pageSize,
        'page': page,
      };

      if (minPostCount > 0) {
        queryParams['search[post_count]'] = '>=$minPostCount';
      }

      final response = await _dio.get(
        '$_baseUrl$_tagsEndpoint',
        queryParameters: queryParams,
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 10),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'NAI-Launcher/1.0',
          },
        ),
      );

      if (response.data is List) {
        final tags = <LocalTag>[];
        for (final item in response.data as List) {
          if (item is Map<String, dynamic>) {
            final tag = LocalTag(
              tag: (item['name'] as String?)?.toLowerCase() ?? '',
              category: item['category'] as int? ?? 0,
              count: item['post_count'] as int? ?? 0,
            );
            if (tag.tag.isNotEmpty) {
              tags.add(tag);
            }
          }
        }
        return tags;
      }

      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      AppLogger.w('Failed to fetch tags page $page: $e', 'DanbooruTagsLazy');
      return null;
    } catch (e) {
      AppLogger.w('Failed to fetch tags page $page: $e', 'DanbooruTagsLazy');
      return null;
    }
  }

  Future<void> _loadMeta() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _lastUpdate = DateTime.parse(json['lastUpdate'] as String);
        _currentThreshold = json['hotThreshold'] as int? ?? 1000;
      }

      final prefs = await SharedPreferences.getInstance();
      final days = prefs.getInt(StorageKeys.danbooruTagsRefreshIntervalDays);
      if (days != null) {
        _refreshInterval = AutoRefreshInterval.fromDays(days);
      }
    } catch (e) {
      AppLogger.w('Failed to load Danbooru tags meta: $e', 'DanbooruTagsLazy');
    }
  }

  Future<void> _saveMeta(int totalTags) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      final now = DateTime.now();
      final json = {
        'lastUpdate': now.toIso8601String(),
        'totalTags': totalTags,
        'hotThreshold': _currentThreshold,
        'version': 1,
      };

      await metaFile.writeAsString(jsonEncode(json));
      _lastUpdate = now;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(StorageKeys.danbooruTagsLastUpdate, now.millisecondsSinceEpoch);
    } catch (e) {
      AppLogger.w('Failed to save Danbooru tags meta: $e', 'DanbooruTagsLazy');
    }
  }

  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDirName');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  // 实现 LazyDataSourceService 接口的缺失方法
  @override
  Future<List<LocalTag>> getMultiple(List<String> keys) async {
    final result = <LocalTag>[];
    for (final key in keys) {
      final tag = await get(key);
      if (tag != null) {
        result.add(tag);
      }
    }
    return result;
  }

  @override
  Future<void> clearCache() async {
    _hotDataCache.clear();
    AppLogger.i('Danbooru tags cache cleared', 'DanbooruTagsLazy');
  }

  // 兼容旧 API 的方法
  Future<List<LocalTag>> searchTags(String query, {int? category, int limit = 20}) async {
    return search(query, category: category, limit: limit);
  }

  TagHotPreset getHotPreset() {
    return TagHotPreset.fromThreshold(_currentThreshold);
  }

  Future<void> setHotPreset(TagHotPreset preset, {int? customThreshold}) async {
    _currentThreshold = customThreshold ?? preset.threshold;
  }

  AutoRefreshInterval getRefreshInterval() {
    return _refreshInterval;
  }

  Future<void> setRefreshInterval(AutoRefreshInterval interval) async {
    _refreshInterval = interval;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.danbooruTagsRefreshIntervalDays, interval.days);
  }
}

@Riverpod(keepAlive: true)
DanbooruTagsLazyService danbooruTagsLazyService(Ref ref) {
  final unifiedDb = ref.watch(unifiedTagDatabaseProvider);
  final dio = Dio();
  return DanbooruTagsLazyService(unifiedDb, dio);
}
