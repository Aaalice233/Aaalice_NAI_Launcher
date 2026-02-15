import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/services/danbooru_tags_lazy_service.dart';
import '../../core/services/unified_tag_database.dart';
import '../../data/models/cache/data_source_cache_meta.dart';

part 'data_source_cache_provider.g.dart';

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
      refreshInterval: refreshInterval ?? this.refreshInterval,
    );
  }
}

/// Danbooru 标签缓存 Notifier
@Riverpod(keepAlive: true)
class DanbooruTagsCacheNotifier extends _$DanbooruTagsCacheNotifier {
  @override
  DanbooruTagsCacheState build() {
    // 在 build 中同步初始化状态，避免访问未初始化的 state
    final service = ref.read(danbooruTagsLazyServiceProvider);
    final preset = service.getHotPreset();
    final refreshInterval = service.getRefreshInterval();

    // 异步加载标签数量
    _loadTagCount();

    return DanbooruTagsCacheState(
      lastUpdate: service.lastUpdate,
      totalTags: 0,
      hotPreset: preset,
      customThreshold: service.currentThreshold,
      refreshInterval: refreshInterval,
    );
  }

  /// 从数据库加载标签数量
  Future<void> _loadTagCount() async {
    try {
      final db = ref.read(unifiedTagDatabaseProvider);
      await db.initialize();
      final count = await db.getDanbooruTagCount();
      state = state.copyWith(totalTags: count);
    } catch (e) {
      // 静默失败，保持现有状态
    }
  }

  /// 手动刷新标签数据
  Future<void> refresh() async {
    if (state.isRefreshing) return;

    state = state.copyWith(isRefreshing: true, progress: 0.0, error: null);

    final service = ref.read(danbooruTagsLazyServiceProvider);
    service.onProgress = (progress, message) {
      state = state.copyWith(progress: progress, message: message);
    };

    try {
      await service.refresh();
      // 刷新完成后重新加载标签数量
      final db = ref.read(unifiedTagDatabaseProvider);
      final count = await db.getDanbooruTagCount();
      state = state.copyWith(
        isRefreshing: false,
        progress: 1.0,
        lastUpdate: DateTime.now(),
        totalTags: count,
        message: null,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        error: e.toString(),
      );
    } finally {
      service.onProgress = null;
    }
  }

  /// 取消同步
  void cancelSync() {
    final service = ref.read(danbooruTagsLazyServiceProvider);
    service.cancelRefresh();
  }

  /// 设置热度档位
  Future<void> setHotPreset(TagHotPreset preset, {int? customThreshold}) async {
    final service = ref.read(danbooruTagsLazyServiceProvider);
    await service.setHotPreset(preset, customThreshold: customThreshold);

    state = state.copyWith(
      hotPreset: preset,
      customThreshold: customThreshold ?? state.customThreshold,
    );
  }

  /// 清除缓存
  Future<void> clearCache() async {
    final service = ref.read(danbooruTagsLazyServiceProvider);
    await service.clearCache();

    state = state.copyWith(
      lastUpdate: null,
      totalTags: 0,
    );
  }

  /// 设置自动刷新间隔
  Future<void> setRefreshInterval(AutoRefreshInterval interval) async {
    final service = ref.read(danbooruTagsLazyServiceProvider);
    await service.setRefreshInterval(interval);
    state = state.copyWith(refreshInterval: interval);
  }
}
