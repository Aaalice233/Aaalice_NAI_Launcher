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
  Future<void>? _metaLoadFuture;
  int _totalTags = 0;

  @override
  DataSourceProgressCallback? get onProgress => _onProgress;

  DanbooruTagsLazyService(this._unifiedDb, this._dio) {
    _metaLoadFuture = _loadMeta();
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
      _onProgress?.call(1.0, '标签数据已就绪');
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

      // 预构建数据库检测：如果有足够的标签（>30000条），视为预构建数据库
      const prebuiltThreshold = 30000;
      final isPrebuiltDatabase = tagCount >= prebuiltThreshold;

      if (isPrebuiltDatabase) {
        AppLogger.i(
          'Detected prebuilt database with $tagCount Danbooru tags, skipping download',
          'DanbooruTagsLazy',
        );
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

      // 等待元数据加载完成，避免竞争条件
      await _metaLoadFuture;

      // 验证缓存状态：检查数据库计数是否与元数据匹配
      final validationResult = await _validateCacheState();
      AppLogger.i(
        '[DanbooruTagsLazy] 缓存状态验证: ${validationResult.reason}',
        'DanbooruTagsLazy',
      );

      // 如果缓存状态无效，强制刷新
      if (!validationResult.isValid) {
        AppLogger.w(
          '[DanbooruTagsLazy] 缓存状态无效，需要重新下载: ${validationResult.reason}',
          'DanbooruTagsLazy',
        );
        _lastUpdate = null;
      }

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

    // 诊断：记录热键配置
    AppLogger.d(
      '[DanbooruTagsLazy] _loadHotData: '
      'requestedHotKeys=${hotKeys.length} '
      'hotKeysSample=${hotKeys.take(5).join(",")}',
      'DanbooruTagsLazy',
    );

    final records = await _unifiedDb.getDanbooruTags(hotKeys.toList());

    // 诊断：记录数据库返回情况
    AppLogger.d(
      '[DanbooruTagsLazy] _loadHotData: '
      'dbReturned=${records.length} '
      'requested=${hotKeys.length} '
      'foundTags=${records.map((r) => r.tag).join(",")}',
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

      for (final tag in tags) {
        // 统一使用标准化标签作为 key 查找翻译
        final normalizedTag = TagNormalizer.normalize(tag.tag);
        final translation = translations[normalizedTag];
        AppLogger.d(
          '[_loadHotData] tag="${tag.tag}", '
          'normalized="$normalizedTag", '
          'translation="$translation"',
          'DanbooruTagsLazy',
        );

        // 诊断：记录缓存键存储决策
        final cacheKey = tag.tag; // 使用原始标签作为缓存键
        AppLogger.d(
          '[DanbooruTagsLazy] cacheKeyDecision: '
          'original="${tag.tag}" '
          'normalized="$normalizedTag" '
          'usingKey="$cacheKey" '
          'hasTranslation=${translation != null}',
          'DanbooruTagsLazy',
        );

        if (translation != null) {
          _hotDataCache[cacheKey] = tag.copyWith(translation: translation);
        } else {
          _hotDataCache[cacheKey] = tag;
        }
      }
    }

    _onProgress?.call(1.0, '热数据加载完成');

    // 诊断：记录最终缓存状态
    AppLogger.i(
      'Loaded ${_hotDataCache.length} hot Danbooru tags into memory. '
      'Cache keys sample: ${_hotDataCache.keys.take(5).join(",")}',
      'DanbooruTagsLazy',
    );

    // 诊断：检查热键匹配情况
    final loadedKeys = _hotDataCache.keys.toSet();
    final missingKeys = hotKeys.where((k) => !loadedKeys.contains(k)).toList();
    if (missingKeys.isNotEmpty) {
      AppLogger.w(
        '[DanbooruTagsLazy] _loadHotData: missing hot keys: ${missingKeys.join(",")}',
        'DanbooruTagsLazy',
      );
    }
  }

  @override
  Future<LocalTag?> get(String key) async {
    // 统一标准化标签
    final normalizedKey = TagNormalizer.normalize(key);
    AppLogger.d(
      '[DanbooruTagsLazy] get("$key") -> normalizedKey="$normalizedKey"',
      'DanbooruTagsLazy',
    );

    // 诊断：记录缓存决策的关键信息
    AppLogger.d(
      '[DanbooruTagsLazy] cacheDecision: '
      'input="$key" '
      'normalized="$normalizedKey" '
      'hotCacheSize=${_hotDataCache.length} '
      'cacheKeysSample=${_hotDataCache.keys.take(5).join(",")}',
      'DanbooruTagsLazy',
    );

    // 尝试精确匹配
    if (_hotDataCache.containsKey(normalizedKey)) {
      final cached = _hotDataCache[normalizedKey];
      AppLogger.d(
        '[DanbooruTagsLazy] cache hit: '
        'key="$normalizedKey" '
        'translation="${cached?.translation}" '
        'category=${cached?.category} '
        'count=${cached?.count}',
        'DanbooruTagsLazy',
      );
      return cached;
    }

    // 诊断：缓存未命中，记录可能的原因
    AppLogger.d(
      '[DanbooruTagsLazy] cache miss: '
      'key="$normalizedKey" '
      'inHotKeys=${hotKeys.contains(normalizedKey)} '
      'hotCacheHasKey=${_hotDataCache.containsKey(key)}',
      'DanbooruTagsLazy',
    );

    final record = await _unifiedDb.getDanbooruTag(normalizedKey);
    AppLogger.d(
      '[DanbooruTagsLazy] DB lookup: '
      'key="$normalizedKey" '
      'result=${record != null ? "found" : "not_found"}',
      'DanbooruTagsLazy',
    );

    if (record != null) {
      // 获取翻译
      final translation = await _unifiedDb.getTranslation(normalizedKey);
      AppLogger.d(
        '[DanbooruTagsLazy] DB translation: '
        'key="$normalizedKey" '
        'translation="$translation"',
        'DanbooruTagsLazy',
      );
      return LocalTag(
        tag: record.tag,
        category: record.category,
        count: record.postCount,
        translation: translation,
      );
    }

    AppLogger.d(
      '[DanbooruTagsLazy] tag not found: '
      'key="$normalizedKey" '
      'source=both_cache_and_db',
      'DanbooruTagsLazy',
    );
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

      // 画师标签进度：45% ~ 90%
      final progress = 0.45 + (currentPage / _maxPages * 0.45).clamp(0.0, 0.45);
      _onProgress?.call(progress, '拉取画师标签... $artistTagCount 个 (第 $currentPage 页)');

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
        _totalTags = json['totalTags'] as int? ?? 0;
        AppLogger.d(
          '[DanbooruTagsLazy] _loadMeta: loaded metadata '
          'lastUpdate=$_lastUpdate, '
          'totalTags=$_totalTags, '
          'hotThreshold=$_currentThreshold',
          'DanbooruTagsLazy',
        );
      } else {
        AppLogger.d(
          '[DanbooruTagsLazy] _loadMeta: no metadata file found at ${metaFile.path}',
          'DanbooruTagsLazy',
        );
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
      _totalTags = totalTags;

      AppLogger.d(
        '[DanbooruTagsLazy] _saveMeta: saved metadata to ${metaFile.path} '
        'lastUpdate=$now, '
        'totalTags=$totalTags, '
        'hotThreshold=$_currentThreshold',
        'DanbooruTagsLazy',
      );

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
    _lastUpdate = null;
    _isInitialized = false;

    try {
      // 清除元数据文件
      final cacheDir = await _getCacheDirectory();
      final metaFile = File('${cacheDir.path}/$_metaFileName');
      if (await metaFile.exists()) {
        await metaFile.delete();
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
    return await _unifiedDb.getDanbooruTagCount();
  }

  /// 验证缓存状态：检查数据库计数是否与元数据匹配
  ///
  /// 返回验证结果，包含是否有效以及详细诊断信息
  Future<CacheValidationResult> _validateCacheState() async {
    try {
      // 等待元数据加载完成
      await _metaLoadFuture;

      // 获取实际数据库计数
      final actualCount = await _unifiedDb.getDanbooruTagCount();
      final metadataCount = _totalTags;

      // 诊断日志
      AppLogger.d(
        '[DanbooruTagsLazy] _validateCacheState: '
        'actualCount=$actualCount, '
        'metadataCount=$metadataCount, '
        'lastUpdate=$_lastUpdate',
        'DanbooruTagsLazy',
      );

      // 情况1：元数据不存在（从未同步过）
      if (_lastUpdate == null) {
        return CacheValidationResult(
          isValid: false,
          reason: '无缓存元数据（从未同步）',
          actualCount: actualCount,
          metadataCount: 0,
        );
      }

      // 情况2：数据库为空但元数据显示有数据
      if (actualCount == 0 && metadataCount > 0) {
        return CacheValidationResult(
          isValid: false,
          reason: '数据库为空但元数据显示有 $metadataCount 条记录',
          actualCount: 0,
          metadataCount: metadataCount,
        );
      }

      // 情况3：数据库有数据但元数据计数为0（异常情况）
      if (actualCount > 0 && metadataCount == 0) {
        AppLogger.w(
          '[DanbooruTagsLazy] 数据库有 $actualCount 条记录但元数据计数为0，'
          '可能使用了旧版本元数据',
          'DanbooruTagsLazy',
        );
        // 这种情况下认为缓存有效，但记录警告
        return CacheValidationResult(
          isValid: true,
          reason: '数据库有数据但元数据计数为0（旧版本兼容）',
          actualCount: actualCount,
          metadataCount: metadataCount,
        );
      }

      // 情况4：计数不匹配（允许小范围差异，可能是后台同步中断导致）
      const tolerancePercent = 0.05; // 5%容差
      final difference = (actualCount - metadataCount).abs();
      final maxAllowedDifference = (metadataCount * tolerancePercent).ceil();

      if (difference > maxAllowedDifference && metadataCount > 0) {
        return CacheValidationResult(
          isValid: false,
          reason: '数据库计数($actualCount)与元数据($metadataCount)不匹配，'
              '差异 $difference 超过容差($maxAllowedDifference)',
          actualCount: actualCount,
          metadataCount: metadataCount,
        );
      }

      // 缓存状态有效
      return CacheValidationResult(
        isValid: true,
        reason: '缓存状态正常',
        actualCount: actualCount,
        metadataCount: metadataCount,
      );
    } catch (e, stack) {
      AppLogger.e(
        '[DanbooruTagsLazy] 缓存状态验证失败',
        e,
        stack,
        'DanbooruTagsLazy',
      );
      return CacheValidationResult(
        isValid: false,
        reason: '验证过程出错: $e',
        actualCount: 0,
        metadataCount: _totalTags,
      );
    }
  }
}

/// 缓存状态验证结果
class CacheValidationResult {
  final bool isValid;
  final String reason;
  final int actualCount;
  final int metadataCount;

  const CacheValidationResult({
    required this.isValid,
    required this.reason,
    required this.actualCount,
    required this.metadataCount,
  });

  @override
  String toString() {
    return 'CacheValidationResult(isValid=$isValid, reason=$reason, '
        'actualCount=$actualCount, metadataCount=$metadataCount)';
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
