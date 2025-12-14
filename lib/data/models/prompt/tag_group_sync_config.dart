import 'package:freezed_annotation/freezed_annotation.dart';

import 'tag_group_mapping.dart';

part 'tag_group_sync_config.freezed.dart';
part 'tag_group_sync_config.g.dart';

/// Tag Group 同步配置
///
/// 管理 Danbooru Tag Group 同步的全局配置
/// 替代原有的 PoolSyncConfig
@freezed
class TagGroupSyncConfig with _$TagGroupSyncConfig {
  const TagGroupSyncConfig._();

  const factory TagGroupSyncConfig({
    /// 是否启用 Tag Group 同步
    @Default(true) bool enabled,

    /// Tag Group 映射列表
    @Default([]) List<TagGroupMapping> mappings,

    /// 最小帖子数量阈值（默认1000）
    /// 低于此阈值的标签将被过滤
    @Default(1000) int minPostCount,

    /// 每个分组最大获取标签数
    @Default(200) int maxTagsPerGroup,

    /// 上次完整同步时间
    DateTime? lastFullSyncTime,

    /// 同步间隔天数
    @Default(7) int syncIntervalDays,

    /// 是否默认包含子分组
    @Default(true) bool includeChildGroups,
  }) = _TagGroupSyncConfig;

  factory TagGroupSyncConfig.fromJson(Map<String, dynamic> json) =>
      _$TagGroupSyncConfigFromJson(json);

  /// 已启用的映射数量
  int get enabledMappingCount => mappings.where((m) => m.enabled).length;

  /// 是否有任何映射
  bool get hasMappings => mappings.isNotEmpty;

  /// 获取已启用的映射
  List<TagGroupMapping> get enabledMappings =>
      mappings.where((m) => m.enabled).toList();

  /// 根据 ID 查找映射
  TagGroupMapping? findMappingById(String id) {
    try {
      return mappings.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 根据分组标题查找映射
  TagGroupMapping? findMappingByGroupTitle(String groupTitle) {
    try {
      return mappings.firstWhere((m) => m.groupTitle == groupTitle);
    } catch (_) {
      return null;
    }
  }

  /// 检查分组是否已添加
  bool hasGroup(String groupTitle) =>
      mappings.any((m) => m.groupTitle == groupTitle);

  /// 是否需要同步
  bool shouldSync() {
    if (!enabled) return false;
    if (lastFullSyncTime == null) return true;
    final elapsed = DateTime.now().difference(lastFullSyncTime!);
    return elapsed.inDays >= syncIntervalDays;
  }

  /// 获取有效的最小热度阈值
  /// 确保值在合理范围内
  int get effectiveMinPostCount => minPostCount.clamp(0, 100000);
}

/// 预设的热度阈值选项
class PostCountThresholds {
  static const int veryLow = 100;
  static const int low = 500;
  static const int medium = 1000;
  static const int high = 5000;
  static const int veryHigh = 10000;

  static const List<int> presets = [
    veryLow,
    low,
    medium,
    high,
    veryHigh,
  ];

  /// 获取阈值的描述
  static String getDescription(int threshold) {
    if (threshold <= veryLow) return '非常宽松';
    if (threshold <= low) return '宽松';
    if (threshold <= medium) return '适中';
    if (threshold <= high) return '严格';
    return '非常严格';
  }
}
