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

  /// 每页最大数量
  static const int _pageSize = 1000;

  /// 最大页数（安全限制）
  static const int _maxPages = 200;

  /// 请求间隔（毫秒）
  static const int _requestIntervalMs = 500;

  /// 缓存目录名
  static const String _cacheDirName = 'tag_cache';

  /// 缓存文件名
  static const String _cacheFileName = 'danbooru_tags_api.csv';

  /// 元数据文件名
  static const String _metaFileName = 'danbooru_tags_meta.json';

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
      var page = 1;
      var consecutiveEmpty = 0;
      var estimatedPages = _estimatePages(minPostCount);

      while (page <= _maxPages && allTags.length < maxTags && !_isCancelled) {
        // 拉取一页
        final tags = await _fetchTagsPage(page, minPostCount);

        if (tags == null) {
          AppLogger.w('Failed to fetch page $page, stopping', 'DanbooruSync');
          break;
        }

        if (tags.isEmpty) {
          consecutiveEmpty++;
          if (consecutiveEmpty >= 2) {
            AppLogger.i('No more tags available (page $page)', 'DanbooruSync');
            break;
          }
        } else {
          consecutiveEmpty = 0;
          allTags.addAll(tags);
        }

        // 动态调整估计页数（当实际页数超过估计时）
        if (page >= estimatedPages && tags.isNotEmpty) {
          estimatedPages = page + 2; // 预留2页余量
        }

        // 更新进度
        final progress = (page / estimatedPages).clamp(0.0, 0.95);
        onSyncProgress?.call(
          progress,
          '拉取标签 第$page页 (${allTags.length} 个)',
        );

        page++;

        // 速率限制
        if (page <= _maxPages && !_isCancelled) {
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

  /// 估算页数
  int _estimatePages(int minPostCount) {
    // 根据热度阈值估算标签数量
    if (minPostCount >= 10000) return 1;
    if (minPostCount >= 1000) return 10;
    if (minPostCount >= 100) return 50;
    return 100;
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
}

/// DanbooruTagsSyncService Provider
@Riverpod(keepAlive: true)
DanbooruTagsSyncService danbooruTagsSyncService(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 10),
    ),
  );

  return DanbooruTagsSyncService(dio);
}
