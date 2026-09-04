import 'package:shared_preferences/shared_preferences.dart';

import '../autocomplete/autocomplete_cache_database.dart';
import '../cache/local_gallery_thumbnail_provider.dart';
import '../autocomplete/autocomplete_providers.dart';
import '../constants/storage_keys.dart';
import '../database/providers/database_state_providers.dart';
import '../utils/app_logger.dart';

/// 清除结果
class ClearResult {
  final bool success;
  final String? error;
  final int totalRemoved;
  final Map<String, int> tableStats;

  ClearResult({
    required this.success,
    this.error,
    this.totalRemoved = 0,
    this.tableStats = const {},
  });
}

/// 服务层清除回调函数类型
typedef ServiceClearCallback = Future<void> Function();

/// 缓存清除服务
///
/// 职责：统一处理所有缓存清除逻辑，使用原子清除操作
/// 原则：纯粹的数据操作，完成后通过返回值通知调用方
class CacheClearService {
  static final CacheClearService _instance = CacheClearService._internal();
  factory CacheClearService() => _instance;
  CacheClearService._internal();

  bool _isClearing = false;
  dynamic _ref;

  /// 设置 Riverpod Ref（用于访问 Providers）
  void setRef(dynamic ref) {
    _ref = ref;
  }

  /// 执行完整的缓存清除流程
  ///
  /// 步骤：
  /// 1. 检查数据库健康状态
  /// 2. 使用原子清除操作执行清除
  /// 3. 清除 SharedPreferences 元数据
  /// 4. 返回结果
  ///
  /// [serviceClearCallback] 可选的服务层清除回调，用于清除内存缓存和元数据文件
  Future<ClearResult> clearAllCache({
    ServiceClearCallback? serviceClearCallback,
  }) async {
    if (_isClearing) {
      return ClearResult(success: false, error: '清除操作正在进行中');
    }

    if (_ref == null) {
      return ClearResult(
        success: false,
        error: 'CacheClearService 未初始化，请先调用 setRef()',
      );
    }

    _isClearing = true;
    AppLogger.i(
      '[CacheClearService] Starting cache clear process',
      'CacheClearService',
    );

    try {
      // 使用原子清除操作
      AppLogger.i(
        '[CacheClearService] Using atomic clear operation',
        'CacheClearService',
      );
      final result = await _performAtomicClear(serviceClearCallback);

      if (result.success) {
        // 清除 SharedPreferences 元数据
        await _clearSharedPreferences();
      }

      return result;
    } catch (e, stack) {
      AppLogger.e(
        '[CacheClearService] Cache clear failed',
        e,
        stack,
        'CacheClearService',
      );
      return ClearResult(success: false, error: e.toString());
    } finally {
      _isClearing = false;
    }
  }

  /// 使用新架构执行原子清除
  Future<ClearResult> _performAtomicClear(
    ServiceClearCallback? serviceClearCallback,
  ) async {
    final notifier = _ref!.read(databaseStatusNotifierProvider.notifier);
    final autocompleteCache =
        _ref!.read(autocompleteCacheDatabaseProvider)
            as AutocompleteCacheDatabase;
    var danbooruRemoved = 0;
    var aiRemoved = 0;
    var localGalleryThumbnailsRemoved = 0;
    final result = await notifier.clearCache(
      serviceClearCallback: () async {
        await serviceClearCallback?.call();
        localGalleryThumbnailsRemoved = LocalGalleryThumbnailMemoryCache
            .instance
            .clear();
        // The shipped catalog and user-installed ffdkj dictionary are data
        // sources, not caches, so a global cache clear must not remove them.
        danbooruRemoved = await autocompleteCache.clearDanbooruCache();
        aiRemoved = await autocompleteCache.clearAiTranslationCache();
      },
    );
    final tableStats = <String, int>{
      ...Map<String, int>.from(result.tableStats as Map),
      'local_gallery_thumbnails': localGalleryThumbnailsRemoved,
      'autocomplete_remote_queries': danbooruRemoved,
      'autocomplete_ai_translations': aiRemoved,
    };

    return ClearResult(
      success: result.success,
      error: result.error,
      totalRemoved:
          result.totalRemoved +
          localGalleryThumbnailsRemoved +
          danbooruRemoved +
          aiRemoved,
      tableStats: tableStats,
    );
  }

  /// 清除 SharedPreferences 元数据
  Future<void> _clearSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // 清除所有相关键
    final keysToRemove = [
      // 标签数据源相关
      StorageKeys.danbooruTagsLastUpdate,
      StorageKeys.danbooruTagsRefreshInterval,
      StorageKeys.danbooruTagsRefreshIntervalDays,
      StorageKeys.danbooruTagsHotThreshold,
      StorageKeys.danbooruTagsHotPreset,
      // 分类阈值配置
      StorageKeys.danbooruGeneralThreshold,
      StorageKeys.danbooruArtistThreshold,
      StorageKeys.danbooruCharacterThreshold,
      StorageKeys.danbooruCopyrightThreshold,
      StorageKeys.danbooruMetaThreshold,
      StorageKeys.danbooruCategoryThresholds,
      // 画师同步相关
      StorageKeys.danbooruArtistThreshold,
      // 翻译数据源相关
      StorageKeys.hfTranslationLastUpdate,
      StorageKeys.hfTranslationRefreshInterval,
      // 共现数据相关
      StorageKeys.cooccurrenceRefreshInterval,
    ];

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }

    AppLogger.i(
      '[CacheClearService] SharedPreferences cleared: ${keysToRemove.length} keys',
      'CacheClearService',
    );
  }
}

// 全局实例
final cacheClearService = CacheClearService();
