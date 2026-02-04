import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/cache/data_source_cache_meta.dart';
import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';
import '../utils/download_message_keys.dart';
import 'lazy_data_source_service.dart';
import 'translation_sqlite_service.dart';

part 'translation_lazy_service.g.dart';

/// 翻译懒加载服务
/// 实现 LazyDataSourceService 接口，提供统一的懒加载架构
class TranslationLazyService implements LazyDataSourceService<String> {
  /// HuggingFace 数据集 URL
  static const String _baseUrl =
      'https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv/resolve/main';

  /// 翻译文件名
  static const String _translationFileName = 'danbooru_tags.csv';

  /// 缓存目录名
  static const String _cacheDirName = 'translation_cache';

  /// 元数据文件名
  static const String _metaFileName = 'translation_meta.json';

  /// SQLite 存储服务
  final TranslationSqliteService _sqliteService;

  /// HTTP 客户端
  final Dio _dio;

  /// 内存中的热数据缓存
  final Map<String, String> _hotDataCache = {};

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

  /// 当前刷新间隔
  AutoRefreshInterval _refreshInterval = AutoRefreshInterval.days30;

  TranslationLazyService(this._sqliteService, this._dio) {
    // 异步加载元数据
    unawaited(_loadMeta());
  }

  @override
  String get serviceName => 'translation';

  @override
  Set<String> get hotKeys => const {
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

  /// 获取当前刷新间隔
  AutoRefreshInterval get refreshInterval => _refreshInterval;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _onProgress?.call(0.0, '初始化翻译数据...');

      // 1. 确保 SQLite 数据库已初始化
      await _sqliteService.initialize();
      _onProgress?.call(0.2, '数据库已就绪');

      // 2. 检查是否需要下载数据（首次使用或需要刷新）
      final needsDownload = await shouldRefresh();

      if (needsDownload) {
        _onProgress?.call(0.3, '需要下载翻译数据...');
        AppLogger.i('Translation data needs download, starting...', 'TranslationLazy');

        // 执行下载和导入
        await refresh();

        _onProgress?.call(0.9, '翻译数据下载完成');
      } else {
        _onProgress?.call(0.5, '使用本地缓存数据');
      }

      // 3. 加载热数据到内存
      await _loadHotData();
      _onProgress?.call(1.0, '翻译数据初始化完成');

      _isInitialized = true;
      AppLogger.i('Translation lazy service initialized', 'TranslationLazy');
    } catch (e, stack) {
      AppLogger.e(
        'Failed to initialize translation lazy service',
        e,
        stack,
        'TranslationLazy',
      );
      // 即使失败也标记为已初始化，避免阻塞启动
      _isInitialized = true;
    }
  }

  /// 加载热数据到内存缓存
  Future<void> _loadHotData() async {
    _onProgress?.call(0.0, '加载热数据...');

    // 从 SQLite 加载热标签
    final translations = await _sqliteService.getTranslations(hotKeys.toList());

    for (final entry in translations.entries) {
      _hotDataCache[entry.key] = entry.value;
    }

    // 补充回退数据中的热标签
    final fallbackData = await _loadLocalFallback();
    for (final tag in hotKeys) {
      if (!_hotDataCache.containsKey(tag) && fallbackData.containsKey(tag)) {
        _hotDataCache[tag] = fallbackData[tag]!;
      }
    }

    _onProgress?.call(1.0, '热数据加载完成');
    AppLogger.i(
      'Loaded ${_hotDataCache.length} hot translations into memory',
      'TranslationLazy',
    );
  }

  @override
  Future<String?> get(String key) async {
    final normalizedKey = key.toLowerCase().trim();

    // 1. 检查内存缓存
    if (_hotDataCache.containsKey(normalizedKey)) {
      return _hotDataCache[normalizedKey];
    }

    // 2. 从 SQLite 查询
    final translation = await _sqliteService.getTranslation(normalizedKey);
    if (translation != null) {
      // 添加到热缓存
      _hotDataCache[normalizedKey] = translation;
      return translation;
    }

    // 3. 尝试从回退数据加载
    final fallbackData = await _loadLocalFallback();
    if (fallbackData.containsKey(normalizedKey)) {
      final value = fallbackData[normalizedKey]!;
      _hotDataCache[normalizedKey] = value;
      return value;
    }

    return null;
  }

  @override
  Future<List<String>> getMultiple(List<String> keys) async {
    if (keys.isEmpty) return [];

    final result = <String>[];
    final normalizedKeys = keys.map((k) => k.toLowerCase().trim()).toList();

    // 批量从 SQLite 获取
    final translations = await _sqliteService.getTranslations(normalizedKeys);

    for (final key in normalizedKeys) {
      if (translations.containsKey(key)) {
        result.add(translations[key]!);
      }
    }

    return result;
  }

  @override
  Future<bool> shouldRefresh() async {
    if (_lastUpdate == null) {
      await _loadMeta();
    }

    final prefs = await SharedPreferences.getInstance();
    final intervalDays = prefs.getInt(StorageKeys.hfTranslationRefreshInterval);
    final interval = AutoRefreshInterval.fromDays(intervalDays ?? 30);

    return interval.shouldRefresh(_lastUpdate);
  }

  @override
  Future<void> refresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _onProgress?.call(0.0, DownloadMessageKeys.downloadingTags);

    try {
      // 下载翻译数据
      final content = await _downloadTranslations();

      if (content.isEmpty) {
        throw Exception('Downloaded content is empty');
      }

      _onProgress?.call(0.5, DownloadMessageKeys.parsingData);

      // 解析翻译数据（使用 Isolate）
      final lines = content.split('\n');

      _onProgress?.call(0.6, '导入数据库...');

      // 导入到 SQLite
      await _sqliteService.importFromCsv(
        lines,
        onProgress: (processed, total) {
          final progress = 0.6 + (processed / total) * 0.3;
          _onProgress?.call(progress, '导入: $processed / $total');
        },
      );

      _onProgress?.call(0.9, '更新热数据...');

      // 重新加载热数据
      await _loadHotData();

      // 保存元数据
      await _saveMeta();

      _lastUpdate = DateTime.now();

      _onProgress?.call(1.0, '完成');
      AppLogger.i('Translation data refreshed successfully', 'TranslationLazy');
    } catch (e, stack) {
      AppLogger.e('Failed to refresh translation data', e, stack, 'TranslationLazy');
      _onProgress?.call(1.0, '刷新失败: $e');
      rethrow;
    } finally {
      _isRefreshing = false;
    }
  }

  /// 下载翻译数据
  Future<String> _downloadTranslations() async {
    _onProgress?.call(0.0, '下载翻译数据...');

    final response = await _dio.get<String>(
      '$_baseUrl/$_translationFileName',
      options: Options(
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 60),
      ),
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final progress = (received / total) * 0.5;
          final percent = (progress * 100).toInt();
          _onProgress?.call(progress, '下载中... $percent%');
        }
      },
    );

    return response.data ?? '';
  }

  /// 加载本地回退数据
  Future<Map<String, String>> _loadLocalFallback() async {
    try {
      final csvData =
          await rootBundle.loadString('assets/translations/danbooru.csv');
      final translations = <String, String>{};
      final lines = csvData.split('\n');

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        final parts = line.split(',');
        if (parts.length >= 2) {
          final tag = parts[0].trim().toLowerCase();
          final translation = parts.sublist(1).join(',').trim();

          if (tag.isNotEmpty && translation.isNotEmpty) {
            translations[tag] = translation;
          }
        }
      }

      return translations;
    } catch (e) {
      AppLogger.w('Failed to load local fallback: $e', 'TranslationLazy');
      return {};
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
      }

      // 加载刷新间隔设置
      final prefs = await SharedPreferences.getInstance();
      final intervalDays = prefs.getInt(StorageKeys.hfTranslationRefreshInterval);
      if (intervalDays != null) {
        _refreshInterval = AutoRefreshInterval.fromDays(intervalDays);
      }
    } catch (e) {
      AppLogger.w('Failed to load translation meta: $e', 'TranslationLazy');
    }
  }

  /// 保存元数据
  Future<void> _saveMeta() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      final now = DateTime.now();
      final json = {
        'lastUpdate': now.toIso8601String(),
        'totalTags': await _sqliteService.getRecordCount(),
        'version': 1,
      };

      await metaFile.writeAsString(jsonEncode(json));
      _lastUpdate = now;

      // 同时保存到 SharedPreferences 以便快速访问
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        StorageKeys.hfTranslationLastUpdate,
        now.toIso8601String(),
      );
    } catch (e) {
      AppLogger.w('Failed to save translation meta: $e', 'TranslationLazy');
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

      // 3. 删除缓存文件
      try {
        final cacheDir = await _getCacheDirectory();
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
        }
      } catch (e) {
        AppLogger.w('Failed to delete translation cache directory: $e', 'TranslationLazy');
      }

      // 4. 清除 SharedPreferences 中的元数据
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.hfTranslationLastUpdate);
      await prefs.remove(StorageKeys.hfTranslationRefreshInterval);

      AppLogger.i('Translation cache cleared', 'TranslationLazy');
    } catch (e) {
      AppLogger.w('Failed to clear translation cache: $e', 'TranslationLazy');
    }
  }

  /// 获取当前刷新间隔设置
  Future<AutoRefreshInterval> getRefreshInterval() async {
    final prefs = await SharedPreferences.getInstance();
    final intervalDays = prefs.getInt(StorageKeys.hfTranslationRefreshInterval);
    return AutoRefreshInterval.fromDays(intervalDays ?? 30);
  }

  /// 设置刷新间隔
  Future<void> setRefreshInterval(AutoRefreshInterval interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.hfTranslationRefreshInterval, interval.days);
    _refreshInterval = interval;
  }
}

/// TranslationLazyService Provider
@Riverpod(keepAlive: true)
TranslationLazyService translationLazyService(Ref ref) {
  final sqliteService = ref.watch(translationSqliteServiceProvider);
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  return TranslationLazyService(sqliteService, dio);
}

/// TranslationSqliteService Provider
@Riverpod(keepAlive: true)
TranslationSqliteService translationSqliteService(Ref ref) {
  return TranslationSqliteService();
}
