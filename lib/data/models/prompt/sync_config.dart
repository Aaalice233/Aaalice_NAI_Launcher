import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_config.freezed.dart';
part 'sync_config.g.dart';

/// 数据量范围
///
/// 决定从 Danbooru 拉取多少标签
enum DataRange {
  /// 热门标签（约1000个，post_count > 1000）
  @JsonValue('popular')
  popular,

  /// 中等规模（约5000个，post_count > 500）
  @JsonValue('medium')
  medium,

  /// 完整数据（约20000个，post_count > 100）
  @JsonValue('full')
  full,
}

/// 同步状态
enum SyncStatus {
  /// 空闲
  @JsonValue('idle')
  idle,

  /// 同步中
  @JsonValue('syncing')
  syncing,

  /// 同步成功
  @JsonValue('success')
  success,

  /// 同步失败
  @JsonValue('failed')
  failed,
}

/// 词库同步配置
@freezed
class TagLibrarySyncConfig with _$TagLibrarySyncConfig {
  const TagLibrarySyncConfig._();

  const factory TagLibrarySyncConfig({
    /// 是否启用自动同步
    @Default(true) bool autoSyncEnabled,

    /// 同步间隔（天）
    @Default(30) int syncIntervalDays,

    /// 数据量范围
    @Default(DataRange.medium) DataRange dataRange,

    /// 上次同步时间
    DateTime? lastSyncTime,

    /// 当前同步状态
    @Default(SyncStatus.idle) SyncStatus status,

    /// 上次同步的标签数量
    @Default(0) int lastSyncTagCount,

    /// 上次同步错误信息
    String? lastError,
  }) = _TagLibrarySyncConfig;

  factory TagLibrarySyncConfig.fromJson(Map<String, dynamic> json) =>
      _$TagLibrarySyncConfigFromJson(json);

  /// 检查是否需要同步
  bool shouldSync() {
    if (!autoSyncEnabled) return false;
    if (lastSyncTime == null) return true;

    final daysSinceLastSync =
        DateTime.now().difference(lastSyncTime!).inDays;
    return daysSinceLastSync >= syncIntervalDays;
  }

  /// 获取下次同步时间
  DateTime? get nextSyncTime {
    if (!autoSyncEnabled || lastSyncTime == null) return null;
    return lastSyncTime!.add(Duration(days: syncIntervalDays));
  }

  /// 获取数据范围的最小 post_count
  int get minPostCount {
    return switch (dataRange) {
      DataRange.popular => 1000,
      DataRange.medium => 500,
      DataRange.full => 100,
    };
  }

  /// 获取数据范围的预估标签数
  int get estimatedTagCount {
    return switch (dataRange) {
      DataRange.popular => 1000,
      DataRange.medium => 5000,
      DataRange.full => 20000,
    };
  }

  /// 格式化上次同步时间
  String formatLastSyncTime() {
    if (lastSyncTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(lastSyncTime!);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 30) {
      return '${diff.inDays}天前';
    } else {
      return '${lastSyncTime!.year}-${lastSyncTime!.month.toString().padLeft(2, '0')}-${lastSyncTime!.day.toString().padLeft(2, '0')}';
    }
  }
}

/// 同步进度
class SyncProgress {
  final double progress; // 0.0 - 1.0
  final String message;
  final String? currentCategory;
  final int fetchedCount;
  final int totalEstimate;

  const SyncProgress({
    required this.progress,
    required this.message,
    this.currentCategory,
    this.fetchedCount = 0,
    this.totalEstimate = 0,
  });

  factory SyncProgress.initial() {
    return const SyncProgress(
      progress: 0,
      message: '准备同步...',
    );
  }

  factory SyncProgress.fetching(String category, int fetched, int total) {
    return SyncProgress(
      progress: fetched / total.clamp(1, double.infinity),
      message: '正在获取 $category...',
      currentCategory: category,
      fetchedCount: fetched,
      totalEstimate: total,
    );
  }

  factory SyncProgress.processing() {
    return const SyncProgress(
      progress: 0.9,
      message: '正在处理数据...',
    );
  }

  factory SyncProgress.saving() {
    return const SyncProgress(
      progress: 0.95,
      message: '正在保存...',
    );
  }

  factory SyncProgress.completed(int count) {
    return SyncProgress(
      progress: 1.0,
      message: '同步完成，共 $count 个标签',
      fetchedCount: count,
    );
  }

  factory SyncProgress.failed(String error) {
    return SyncProgress(
      progress: 0,
      message: '同步失败: $error',
    );
  }
}
