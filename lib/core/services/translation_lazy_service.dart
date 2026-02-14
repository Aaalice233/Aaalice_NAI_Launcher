import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/cache/data_source_cache_meta.dart';
import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';
import 'lazy_data_source_service.dart';
import 'unified_tag_database.dart';

part 'translation_lazy_service.g.dart';

/// 翻译懒加载服务
class TranslationLazyService implements LazyDataSourceService<String> {
  static const String _baseUrl =
      'https://huggingface.co/datasets/SmirkingFace/NAI_tag_translation/resolve/main';
  static const String _tagTranslationFile = 'translation.csv';
  static const String _charTranslationFile = 'character.csv';
  static const String _cacheDirName = 'tag_cache';
  static const String _metaFileName = 'translation_meta.json';

  final UnifiedTagDatabase _unifiedDb;
  final Dio _dio;

  final Map<String, String> _hotDataCache = {};
  bool _isInitialized = false;
  bool _isRefreshing = false;
  DataSourceProgressCallback? _onProgress;
  DateTime? _lastUpdate;
  AutoRefreshInterval _refreshInterval = AutoRefreshInterval.days30;

  @override
  DataSourceProgressCallback? get onProgress => _onProgress;

  TranslationLazyService(this._unifiedDb, this._dio) {
    unawaited(_loadMeta());
  }

  @override
  String get serviceName => 'translation';

  @override
  Set<String> get hotKeys => const {
    '1girl', 'solo', '1boy', '2girls', 'multiple_girls',
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
  AutoRefreshInterval get refreshInterval => _refreshInterval;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _onProgress?.call(0.0, '初始化翻译数据...');

      if (!_unifiedDb.isInitialized) {
        await _unifiedDb.initialize();
      }
      _onProgress?.call(0.2, '数据库已就绪');

      final needsDownload = await shouldRefresh();

      if (needsDownload) {
        _onProgress?.call(0.3, '需要下载翻译数据...');
        AppLogger.i('Translation data needs download, starting...', 'TranslationLazy');
        await refresh();
        _onProgress?.call(0.9, '翻译数据下载完成');
      } else {
        _onProgress?.call(0.5, '使用本地缓存数据');
      }

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
      _isInitialized = true;
    }
  }

  Future<void> _loadHotData() async {
    _onProgress?.call(0.0, '加载热数据...');

    final translations = await _unifiedDb.getTranslations(hotKeys.toList());

    for (final entry in translations.entries) {
      _hotDataCache[entry.key] = entry.value;
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

    if (_hotDataCache.containsKey(normalizedKey)) {
      return _hotDataCache[normalizedKey];
    }

    final translation = await _unifiedDb.getTranslation(normalizedKey);
    if (translation != null) {
      _hotDataCache[normalizedKey] = translation;
      return translation;
    }

    return null;
  }

  @override
  Future<List<String>> getMultiple(List<String> keys) async {
    if (keys.isEmpty) return [];

    final normalizedKeys = keys.map((k) => k.toLowerCase().trim()).toList();
    final translations = await _unifiedDb.getTranslations(normalizedKeys);
    return translations.values.toList();
  }

  @override
  Future<bool> shouldRefresh() async {
    if (_lastUpdate == null) {
      await _loadMeta();
    }

    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getInt(StorageKeys.hfTranslationRefreshInterval);
    final interval = AutoRefreshInterval.fromDays(days ?? 30);

    return interval.shouldRefresh(_lastUpdate);
  }

  @override
  Future<void> refresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _onProgress?.call(0.0, '开始同步翻译...');

    try {
      final allTranslations = <TranslationRecord>[];

      _onProgress?.call(0.1, '下载标签翻译...');
      final tagTranslations = await _downloadTranslationFile(_tagTranslationFile);
      if (tagTranslations != null) {
        for (final entry in tagTranslations.entries) {
          allTranslations.add(
            TranslationRecord(
              enTag: entry.key.toLowerCase().trim(),
              zhTranslation: entry.value,
              source: 'hf_translation',
            ),
          );
        }
      }

      _onProgress?.call(0.5, '下载角色翻译...');
      final charTranslations = await _downloadTranslationFile(_charTranslationFile);
      if (charTranslations != null) {
        for (final entry in charTranslations.entries) {
          allTranslations.add(
            TranslationRecord(
              enTag: entry.key.toLowerCase().trim(),
              zhTranslation: entry.value,
              source: 'hf_character',
            ),
          );
        }
      }

      _onProgress?.call(0.8, '导入数据库...');
      await _unifiedDb.insertTranslations(allTranslations);

      _onProgress?.call(0.95, '更新热数据...');
      await _loadHotData();
      await _saveMeta(allTranslations.length);

      _lastUpdate = DateTime.now();

      _onProgress?.call(1.0, '完成');
      AppLogger.i(
        'Translation data refreshed: ${allTranslations.length} translations',
        'TranslationLazy',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to refresh translation data', e, stack, 'TranslationLazy');
      _onProgress?.call(1.0, '刷新失败: $e');
      rethrow;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Map<String, String>?> _downloadTranslationFile(String fileName) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/$fileName',
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(seconds: 10),
          responseType: ResponseType.plain,
        ),
      );

      if (response.data is String) {
        return _parseCsvContent(response.data as String);
      }
      return null;
    } on DioException catch (e) {
      AppLogger.e('Failed to download translation file: $fileName', e, null, 'TranslationLazy');
      return null;
    }
  }

  Map<String, String> _parseCsvContent(String content) {
    final result = <String, String>{};
    final lines = const LineSplitter().convert(content);

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final parts = line.split(',');
      if (parts.length >= 2) {
        final tag = parts[0].trim().toLowerCase();
        final translation = parts.sublist(1).join(',').trim();

        if (tag.isNotEmpty && translation.isNotEmpty) {
          result[tag] = translation;
        }
      }
    }

    return result;
  }

  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDirName');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  Future<void> _loadMeta() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _lastUpdate = DateTime.parse(json['lastUpdate'] as String);
      }

      final prefs = await SharedPreferences.getInstance();
      final days = prefs.getInt(StorageKeys.hfTranslationRefreshInterval);
      if (days != null) {
        _refreshInterval = AutoRefreshInterval.fromDays(days);
      }
    } catch (e) {
      AppLogger.w('Failed to load translation meta: $e', 'TranslationLazy');
    }
  }

  Future<void> _saveMeta(int totalTranslations) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      final now = DateTime.now();
      final json = {
        'lastUpdate': now.toIso8601String(),
        'totalTranslations': totalTranslations,
        'version': 1,
      };

      await metaFile.writeAsString(jsonEncode(json));
      _lastUpdate = now;

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
      _hotDataCache.clear();
      _lastUpdate = null;
      _isInitialized = false;
      _isRefreshing = false;

      try {
        final cacheDir = await _getCacheDirectory();
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
        }
      } catch (e) {
        AppLogger.w('Failed to delete translation cache directory: $e', 'TranslationLazy');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.hfTranslationLastUpdate);
      await prefs.remove(StorageKeys.hfTranslationRefreshInterval);

      AppLogger.i('Translation cache cleared', 'TranslationLazy');
    } catch (e) {
      AppLogger.w('Failed to clear translation cache: $e', 'TranslationLazy');
    }
  }

  Future<AutoRefreshInterval> getRefreshInterval() async {
    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getInt(StorageKeys.hfTranslationRefreshInterval);
    return AutoRefreshInterval.fromDays(days ?? 30);
  }

  Future<void> setRefreshInterval(AutoRefreshInterval interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.hfTranslationRefreshInterval, interval.days);
    _refreshInterval = interval;
  }
}

/// TranslationLazyService Provider
@Riverpod(keepAlive: true)
TranslationLazyService translationLazyService(Ref ref) {
  final unifiedDb = ref.watch(unifiedTagDatabaseProvider).valueOrNull;
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(seconds: 10),
    ),
  );

  if (unifiedDb == null) {
    throw StateError('UnifiedTagDatabase not initialized');
  }

  return TranslationLazyService(unifiedDb, dio);
}
