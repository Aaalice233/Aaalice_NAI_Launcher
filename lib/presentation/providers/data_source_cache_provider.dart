import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/services/danbooru_tags_sync_service.dart';
import '../../core/services/hf_translation_sync_service.dart';
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
    final service = ref.read(hfTranslationSyncServiceProvider);
    await service.clearCache();
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

  const DanbooruTagsCacheState({
    this.isRefreshing = false,
    this.progress = 0.0,
    this.message,
    this.lastUpdate,
    this.totalTags = 0,
    this.hotPreset = TagHotPreset.common1k,
    this.customThreshold = 1000,
    this.error,
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
  }) {
    return DanbooruTagsCacheState(
      isRefreshing: isRefreshing ?? this.isRefreshing,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      totalTags: totalTags ?? this.totalTags,
      hotPreset: hotPreset ?? this.hotPreset,
      customThreshold: customThreshold ?? this.customThreshold,
      error: error,
    );
  }
}

/// Danbooru 标签缓存 Notifier
@riverpod
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

    state = state.copyWith(
      lastUpdate: service.lastUpdate,
      totalTags: service.tagCount,
      hotPreset: preset,
      customThreshold: service.currentThreshold,
    );
  }

  /// 手动刷新
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
    final service = ref.read(danbooruTagsSyncServiceProvider);
    await service.clearCache();
    state = state.copyWith(
      lastUpdate: null,
      totalTags: 0,
    );
  }
}
