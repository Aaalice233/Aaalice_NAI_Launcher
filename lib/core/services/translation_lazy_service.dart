import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/cache/data_source_cache_meta.dart';
import '../../presentation/providers/proxy_settings_provider.dart';
import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';
import '../utils/tag_normalizer.dart';
import 'lazy_data_source_service.dart';
import 'unified_tag_database.dart';

part 'translation_lazy_service.g.dart';

/// 翻译懒加载服务
class TranslationLazyService implements LazyDataSourceService<String> {
  static const String _baseUrl =
      'https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv/resolve/main';
  static const String _tagsFile = 'danbooru_tags.csv';
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

      var needsDownload = await shouldRefresh();

      // 检查数据库中是否实际有翻译数据
      if (!needsDownload) {
        final sampleTranslation = await _unifiedDb.getTranslation('1girl');
        if (sampleTranslation == null) {
          AppLogger.w(
            'Translation data appears empty in database, forcing download',
            'TranslationLazy',
          );
          needsDownload = true;
          // 重置 _lastUpdate 以确保下次会重新下载
          _lastUpdate = null;
        }
      }

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
    // 统一标准化标签
    final normalizedKey = TagNormalizer.normalize(key);

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
      // 1. 先加载本地 CSV 翻译（用于补充 HuggingFace 缺失的数据）
      _onProgress?.call(0.05, '加载本地翻译数据...');
      final localTranslations = await _loadLocalTranslations();
      AppLogger.i('Loaded ${localTranslations.length} local translations', 'TranslationLazy');

      // 2. 下载 HuggingFace 数据
      final allTranslations = <TranslationRecord>[];
      final translatedTags = <String>{};

      _onProgress?.call(0.1, '下载标签翻译...');
      final tagTranslations = await _downloadTranslationFile(_tagsFile);
      if (tagTranslations != null) {
        for (final entry in tagTranslations.entries) {
          final tag = entry.key.toLowerCase().trim();
          var translation = entry.value;

          // HuggingFace 翻译为空，使用本地翻译补充
          if (translation.isEmpty && localTranslations.containsKey(tag)) {
            translation = localTranslations[tag]!;
            AppLogger.d('Using local translation for "$tag": "$translation"', 'TranslationLazy');
          }

          if (translation.isNotEmpty) {
            allTranslations.add(
              TranslationRecord(
                enTag: tag,
                zhTranslation: translation,
                source: 'hf_danbooru_tags',
              ),
            );
            translatedTags.add(tag);
          }
        }
      } else {
        throw Exception('标签翻译文件下载失败');
      }

      // 3. 添加本地有但 HuggingFace 没有的翻译
      _onProgress?.call(0.7, '合并本地翻译...');
      var localAddedCount = 0;
      for (final entry in localTranslations.entries) {
        if (!translatedTags.contains(entry.key)) {
          allTranslations.add(
            TranslationRecord(
              enTag: entry.key,
              zhTranslation: entry.value,
              source: 'local_assets',
            ),
          );
          localAddedCount++;
        }
      }
      AppLogger.i('Added $localAddedCount translations from local assets', 'TranslationLazy');

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
      // 下载失败时不更新 _lastUpdate，确保下次启动会重新尝试下载
      rethrow;
    } finally {
      _isRefreshing = false;
    }
  }

  /// 加载本地 assets 中的翻译数据（用于补充 HuggingFace 缺失的翻译）
  Future<Map<String, String>> _loadLocalTranslations() async {
    final result = <String, String>{};

    try {
      var csvContent = await rootBundle.loadString('assets/translations/danbooru.csv');

      // 统一换行符：将 Windows 换行符(\r\n)和旧 Mac 换行符(\r)统一为 Unix 换行符(\n)
      csvContent = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      const converter = CsvToListConverter(
        fieldDelimiter: ',',
        textDelimiter: '"',
        textEndDelimiter: '"',
        eol: '\n',
        shouldParseNumbers: false,
      );

      final rows = converter.convert(csvContent);
      for (final row in rows) {
        if (row.length >= 2) {
          final tag = row[0].toString().trim().toLowerCase();
          final translation = row[1].toString().trim();
          if (tag.isNotEmpty && translation.isNotEmpty) {
            result[tag] = translation;
          }
        }
      }

      AppLogger.i('Loaded ${result.length} translations from local assets', 'TranslationLazy');
    } catch (e, stack) {
      AppLogger.e('Failed to load local translations', e, stack, 'TranslationLazy');
    }

    return result;
  }

  Future<Map<String, String>?> _downloadTranslationFile(String fileName) async {
    // 尝试主 URL
    try {
      final response = await _dio.get(
        '$_baseUrl/$fileName',
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(seconds: 10),
          responseType: ResponseType.plain,
          headers: {
            'User-Agent': 'NAI-Launcher/1.0',
          },
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
    var isFirstLine = true;

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      // 跳过 CSV 标题行
      if (isFirstLine) {
        isFirstLine = false;
        if (line.toLowerCase().contains('tag') && line.toLowerCase().contains('alias')) {
          continue;
        }
      }

      final parts = line.split(',');
      // 新格式: tag,category,count,alias1,alias2,alias3...
      // alias 列包含多语言翻译（中文、日文、韩文、英文等），直接显示所有 alias
      if (parts.length >= 4) {
        final tag = parts[0].trim().toLowerCase();
        // 从第4列开始是 alias（索引3），将所有 alias 用逗号连接
        final aliases = parts.sublist(3).where((a) => a.trim().isNotEmpty).toList();
        final translation = aliases.join(', ');

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

  // ===========================================================================
  // V2: 三阶段预热架构支持
  // ===========================================================================

  /// V2: 轻量级初始化（仅检查状态，不下载）
  Future<void> initializeLightweight() async {
    if (_isInitialized) return;

    try {
      // 只检查数据库中是否有数据，不触发下载
      final sampleTranslation = await _unifiedDb.getTranslation('1girl');
      if (sampleTranslation != null) {
        _isInitialized = true;
      }
      // 注意：这里不触发 refresh()，留到后台阶段
    } catch (e) {
      AppLogger.w('Translation lightweight init failed: $e', 'TranslationLazy');
    }
  }

  /// V2: 后台预加载（仅加载热数据，不强制下载）
  Future<void> preloadHotDataInBackground() async {
    try {
      _onProgress?.call(0.0, '检查翻译数据...');

      // 加载热数据到内存
      await _loadHotData();

      // 检查是否需要后台更新（但不阻塞）
      if (await shouldRefreshInBackground()) {
        _onProgress?.call(0.5, '需要更新翻译数据...');
        // 可以在这里触发后台下载，或标记为待更新
      }

      _onProgress?.call(1.0, '翻译数据就绪');
    } catch (e) {
      AppLogger.w('Translation hot data preload failed: $e', 'TranslationLazy');
    }
  }

  /// 是否应该后台刷新（不阻塞启动）
  Future<bool> shouldRefreshInBackground() async {
    if (_lastUpdate == null) {
      await _loadMeta();
    }
    return _refreshInterval.shouldRefresh(_lastUpdate);
  }

  /// V2: 后台进度回调（与 onProgress 相同）
  set onBackgroundProgress(DataSourceProgressCallback? callback) {
    _onProgress = callback;
  }

  /// V2: 取消后台操作（翻译服务暂不需要特殊处理）
  void cancelBackgroundOperation() {
    // 翻译服务没有长时间运行的后台操作，无需取消
  }
}

/// 用于外部资源下载的 Dio Provider（无认证）
///
/// 使用代理配置但不添加认证头，适用于 HuggingFace 等公开资源
@Riverpod(keepAlive: true)
Dio externalDio(Ref ref) {
  // 监听代理设置变化
  final proxyAddress = ref.watch(currentProxyAddressProvider);

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'NAI-Launcher/1.0',
      },
    ),
  );

  // 根据代理设置选择适配器
  if (proxyAddress != null && proxyAddress.isNotEmpty) {
    AppLogger.i('External Dio using proxy: $proxyAddress', 'NETWORK');
  } else {
    AppLogger.d('External Dio using default adapter (no proxy)', 'NETWORK');
  }

  return dio;
}

/// TranslationLazyService Provider
@Riverpod(keepAlive: true)
TranslationLazyService translationLazyService(Ref ref) {
  final unifiedDb = ref.watch(unifiedTagDatabaseProvider);
  final dio = ref.watch(externalDioProvider);

  return TranslationLazyService(unifiedDb, dio);
}
