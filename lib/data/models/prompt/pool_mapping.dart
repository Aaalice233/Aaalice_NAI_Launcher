import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/widgets.dart';

import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'pool_output_config.dart';
import 'tag_category.dart';

part 'pool_mapping.freezed.dart';
part 'pool_mapping.g.dart';

/// Pool 映射配置
///
/// 将 Danbooru Pool 映射到 NAI 标签分类
@freezed
class PoolMapping with _$PoolMapping {
  const PoolMapping._();

  const factory PoolMapping({
    /// 唯一标识符
    required String id,

    /// Danbooru Pool ID
    required int poolId,

    /// Pool 名称（用于显示）
    required String poolName,

    /// Pool 帖子数量
    @Default(0) int postCount,

    /// 目标 NAI 分类
    required TagSubCategory targetCategory,

    /// 是否启用
    @Default(true) bool enabled,

    /// 创建时间
    required DateTime createdAt,

    /// 上次同步时间
    DateTime? lastSyncedAt,

    /// 上次同步的帖子数量（已缓存）
    @Default(0) int lastSyncedPostCount,

    /// Pool 输出配置
    @Default(PoolOutputConfig()) PoolOutputConfig outputConfig,
  }) = _PoolMapping;

  factory PoolMapping.fromJson(Map<String, dynamic> json) =>
      _$PoolMappingFromJson(json);

  /// Pool 显示名称（空格格式）
  String get poolDisplayName => poolName.replaceAll('_', ' ');

  /// 目标分类显示名称
  String get categoryDisplayName =>
      TagSubCategoryHelper.getDisplayName(targetCategory);

  /// 是否已同步过
  bool get hasSynced => lastSyncedAt != null;

  /// 格式化上次同步时间
  String formatLastSyncTime(BuildContext context) {
    if (lastSyncedAt == null) return context.l10n.time_never_synced;

    final diff = DateTime.now().difference(lastSyncedAt!);

    if (diff.inMinutes < 1) return context.l10n.time_just_now;
    if (diff.inHours < 1) return context.l10n.time_minutes_ago(diff.inMinutes);
    if (diff.inDays < 1) return context.l10n.time_hours_ago(diff.inHours);
    if (diff.inDays < 30) return context.l10n.time_days_ago(diff.inDays);

    return '${lastSyncedAt!.year}-${lastSyncedAt!.month.toString().padLeft(2, '0')}-${lastSyncedAt!.day.toString().padLeft(2, '0')}';
  }
}
