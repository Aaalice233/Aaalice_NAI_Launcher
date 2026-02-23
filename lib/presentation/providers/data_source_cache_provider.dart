import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/database/providers/database_state_providers.dart';
import '../../core/database/services/services.dart';
import '../../core/database/services/service_providers.dart';
import '../../core/database/state/database_state.dart';
import '../../core/services/danbooru_tags_lazy_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/cache/data_source_cache_meta.dart';

part 'data_source_cache_provider.g.dart';

/// 标签分类统计
class TagCategoryStats {
  final int total;
  final int general; // category 0: 一般标签
  final int artist; // category 1: 画师标签
  final int copyright; // category 3: 版权/作品标签
  final int character; // category 4: 角色标签
  final int meta; // category 5: 元标签

  const TagCategoryStats({
    this.total = 0,
    this.general = 0,
    this.artist = 0,
    this.copyright = 0,
    this.character = 0,
    this.meta = 0,
  });

  TagCategoryStats copyWith({
    int? total,
    int? general,
    int? artist,
    int? copyright,
    int? character,
    int? meta,
  }) {
    return TagCategoryStats(
      total: total ?? this.total,
      general: general ?? this.general,
      artist: artist ?? this.artist,
      copyright: copyright ?? this.copyright,
      character: character ?? this.character,
      meta: meta ?? this.meta,
    );
  }
}

/// Danbooru 标签缓存状态
class DanbooruTagsCacheState {
  final bool isRefreshing;
  final double progress;
  final String? message;
  final DateTime? lastUpdate;
  final int totalTags;
  final TagCategoryStats categoryStats; // 分类统计
  final String? error;
  final AutoRefreshInterval refreshInterval;
  // 画师同步相关状态
  final bool syncArtists;
  final bool isSyncingArtists;
  final double artistsProgress;
  final int artistsTotal;
  final DateTime? artistsLastUpdate;
  // 分类阈值配置（V2新增）
  final TagCategoryThresholds categoryThresholds;
  // 预构建数据库统计
  final int translationCount; // 翻译数据数量
  final int cooccurrenceCount; // 共现数据数量

  const DanbooruTagsCacheState({
    this.isRefreshing = false,
    this.progress = 0.0,
    this.message,
    this.lastUpdate,
    this.totalTags = 0,
    this.categoryStats = const TagCategoryStats(),
    this.error,
    this.refreshInterval = AutoRefreshInterval.days30,
    // 画师同步默认值
    this.syncArtists = true,
    this.isSyncingArtists = false,
    this.artistsProgress = 0.0,
    this.artistsTotal = 0,
    this.artistsLastUpdate,
    // 分类阈值默认配置
    this.categoryThresholds = const TagCategoryThresholds(),
    // 预构建数据库统计默认值
    this.translationCount = 0,
    this.cooccurrenceCount = 0,
  });

  /// 获取一般标签的当前阈值（兼容旧API）
  int get generalThreshold => categoryThresholds.generalThreshold;

  /// 获取画师标签的当前阈值
  int get artistThreshold => categoryThresholds.artistThreshold;

  /// 获取角色标签的当前阈值
  int get characterThreshold => categoryThresholds.characterThreshold;

  /// 获取版权标签的当前阈值
  int get copyrightThreshold => categoryThresholds.copyrightThreshold;

  /// 获取元标签的当前阈值
  int get metaThreshold => categoryThresholds.metaThreshold;

  DanbooruTagsCacheState copyWith({
    bool? isRefreshing,
    double? progress,
    String? message,
    DateTime? lastUpdate,
    int? totalTags,
    TagCategoryStats? categoryStats,
    String? error,
    AutoRefreshInterval? refreshInterval,
    bool? syncArtists,
    bool? isSyncingArtists,
    double? artistsProgress,
    int? artistsTotal,
    DateTime? artistsLastUpdate,
    TagCategoryThresholds? categoryThresholds,
    int? translationCount,
    int? cooccurrenceCount,
  }) {
    return DanbooruTagsCacheState(
      isRefreshing: isRefreshing ?? this.isRefreshing,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      totalTags: totalTags ?? this.totalTags,
      categoryStats: categoryStats ?? this.categoryStats,
      error: error,
      refreshInterval: refreshInterval ?? this.refreshInterval,
      syncArtists: syncArtists ?? this.syncArtists,
      isSyncingArtists: isSyncingArtists ?? this.isSyncingArtists,
      artistsProgress: artistsProgress ?? this.artistsProgress,
      artistsTotal: artistsTotal ?? this.artistsTotal,
      artistsLastUpdate: artistsLastUpdate ?? this.artistsLastUpdate,
      categoryThresholds: categoryThresholds ?? this.categoryThresholds,
      translationCount: translationCount ?? this.translationCount,
      cooccurrenceCount: cooccurrenceCount ?? this.cooccurrenceCount,
    );
  }
}

/// Danbooru 标签缓存 Notifier
@Riverpod(keepAlive: true)
class DanbooruTagsCacheNotifier extends _$DanbooruTagsCacheNotifier {
  bool _isClearing = false;
  DanbooruTagsLazyService? _service;

  @override
  Future<DanbooruTagsCacheState> build() async {
    AppLogger.i(
      '[ProviderLifecycle] DanbooruTagsCacheNotifier.build() START - _service=${_service?.hashCode}',
      'DanbooruTagsCacheNotifier',
    );

    // 新架构：监听数据库状态，如果正在清除则等待
    try {
      final dbState = ref.read(databaseStatusNotifierProvider);
      if (dbState == DatabaseState.clearing ||
          dbState == DatabaseState.closing ||
          dbState == DatabaseState.recovering) {
        AppLogger.w(
          '[ProviderLifecycle] Database is $dbState, waiting...',
          'DanbooruTagsCacheNotifier',
        );
        // 等待数据库就绪
        await ref.read(databaseStateMachineProvider).waitForReady(
              timeout: const Duration(seconds: 30),
            );
        AppLogger.i(
          '[ProviderLifecycle] Database is now ready, continuing build',
          'DanbooruTagsCacheNotifier',
        );
      }
    } catch (e) {
      // 如果新架构不可用，继续执行（兼容旧架构）
      AppLogger.d(
        '[ProviderLifecycle] New architecture not available, continuing with legacy mode',
        'DanbooruTagsCacheNotifier',
      );
    }

    // 等待服务初始化完成（带重试，处理数据库关闭错误）
    var retryCount = 0;
    const maxRetries = 5;
    while (retryCount < maxRetries) {
      try {
        _service = await ref.watch(danbooruTagsLazyServiceProvider.future);
        break; // 成功，跳出重试循环
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        final isDbClosed = errorStr.contains('database_closed') || 
                          errorStr.contains('databaseexception');
        if (isDbClosed && retryCount < maxRetries - 1) {
          retryCount++;
          AppLogger.w(
            '[ProviderLifecycle] Database closed during service initialization, retrying ($retryCount/$maxRetries)...',
            'DanbooruTagsCacheNotifier',
          );
          // 增加等待时间，给数据库重建连接池留出更多时间
          await Future.delayed(Duration(milliseconds: 300 * retryCount));
        } else {
          rethrow;
        }
      }
    }
    
    AppLogger.i(
      '[ProviderLifecycle] DanbooruTagsCacheNotifier.build() - service initialized, hash=${_service.hashCode}',
      'DanbooruTagsCacheNotifier',
    );

    final refreshInterval = _service!.getRefreshInterval();

    // 获取标签数量和分类统计（带重试机制）
    var count = 0;
    TagCategoryStats categoryStats = const TagCategoryStats();
    var statsRetryCount = 0;
    const maxStatsRetries = 5;
    
    while (statsRetryCount < maxStatsRetries) {
      try {
        final completionService = await ref.read(completionServiceProvider.future);
        count = await completionService.getTagCount();

        // 获取分类统计
        final stats = await _service!.getCategoryStats();
        categoryStats = TagCategoryStats(
          total: stats['total'] ?? 0,
          general: stats['general'] ?? 0,
          artist: stats['artist'] ?? 0,
          copyright: stats['copyright'] ?? 0,
          character: stats['character'] ?? 0,
          meta: stats['meta'] ?? 0,
        );
        break; // 成功，跳出重试循环
      } catch (e, stack) {
        final errorStr = e.toString().toLowerCase();
        final isDbClosed = errorStr.contains('database_closed') || 
                          errorStr.contains('databaseexception');
        if (isDbClosed && statsRetryCount < maxStatsRetries - 1) {
          statsRetryCount++;
          AppLogger.w(
            '[ProviderLifecycle] Database closed during stats loading, retrying ($statsRetryCount/$maxStatsRetries)...',
            'DanbooruTagsCacheNotifier',
          );
          // 增加等待时间，给数据库重建连接池留出更多时间
          await Future.delayed(Duration(milliseconds: 300 * statsRetryCount));
        } else {
          AppLogger.e('Failed to load cache stats', e, stack, 'DanbooruTagsCacheNotifier');
          break; // 非 database_closed 错误或已达到最大重试次数
        }
      }
    }
    
    // 获取翻译和共现数据数量（预构建数据库）
    var translationCount = 0;
    var cooccurrenceCount = 0;
    try {
      final translationService = await ref.read(translationServiceProvider.future);
      translationCount = await translationService.getCount();
      
      final cooccurrenceService = await ref.read(cooccurrenceServiceProvider.future);
      cooccurrenceCount = await cooccurrenceService.getCount();
      
      AppLogger.i(
        '[ProviderLifecycle] Database stats - translations: $translationCount, cooccurrences: $cooccurrenceCount',
        'DanbooruTagsCacheNotifier',
      );
    } catch (e) {
      AppLogger.w(
        '[ProviderLifecycle] Failed to load translation/cooccurrence stats: $e',
        'DanbooruTagsCacheNotifier',
      );
    }
    
    AppLogger.i(
      '[ProviderLifecycle] DanbooruTagsCacheNotifier.build() END - totalTags=$count',
      'DanbooruTagsCacheNotifier',
    );

    // 读取分类阈值配置
    final categoryThresholds = await _loadCategoryThresholds();

    return DanbooruTagsCacheState(
      lastUpdate: _service!.lastUpdate,
      totalTags: count,
      categoryStats: categoryStats,
      refreshInterval: refreshInterval,
      categoryThresholds: categoryThresholds,
      syncArtists: true, // 画师同步现在是默认行为
      translationCount: translationCount,
      cooccurrenceCount: cooccurrenceCount,
    );
  }

  /// 加载分类阈值配置
  Future<TagCategoryThresholds> _loadCategoryThresholds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(StorageKeys.danbooruCategoryThresholds);
      if (jsonStr != null) {
        final json = Map<String, dynamic>.from(
          jsonDecode(jsonStr) as Map,
        );
        return TagCategoryThresholds.fromJson(json);
      }
    } catch (e) {
      AppLogger.w('Failed to load category thresholds: $e', 'DanbooruTagsCacheNotifier');
    }
    return const TagCategoryThresholds();
  }

  DanbooruTagsLazyService get _requireService {
    if (_service == null) {
      throw StateError('DanbooruTagsLazyService not initialized');
    }
    return _service!;
  }

  /// 手动刷新标签数据
  Future<void> refresh() async {
    final currentState = await future;
    if (currentState.isRefreshing) return;

    state = const AsyncLoading();

    try {
      _requireService.onProgress = (progress, message) {
        // 更新状态
        state = AsyncValue.data(currentState.copyWith(
          isRefreshing: true,
          progress: progress,
          message: message,
        ),);
      };

      await _requireService.refresh();
      
      // 刷新完成后重新加载标签数量
      final completionService = await ref.read(completionServiceProvider.future);
      final count = await completionService.getTagCount();
      
      state = AsyncValue.data(currentState.copyWith(
        isRefreshing: false,
        progress: 1.0,
        lastUpdate: DateTime.now(),
        totalTags: count,
        message: null,
      ),);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    } finally {
      _requireService.onProgress = null;
    }
  }

  /// 取消同步
  void cancelSync() {
    _requireService.cancelRefresh();
  }

  /// 设置热度档位
  Future<void> setHotPreset(TagHotPreset preset, {int? customThreshold}) async {
    await _requireService.setHotPreset(preset, customThreshold: customThreshold);

    final currentState = await future;
    state = AsyncValue.data(
      currentState.copyWith(
        categoryThresholds: currentState.categoryThresholds.copyWith(
          generalPreset: preset,
          generalCustomThreshold: customThreshold ??
              currentState.categoryThresholds.generalCustomThreshold,
        ),
      ),
    );
  }

  /// 清除缓存
  Future<void> clearCache() async {
    if (_isClearing) return;
    _isClearing = true;
    
    AppLogger.i(
      '[ProviderLifecycle] clearCache() START - _service=${_service?.hashCode}, _isClearing=$_isClearing',
      'DanbooruTagsCacheNotifier',
    );

    try {
      // 如果服务已初始化，清除服务状态
      if (_service != null) {
        AppLogger.i(
          '[ProviderLifecycle] clearCache() - calling _service.clearCache(), service=${_service.hashCode}',
          'DanbooruTagsCacheNotifier',
        );
        await _service!.clearCache();
        AppLogger.i(
          '[ProviderLifecycle] clearCache() - _service.clearCache() completed',
          'DanbooruTagsCacheNotifier',
        );
      }

      // 清除共现数据
      // 注意：CooccurrenceService.clearAllData() 已移除，现在使用预构建数据库（只读）
      AppLogger.i(
        '[ProviderLifecycle] clearCache() - cooccurrence data is read-only, skipping clear',
        'DanbooruTagsCacheNotifier',
      );

      // 更新状态为已清除
      state = const AsyncValue.data(
        DanbooruTagsCacheState(
          lastUpdate: null,
          totalTags: 0,
          refreshInterval: AutoRefreshInterval.days30,
        ),
      );

      // 关键：invalidate 懒加载服务 Provider，确保下次访问时重新创建实例
      AppLogger.i(
        '[ProviderLifecycle] clearCache() - BEFORE invalidate danbooruTagsLazyServiceProvider',
        'DanbooruTagsCacheNotifier',
      );
      ref.invalidate(danbooruTagsLazyServiceProvider);
      AppLogger.i(
        '[ProviderLifecycle] clearCache() - AFTER invalidate danbooruTagsLazyServiceProvider, _service still=${_service.hashCode}',
        'DanbooruTagsCacheNotifier',
      );
      
      // 🔴 关键修复：invalidate 自己，强制 build() 重新执行
      // 注意：必须在所有数据库操作完成后才调用，否则会导致 database_closed 错误
      AppLogger.i(
        '[ProviderLifecycle] clearCache() - about to invalidateSelf(), ensure all DB operations completed',
        'DanbooruTagsCacheNotifier',
      );
      
      // 延迟 invalidate，确保数据库连接已完全释放
      await Future.delayed(const Duration(milliseconds: 100));
      ref.invalidateSelf();
      AppLogger.i(
        '[ProviderLifecycle] clearCache() - invalidateSelf() called after delay',
        'DanbooruTagsCacheNotifier',
      );
    } finally {
      _isClearing = false;
    }
  }

  /// 设置自动刷新间隔
  Future<void> setRefreshInterval(AutoRefreshInterval interval) async {
    await _requireService.setRefreshInterval(interval);
    final currentState = await future;
    state = AsyncValue.data(currentState.copyWith(refreshInterval: interval));
  }

  /// 设置是否同步画师
  Future<void> setSyncArtists(bool value) async {
    final currentState = await future;
    state = AsyncValue.data(currentState.copyWith(syncArtists: value));
    
    // 画师同步现在是默认行为，不再持久化设置
    AppLogger.i('Sync artists setting changed to: $value', 'DanbooruTagsCacheNotifier');
  }

  /// 同步画师数据
  /// 同步画师标签（手动触发或自动刷新）
  ///
  /// [force] 为 true 时强制同步，忽略时间间隔检查
  /// [onExternalProgress] 可选的外部进度回调，用于后台任务通知
  Future<void> syncArtists({
    bool force = false,
    void Function(int currentPage, int importedCount, String message)? onExternalProgress,
  }) async {
    final currentState = await future;
    
    // 检查是否启用画师同步
    if (!currentState.syncArtists && !force) {
      AppLogger.i('Artist sync is disabled, skipping', 'DanbooruTagsCacheNotifier');
      return;
    }
    
    // 检查是否已经在同步中
    if (currentState.isSyncingArtists) {
      AppLogger.w('Artist sync already in progress', 'DanbooruTagsCacheNotifier');
      return;
    }
    
    // 检查是否需要同步（基于画师标签数量，而不是总数）
    if (!force) {
      final existingCount = await _requireService.getTagCountByCategory(1); // category=1 是画师
      if (existingCount > 0) {
        AppLogger.i('Artist tags already exist ($existingCount), skipping sync', 'DanbooruTagsCacheNotifier');
        return;
      }
    }
    
    // 更新状态为同步中
    state = AsyncValue.data(currentState.copyWith(
      isSyncingArtists: true,
      artistsProgress: 0.0,
    ),);
    
    try {
      await _requireService.fetchArtistTags(
        onProgress: (currentPage, importedCount, message) {
          final progress = currentPage > 0 ? (currentPage / 200).clamp(0.0, 1.0) : 0.0;
          state = AsyncValue.data(currentState.copyWith(
            isSyncingArtists: true,
            artistsProgress: progress,
            artistsTotal: importedCount,
          ),);
          // 调用外部进度回调（如果有）
          onExternalProgress?.call(currentPage, importedCount, message);
        },
        maxPages: 200,
      );
      
      // 同步完成
      final stats = await _requireService.getCategoryStats();
      state = AsyncValue.data(currentState.copyWith(
        isSyncingArtists: false,
        artistsProgress: 1.0,
        artistsTotal: stats['artist'] ?? 0,
        artistsLastUpdate: DateTime.now(),
        categoryStats: currentState.categoryStats.copyWith(
          artist: stats['artist'] ?? 0,
        ),
      ),);
      
      AppLogger.i('Artist sync completed successfully', 'DanbooruTagsCacheNotifier');
    } catch (e, stack) {
      AppLogger.e('Artist sync failed', e, stack, 'DanbooruTagsCacheNotifier');
      state = AsyncValue.data(currentState.copyWith(
        isSyncingArtists: false,
        error: '画师同步失败: $e',
      ),);
    }
  }

  /// 检查并自动同步画师标签（用于启动时调用）
  ///
  /// 注意：画师同步现在是默认行为，不再受设置开关控制
  Future<void> checkAndSyncArtists() async {
    try {
      // 关键修复：检查服务是否已初始化
      // 如果 Provider 正在重建（如清除缓存后），_service 可能为 null
      if (_service == null) {
        AppLogger.w(
          'DanbooruTagsLazyService not initialized yet, skipping artist sync check. '
          'This is normal during cache clear recovery.',
          'DanbooruTagsCacheNotifier',
        );
        return;
      }

      // 检查是否需要同步（基于画师标签数量，而不是总数）
      final existingCount = await _service!.getTagCountByCategory(1); // category=1 是画师
      if (existingCount == 0) {
        AppLogger.i('Auto-syncing artist tags on startup...', 'DanbooruTagsCacheNotifier');
        await syncArtists(force: false);
      } else {
        AppLogger.i('Artist tags already exist ($existingCount), no sync needed', 'DanbooruTagsCacheNotifier');
      }
    } catch (e, stack) {
      AppLogger.e('Failed to check and sync artists', e, stack, 'DanbooruTagsCacheNotifier');
    }
  }

  /// 取消画师同步
  Future<void> cancelArtistsSync() async {
    _requireService.cancelRefresh();
    final currentState = await future;
    state = AsyncValue.data(currentState.copyWith(isSyncingArtists: false));
  }

  // ===========================================================================
  // 分类阈值设置（V2新增）
  // ===========================================================================

  /// 设置一般标签的阈值
  Future<void> setGeneralThreshold(TagHotPreset preset, {int? customThreshold}) async {
    final currentState = await future;
    final newThresholds = currentState.categoryThresholds.copyWith(
      generalPreset: preset,
      generalCustomThreshold: customThreshold ?? preset.threshold,
    );

    await _saveCategoryThresholds(newThresholds);
    
    // 同步更新服务层的阈值
    await _requireService.setCategoryThresholds(
      generalThreshold: newThresholds.generalThreshold,
      artistThreshold: newThresholds.artistThreshold,
      characterThreshold: newThresholds.characterThreshold,
    );
    
    state = AsyncValue.data(currentState.copyWith(categoryThresholds: newThresholds));

    AppLogger.i(
      'General threshold set to: ${newThresholds.generalThreshold}',
      'DanbooruTagsCacheNotifier',
    );
  }

  /// 设置画师标签的阈值
  Future<void> setArtistThreshold(TagHotPreset preset, {int? customThreshold}) async {
    final currentState = await future;
    final newThresholds = currentState.categoryThresholds.copyWith(
      artistPreset: preset,
      artistCustomThreshold: customThreshold ?? preset.threshold,
    );

    await _saveCategoryThresholds(newThresholds);
    
    // 同步更新服务层的阈值
    await _requireService.setCategoryThresholds(
      generalThreshold: newThresholds.generalThreshold,
      artistThreshold: newThresholds.artistThreshold,
      characterThreshold: newThresholds.characterThreshold,
    );
    
    state = AsyncValue.data(currentState.copyWith(categoryThresholds: newThresholds));

    AppLogger.i(
      'Artist threshold set to: ${newThresholds.artistThreshold}',
      'DanbooruTagsCacheNotifier',
    );
  }

  /// 设置角色标签的阈值
  Future<void> setCharacterThreshold(TagHotPreset preset, {int? customThreshold}) async {
    final currentState = await future;
    final newThresholds = currentState.categoryThresholds.copyWith(
      characterPreset: preset,
      characterCustomThreshold: customThreshold ?? preset.threshold,
    );

    await _saveCategoryThresholds(newThresholds);
    
    // 同步更新服务层的阈值
    await _requireService.setCategoryThresholds(
      generalThreshold: newThresholds.generalThreshold,
      artistThreshold: newThresholds.artistThreshold,
      characterThreshold: newThresholds.characterThreshold,
    );
    
    state = AsyncValue.data(currentState.copyWith(categoryThresholds: newThresholds));

    AppLogger.i(
      'Character threshold set to: ${newThresholds.characterThreshold}',
      'DanbooruTagsCacheNotifier',
    );
  }

  /// 设置版权标签的阈值
  Future<void> setCopyrightThreshold(TagHotPreset preset, {int? customThreshold}) async {
    final currentState = await future;
    final newThresholds = currentState.categoryThresholds.copyWith(
      copyrightPreset: preset,
      copyrightCustomThreshold: customThreshold ?? preset.threshold,
    );

    await _saveCategoryThresholds(newThresholds);

    // 同步更新服务层的阈值
    await _requireService.setCategoryThresholds(
      generalThreshold: newThresholds.generalThreshold,
      artistThreshold: newThresholds.artistThreshold,
      characterThreshold: newThresholds.characterThreshold,
      copyrightThreshold: newThresholds.copyrightThreshold,
      metaThreshold: newThresholds.metaThreshold,
    );

    state = AsyncValue.data(currentState.copyWith(categoryThresholds: newThresholds));

    AppLogger.i(
      'Copyright threshold set to: ${newThresholds.copyrightThreshold}',
      'DanbooruTagsCacheNotifier',
    );
  }

  /// 设置元标签的阈值
  Future<void> setMetaThreshold(TagHotPreset preset, {int? customThreshold}) async {
    final currentState = await future;
    final newThresholds = currentState.categoryThresholds.copyWith(
      metaPreset: preset,
      metaCustomThreshold: customThreshold ?? preset.threshold,
    );

    await _saveCategoryThresholds(newThresholds);

    // 同步更新服务层的阈值
    await _requireService.setCategoryThresholds(
      generalThreshold: newThresholds.generalThreshold,
      artistThreshold: newThresholds.artistThreshold,
      characterThreshold: newThresholds.characterThreshold,
      copyrightThreshold: newThresholds.copyrightThreshold,
      metaThreshold: newThresholds.metaThreshold,
    );

    state = AsyncValue.data(currentState.copyWith(categoryThresholds: newThresholds));

    AppLogger.i(
      'Meta threshold set to: ${newThresholds.metaThreshold}',
      'DanbooruTagsCacheNotifier',
    );
  }

  /// 保存分类阈值配置
  Future<void> _saveCategoryThresholds(TagCategoryThresholds thresholds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        StorageKeys.danbooruCategoryThresholds,
        jsonEncode(thresholds.toJson()),
      );
    } catch (e) {
      AppLogger.e('Failed to save category thresholds', e, null, 'DanbooruTagsCacheNotifier');
    }
  }

  /// 使用当前阈值重新筛选标签
  /// 
  /// 这会触发标签服务的重新筛选，只保留符合阈值的标签
  Future<void> applyCategoryThresholds() async {
    final currentState = await future;

    // 更新状态为刷新中
    state = AsyncValue.data(currentState.copyWith(isRefreshing: true));

    try {
      // 同步阈值到服务层
      await _requireService.setCategoryThresholds(
        generalThreshold: currentState.categoryThresholds.generalThreshold,
        artistThreshold: currentState.categoryThresholds.artistThreshold,
        characterThreshold: currentState.categoryThresholds.characterThreshold,
        copyrightThreshold: currentState.categoryThresholds.copyrightThreshold,
        metaThreshold: currentState.categoryThresholds.metaThreshold,
      );

      // 刷新分类统计
      final stats = await _requireService.getCategoryStats();
      final newCategoryStats = TagCategoryStats(
        total: stats['total'] ?? 0,
        general: stats['general'] ?? 0,
        artist: stats['artist'] ?? 0,
        copyright: stats['copyright'] ?? 0,
        character: stats['character'] ?? 0,
        meta: stats['meta'] ?? 0,
      );

      state = AsyncValue.data(currentState.copyWith(
        isRefreshing: false,
        categoryStats: newCategoryStats,
      ),);

      AppLogger.i(
        'Category thresholds applied: general=${currentState.categoryThresholds.generalThreshold}, '
        'artist=${currentState.categoryThresholds.artistThreshold}, '
        'character=${currentState.categoryThresholds.characterThreshold}, '
        'copyright=${currentState.categoryThresholds.copyrightThreshold}, '
        'meta=${currentState.categoryThresholds.metaThreshold}',
        'DanbooruTagsCacheNotifier',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to apply category thresholds', e, stack, 'DanbooruTagsCacheNotifier');
      state = AsyncValue.data(currentState.copyWith(isRefreshing: false));
    }
  }

} 
