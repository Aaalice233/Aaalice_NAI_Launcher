import 'package:freezed_annotation/freezed_annotation.dart';

import 'pool_mapping.dart';

part 'pool_sync_config.freezed.dart';
part 'pool_sync_config.g.dart';

/// Pool 同步配置
///
/// 管理 Danbooru Pool 同步的全局配置
@freezed
class PoolSyncConfig with _$PoolSyncConfig {
  const PoolSyncConfig._();

  const factory PoolSyncConfig({
    /// 是否启用 Pool 同步
    @Default(false) bool enabled,

    /// Pool 映射列表
    @Default([]) List<PoolMapping> mappings,

    /// 每个 Pool 最大获取帖子数
    @Default(100) int maxPostsPerPool,

    /// 最小标签出现次数（过滤低频标签）
    @Default(3) int minTagOccurrence,

    /// 上次完整同步时间
    DateTime? lastFullSyncTime,
  }) = _PoolSyncConfig;

  factory PoolSyncConfig.fromJson(Map<String, dynamic> json) =>
      _$PoolSyncConfigFromJson(json);

  /// 已启用的映射数量
  int get enabledMappingCount => mappings.where((m) => m.enabled).length;

  /// 是否有任何映射
  bool get hasMappings => mappings.isNotEmpty;

  /// 获取已启用的映射
  List<PoolMapping> get enabledMappings =>
      mappings.where((m) => m.enabled).toList();

  /// 根据 ID 查找映射
  PoolMapping? findMappingById(String id) {
    try {
      return mappings.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 根据 Pool ID 查找映射
  PoolMapping? findMappingByPoolId(int poolId) {
    try {
      return mappings.firstWhere((m) => m.poolId == poolId);
    } catch (_) {
      return null;
    }
  }

  /// 检查 Pool 是否已添加
  bool hasPool(int poolId) => mappings.any((m) => m.poolId == poolId);
}

/// Pool 同步进度
class PoolSyncProgress {
  final double progress; // 0.0 - 1.0
  final String message;
  final String? currentPool;
  final int completedCount;
  final int totalCount;

  const PoolSyncProgress({
    required this.progress,
    required this.message,
    this.currentPool,
    this.completedCount = 0,
    this.totalCount = 0,
  });

  factory PoolSyncProgress.initial() {
    return const PoolSyncProgress(
      progress: 0,
      message: '准备同步...',
    );
  }

  factory PoolSyncProgress.fetching(String poolName, int completed, int total) {
    return PoolSyncProgress(
      progress: completed / total.clamp(1, double.infinity),
      message: '正在获取 $poolName...',
      currentPool: poolName,
      completedCount: completed,
      totalCount: total,
    );
  }

  factory PoolSyncProgress.extracting(String poolName) {
    return PoolSyncProgress(
      progress: 0.8,
      message: '正在提取 $poolName 标签...',
      currentPool: poolName,
    );
  }

  factory PoolSyncProgress.merging() {
    return const PoolSyncProgress(
      progress: 0.9,
      message: '正在合并标签...',
    );
  }

  factory PoolSyncProgress.saving() {
    return const PoolSyncProgress(
      progress: 0.95,
      message: '正在保存...',
    );
  }

  factory PoolSyncProgress.completed(int tagCount) {
    return PoolSyncProgress(
      progress: 1.0,
      message: '同步完成，共 $tagCount 个标签',
      completedCount: tagCount,
    );
  }

  factory PoolSyncProgress.failed(String error) {
    return PoolSyncProgress(
      progress: 0,
      message: '同步失败: $error',
    );
  }
}
