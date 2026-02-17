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
import '../database/datasources/danbooru_tag_data_source.dart';
import '../database/database_providers.dart';
import '../utils/app_logger.dart';
import '../utils/tag_normalizer.dart';
import 'lazy_data_source_service.dart';

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

  final DanbooruTagDataSource _tagDataSource;
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

  DanbooruTagsLazyService(this._tagDataSource, this._dio) {
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
      await _tagDataSource.initialize();
      _onProgress?.call(0.2, '数据库已就绪');

      // 检查数据库中实际有多少记录
      final tagCount = await _tagDataSource.getCount();
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

    final records = await _tagDataSource.getByNames(hotKeys.toList());
    final tags = records
        .map(
          (r) => LocalTag(
            tag: r.tag,
            category: r.category,
            count: r.postCount,
          ),
        )
        .toList();

    // TODO: 需要从 TranslationDataSource 批量获取翻译
    // 暂时直接使用标签数据，不添加翻译
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
    // 统一标准化标签
    final normalizedKey = TagNormalizer.normalize(key);
    AppLogger.d('[DanbooruTagsLazy] get("$key") -> normalizedKey="$normalizedKey"', 'DanbooruTagsLazy');

    // 尝试精确匹配
    if (_hotDataCache.containsKey(normalizedKey)) {
      final cached = _hotDataCache[normalizedKey];
      AppLogger.d('[DanbooruTagsLazy] cache hit: translation="${cached?.translation}"', 'DanbooruTagsLazy');
      return cached;
    }

    final record = await _tagDataSource.getByName(normalizedKey);
    AppLogger.d('[DanbooruTagsLazy] DB record: ${record != null ? "found" : "not found"}', 'DanbooruTagsLazy');
    if (record != null) {
      // 获取翻译（通过 TranslationDataSource）
      // TODO: 需要通过依赖注入获取 TranslationDataSource
      final translation = await _getTranslation(normalizedKey);
      AppLogger.d('[DanbooruTagsLazy] DB translation: "$translation"', 'DanbooruTagsLazy');
      return LocalTag(
        tag: record.tag,
        category: record.category,
        count: record.postCount,
        translation: translation,
      );
    }

    return null;
  }

  Future<List<LocalTag>> search(
    String query, {
    int? category,
    int limit = 20,
  }) async {
    // 使用新的数据源搜索标签
    final records = await _tagDataSource.search(
      query,
      limit: limit,
      category: category != null ? TagCategory.values.firstWhere(
        (c) => c.value == category,
        orElse: () => TagCategory.general,
      ) : null,
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

    // TODO: 需要通过依赖注入获取 TranslationDataSource 来批量获取翻译
    // 暂时返回没有翻译的标签
    return tags;
  }

  Future<List<LocalTag>> getHotTags({
    int? category,
    int minCount = 1000,
    int limit = 100,
  }) async {
    final records = await _tagDataSource.getHotTags(
      limit: limit,
      category: category != null ? TagCategory.values.firstWhere(
        (c) => c.value == category,
        orElse: () => TagCategory.general,
      ) : null,
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

    // TODO: 需要通过依赖注入获取 TranslationDataSource 来批量获取翻译
    // 暂时返回没有翻译的标签
    return tags;
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
      var downloadFailed = false;

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
            downloadFailed = true;
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

      // 如果下载失败，抛出异常以确保不更新 _lastUpdate
      if (downloadFailed) {
        throw Exception('Danbooru 标签下载失败');
      }

      _onProgress?.call(0.95, '导入数据库...');

      // 导入数据 - 使用新的数据源
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
      await _tagDataSource.upsertBatch(records);
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
      // 下载失败时不更新 _lastUpdate，确保下次启动会重新尝试下载
      rethrow;
    } finally {
      _isRefreshing = false;
      _isCancelled = false;
    }
  }

  void cancelRefresh() {
    _isCancelled = true;
  }

  /// 拉取画师标签（category = 1）
  ///
  /// 特点：
  /// - 后台顺序拉取，不阻塞UI
  /// - 使用分页和并发控制避免限流
  /// - 分批写入数据库，避免内存溢出
  /// - 进度回调显示当前页数和数量（不显示总数，因为画师标签数量不固定）
  Future<void> fetchArtistTags({
    required void Function(int currentPage, int importedCount, String message) onProgress,
    int maxPages = 100, // 画师标签量大，限制页数
  }) async {
    AppLogger.i('Starting artist tags fetch...', 'DanbooruTagsLazy');

    _isRefreshing = true;
    _isCancelled = false;

    var currentPage = 1;
    var importedCount = 0;
    const batchInsertThreshold = 5000; // 每5000条写入一次
    final records = <LocalTag>[];

    try {
      while (currentPage <= maxPages && !_isCancelled) {
        // 拉取一页画师标签（4页并发）
        const batchSize = _concurrentRequests;
        final remainingPages = maxPages - currentPage + 1;
        final actualBatchSize = batchSize < remainingPages ? batchSize : remainingPages;

        final futures = List.generate(actualBatchSize, (i) {
          final page = currentPage + i;
          return _fetchArtistTagsPage(page: page,);
        });

        final results = await Future.wait(futures);

        var batchHasData = false;
        for (var i = 0; i < results.length; i++) {
          final tags = results[i];
          if (tags != null && tags.isNotEmpty) {
            batchHasData = true;
            records.addAll(tags);
          }
        }

        if (!batchHasData) {
          AppLogger.i('No more artist tags available', 'DanbooruTagsLazy');
          break;
        }

        // 达到阈值，批量写入
        if (records.length >= batchInsertThreshold) {
          final dbRecords = records
              .map((t) => DanbooruTagRecord(
                    tag: t.tag,
                    category: 1, // 画师标签 category = 1
                    postCount: t.count,
                    lastUpdated: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  ),)
              .toList();

          await _tagDataSource.upsertBatch(dbRecords);
          importedCount += records.length;
          records.clear();

          // 进度回调：显示当前页数和数量（不显示总页数）
          onProgress(
            currentPage + actualBatchSize - 1,
            importedCount,
            '第 ${currentPage + actualBatchSize - 1} 页，已导入 $importedCount 条',
          );

          // 让出时间片，避免阻塞UI
          await Future.delayed(const Duration(milliseconds: 100));
        }

        currentPage += actualBatchSize;

        // 请求间隔，避免限流
        if (currentPage <= maxPages && !_isCancelled) {
          await Future.delayed(const Duration(milliseconds: _requestIntervalMs));
        }
      }

      // 写入剩余数据
      if (records.isNotEmpty && !_isCancelled) {
        final dbRecords = records
            .map((t) => DanbooruTagRecord(
                  tag: t.tag,
                  category: 1,
                  postCount: t.count,
                  lastUpdated: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                ),)
            .toList();

        await _tagDataSource.upsertBatch(dbRecords);
        importedCount += records.length;
      }

      onProgress(
        currentPage - 1,
        importedCount,
        '画师标签导入完成，共 $importedCount 条',
      );

      AppLogger.i('Artist tags fetch completed: $importedCount tags', 'DanbooruTagsLazy');
    } catch (e, stack) {
      AppLogger.e('Failed to fetch artist tags', e, stack, 'DanbooruTagsLazy');
      rethrow;
    } finally {
      _isRefreshing = false;
      _isCancelled = false;
    }
  }

  /// 拉取画师标签页
  Future<List<LocalTag>?> _fetchArtistTagsPage({required int page}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl$_tagsEndpoint',
        queryParameters: {
          'page': page,
          'limit': _pageSize,
          'search[order]': 'count',
          'search[category]': '1', // 只拉取画师标签
        },
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
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      AppLogger.w('Failed to fetch artist tags page $page: $e', 'DanbooruTagsLazy');
      return null;
    } catch (e) {
      AppLogger.w('Failed to fetch artist tags page $page: $e', 'DanbooruTagsLazy');
      return null;
    }
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

  // ===========================================================================
  // V2: 三阶段预热架构支持
  // ===========================================================================

  /// V2: 轻量级初始化（仅检查状态）
  Future<void> initializeLightweight() async {
    if (_isInitialized) return;

    try {
      await _tagDataSource.getCount();
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
      final tagCount = await _tagDataSource.getCount();
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
    if (_lastUpdate == null) {
      await _loadMeta();
    }
    return _refreshInterval.shouldRefresh(_lastUpdate);
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
    return await _tagDataSource.getCount();
  }

  // ===========================================================================
  // 分层标签拉取支持（预打包数据库 + 分层获取架构）
  // ===========================================================================

  /// 拉取一般标签（非画师标签，category != 1）
  ///
  /// 用于预热阶段快速拉取高频一般标签，排除数量庞大的画师标签
  Future<void> fetchGeneralTags({
    required int threshold,
    required int maxPages,
  }) async {
    _onProgress?.call(0.0, '准备拉取标签...');

    final allTags = <LocalTag>[];
    var currentPage = 1;

    while (currentPage <= maxPages && !_isCancelled) {
      // 并发拉取多页
      final remainingPages = maxPages - currentPage + 1;
      final actualBatchSize = _concurrentRequests < remainingPages
          ? _concurrentRequests
          : remainingPages;

      final futures = List.generate(actualBatchSize, (i) {
        final page = currentPage + i;
        return _fetchTagsPageWithCategory(
          page: page,
          threshold: threshold,
          excludeCategory: 1, // 排除画师标签 category=1
        );
      });

      final results = await Future.wait(futures);

      for (final tags in results) {
        if (tags != null) {
          allTags.addAll(tags);
        }
      }

      // 报告进度
      final progress = currentPage / maxPages;
      _onProgress?.call(
        progress * 0.9,
        '已拉取 ${allTags.length} 条标签',
      );

      currentPage += actualBatchSize;

      // 间隔避免限流
      if (currentPage <= maxPages && !_isCancelled) {
        await Future.delayed(
          const Duration(milliseconds: _requestIntervalMs),
        );
      }
    }

    if (_isCancelled) {
      AppLogger.w('General tags fetch cancelled', 'DanbooruTagsLazy');
      return;
    }

    // 导入数据库
    _onProgress?.call(0.95, '导入数据库...');
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

    await _tagDataSource.upsertBatch(records);

    _onProgress?.call(1.0, '标签拉取完成');
    AppLogger.i(
      'General tags fetched: ${allTags.length} tags (threshold >= $threshold)',
      'DanbooruTagsLazy',
    );
  }

  /// 拉取指定页的标签（带分类过滤）
  Future<List<LocalTag>?> _fetchTagsPageWithCategory({
    required int page,
    required int threshold,
    required int excludeCategory,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl$_tagsEndpoint',
        queryParameters: {
          'page': page,
          'limit': _pageSize,
          'search[order]': 'count',
          'search[post_count]': '>=$threshold',
          // 不指定category，在结果中过滤
        },
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
        final tags = (response.data as List)
            .map((item) {
              if (item is Map<String, dynamic>) {
                return LocalTag(
                  tag: (item['name'] as String?)?.toLowerCase() ?? '',
                  category: item['category'] as int? ?? 0,
                  count: item['post_count'] as int? ?? 0,
                );
              }
              return null;
            })
            .where((tag) => tag != null && tag.tag.isNotEmpty)
            .cast<LocalTag>()
            .where((tag) => tag.category != excludeCategory) // 过滤画师标签
            .toList();
        return tags;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      AppLogger.w('Failed to fetch page $page: $e', 'DanbooruTagsLazy');
    } catch (e) {
      AppLogger.w('Failed to fetch page $page: $e', 'DanbooruTagsLazy');
    }
    return null;
  }
}

@Riverpod(keepAlive: true)
Future<DanbooruTagsLazyService> danbooruTagsLazyService(Ref ref) async {
  final tagDataSource = await ref.watch(danbooruTagDataSourceProvider.future);
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );
  return DanbooruTagsLazyService(tagDataSource, dio);
}

/// 辅助方法：获取翻译（临时实现）
Future<String?> _getTranslation(String tag) async {
  // TODO: 需要从 TranslationDataSource 获取翻译
  // 这是一个临时实现，实际应该从依赖注入获取
  return null;
}
