import 'dart:async';
import 'dart:isolate';

import 'package:csv/csv.dart';
import 'package:flutter/services.dart';

import '../../utils/app_logger.dart';
import '../../utils/tag_normalizer.dart';
import '../unified_tag_database.dart';
import 'translation_data_source.dart';

/// 统一翻译服务
///
/// 管理多个内置翻译数据源，首次加载时缓存到数据库，后续从数据库读取
class UnifiedTranslationService {
  /// 数据源配置列表
  final List<TranslationDataSourceConfig> _dataSourceConfigs;

  /// 数据库引用
  UnifiedTagDatabase? _db;

  /// 热数据缓存（高频查询的标签）
  final Map<String, String> _hotCache = {};

  /// 是否已初始化
  bool _isInitialized = false;

  /// 数据源统计信息
  final Map<String, DataSourceStats> _stats = {};

  static const int _maxHotCacheSize = 1000;

  /// 缓存版本号（修改此值可强制重新加载）
  static const int _cacheVersion = 6; // 强制刷新：修复CSV换行符问题

  UnifiedTranslationService({
    List<TranslationDataSourceConfig>? dataSources,
  }) : _dataSourceConfigs = dataSources ?? PredefinedDataSources.all;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 获取统计信息
  Map<String, DataSourceStats> get stats => Map.unmodifiable(_stats);

  /// 获取所有数据源配置
  List<TranslationDataSourceConfig> get dataSourceConfigs =>
      List.unmodifiable(_dataSourceConfigs);

  /// 获取数据库实例
  UnifiedTagDatabase get _database {
    if (_db == null) {
      throw StateError('UnifiedTranslationService not initialized');
    }
    return _db!;
  }

  /// 初始化服务
  ///
  /// 优先从数据库加载缓存，如果没有缓存则从 CSV 加载并缓存到数据库
  Future<void> initialize() async {
    if (_isInitialized) return;

    AppLogger.i('[UnifiedTranslation] Initializing...', 'UnifiedTranslation');
    final stopwatch = Stopwatch()..start();

    try {
      // 初始化数据库
      _db = UnifiedTagDatabase();
      await _database.initialize();

      // 检查是否需要重新加载（CSV 更新或首次运行）
      final needsReload = await _checkNeedsReload();

      if (needsReload) {
        AppLogger.i('[UnifiedTranslation] Cache miss or outdated, loading from CSV...', 'UnifiedTranslation');
        await _loadFromCsvAndCache();
      } else {
        AppLogger.i('[UnifiedTranslation] Loading from database cache...', 'UnifiedTranslation');
        await _loadHotDataFromDb();
      }

      _isInitialized = true;
      stopwatch.stop();

      AppLogger.i(
        '[UnifiedTranslation] Initialized in ${stopwatch.elapsedMilliseconds}ms',
        'UnifiedTranslation',
      );

      _logStats();
    } catch (e, stack) {
      AppLogger.e(
        '[UnifiedTranslation] Failed to initialize',
        e,
        stack,
        'UnifiedTranslation',
      );
      // 出错时尝试从 CSV 直接加载（降级方案）
      await _loadFromCsvDirectly();
      _isInitialized = true;
    }
  }

  /// 检查是否需要重新加载 CSV
  Future<bool> _checkNeedsReload() async {
    try {
      // 检查缓存版本号
      final cachedVersion = await _database.getTranslationCacheVersion();
      if (cachedVersion != _cacheVersion) {
        AppLogger.d('[UnifiedTranslation] Cache version changed: $cachedVersion -> $_cacheVersion', 'UnifiedTranslation');
        return true;
      }

      // 检查是否有翻译数据
      final count = await _database.getTranslationCount();
      if (count == 0) {
        AppLogger.d('[UnifiedTranslation] No cached translations found', 'UnifiedTranslation');
        return true;
      }

      AppLogger.d('[UnifiedTranslation] Found $count cached translations', 'UnifiedTranslation');
      return false;
    } catch (e) {
      AppLogger.w('[UnifiedTranslation] Error checking cache status: $e', 'UnifiedTranslation');
      return true;
    }
  }

  /// 从 CSV 加载并缓存到数据库
  Future<void> _loadFromCsvAndCache() async {
    // 按优先级排序（高优先级在后，覆盖低优先级）
    final sortedConfigs = _dataSourceConfigs
        .where((c) => c.enabled)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    // 先清空旧缓存
    await _database.clearTranslations();

    // 加载每个数据源
    final allTranslations = <String, String>{};
    for (final config in sortedConfigs) {
      final translations = await _loadDataSource(config);

      // 合并到总表（高优先级覆盖低优先级）
      for (final entry in translations.entries) {
        final normalizedTag = TagNormalizer.normalize(entry.key);
        allTranslations[normalizedTag] = entry.value;
      }

      _stats[config.id] = DataSourceStats(
        id: config.id,
        name: config.name,
        loadedCount: translations.length,
        loadTimeMs: 0, // 会在后面统计
      );
    }

    // 批量存入数据库
    AppLogger.i('[UnifiedTranslation] Saving ${allTranslations.length} translations to database...', 'UnifiedTranslation');
    final dbStopwatch = Stopwatch()..start();

    final records = allTranslations.entries.map((e) => TranslationRecord(
      enTag: e.key,
      zhTranslation: e.value,
      source: 'merged',
    ),).toList();

    await _database.insertTranslations(records);
    await _database.setTranslationCacheVersion(_cacheVersion);

    dbStopwatch.stop();
    AppLogger.i('[UnifiedTranslation] Saved to database in ${dbStopwatch.elapsedMilliseconds}ms', 'UnifiedTranslation');

    // 加载热数据
    await _loadHotDataFromDb();
  }

  /// 直接从 CSV 加载（降级方案，不缓存到数据库）
  Future<void> _loadFromCsvDirectly() async {
    AppLogger.w('[UnifiedTranslation] Falling back to direct CSV loading', 'UnifiedTranslation');

    final sortedConfigs = _dataSourceConfigs
        .where((c) => c.enabled)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    for (final config in sortedConfigs) {
      await _loadDataSource(config);
    }

    // 直接加载热数据到内存
    await _loadHotDataDirectly();
  }

  /// 从数据库加载热数据
  Future<void> _loadHotDataFromDb() async {
    const hotTags = [
      '1girl', 'solo', '1boy', '2girls', 'multiple_girls',
      'long_hair', 'short_hair', 'blonde_hair', 'brown_hair', 'black_hair',
      'blue_eyes', 'red_eyes', 'green_eyes', 'brown_eyes', 'purple_eyes',
      'looking_at_viewer', 'smile', 'open_mouth', 'blush',
      'breasts', 'thighhighs', 'gloves', 'bow', 'ribbon',
      'simple_background', 'white_background',
    ];

    final translations = await _database.getTranslations(hotTags);
    _hotCache.addAll(translations);

    AppLogger.i(
      '[UnifiedTranslation] Loaded ${_hotCache.length} hot translations from DB',
      'UnifiedTranslation',
    );
  }

  /// 直接加载热数据（降级方案）
  Future<void> _loadHotDataDirectly() async {
    // 从已加载的数据源中提取热数据
    // 这个方案实际上无法直接实现，因为我们没有保存完整数据
    // 只能依赖后续查询时逐个加载
    AppLogger.w('[UnifiedTranslation] Hot data loading skipped in fallback mode', 'UnifiedTranslation');
  }

  /// 加载单个数据源
  Future<Map<String, String>> _loadDataSource(TranslationDataSourceConfig config) async {
    final stopwatch = Stopwatch()..start();

    try {
      final translations = await _loadLocalAssets(config);

      stopwatch.stop();

      _stats[config.id] = DataSourceStats(
        id: config.id,
        name: config.name,
        loadedCount: translations.length,
        loadTimeMs: stopwatch.elapsedMilliseconds,
      );

      AppLogger.i(
        '[UnifiedTranslation] [${config.id}] Loaded ${translations.length} translations in ${stopwatch.elapsedMilliseconds}ms',
        'UnifiedTranslation',
      );

      return translations;
    } catch (e, stack) {
      AppLogger.e(
        '[UnifiedTranslation] [${config.id}] Failed to load',
        e,
        stack,
        'UnifiedTranslation',
      );

      _stats[config.id] = DataSourceStats(
        id: config.id,
        name: config.name,
        error: e.toString(),
        loadTimeMs: stopwatch.elapsedMilliseconds,
      );

      return {};
    }
  }

  /// 加载本地 assets
  Future<Map<String, String>> _loadLocalAssets(
    TranslationDataSourceConfig config,
  ) async {
    var csvContent = await rootBundle.loadString(config.path);

    // 统一换行符：将 Windows 换行符(\r\n)和旧 Mac 换行符(\r)统一为 Unix 换行符(\n)
    csvContent = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 使用 Isolate 解析大文件
    return await Isolate.run(() {
      final result = <String, String>{};
      const converter = CsvToListConverter(
        fieldDelimiter: ',',
        textDelimiter: '"',
        textEndDelimiter: '"',
        eol: '\n',
        shouldParseNumbers: false,
      );

      final rows = converter.convert(csvContent);

      // 跳过标题行
      final startIndex = config.csvConfig.hasHeader ? 1 : 0;

      for (var i = startIndex; i < rows.length; i++) {
        final row = rows[i];
        final tagIndex = config.csvConfig.tagColumnIndex;
        final transIndex = config.csvConfig.translationColumnIndex;

        if (tagIndex < row.length && transIndex < row.length) {
          final tag = row[tagIndex].toString().trim().toLowerCase();
          var translation = row[transIndex].toString().trim();

          // 跳过 "None" 值（表示无翻译）
          if (translation.toLowerCase() == 'none') continue;

          // 对于多 alias 的情况，只取第一个（通常是中文）
          if (translation.contains(',')) {
            translation = translation.split(',')[0].trim();
          }

          if (tag.isNotEmpty && translation.isNotEmpty) {
            result[tag] = translation;
          }
        }
      }

      return result;
    });
  }

  /// 获取翻译
  ///
  /// 按以下顺序查找：
  /// 1. 热数据缓存
  /// 2. 数据库查询
  Future<String?> getTranslation(String tag) async {
    final normalizedTag = TagNormalizer.normalize(tag);

    // 先查热缓存
    if (_hotCache.containsKey(normalizedTag)) {
      return _hotCache[normalizedTag];
    }

    // 查数据库
    try {
      final translation = await _database.getTranslation(normalizedTag);

      // 添加到热缓存
      if (translation != null) {
        _addToHotCache(normalizedTag, translation);
      }

      return translation;
    } catch (e) {
      AppLogger.w('[UnifiedTranslation] Error querying translation: $e', 'UnifiedTranslation');
      return null;
    }
  }

  /// 批量获取翻译
  Future<Map<String, String>> getTranslations(List<String> tags) async {
    final result = <String, String>{};
    final normalizedTags = tags.map(TagNormalizer.normalize).toList();

    try {
      return await _database.getTranslations(normalizedTags);
    } catch (e) {
      AppLogger.w('[UnifiedTranslation] Error querying translations: $e', 'UnifiedTranslation');
      return result;
    }
  }

  /// 添加到热缓存
  void _addToHotCache(String tag, String translation) {
    if (_hotCache.length >= _maxHotCacheSize) {
      _hotCache.remove(_hotCache.keys.first);
    }
    _hotCache[tag] = translation;
  }

  /// 从热缓存同步获取翻译
  ///
  /// 这是为了向后兼容 TagTranslationService 的同步方法。
  /// 如果热缓存中没有，会触发异步加载，但本次返回 null。
  String? getTranslationFromCache(String tag) {
    final normalizedTag = TagNormalizer.normalize(tag);

    // 先查热缓存
    if (_hotCache.containsKey(normalizedTag)) {
      return _hotCache[normalizedTag];
    }

    // 触发异步加载到缓存（但不等待）
    if (_isInitialized) {
      getTranslation(normalizedTag).then((translation) {
        // 结果会被自动添加到热缓存
        AppLogger.d('[UnifiedTranslation] Async loaded "$normalizedTag" for future cache hits', 'UnifiedTranslation');
      });
    }

    return null;
  }

  /// 搜索翻译（支持部分匹配）
  Future<List<TranslationMatch>> searchTranslations(
    String query, {
    int limit = 20,
    bool matchTag = true,
    bool matchTranslation = true,
  }) async {
    try {
      return await _database.searchTranslations(
        query,
        limit: limit,
        matchTag: matchTag,
        matchTranslation: matchTranslation,
      );
    } catch (e) {
      AppLogger.w('[UnifiedTranslation] Error searching translations: $e', 'UnifiedTranslation');
      return [];
    }
  }

  /// 获取翻译数量
  Future<int> getTranslationCount() async {
    try {
      return await _database.getTranslationCount();
    } catch (e) {
      return 0;
    }
  }

  /// 强制刷新缓存（重新加载 CSV）
  Future<void> refreshCache() async {
    AppLogger.i('[UnifiedTranslation] Force refreshing cache...', 'UnifiedTranslation');
    await _database.setTranslationCacheVersion(-1); // 设置无效版本号强制刷新
    _hotCache.clear();
    _stats.clear();
    await initialize();
  }

  /// 输出统计日志
  void _logStats() {
    AppLogger.i('=== Translation Data Source Stats ===', 'UnifiedTranslation');
    for (final stat in _stats.values) {
      if (stat.error != null) {
        AppLogger.i(
          '[${stat.id}] ${stat.name}: ERROR - ${stat.error}',
          'UnifiedTranslation',
        );
      } else {
        AppLogger.i(
          '[${stat.id}] ${stat.name}: ${stat.loadedCount} loaded, '
          '${stat.loadTimeMs}ms',
          'UnifiedTranslation',
        );
      }
    }
    AppLogger.i('=====================================', 'UnifiedTranslation');
  }

  /// 清除所有数据
  Future<void> clear() async {
    _hotCache.clear();
    _stats.clear();
    _isInitialized = false;
    try {
      await _database.clearTranslations();
    } catch (e) {
      AppLogger.w('[UnifiedTranslation] Error clearing cache: $e', 'UnifiedTranslation');
    }
  }
}

/// 数据源统计信息
class DataSourceStats {
  final String id;
  final String name;
  final int? loadedCount;
  final int? addedCount;
  final int? updatedCount;
  final String? error;
  final int loadTimeMs;

  const DataSourceStats({
    required this.id,
    required this.name,
    this.loadedCount,
    this.addedCount,
    this.updatedCount,
    this.error,
    required this.loadTimeMs,
  });
}

// TranslationMatch 类从 unified_tag_database.dart 导入
