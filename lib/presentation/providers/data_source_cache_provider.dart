import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/services/danbooru_tags_lazy_service.dart';
import '../../core/services/danbooru_tags_sync_service.dart';
import '../../core/services/hf_translation_sync_service.dart';
import '../../core/services/translation_lazy_service.dart';
import '../../data/models/cache/data_source_cache_meta.dart';

part 'data_source_cache_provider.g.dart';

/// HuggingFace 翻译缓存状态
class HFTranslationCacheState {
  final bool isRefreshing;
  final double progress;
  final String? message;
  final DateTime? lastUpdate;
  final int totalTags;
  final AutoRefreshInterval refreshInterval;
  final String? error;

  const HFTranslationCacheState({
    this.isRefreshing = false,
    this.progress = 0.0,
    this.message,
    this.lastUpdate,
    this.totalTags = 0,
    this.refreshInterval = AutoRefreshInterval.days30,
    this.error,
  });

  HFTranslationCacheState copyWith({
    bool? isRefreshing,
    double? progress,
    String? message,
    DateTime? lastUpdate,
    int? totalTags,
    AutoRefreshInterval? refreshInterval,
    String? error,
  }) {
    return HFTranslationCacheState(
      isRefreshing: isRefreshing ?? this.isRefreshing,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      totalTags: totalTags ?? this.totalTags,
      refreshInterval: refreshInterval ?? this.refreshInterval,
      error: error,
    );
  }
}

/// HuggingFace 翻译缓存 Notifier
@riverpod
class HFTranslationCacheNotifier extends _$HFTranslationCacheNotifier {
  @override
  HFTranslationCacheState build() {
    _initialize();
    return const HFTranslationCacheState();
  }

  Future<void> _initialize() async {
    final service = ref.read(hfTranslationSyncServiceProvider);
    await service.initialize();

    final interval = await service.getRefreshInterval();

    state = state.copyWith(
      lastUpdate: service.lastUpdate,
      totalTags: service.translationCount,
      refreshInterval: interval,
    );
  }

  /// 手动刷新
  Future<void> refresh() async {
    if (state.isRefreshing) return;

    state = state.copyWith(isRefreshing: true, progress: 0.0, error: null);

    final service = ref.read(hfTranslationSyncServiceProvider);
    service.onSyncProgress = (progress, message) {
      state = state.copyWith(progress: progress, message: message);
    };

    try {
      final result = await service.syncTranslations();
      state = state.copyWith(
        isRefreshing: false,
        progress: 1.0,
        lastUpdate: DateTime.now(),
        totalTags: result.length,
        message: null,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        error: e.toString(),
      );
    } finally {
      service.onSyncProgress = null;
    }
  }

  /// 设置刷新间隔
  Future<void> setRefreshInterval(AutoRefreshInterval interval) async {
    final service = ref.read(hfTranslationSyncServiceProvider);
    await service.setRefreshInterval(interval);
    state = state.copyWith(refreshInterval: interval);
  }

  /// 清除缓存
  Future<void> clearCache() async {
    // 清除旧服务的缓存
    final service = ref.read(hfTranslationSyncServiceProvider);
    await service.clearCache();

    // 同时清除新懒加载服务的缓存（SQLite 数据库）
    try {
      final lazyService = ref.read(translationLazyServiceProvider);
      await lazyService.clearCache();
    } catch (e) {
      // 如果懒加载服务未初始化，忽略错误
    }

    state = state.copyWith(
      lastUpdate: null,
      totalTags: 0,
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
  final TagHotPreset hotPreset;
  final int customThreshold;
  final String? error;
  final AutoRefreshInterval refreshInterval;

  // 画师同步相关状态
  final bool syncArtists;
  final bool isSyncingArtists;
  final double artistsProgress;
  final int artistsTotal;  // 已拉取数量
  final int artistsEstimatedTotal;  // 预估总数（用于显示进度）
  final DateTime? artistsLastUpdate;
  final bool artistsSyncFailed;

  const DanbooruTagsCacheState({
    this.isRefreshing = false,
    this.progress = 0.0,
    this.message,
    this.lastUpdate,
    this.totalTags = 0,
    this.hotPreset = TagHotPreset.common1k,
    this.customThreshold = 1000,
    this.error,
    this.refreshInterval = AutoRefreshInterval.days30,
    // 画师同步默认开启
    this.syncArtists = true,
    this.isSyncingArtists = false,
    this.artistsProgress = 0.0,
    this.artistsTotal = 0,
    this.artistsEstimatedTotal = 0,
    this.artistsLastUpdate,
    this.artistsSyncFailed = false,
  });

  DanbooruTagsCacheState copyWith({
    bool? isRefreshing,
    double? progress,
    String? message,
    DateTime? lastUpdate,
    int? totalTags,
    TagHotPreset? hotPreset,
    int? customThreshold,
    String? error,
    AutoRefreshInterval? refreshInterval,
    bool? syncArtists,
    bool? isSyncingArtists,
    double? artistsProgress,
    int? artistsTotal,
    int? artistsEstimatedTotal,
    DateTime? artistsLastUpdate,
    bool? artistsSyncFailed,
  }) {
    return DanbooruTagsCacheState(
      isRefreshing: isRefreshing ?? this.isRefreshing,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      totalTags: totalTags ?? this.totalTags,
      hotPreset: hotPreset ?? this.hotPreset,
      customThreshold: customThreshold ?? this.customThreshold,
      error: error ?? this.error,
      refreshInterval: refreshInterval ?? this.refreshInterval,
      syncArtists: syncArtists ?? this.syncArtists,
      isSyncingArtists: isSyncingArtists ?? this.isSyncingArtists,
      artistsProgress: artistsProgress ?? this.artistsProgress,
      artistsTotal: artistsTotal ?? this.artistsTotal,
      artistsEstimatedTotal: artistsEstimatedTotal ?? this.artistsEstimatedTotal,
      artistsLastUpdate: artistsLastUpdate ?? this.artistsLastUpdate,
      artistsSyncFailed: artistsSyncFailed ?? this.artistsSyncFailed,
    );
  }
}

/// Danbooru 标签缓存 Notifier
@Riverpod(keepAlive: true)
class DanbooruTagsCacheNotifier extends _$DanbooruTagsCacheNotifier {
  @override
  DanbooruTagsCacheState build() {
    _initialize();
    return const DanbooruTagsCacheState();
  }

  Future<void> _initialize() async {
    final service = ref.read(danbooruTagsSyncServiceProvider);
    await service.initialize();

    final preset = await service.getHotPreset();
    final syncArtists = await service.getSyncArtistsSetting();
    final refreshInterval = await service.getRefreshInterval();

    state = state.copyWith(
      lastUpdate: service.lastUpdate,
      totalTags: service.tagCount,
      hotPreset: preset,
      customThreshold: service.currentThreshold,
      refreshInterval: refreshInterval,
      syncArtists: syncArtists,
      artistsTotal: service.cachedArtistsCount,
      artistsLastUpdate: service.artistsLastUpdate,
      artistsSyncFailed: service.artistsSyncFailed,
    );
  }

  /// 手动刷新标签数据
  Future<void> refresh() async {
    if (state.isRefreshing) return;

    state = state.copyWith(isRefreshing: true, progress: 0.0, error: null);

    final service = ref.read(danbooruTagsSyncServiceProvider);
    service.onSyncProgress = (progress, message) {
      state = state.copyWith(progress: progress, message: message);
    };

    try {
      final threshold = state.hotPreset.isCustom
          ? state.customThreshold
          : state.hotPreset.threshold;

      final result = await service.syncHotTags(minPostCount: threshold);
      state = state.copyWith(
        isRefreshing: false,
        progress: 1.0,
        lastUpdate: DateTime.now(),
        totalTags: result.length,
        message: null,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        error: e.toString(),
      );
    } finally {
      service.onSyncProgress = null;
    }
  }

  /// 取消同步
  void cancelSync() {
    final service = ref.read(danbooruTagsSyncServiceProvider);
    service.cancelSync();
  }

  /// 设置热度档位
  Future<void> setHotPreset(TagHotPreset preset, {int? customThreshold}) async {
    final service = ref.read(danbooruTagsSyncServiceProvider);
    await service.setHotPreset(preset, customThreshold: customThreshold);

    state = state.copyWith(
      hotPreset: preset,
      customThreshold: customThreshold ?? state.customThreshold,
    );
  }

  /// 清除缓存
  Future<void> clearCache() async {
    // 清除旧服务的缓存
    final service = ref.read(danbooruTagsSyncServiceProvider);
    await service.clearCache();

    // 同时清除新懒加载服务的缓存（SQLite 数据库）
    try {
      final lazyService = ref.read(danbooruTagsLazyServiceProvider);
      await lazyService.clearCache();
    } catch (e) {
      // 如果懒加载服务未初始化，忽略错误
    }

    state = state.copyWith(
      lastUpdate: null,
      totalTags: 0,
    );
  }

  /// 设置自动刷新间隔
  Future<void> setRefreshInterval(AutoRefreshInterval interval) async {
    final service = ref.read(danbooruTagsSyncServiceProvider);
    await service.setRefreshInterval(interval);
    state = state.copyWith(refreshInterval: interval);
  }

  /// 设置画师同步开关
  Future<void> setSyncArtists(bool value) async {
    final service = ref.read(danbooruTagsSyncServiceProvider);
    await service.setSyncArtistsSetting(value);
    state = state.copyWith(syncArtists: value);

    // 如果开启同步且需要同步，立即执行
    if (value) {
      final shouldSync = await service.shouldSyncArtists();
      if (shouldSync) {
        await syncArtists();
      }
    }
  }

  /// 同步画师数据
  ///
  /// 根据条件自动判断是否同步，或强制刷新
  Future<void> syncArtists({bool force = false}) async {
    if (state.isSyncingArtists) return;

    state = state.copyWith(
      isSyncingArtists: true,
      artistsProgress: 0.0,
      artistsSyncFailed: false,
    );

    final service = ref.read(danbooruTagsSyncServiceProvider);
    service.onArtistsSyncProgress = (progress, fetched, estimatedTotal) {
      state = state.copyWith(
        artistsProgress: progress,
        artistsTotal: fetched,
        artistsEstimatedTotal: estimatedTotal,
      );
    };

    try {
      final result = await service.syncArtists(force: force, minPostCount: 50);
      state = state.copyWith(
        isSyncingArtists: false,
        artistsProgress: 1.0,
        artistsTotal: result.length,
        artistsLastUpdate: DateTime.now(),
        artistsSyncFailed: false,
      );
    } catch (e) {
      state = state.copyWith(
        isSyncingArtists: false,
        artistsSyncFailed: true,
      );
    } finally {
      service.onArtistsSyncProgress = null;
    }
  }

  /// 取消画师同步
  void cancelArtistsSync() {
    final service = ref.read(danbooruTagsSyncServiceProvider);
    service.cancelArtistsSync();
  }

  /// 清除画师缓存
  Future<void> clearArtistsCache() async {
    final service = ref.read(danbooruTagsSyncServiceProvider);
    await service.clearArtistsCache();
    state = state.copyWith(
      artistsTotal: 0,
      artistsLastUpdate: null,
      artistsSyncFailed: false,
    );
  }
}
