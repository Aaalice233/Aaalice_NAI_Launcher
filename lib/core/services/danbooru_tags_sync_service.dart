import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/cache/data_source_cache_meta.dart';
import '../../data/models/tag/local_tag.dart';
import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';

part 'danbooru_tags_sync_service.g.dart';

/// 画师同步进度回调
typedef ArtistsSyncProgressCallback = void Function(
  double progress,
  int fetched,
  int total,
);

/// 同步进度回调
typedef DanbooruSyncProgressCallback = void Function(
  double progress,
  String? message,
);

/// Danbooru 标签同步服务
/// 负责从 Danbooru API 批量拉取标签数据
class DanbooruTagsSyncService {
  /// Danbooru API 基础 URL
  static const String _baseUrl = 'https://danbooru.donmai.us';

  /// 标签 API 端点
  static const String _tagsEndpoint = '/tags.json';

  /// 每页最大数量（Danbooru 最大允许 1000）
  static const int _pageSize = 1000;

  /// 最大页数（安全限制）
  static const int _maxPages = 200;

  /// 并发请求数（同时拉取的页数）
  static const int _concurrentRequests = 4;

  /// 请求间隔（毫秒）- 批次间的间隔，避免被 ban
  static const int _requestIntervalMs = 100;

  /// 缓存目录名
  static const String _cacheDirName = 'tag_cache';

  /// 缓存文件名
  static const String _cacheFileName = 'danbooru_tags_api.csv';

  /// 元数据文件名
  static const String _metaFileName = 'danbooru_tags_meta.json';

  /// 画师缓存文件名
  static const String _artistsCacheFileName = 'danbooru_artists.csv';

  /// 画师元数据文件名
  static const String _artistsMetaFileName = 'danbooru_artists_meta.json';

  /// 画师分类 ID
  static const int _artistCategory = 1;

  final Dio _dio;

  /// 是否正在同步
  bool _isSyncing = false;

  /// 是否已取消
  bool _isCancelled = false;

  /// 同步进度回调
  DanbooruSyncProgressCallback? onSyncProgress;

  /// 当前缓存的标签数量
  int _cachedTagCount = 0;

  /// 上次更新时间
  DateTime? _lastUpdate;

  /// 当前热度阈值
  int _currentThreshold = 1000;

  /// 画师数据相关
  int _cachedArtistsCount = 0;
  DateTime? _artistsLastUpdate;
  bool _artistsSyncFailed = false;
  int _artistsMinPostCount = 50;

  /// 自动刷新间隔
  AutoRefreshInterval _refreshInterval = AutoRefreshInterval.days30;

  /// 是否正在同步画师
  bool _isSyncingArtists = false;

  /// 是否已取消画师同步
  bool _isArtistsCancelled = false;

  /// 画师同步进度回调
  ArtistsSyncProgressCallback? onArtistsSyncProgress;

  DanbooruTagsSyncService(this._dio);

  /// 是否正在同步
  bool get isSyncing => _isSyncing;

  /// 标签数量
  int get tagCount => _cachedTagCount;

  /// 上次更新时间
  DateTime? get lastUpdate => _lastUpdate;

  /// 当前热度阈值
  int get currentThreshold => _currentThreshold;

  /// 初始化（加载元数据）
  Future<void> initialize() async {
    try {
      final meta = await _loadMeta();
      if (meta != null) {
        _lastUpdate = meta.lastUpdate;
        _cachedTagCount = meta.totalTags;
        _currentThreshold = meta.hotThreshold;
      }

      // 加载画师元数据
      final artistsMeta = await _loadArtistsMeta();
      if (artistsMeta != null) {
        _artistsLastUpdate = artistsMeta.lastUpdate;
        _cachedArtistsCount = artistsMeta.totalArtists;
        _artistsSyncFailed = artistsMeta.syncFailed;
        _artistsMinPostCount = artistsMeta.minPostCount;
      }
    } catch (e) {
      AppLogger.w('Failed to load danbooru tags meta: $e', 'DanbooruSync');
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
    if (days != null) {
      _refreshInterval = AutoRefreshInterval.fromDays(days);
    }
    return _refreshInterval;
  }

  /// 设置自动刷新间隔
  Future<void> setRefreshInterval(AutoRefreshInterval interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.danbooruTagsRefreshIntervalDays, interval.days);
    _refreshInterval = interval;
  }

  /// 检查是否需要刷新
  bool get shouldRefresh => _refreshInterval.shouldRefresh(_lastUpdate);

  /// 同步热门标签
  Future<List<LocalTag>> syncHotTags({
    required int minPostCount,
    int maxTags = 100000,
  }) async {
    if (_isSyncing) {
      return await _loadFromCacheOrFallback();
    }

    _isSyncing = true;
    _isCancelled = false;
    _currentThreshold = minPostCount;

    try {
      onSyncProgress?.call(0, '开始同步标签...');

      final allTags = <LocalTag>[];
      var currentPage = 1;
      var consecutiveEmpty = 0;
      // 根据热度阈值预估总标签数（用于进度计算）
      var estimatedTotalTags = _estimateTotalTags(minPostCount);

      // 使用并发请求优化：每批并发拉取多页
      while (currentPage <= _maxPages && allTags.length < maxTags && !_isCancelled) {
        // 计算本批要拉取的页数
        const batchSize = _concurrentRequests;
        final remainingPages = _maxPages - currentPage + 1;
        final actualBatchSize = batchSize < remainingPages ? batchSize : remainingPages;

        // 并发拉取本批页面
        final futures = List.generate(actualBatchSize, (i) {
          final page = currentPage + i;
          return _fetchTagsPage(page, minPostCount);
        });

        final results = await Future.wait(futures);

        // 处理结果
        var batchHasData = false;
        for (var i = 0; i < results.length; i++) {
          final tags = results[i];
          final page = currentPage + i;

          if (tags == null) {
            AppLogger.w('Failed to fetch page $page, stopping', 'DanbooruSync');
            _isCancelled = true;
            break;
          }

          if (tags.isEmpty) {
            consecutiveEmpty++;
            if (consecutiveEmpty >= 2) {
              AppLogger.i('No more tags available (page $page)', 'DanbooruSync');
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

        // 动态调整预估总数（当实际数量超过预估时）
        if (allTags.length >= estimatedTotalTags && batchHasData) {
          estimatedTotalTags = allTags.length + _pageSize * 2;
        }

        // 更新进度：基于标签数量而非页数
        final progress = (allTags.length / estimatedTotalTags).clamp(0.0, 0.95);
        onSyncProgress?.call(
          progress,
          '${(progress * 100).toInt()}%',
        );

        currentPage += actualBatchSize;

        // 速率限制：批次间短暂等待，避免被 ban
        if (currentPage <= _maxPages && !_isCancelled && batchHasData) {
          await Future.delayed(
            const Duration(milliseconds: _requestIntervalMs),
          );
        }
      }

      if (_isCancelled) {
        onSyncProgress?.call(1.0, '同步已取消');
        return await _loadFromCacheOrFallback();
      }

      // 保存到缓存
      await _saveToCache(allTags, minPostCount);

      _cachedTagCount = allTags.length;
      _lastUpdate = DateTime.now();

      onSyncProgress?.call(1.0, '同步完成');

      AppLogger.i(
        'Synced ${allTags.length} tags from Danbooru (threshold: $minPostCount)',
        'DanbooruSync',
      );

      return allTags;
    } catch (e, stack) {
      AppLogger.e('Failed to sync tags', e, stack, 'DanbooruSync');
      onSyncProgress?.call(1.0, '同步失败，使用本地数据');

      return await _loadFromCacheOrFallback();
    } finally {
      _isSyncing = false;
    }
  }

  /// 取消同步
  void cancelSync() {
    _isCancelled = true;
  }

  /// 估算标签总数（用于进度计算）
  int _estimateTotalTags(int minPostCount) {
    // 根据热度阈值估算标签数量（基于 Danbooru 实际数据分布）
    if (minPostCount >= 10000) return 5000; // >1万投稿的标签约5000个
    if (minPostCount >= 5000) return 10000; // >5000投稿的标签约1万个
    if (minPostCount >= 1000) return 50000; // >1000投稿的标签约5万个
    if (minPostCount >= 100) return 200000; // >100投稿的标签约20万个
    return 500000; // 全部标签约50万个
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
        // Rate limited, wait and retry
        AppLogger.w('Rate limited, waiting...', 'DanbooruSync');
        await Future.delayed(const Duration(seconds: 2));
        return _fetchTagsPage(page, minPostCount);
      }
      AppLogger.e(
        'Failed to fetch tags page $page: $e',
        e,
        null,
        'DanbooruSync',
      );
      return null;
    }
  }

  /// 从缓存或本地回退加载
  Future<List<LocalTag>> _loadFromCacheOrFallback() async {
    try {
      final cached = await _loadFromCache();
      if (cached.isNotEmpty) {
        return cached;
      }
    } catch (e) {
      AppLogger.w('Failed to load from cache: $e', 'DanbooruSync');
    }

    return await _loadLocalFallback();
  }

  /// 从缓存加载
  Future<List<LocalTag>> _loadFromCache() async {
    final cacheDir = await _getCacheDirectory();
    final cacheFile = File('${cacheDir.path}/$_cacheFileName');

    if (!await cacheFile.exists()) {
      return [];
    }

    final content = await cacheFile.readAsString();
    return await Isolate.run(() => _parseCsvContent(content));
  }

  /// 解析 CSV 内容
  static List<LocalTag> _parseCsvContent(String content) {
    final tags = <LocalTag>[];
    final lines = content.split('\n');

    // 跳过标题行
    final startIndex =
        lines.isNotEmpty && lines[0].toLowerCase().startsWith('tag,') ? 1 : 0;

    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      if (parts.length >= 3) {
        final tag = LocalTag(
          tag: parts[0].trim().toLowerCase(),
          category: int.tryParse(parts[1].trim()) ?? 0,
          count: int.tryParse(parts[2].trim()) ?? 0,
        );
        if (tag.tag.isNotEmpty) {
          tags.add(tag);
        }
      }
    }

    return tags;
  }

  /// 加载本地回退数据
  Future<List<LocalTag>> _loadLocalFallback() async {
    try {
      final csvData =
          await rootBundle.loadString('assets/translations/danbooru.csv');
      final tags = <LocalTag>[];
      final lines = csvData.split('\n');

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        final parts = line.split(',');
        if (parts.isNotEmpty) {
          final tag = LocalTag(
            tag: parts[0].trim().toLowerCase(),
            count: 1000, // 默认计数
          );
          if (tag.tag.isNotEmpty) {
            tags.add(tag);
          }
        }
      }

      _cachedTagCount = tags.length;
      AppLogger.i(
        'Loaded ${tags.length} tags from local fallback',
        'DanbooruSync',
      );

      return tags;
    } catch (e) {
      AppLogger.e('Failed to load local fallback', e, null, 'DanbooruSync');
      return [];
    }
  }

  /// 保存到缓存
  Future<void> _saveToCache(List<LocalTag> tags, int threshold) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheFile = File('${cacheDir.path}/$_cacheFileName');
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      // 保存 CSV
      final csvContent = StringBuffer('tag,category,count\n');
      for (final tag in tags) {
        csvContent.writeln('${tag.tag},${tag.category},${tag.count}');
      }
      await cacheFile.writeAsString(csvContent.toString());

      // 保存元数据
      await metaFile.writeAsString(
        json.encode({
          'lastUpdate': DateTime.now().toIso8601String(),
          'totalTags': tags.length,
          'hotThreshold': threshold,
        }),
      );

      AppLogger.d('Danbooru tags cache saved', 'DanbooruSync');
    } catch (e) {
      AppLogger.w('Failed to save cache: $e', 'DanbooruSync');
    }
  }

  /// 加载元数据
  Future<TagsCacheMeta?> _loadMeta() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      if (!await metaFile.exists()) {
        return null;
      }

      final content = await metaFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return TagsCacheMeta.fromJson(json);
    } catch (e) {
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

  /// 清除缓存
  Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheFile = File('${cacheDir.path}/$_cacheFileName');
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
      if (await metaFile.exists()) {
        await metaFile.delete();
      }

      _cachedTagCount = 0;
      _lastUpdate = null;
      AppLogger.i('Danbooru tags cache cleared', 'DanbooruSync');
    } catch (e) {
      AppLogger.w('Failed to clear cache: $e', 'DanbooruSync');
    }
  }

  // ==================== 画师同步相关方法 ====================

  /// 获取画师同步设置（默认开启）
  Future<bool> getSyncArtistsSetting() async {
    final prefs = await SharedPreferences.getInstance();
    // 如果键不存在，说明是旧版本升级，返回 true 以触发首次同步
    if (!prefs.containsKey(StorageKeys.danbooruSyncArtists)) {
      return true;
    }
    return prefs.getBool(StorageKeys.danbooruSyncArtists) ?? true;
  }

  /// 设置画师同步开关
  Future<void> setSyncArtistsSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.danbooruSyncArtists, value);
  }

  /// 获取画师标签数量
  int get cachedArtistsCount => _cachedArtistsCount;

  /// 获取画师数据最后更新时间
  DateTime? get artistsLastUpdate => _artistsLastUpdate;

  /// 获取画师同步失败状态
  bool get artistsSyncFailed => _artistsSyncFailed;

  /// 检查是否需要同步画师数据
  Future<bool> shouldSyncArtists() async {
    final syncEnabled = await getSyncArtistsSetting();
    if (!syncEnabled) return false;

    // 如果上次同步失败，需要重试
    if (_artistsSyncFailed) return true;

    // 如果没有数据，需要同步
    if (_cachedArtistsCount == 0) return true;

    // 如果超过30天未更新，建议同步
    if (_artistsLastUpdate != null) {
      final daysSinceUpdate = DateTime.now().difference(_artistsLastUpdate!).inDays;
      return daysSinceUpdate >= 30;
    }

    return true;
  }

  /// 同步画师标签
  Future<List<LocalTag>> syncArtists({
    bool force = false,
    int minPostCount = 50,
  }) async {
    if (_isSyncingArtists) {
      return await loadArtistsFromCache();
    }

    // 检查是否需要同步
    if (!force) {
      final shouldSync = await shouldSyncArtists();
      if (!shouldSync) {
        return await loadArtistsFromCache();
      }
    }

    _isSyncingArtists = true;
    _isArtistsCancelled = false;
    _artistsMinPostCount = minPostCount;

    try {
      onArtistsSyncProgress?.call(0.0, 0, 0);

      final allArtists = <LocalTag>[];
      var currentPage = 1;
      var consecutiveEmpty = 0;
      const maxPages = 100; // 画师数据页数限制
      // 估算画师总数（用于进度计算）：
      // >50 投稿的画师约有 3-5 万个
      var estimatedTotalArtists = minPostCount >= 100 ? 10000 : 50000;

      // 使用并发请求优化：每批并发拉取多页
      while (currentPage <= maxPages && !_isArtistsCancelled) {
        // 计算本批要拉取的页数
        const batchSize = _concurrentRequests;
        final remainingPages = maxPages - currentPage + 1;
        final actualBatchSize = batchSize < remainingPages ? batchSize : remainingPages;

        // 并发拉取本批页面
        final futures = List.generate(actualBatchSize, (i) {
          final page = currentPage + i;
          return _fetchArtistsPage(page, minPostCount);
        });

        final results = await Future.wait(futures);

        // 处理结果
        var batchHasData = false;
        for (var i = 0; i < results.length; i++) {
          final artists = results[i];
          final page = currentPage + i;

          if (artists == null) {
            AppLogger.w('Failed to fetch artists page $page, stopping', 'DanbooruSync');
            // 标记同步失败
            await _saveArtistsMeta(syncFailed: true);
            _artistsSyncFailed = true;
            _isArtistsCancelled = true;
            break;
          }

          if (artists.isEmpty) {
            consecutiveEmpty++;
            if (consecutiveEmpty >= 2) {
              AppLogger.i('No more artists available (page $page)', 'DanbooruSync');
              _isArtistsCancelled = true;
              break;
            }
          } else {
            consecutiveEmpty = 0;
            batchHasData = true;
            allArtists.addAll(artists);
          }
        }

        if (_isArtistsCancelled) break;

        // 动态调整预估总数（当实际数量超过预估时）
        if (allArtists.length >= estimatedTotalArtists && batchHasData) {
          estimatedTotalArtists = allArtists.length + _pageSize * 2;
        }

        // 更新进度：基于画师数量而非页数
        final progress = (allArtists.length / estimatedTotalArtists).clamp(0.0, 0.95);
        onArtistsSyncProgress?.call(
          progress,
          allArtists.length,
          estimatedTotalArtists,
        );

        currentPage += actualBatchSize;

        // 速率限制：批次间短暂等待，避免被 ban
        if (currentPage <= maxPages && !_isArtistsCancelled && batchHasData) {
          await Future.delayed(
            const Duration(milliseconds: _requestIntervalMs),
          );
        }
      }

      // 如果用户取消同步，不保存部分数据，直接返回已有缓存
      if (_isArtistsCancelled) {
        onArtistsSyncProgress?.call(1.0, allArtists.length, allArtists.length);
        AppLogger.w('Artists sync cancelled, not saving partial data', 'DanbooruSync');
        return await loadArtistsFromCache();
      }

      // 保存到缓存（只有完整同步才会执行到这里）
      await _saveArtistsToCache(allArtists, minPostCount);

      _cachedArtistsCount = allArtists.length;
      _artistsLastUpdate = DateTime.now();
      _artistsSyncFailed = false;

      onArtistsSyncProgress?.call(1.0, allArtists.length, allArtists.length);

      AppLogger.i(
        'Synced ${allArtists.length} artists from Danbooru (threshold: $minPostCount)',
        'DanbooruSync',
      );

      return allArtists;
    } catch (e, stack) {
      AppLogger.e('Failed to sync artists', e, stack, 'DanbooruSync');
      // 标记同步失败
      await _saveArtistsMeta(syncFailed: true);
      _artistsSyncFailed = true;
      onArtistsSyncProgress?.call(1.0, 0, 0);
      return await loadArtistsFromCache();
    } finally {
      _isSyncingArtists = false;
    }
  }

  /// 取消画师同步
  void cancelArtistsSync() {
    _isArtistsCancelled = true;
  }

  /// 拉取一页画师标签
  Future<List<LocalTag>?> _fetchArtistsPage(int page, int minPostCount) async {
    try {
      final queryParams = <String, dynamic>{
        'search[order]': 'count',
        'search[hide_empty]': 'true',
        'search[category]': '$_artistCategory', // 只获取艺术家分类
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
        final artists = <LocalTag>[];
        for (final item in response.data as List) {
          if (item is Map<String, dynamic>) {
            // 强制使用艺术家分类(1)，确保分类正确
            // 即使API返回了其他分类，我们也强制设为1，因为我们查询时就是按艺术家分类过滤的
            final artist = LocalTag(
              tag: (item['name'] as String?)?.toLowerCase() ?? '',
              category: _artistCategory, // 强制设为1(艺术家)
              count: item['post_count'] as int? ?? 0,
            );
            if (artist.tag.isNotEmpty) {
              artists.add(artist);
            }
          }
        }
        return artists;
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        // Rate limited, wait and retry
        AppLogger.w('Rate limited when fetching artists, waiting...', 'DanbooruSync');
        await Future.delayed(const Duration(seconds: 2));
        return _fetchArtistsPage(page, minPostCount);
      }
      AppLogger.e(
        'Failed to fetch artists page $page: $e',
        e,
        null,
        'DanbooruSync',
      );
      return null;
    }
  }

  /// 保存画师数据到缓存
  Future<void> _saveArtistsToCache(List<LocalTag> artists, int minPostCount) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheFile = File('${cacheDir.path}/$_artistsCacheFileName');

      // 保存 CSV
      final csvContent = StringBuffer('tag,category,count\n');
      for (final artist in artists) {
        csvContent.writeln('${artist.tag},${artist.category},${artist.count}');
      }
      await cacheFile.writeAsString(csvContent.toString());

      // 保存元数据
      await _saveArtistsMeta(
        totalArtists: artists.length,
        minPostCount: minPostCount,
        syncFailed: false,
      );

      AppLogger.d('Danbooru artists cache saved', 'DanbooruSync');
    } catch (e) {
      AppLogger.w('Failed to save artists cache: $e', 'DanbooruSync');
    }
  }

  /// 保存画师元数据
  Future<void> _saveArtistsMeta({
    int? totalArtists,
    int? minPostCount,
    bool? syncFailed,
  }) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final metaFile = File('${cacheDir.path}/$_artistsMetaFileName');

      final meta = ArtistsCacheMeta(
        lastUpdate: DateTime.now(),
        totalArtists: totalArtists ?? _cachedArtistsCount,
        minPostCount: minPostCount ?? _artistsMinPostCount,
        syncFailed: syncFailed ?? _artistsSyncFailed,
      );

      await metaFile.writeAsString(json.encode(meta.toJson()));

      // 更新内存状态
      if (syncFailed != null) {
        _artistsSyncFailed = syncFailed;
      }
    } catch (e) {
      AppLogger.w('Failed to save artists meta: $e', 'DanbooruSync');
    }
  }

  /// 加载画师元数据
  Future<ArtistsCacheMeta?> _loadArtistsMeta() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final metaFile = File('${cacheDir.path}/$_artistsMetaFileName');

      if (!await metaFile.exists()) {
        return null;
      }

      final content = await metaFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return ArtistsCacheMeta.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// 从缓存加载画师数据
  Future<List<LocalTag>> loadArtistsFromCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheFile = File('${cacheDir.path}/$_artistsCacheFileName');

      if (!await cacheFile.exists()) {
        return [];
      }

      final content = await cacheFile.readAsString();
      return await Isolate.run(() => _parseCsvContent(content));
    } catch (e) {
      AppLogger.w('Failed to load artists from cache: $e', 'DanbooruSync');
      return [];
    }
  }

  /// 清除画师缓存
  Future<void> clearArtistsCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheFile = File('${cacheDir.path}/$_artistsCacheFileName');
      final metaFile = File('${cacheDir.path}/$_artistsMetaFileName');

      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
      if (await metaFile.exists()) {
        await metaFile.delete();
      }

      _cachedArtistsCount = 0;
      _artistsLastUpdate = null;
      _artistsSyncFailed = false;
      AppLogger.i('Danbooru artists cache cleared', 'DanbooruSync');
    } catch (e) {
      AppLogger.w('Failed to clear artists cache: $e', 'DanbooruSync');
    }
  }
}

/// DanbooruTagsSyncService Provider
@Riverpod(keepAlive: true)
DanbooruTagsSyncService danbooruTagsSyncService(Ref ref) {
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

  // 注意：HTTP/2 adapter 被禁用，因为 danbooru.donmai.us 不支持 HTTP/2
  // 使用默认 HTTP/1.1 adapter 配合连接池复用
  return DanbooruTagsSyncService(dio);
}
