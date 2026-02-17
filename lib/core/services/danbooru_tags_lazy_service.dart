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
import '../utils/tag_normalizer.dart';
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
    // 决策点1: 检查是否已经初始化且热数据已加载
    if (_isInitialized && _hotDataCache.isNotEmpty) {
      AppLogger.d('[DanbooruTagsLazy] cache decision: ALREADY INITIALIZED - isInitialized=$_isInitialized, hotCacheSize=${_hotDataCache.length}', 'DanbooruTagsLazy');
      _onProgress?.call(1.0, '标签数据已就绪');
      return;
    }
    AppLogger.d('[DanbooruTagsLazy] cache decision: STARTING INIT - isInitialized=$_isInitialized, hotCacheSize=${_hotDataCache.length}', 'DanbooruTagsLazy');

    try {
      _onProgress?.call(0.0, '初始化标签数据...');

      // 先加载元数据，确保 shouldRefresh() 有正确的 _lastUpdate
      await _loadMeta();

      // 确保数据库已初始化
      await _unifiedDb.initialize();
      _onProgress?.call(0.2, '数据库已就绪');

      // 检查数据库中实际有多少记录
      final tagCount = await _unifiedDb.getDanbooruTagCount();
      AppLogger.d('[DanbooruTagsLazy] cache decision: DB CHECK - tagCount=$tagCount', 'DanbooruTagsLazy');

      // 预构建数据库检测：如果有足够的标签（>30000条），视为预构建数据库
      const prebuiltThreshold = 30000;
      final isPrebuiltDatabase = tagCount >= prebuiltThreshold;

      if (isPrebuiltDatabase) {
        AppLogger.d('[DanbooruTagsLazy] cache decision: USING PREBUILT DB - tagCount=$tagCount >= threshold=$prebuiltThreshold', 'DanbooruTagsLazy');
        _onProgress?.call(0.5, '使用预构建标签数据 ($tagCount 个)');
        await _loadHotData();
        _onProgress?.call(1.0, '标签数据初始化完成');
        _isInitialized = true;
        AppLogger.i(
          'Danbooru tags lazy service initialized with ${_hotDataCache.length} hot tags (prebuilt)',
          'DanbooruTagsLazy',
        );
        return;
      }

      // 检查是否需要下载：基于 shouldRefresh() 的结果，同时处理空数据库情况
      var needsDownload = await shouldRefresh();
      // 如果数据库为空但 shouldRefresh() 返回 false（异常情况），仍然需要下载
      if (tagCount == 0 && !needsDownload) {
        AppLogger.d('[DanbooruTagsLazy] cache decision: EMPTY DB BUT SHOULDREFRESH FALSE - forcing download', 'DanbooruTagsLazy');
        needsDownload = true;
      }

      AppLogger.d(
        '[DanbooruTagsLazy] cache decision: DOWNLOAD CHECK - needsDownload=$needsDownload, lastUpdate=$_lastUpdate',
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

    // 决策点: 从数据库加载热数据
    final records = await _unifiedDb.getDanbooruTags(hotKeys.toList());
    AppLogger.d(
      '[DanbooruTagsLazy] cache decision: HOT DATA LOAD - requested=${hotKeys.length} keys, '
      'found=${records.length} records in DB',
      'DanbooruTagsLazy',
    );

    final tags = records
        .map(
          (r) => LocalTag(
            tag: r.tag,
            category: r.category,
            count: r.postCount,
          ),
        )
        .toList();

    // 批量获取翻译
    if (tags.isNotEmpty) {
      final translations = await _unifiedDb.getTranslationsBatch(
        tags.map((t) => t.tag).toList(),
      );

      var translatedCount = 0;
      for (final tag in tags) {
        // 统一使用标准化标签作为 key 查找翻译
        final normalizedTag = TagNormalizer.normalize(tag.tag);
        final translation = translations[normalizedTag];
        if (translation != null) {
          _hotDataCache[tag.tag] = tag.copyWith(translation: translation);
          translatedCount++;
        } else {
          _hotDataCache[tag.tag] = tag;
        }
      }
      AppLogger.d(
        '[DanbooruTagsLazy] cache decision: HOT DATA POPULATED - loaded=${tags.length} tags, '
        'withTranslation=$translatedCount, cacheSize=${_hotDataCache.length}',
        'DanbooruTagsLazy',
      );
    } else {
      AppLogger.w(
        '[DanbooruTagsLazy] cache decision: HOT DATA EMPTY - no records found in DB for hot keys',
        'DanbooruTagsLazy',
      );
    }

    _onProgress?.call(1.0, '热数据加载完成');
    AppLogger.i(
      'Loaded ${_hotDataCache.length} hot Danbooru tags into memory',
      'DanbooruTagsLazy',
    );
  }

  @override
  Future<LocalTag?> get(String key) async {
    // 统一标准化标签
    final normalizedKey = TagNormalizer.normalize(key);
    AppLogger.d('[DanbooruTagsLazy] get("$key") -> normalizedKey="$normalizedKey"', 'DanbooruTagsLazy');

    // 决策点1: 检查热数据缓存 (内存缓存)
    if (_hotDataCache.containsKey(normalizedKey)) {
      final cached = _hotDataCache[normalizedKey];
      AppLogger.d('[DanbooruTagsLazy] cache decision: HOT CACHE HIT - key="$normalizedKey", translation="${cached?.translation}"', 'DanbooruTagsLazy');
      return cached;
    }
    AppLogger.d('[DanbooruTagsLazy] cache decision: HOT CACHE MISS - key="$normalizedKey", cacheSize=${_hotDataCache.length}', 'DanbooruTagsLazy');

    // 决策点2: 查询数据库 (持久化缓存)
    final record = await _unifiedDb.getDanbooruTag(normalizedKey);
    if (record != null) {
      // 获取翻译
      final translation = await _unifiedDb.getTranslation(normalizedKey);
      AppLogger.d('[DanbooruTagsLazy] cache decision: DB CACHE HIT - key="$normalizedKey", translation="$translation"', 'DanbooruTagsLazy');
      return LocalTag(
        tag: record.tag,
        category: record.category,
        count: record.postCount,
        translation: translation,
      );
    }

    // 决策点3: 缓存未命中
    AppLogger.d('[DanbooruTagsLazy] cache decision: CACHE MISS - key="$normalizedKey" not found in any cache layer', 'DanbooruTagsLazy');
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

    // 批量获取翻译
    final tags = records
        .map(
          (r) => LocalTag(
            tag: r.tag,
            category: r.category,
            count: r.postCount,
          ),
        )
        .toList();

    if (tags.isNotEmpty) {
      final translations = await _unifiedDb.getTranslationsBatch(
        tags.map((t) => t.tag).toList(),
      );

      return tags.map((tag) {
        // 统一使用标准化标签作为 key 查找翻译
        final normalizedTag = TagNormalizer.normalize(tag.tag);
        final translation = translations[normalizedTag];
        if (translation != null) {
          return tag.copyWith(translation: translation);
        }
        return tag;
      }).toList();
    }

    return tags;
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
    final tags = records
        .map(
          (r) => LocalTag(
            tag: r.tag,
            category: r.category,
            count: r.postCount,
          ),
        )
        .toList();

    // 批量获取翻译
    if (tags.isNotEmpty) {
      final translations = await _unifiedDb.getTranslationsBatch(
        tags.map((t) => t.tag).toList(),
      );

      return tags.map((tag) {
        // 统一使用标准化标签作为 key 查找翻译
        final normalizedTag = TagNormalizer.normalize(tag.tag);
        final translation = translations[normalizedTag];
        if (translation != null) {
          return tag.copyWith(translation: translation);
        }
        return tag;
      }).toList();
    }

    return tags;
  }

  @override
  Future<bool> shouldRefresh() async {
    // 决策点: 检查元数据是否已加载
    if (_lastUpdate == null) {
      AppLogger.d('[DanbooruTagsLazy] cache decision: LOADING META - _lastUpdate is null, loading metadata...', 'DanbooruTagsLazy');
      await _loadMeta();
    }

    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getInt(StorageKeys.danbooruTagsRefreshIntervalDays);
    final interval = AutoRefreshInterval.fromDays(days ?? 30);

    // 决策点: 计算是否需要刷新
    final needsRefresh = interval.shouldRefresh(_lastUpdate);
    AppLogger.d(
      '[DanbooruTagsLazy] cache decision: REFRESH CHECK - lastUpdate=$_lastUpdate, '
      'interval=${interval.days}days, needsRefresh=$needsRefresh',
      'DanbooruTagsLazy',
    );

    return needsRefresh;
  }

  @override
  Future<void> refresh() async {
    await _executeRefresh(
      fetchTags: (tags) async {
        await _fetchGeneralTags(tags);
        await _fetchArtistTags(tags);
      },
      logPrefix: '',
      importProgress: 0.95,
    );
  }

  /// 仅拉取普通标签（用于预热阶段，不包含画师标签）
  Future<void> refreshGeneralOnly() async {
    await _executeRefresh(
      fetchTags: _fetchGeneralTags,
      logPrefix: 'general ',
      importProgress: 0.9,
    );
  }

  /// 仅拉取画师标签（用于后台任务）
  Future<void> refreshArtistsOnly() async {
    await _executeRefresh(
      fetchTags: _fetchArtistTags,
      logPrefix: 'artist ',
      importProgress: 0.95,
      skipHotDataReload: true,
    );
  }

  /// 执行刷新操作的通用模板
  Future<void> _executeRefresh({
    required Future<void> Function(List<LocalTag>) fetchTags,
    required String logPrefix,
    required double importProgress,
    bool skipHotDataReload = false,
  }) async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _isCancelled = false;
    _onProgress?.call(0.0, '开始同步$logPrefix标签...');

    try {
      final tags = <LocalTag>[];
      await fetchTags(tags);

      if (_isCancelled) {
        throw Exception('用户取消同步');
      }

      _onProgress?.call(importProgress, '导入数据库...');
      await _importTags(tags);

      if (!skipHotDataReload) {
        _onProgress?.call(0.99, '更新热数据...');
        await _loadHotData();
      }
      await _saveMeta(tags.length);
      _lastUpdate = DateTime.now();

      _onProgress?.call(1.0, '完成');
      AppLogger.i(
        'Danbooru ${logPrefix}tags refreshed: ${tags.length} tags',
        'DanbooruTagsLazy',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to refresh ${logPrefix}tags', e, stack, 'DanbooruTagsLazy');
      _onProgress?.call(1.0, '刷新失败: $e');
      rethrow;
    } finally {
      _isRefreshing = false;
      _isCancelled = false;
    }
  }

  /// 将标签导入数据库
  Future<void> _importTags(List<LocalTag> tags) async {
    final records = tags
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
  }

  /// 拉取普通标签（带热度阈值）
  Future<void> _fetchGeneralTags(List<LocalTag> allTags) async {
    var currentPage = 1;
    var consecutiveEmpty = 0;
    var estimatedTotalTags = _estimateTotalTags(_currentThreshold);
    var downloadFailed = false;
    var shouldStop = false;

    while (currentPage <= _maxPages && !shouldStop && !_isCancelled) {
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
          AppLogger.w('Failed to fetch general tags page, stopping', 'DanbooruTagsLazy');
          downloadFailed = true;
          shouldStop = true;
          break;
        }

        if (tags.isEmpty) {
          consecutiveEmpty++;
          if (consecutiveEmpty >= 3) {
            AppLogger.i('No more general tags available after $currentPage pages', 'DanbooruTagsLazy');
            shouldStop = true;
            break;
          }
        } else {
          consecutiveEmpty = 0;
          batchHasData = true;
          allTags.addAll(tags);
        }
      }

      if (shouldStop) break;

      if (allTags.length >= estimatedTotalTags && batchHasData) {
        estimatedTotalTags = allTags.length + _pageSize * 2;
      }

      final progress = (allTags.length / estimatedTotalTags).clamp(0.0, 0.9);
      _onProgress?.call(progress * 0.45, '拉取普通标签... ${allTags.length} 个 (第 $currentPage 页)');

      currentPage += actualBatchSize;

      if (currentPage <= _maxPages && !shouldStop && !_isCancelled && batchHasData) {
        await Future.delayed(
          const Duration(milliseconds: _requestIntervalMs),
        );
      }
    }

    if (downloadFailed) {
      throw Exception('普通标签下载失败');
    }

    AppLogger.i('Fetched ${allTags.length} general tags', 'DanbooruTagsLazy');
  }

  /// 拉取画师标签（全部，无阈值）
  Future<void> _fetchArtistTags(List<LocalTag> allTags) async {
    const artistCategory = 1; // Danbooru: 1 = Artist
    var currentPage = 1;
    var consecutiveEmpty = 0;
    var artistTagCount = 0;
    var shouldStop = false;
    // 预估画师标签总数（基于典型Danbooru数据库规模）
    var estimatedTotalTags = 80000;

    while (currentPage <= _maxPages && !shouldStop && !_isCancelled) {
      const batchSize = _concurrentRequests;
      final remainingPages = _maxPages - currentPage + 1;
      final actualBatchSize = batchSize < remainingPages ? batchSize : remainingPages;

      final futures = List.generate(actualBatchSize, (i) {
        final page = currentPage + i;
        // 画师标签不设置热度阈值，拉取全部
        return _fetchTagsPage(page, 0, category: artistCategory);
      });

      final results = await Future.wait(futures);

      var batchHasData = false;
      for (var i = 0; i < results.length; i++) {
        final tags = results[i];

        if (tags == null) {
          AppLogger.w('Failed to fetch artist tags page $currentPage, skipping artists', 'DanbooruTagsLazy');
          // 画师标签失败不阻断整体流程
          shouldStop = true;
          break;
        }

        if (tags.isEmpty) {
          consecutiveEmpty++;
          if (consecutiveEmpty >= 3) {
            AppLogger.i('No more artist tags available', 'DanbooruTagsLazy');
            shouldStop = true;
            break;
          }
        } else {
          consecutiveEmpty = 0;
          batchHasData = true;
          allTags.addAll(tags);
          artistTagCount += tags.length;
        }
      }

      if (shouldStop) break;

      // 动态调整预估总数：当实际数量接近预估时，扩大预估
      if (artistTagCount >= estimatedTotalTags * 0.9 && batchHasData) {
        estimatedTotalTags = artistTagCount + _pageSize * 2;
      }

      // 画师标签进度：45% ~ 90%，使用 count-based 进度报告
      final progress = 0.45 + (artistTagCount / estimatedTotalTags * 0.45).clamp(0.0, 0.45);
      _onProgress?.call(
        progress,
        '拉取画师标签... $artistTagCount 个 (第 $currentPage 页)',
        processedCount: artistTagCount,
        totalCount: estimatedTotalTags,
      );

      currentPage += actualBatchSize;

      if (currentPage <= _maxPages && !shouldStop && !_isCancelled && batchHasData) {
        await Future.delayed(
          const Duration(milliseconds: _requestIntervalMs),
        );
      }
    }

    AppLogger.i('Fetched $artistTagCount artist tags', 'DanbooruTagsLazy');
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

  Future<List<LocalTag>?> _fetchTagsPage(
    int page,
    int minPostCount, {
    int? category,
  }) async {
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

      // 按类别过滤（0=general, 1=artist, 2=copyright, 3=character）
      if (category != null) {
        queryParams['search[category]'] = category.toString();
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
    final cacheSizeBefore = _hotDataCache.length;

    // 决策点: 清除缓存
    _hotDataCache.clear();
    _lastUpdate = null;
    _isInitialized = false;

    AppLogger.d(
      '[DanbooruTagsLazy] cache decision: CACHE CLEARED - hotCacheSizeBefore=$cacheSizeBefore, hotCacheSizeAfter=${_hotDataCache.length}',
      'DanbooruTagsLazy',
    );

    try {
      // 清除元数据文件
      final cacheDir = await _getCacheDirectory();
      final metaFile = File('${cacheDir.path}/$_metaFileName');
      if (await metaFile.exists()) {
        await metaFile.delete();
        AppLogger.d('[DanbooruTagsLazy] cache decision: META FILE DELETED', 'DanbooruTagsLazy');
      }

      // 清除 SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.danbooruTagsLastUpdate);

      AppLogger.i('Danbooru tags cache cleared', 'DanbooruTagsLazy');
    } catch (e) {
      AppLogger.w('Failed to clear Danbooru tags cache metadata: $e', 'DanbooruTagsLazy');
    }
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

  // ===========================================================================
  // V2: 三阶段预热架构支持
  // ===========================================================================

  /// V2: 轻量级初始化（仅检查状态）
  Future<void> initializeLightweight() async {
    if (_isInitialized) return;

    try {
      await _unifiedDb.getDanbooruTagCount();
      _isInitialized = true; // 标记为已初始化，即使数据为空
      // 注意：不触发 refresh()，数据下载留到后台阶段
    } catch (e) {
      AppLogger.w('Danbooru tags lightweight init failed: $e', 'DanbooruTagsLazy');
      _isInitialized = true;
    }
  }

  /// V2: 后台预加载
  Future<void> preloadHotDataInBackground() async {
    try {
      _onProgress?.call(0.0, '检查标签数据...');

      // 加载热数据
      await _loadHotData();

      // 检查是否需要后台更新
      final tagCount = await _unifiedDb.getDanbooruTagCount();
      if (tagCount == 0) {
        _onProgress?.call(0.5, '需要下载标签数据...');
        // 标记为需要下载，但由用户触发或后台静默下载
      }

      _onProgress?.call(1.0, '标签数据就绪');
    } catch (e) {
      AppLogger.w('Danbooru tags hot data preload failed: $e', 'DanbooruTagsLazy');
    }
  }

  /// 是否应该后台刷新（不阻塞启动）
  Future<bool> shouldRefreshInBackground() async {
    // 决策点: 检查是否需要后台刷新
    if (_lastUpdate == null) {
      AppLogger.d('[DanbooruTagsLazy] cache decision: BG REFRESH CHECK - _lastUpdate is null, loading metadata', 'DanbooruTagsLazy');
      await _loadMeta();
    }

    final needsRefresh = _refreshInterval.shouldRefresh(_lastUpdate);
    AppLogger.d(
      '[DanbooruTagsLazy] cache decision: BG REFRESH CHECK - lastUpdate=$_lastUpdate, '
      'interval=${_refreshInterval.days}days, needsBackgroundRefresh=$needsRefresh',
      'DanbooruTagsLazy',
    );
    return needsRefresh;
  }

  /// V2: 后台进度回调
  set onBackgroundProgress(DataSourceProgressCallback? callback) {
    _onProgress = callback;
  }

  /// V2: 取消后台操作
  void cancelBackgroundOperation() {
    _isCancelled = true;
  }

  /// 获取当前标签数量
  Future<int> getTagCount() async {
    return await _unifiedDb.getDanbooruTagCount();
  }
}

@Riverpod(keepAlive: true)
DanbooruTagsLazyService danbooruTagsLazyService(Ref ref) {
  final unifiedDb = ref.watch(unifiedTagDatabaseProvider);
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );
  return DanbooruTagsLazyService(unifiedDb, dio);
}
