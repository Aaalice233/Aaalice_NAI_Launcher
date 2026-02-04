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
import 'danbooru_tags_sqlite_service.dart';
import 'lazy_data_source_service.dart';

part 'danbooru_tags_lazy_service.g.dart';

/// Danbooru 标签懒加载服务
/// 实现 LazyDataSourceService 接口，提供统一的懒加载架构
class DanbooruTagsLazyService implements LazyDataSourceService<LocalTag> {
  /// Danbooru API 基础 URL
  static const String _baseUrl = 'https://danbooru.donmai.us';

  /// 标签 API 端点
  static const String _tagsEndpoint = '/tags.json';

  /// 每页最大数量
  static const int _pageSize = 1000;

  /// 最大页数（安全限制）
  static const int _maxPages = 200;

  /// 并发请求数
  static const int _concurrentRequests = 4;

  /// 请求间隔（毫秒）
  static const int _requestIntervalMs = 100;

  /// 缓存目录名
  static const String _cacheDirName = 'tag_cache';

  /// 元数据文件名
  static const String _metaFileName = 'danbooru_tags_meta.json';

  /// SQLite 存储服务
  final DanbooruTagsSqliteService _sqliteService;

  /// HTTP 客户端
  final Dio _dio;

  /// 内存中的热数据缓存
  final Map<String, LocalTag> _hotDataCache = {};

  /// 是否已初始化
  bool _isInitialized = false;

  /// 是否正在刷新
  bool _isRefreshing = false;

  /// 刷新进度回调
  DataSourceProgressCallback? _onProgress;

  @override
  DataSourceProgressCallback? get onProgress => _onProgress;

  /// 上次更新时间
  DateTime? _lastUpdate;

  /// 当前热度阈值
  int _currentThreshold = 1000;

  /// 自动刷新间隔
  AutoRefreshInterval _refreshInterval = AutoRefreshInterval.days30;

  DanbooruTagsLazyService(this._sqliteService, this._dio) {
    // 异步加载元数据
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

  /// 获取上次更新时间
  DateTime? get lastUpdate => _lastUpdate;

  /// 获取当前热度阈值
  int get currentThreshold => _currentThreshold;

  /// 获取当前刷新间隔
  AutoRefreshInterval get refreshInterval => _refreshInterval;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _onProgress?.call(0.0, '初始化标签数据...');

      // 1. 确保 SQLite 数据库已初始化
      await _sqliteService.initialize();
      _onProgress?.call(0.2, '数据库已就绪');

      // 2. 检查是否需要下载数据（首次使用或需要刷新）
      final needsDownload = await shouldRefresh();

      if (needsDownload) {
        _onProgress?.call(0.3, '需要下载标签数据...');
        AppLogger.i('Danbooru tags need download, starting...', 'DanbooruTagsLazy');

        // 执行下载和导入
        await refresh();

        _onProgress?.call(0.9, '标签数据下载完成');
      } else {
        _onProgress?.call(0.5, '使用本地缓存数据');
      }

      // 3. 加载热数据到内存
      await _loadHotData();
      _onProgress?.call(1.0, '标签数据初始化完成');

      _isInitialized = true;
      AppLogger.i('Danbooru tags lazy service initialized', 'DanbooruTagsLazy');
    } catch (e, stack) {
      AppLogger.e(
        'Failed to initialize Danbooru tags lazy service',
        e,
        stack,
        'DanbooruTagsLazy',
      );
      // 即使失败也标记为已初始化，避免阻塞启动
      _isInitialized = true;
    }
  }

  /// 加载热数据到内存缓存
  Future<void> _loadHotData() async {
    _onProgress?.call(0.0, '加载热数据...');

    // 从 SQLite 加载热标签
    final tags = await _sqliteService.getTags(hotKeys.toList());

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

    // 1. 检查内存缓存
    if (_hotDataCache.containsKey(normalizedKey)) {
      return _hotDataCache[normalizedKey];
    }

    // 2. 从 SQLite 查询
    final tag = await _sqliteService.getTag(normalizedKey);
    if (tag != null) {
      // 添加到热缓存
      _hotDataCache[normalizedKey] = tag;
      return tag;
    }

    return null;
  }

  @override
  Future<List<LocalTag>> getMultiple(List<String> keys) async {
    if (keys.isEmpty) return [];

    final normalizedKeys = keys.map((k) => k.toLowerCase().trim()).toList();

    // 批量从 SQLite 获取
    return await _sqliteService.getTags(normalizedKeys);
  }

  /// 搜索标签（用于标签联想）
  Future<List<LocalTag>> searchTags(
    String query, {
    int? category,
    int limit = 20,
  }) async {
    return await _sqliteService.searchTags(
      query,
      category: category,
      limit: limit,
    );
  }

  /// 获取热门标签
  Future<List<LocalTag>> getHotTags({
    int? category,
    int minCount = 1000,
    int limit = 100,
  }) async {
    return await _sqliteService.getHotTags(
      category: category,
      minCount: minCount,
      limit: limit,
    );
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
    _onProgress?.call(0.0, '开始同步标签...');

    try {
      final allTags = <LocalTag>[];
      var currentPage = 1;
      var consecutiveEmpty = 0;
      var estimatedTotalTags = _estimateTotalTags(_currentThreshold);

      // 使用并发请求优化
      while (currentPage <= _maxPages && !_isCancelled) {
        const batchSize = _concurrentRequests;
        final remainingPages = _maxPages - currentPage + 1;
        final actualBatchSize = batchSize < remainingPages ? batchSize : remainingPages;

        // 并发拉取本批页面
        final futures = List.generate(actualBatchSize, (i) {
          final page = currentPage + i;
          return _fetchTagsPage(page, _currentThreshold);
        });

        final results = await Future.wait(futures);

        // 处理结果
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

        // 动态调整预估总数
        if (allTags.length >= estimatedTotalTags && batchHasData) {
          estimatedTotalTags = allTags.length + _pageSize * 2;
        }

        // 更新进度
        final progress = (allTags.length / estimatedTotalTags).clamp(0.0, 0.95);
        final percent = (progress * 100).toInt();
        _onProgress?.call(progress, '拉取标签... $percent% (${allTags.length})');

        currentPage += actualBatchSize;

        // 速率限制
        if (currentPage <= _maxPages && !_isCancelled && batchHasData) {
          await Future.delayed(
            const Duration(milliseconds: _requestIntervalMs),
          );
        }
      }

      _onProgress?.call(0.95, '导入数据库...');

      // 导入到 SQLite
      await _sqliteService.importTags(
        allTags,
        onProgress: (processed, total) {
          final progress = 0.95 + (processed / total) * 0.04;
          _onProgress?.call(progress, '导入: $processed / $total');
        },
      );

      _onProgress?.call(0.99, '更新热数据...');

      // 重新加载热数据
      await _loadHotData();

      // 保存元数据
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

  bool _isCancelled = false;

  /// 取消刷新
  void cancelRefresh() {
    _isCancelled = true;
  }

  /// 估算标签总数
  int _estimateTotalTags(int minPostCount) {
    if (minPostCount >= 10000) return 5000;
    if (minPostCount >= 5000) return 10000;
    if (minPostCount >= 1000) return 50000;
    if (minPostCount >= 100) return 200000;
    return 500000;
  }

  /// 拉取一页标签
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
      if (e.response?.statusCode == 429) {
        AppLogger.w('Rate limited, waiting...', 'DanbooruTagsLazy');
        await Future.delayed(const Duration(seconds: 2));
        return _fetchTagsPage(page, minPostCount);
      }
      AppLogger.e('Failed to fetch tags page $page', e, null, 'DanbooruTagsLazy');
      return null;
    }
  }

  /// 获取缓存目录
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDirName');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// 加载元数据
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

      // 加载刷新间隔设置
      final prefs = await SharedPreferences.getInstance();
      final days = prefs.getInt(StorageKeys.danbooruTagsRefreshIntervalDays);
      if (days != null) {
        _refreshInterval = AutoRefreshInterval.fromDays(days);
      }
    } catch (e) {
      AppLogger.w('Failed to load Danbooru tags meta: $e', 'DanbooruTagsLazy');
    }
  }

  /// 保存元数据
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

      // 同时保存到 SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        StorageKeys.danbooruTagsLastUpdate,
        now.toIso8601String(),
      );
    } catch (e) {
      AppLogger.w('Failed to save Danbooru tags meta: $e', 'DanbooruTagsLazy');
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      // 1. 先清除 SQLite 数据，然后关闭数据库（释放文件锁）
      await _sqliteService.clearAll();
      await _sqliteService.close();

      // 2. 清除内存缓存和状态
      _hotDataCache.clear();
      _lastUpdate = null;
      _isInitialized = false; // 重置初始化标志，确保下次会重新初始化
      _isRefreshing = false;

      // 3. 删除缓存文件
      try {
        final cacheDir = await _getCacheDirectory();
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
        }
      } catch (e) {
        AppLogger.w('Failed to delete Danbooru cache directory: $e', 'DanbooruTagsLazy');
      }

      // 4. 清除 SharedPreferences 中的元数据
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.danbooruTagsLastUpdate);
      await prefs.remove(StorageKeys.danbooruTagsRefreshIntervalDays);
      await prefs.remove(StorageKeys.danbooruTagsHotThreshold);

      AppLogger.i('Danbooru tags cache cleared', 'DanbooruTagsLazy');
    } catch (e) {
      AppLogger.w('Failed to clear Danbooru tags cache: $e', 'DanbooruTagsLazy');
    }
  }

  /// 获取当前热度档位设置
  Future<TagHotPreset> getHotPreset() async {
    final prefs = await SharedPreferences.getInstance();
    final threshold = prefs.getInt(StorageKeys.danbooruTagsHotThreshold);
    return TagHotPreset.fromThreshold(threshold ?? 1000);
  }

  /// 设置热度档位
  Future<void> setHotPreset(TagHotPreset preset, {int? customThreshold}) async {
    final prefs = await SharedPreferences.getInstance();
    final threshold =
        preset.isCustom ? (customThreshold ?? 1000) : preset.threshold;
    await prefs.setInt(StorageKeys.danbooruTagsHotThreshold, threshold);
    _currentThreshold = threshold;
  }

  /// 获取自动刷新间隔
  Future<AutoRefreshInterval> getRefreshInterval() async {
    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getInt(StorageKeys.danbooruTagsRefreshIntervalDays);
    return AutoRefreshInterval.fromDays(days ?? 30);
  }

  /// 设置自动刷新间隔
  Future<void> setRefreshInterval(AutoRefreshInterval interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.danbooruTagsRefreshIntervalDays, interval.days);
    _refreshInterval = interval;
  }
}

/// DanbooruTagsLazyService Provider
@Riverpod(keepAlive: true)
DanbooruTagsLazyService danbooruTagsLazyService(Ref ref) {
  final sqliteService = ref.watch(danbooruTagsSqliteServiceProvider);
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'NAI-Launcher/1.0',
      },
    ),
  );

  return DanbooruTagsLazyService(sqliteService, dio);
}

/// DanbooruTagsSqliteService Provider
@Riverpod(keepAlive: true)
DanbooruTagsSqliteService danbooruTagsSqliteService(Ref ref) {
  return DanbooruTagsSqliteService();
}
