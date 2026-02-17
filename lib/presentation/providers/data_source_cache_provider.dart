import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/services/services.dart';
import '../../core/services/danbooru_tags_lazy_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/cache/data_source_cache_meta.dart';

part 'data_source_cache_provider.g.dart';

/// 标签分类统计
class TagCategoryStats {
  final int total;
  final int general; // category 0: 一般标签
  final int artist; // category 1: 画师标签
  final int copyright; // category 2: 版权/作品标签
  final int character; // category 3: 角色标签
  final int meta; // category 4: 元标签

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
  final TagHotPreset hotPreset;
  final int customThreshold;
  final String? error;
  final AutoRefreshInterval refreshInterval;
  // 画师同步相关状态
  final bool syncArtists;
  final bool isSyncingArtists;
  final double artistsProgress;
  final int artistsTotal;
  final DateTime? artistsLastUpdate;

  const DanbooruTagsCacheState({
    this.isRefreshing = false,
    this.progress = 0.0,
    this.message,
    this.lastUpdate,
    this.totalTags = 0,
    this.categoryStats = const TagCategoryStats(),
    this.hotPreset = TagHotPreset.common1k,
    this.customThreshold = 1000,
    this.error,
    this.refreshInterval = AutoRefreshInterval.days30,
    // 画师同步默认值
    this.syncArtists = true,
    this.isSyncingArtists = false,
    this.artistsProgress = 0.0,
    this.artistsTotal = 0,
    this.artistsLastUpdate,
  });

  DanbooruTagsCacheState copyWith({
    bool? isRefreshing,
    double? progress,
    String? message,
    DateTime? lastUpdate,
    int? totalTags,
    TagCategoryStats? categoryStats,
    TagHotPreset? hotPreset,
    int? customThreshold,
    String? error,
    AutoRefreshInterval? refreshInterval,
    bool? syncArtists,
    bool? isSyncingArtists,
    double? artistsProgress,
    int? artistsTotal,
    DateTime? artistsLastUpdate,
  }) {
    return DanbooruTagsCacheState(
      isRefreshing: isRefreshing ?? this.isRefreshing,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      totalTags: totalTags ?? this.totalTags,
      categoryStats: categoryStats ?? this.categoryStats,
      hotPreset: hotPreset ?? this.hotPreset,
      customThreshold: customThreshold ?? this.customThreshold,
      error: error,
      refreshInterval: refreshInterval ?? this.refreshInterval,
      syncArtists: syncArtists ?? this.syncArtists,
      isSyncingArtists: isSyncingArtists ?? this.isSyncingArtists,
      artistsProgress: artistsProgress ?? this.artistsProgress,
      artistsTotal: artistsTotal ?? this.artistsTotal,
      artistsLastUpdate: artistsLastUpdate ?? this.artistsLastUpdate,
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
    // 等待服务初始化完成
    _service = await ref.watch(danbooruTagsLazyServiceProvider.future);

    final preset = _service!.getHotPreset();
    final refreshInterval = _service!.getRefreshInterval();

    // 获取标签数量和分类统计
    var count = 0;
    TagCategoryStats categoryStats = const TagCategoryStats();
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
    } catch (e) {
      // 静默失败
    }

    return DanbooruTagsCacheState(
      lastUpdate: _service!.lastUpdate,
      totalTags: count,
      categoryStats: categoryStats,
      hotPreset: preset,
      customThreshold: _service!.currentThreshold,
      refreshInterval: refreshInterval,
    );
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
    state = AsyncValue.data(currentState.copyWith(
      hotPreset: preset,
      customThreshold: customThreshold ?? currentState.customThreshold,
    ),);
  }

  /// 清除缓存
  Future<void> clearCache() async {
    if (_isClearing) return;
    _isClearing = true;

    try {
      // 如果服务已初始化，清除服务状态
      if (_service != null) {
        await _service!.clearCache();
      }

      // 更新状态为已清除
      state = const AsyncValue.data(
        DanbooruTagsCacheState(
          lastUpdate: null,
          totalTags: 0,
          hotPreset: TagHotPreset.common1k,
          customThreshold: 1000,
          refreshInterval: AutoRefreshInterval.days30,
        ),
      );

      // 关键：invalidate 懒加载服务 Provider，确保下次访问时重新创建实例
      ref.invalidate(danbooruTagsLazyServiceProvider);
      AppLogger.i(
        'Invalidated danbooruTagsLazyServiceProvider after clear cache',
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
    // TODO: 持久化到存储
  }

  /// 同步画师数据（占位实现）
  Future<void> syncArtists({bool force = false}) async {
    // TODO: 实现画师同步功能
  }

  /// 取消画师同步
  Future<void> cancelArtistsSync() async {
    final currentState = await future;
    state = AsyncValue.data(currentState.copyWith(isSyncingArtists: false));
  }
  
} 
