import 'package:shared_preferences/shared_preferences.dart';

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
  Future<ClearResult> clearAllCache({ServiceClearCallback? serviceClearCallback}) async {
    if (_isClearing) {
      return ClearResult(
        success: false,
        error: '清除操作正在进行中',
      );
    }

    if (_ref == null) {
      return ClearResult(
        success: false,
        error: 'CacheClearService 未初始化，请先调用 setRef()',
      );
    }

    _isClearing = true;
    AppLogger.i('[CacheClearService] Starting cache clear process', 'CacheClearService');

    try {
      // 使用原子清除操作
      AppLogger.i('[CacheClearService] Using atomic clear operation', 'CacheClearService');
      final result = await _performAtomicClear(serviceClearCallback);

      if (result.success) {
        // 清除 SharedPreferences 元数据
        await _clearSharedPreferences();
      }

      return result;
    } catch (e, stack) {
      AppLogger.e('[CacheClearService] Cache clear failed', e, stack, 'CacheClearService');
      return ClearResult(
        success: false,
        error: e.toString(),
      );
    } finally {
      _isClearing = false;
    }
  }

  /// 使用新架构执行原子清除
  Future<ClearResult> _performAtomicClear(ServiceClearCallback? serviceClearCallback) async {
    final notifier = _ref!.read(databaseStatusNotifierProvider.notifier);
    final result = await notifier.clearCache(
      serviceClearCallback: serviceClearCallback,
    );

    return ClearResult(
      success: result.success,
      error: result.error,
      totalRemoved: result.totalRemoved,
      tableStats: result.tableStats,
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
      StorageKeys.danbooruSyncArtists,
      StorageKeys.danbooruArtistsLastUpdate,
      StorageKeys.danbooruArtistsTotal,
      StorageKeys.danbooruArtistsSyncFailed,
      StorageKeys.danbooruArtistsSyncCheckpoint,
      StorageKeys.danbooruArtistsMinPostCount,
      // 翻译数据源相关
      StorageKeys.hfTranslationLastUpdate,
      StorageKeys.hfTranslationRefreshInterval,
      // 共现数据相关
      StorageKeys.cooccurrenceLastUpdate,
      StorageKeys.cooccurrenceRefreshInterval,
      // 数据源后台刷新标记
      StorageKeys.pendingDataSourceRefresh,
    ];

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }

    AppLogger.i('[CacheClearService] SharedPreferences cleared: ${keysToRemove.length} keys', 'CacheClearService');
  }
}

// 全局实例
final cacheClearService = CacheClearService();
