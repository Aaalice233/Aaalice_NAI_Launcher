import 'dart:async';

import '../../database/datasources/translation_data_source.dart';
import '../../utils/app_logger.dart';
import '../../utils/tag_normalizer.dart';

/// 统一翻译服务（数据库版）
///
/// 直接从预构建的翻译数据库查询，无需加载CSV
class UnifiedTranslationService {
  /// 翻译数据源
  TranslationDataSource? _translationDataSource;

  /// 热数据缓存（高频查询的标签）
  final Map<String, String> _hotCache = {};

  /// 是否已初始化
  bool _isInitialized = false;

  static const int _maxHotCacheSize = 1000;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 设置翻译数据源
  void setTranslationDataSource(TranslationDataSource dataSource) {
    _translationDataSource = dataSource;
  }

  /// 初始化服务
  ///
  /// 仅加载热数据缓存，所有翻译数据从数据库查询
  Future<void> initialize() async {
    if (_isInitialized) return;

    AppLogger.i('[UnifiedTranslation] Initializing...', 'UnifiedTranslation');
    final stopwatch = Stopwatch()..start();

    try {
      await _loadHotDataFromDb();
      _isInitialized = true;
      stopwatch.stop();

      AppLogger.i(
        '[UnifiedTranslation] Initialized in ${stopwatch.elapsedMilliseconds}ms, hot cache: ${_hotCache.length}',
        'UnifiedTranslation',
      );
    } catch (e, stack) {
      AppLogger.e(
        '[UnifiedTranslation] Failed to initialize',
        e,
        stack,
        'UnifiedTranslation',
      );
      _isInitialized = true; // 即使失败也标记为初始化，允许查询
    }
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

    if (_translationDataSource != null) {
      final translations = await _translationDataSource!.queryBatch(hotTags.toList());
      _hotCache.addAll(translations);
    }
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
      if (_translationDataSource == null) return null;
      final translation = await _translationDataSource!.query(normalizedTag);

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
    if (_translationDataSource == null) return {};
    
    final normalizedTags = tags.map(TagNormalizer.normalize).toList();
    
    try {
      return await _translationDataSource!.queryBatch(normalizedTags);
    } catch (e) {
      AppLogger.w('[UnifiedTranslation] Error querying translations: $e', 'UnifiedTranslation');
      return {};
    }
  }

  /// 搜索翻译（支持部分匹配）
  Future<List<TranslationMatch>> searchTranslations(
    String query, {
    int limit = 20,
    bool matchTag = true,
    bool matchTranslation = true,
  }) async {
    if (_translationDataSource == null) return [];
    
    try {
      return await _translationDataSource!.search(
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
    if (_translationDataSource == null) return 0;
    
    try {
      return await _translationDataSource!.getCount();
    } catch (e) {
      return 0;
    }
  }

  /// 添加到热缓存
  void _addToHotCache(String tag, String translation) {
    if (_hotCache.length >= _maxHotCacheSize) {
      _hotCache.remove(_hotCache.keys.first);
    }
    _hotCache[tag] = translation;
  }

  /// 强制刷新（重新加载热数据）
  Future<void> refreshCache() async {
    AppLogger.i('[UnifiedTranslation] Refreshing hot cache...', 'UnifiedTranslation');
    _hotCache.clear();
    await _loadHotDataFromDb();
  }

  /// 清除所有数据
  Future<void> clear() async {
    _hotCache.clear();
    _isInitialized = false;
  }
}
