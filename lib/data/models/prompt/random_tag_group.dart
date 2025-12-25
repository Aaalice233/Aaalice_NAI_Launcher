import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import 'weighted_tag.dart';

part 'random_tag_group.freezed.dart';
part 'random_tag_group.g.dart';

/// 选择模式
enum SelectionMode {
  /// 单选（加权随机选择一个）
  @JsonValue('single')
  single,

  /// 全选（选择所有子项）
  @JsonValue('all')
  all,

  /// 多选指定数量
  @JsonValue('multiple_num')
  multipleNum,

  /// 多选概率模式（每个子项独立概率判断）
  @JsonValue('multiple_prob')
  multipleProb,

  /// 顺序轮替（跨批次保持状态）
  @JsonValue('sequential')
  sequential,
}

/// 标签分组来源类型
enum TagGroupSourceType {
  /// 用户自定义
  @JsonValue('custom')
  custom,

  /// 来自 Danbooru Tag Group
  @JsonValue('tag_group')
  tagGroup,

  /// 来自 Danbooru Pool
  @JsonValue('pool')
  pool,
}

/// 随机标签分组
///
/// 表示类别下的一个标签分组，可以是用户自定义的，
/// 也可以是从 Danbooru Tag Group 或 Pool 同步而来的。
@freezed
class RandomTagGroup with _$RandomTagGroup {
  const RandomTagGroup._();

  const factory RandomTagGroup({
    /// 分组ID
    required String id,

    /// 显示名称
    required String name,

    /// 来源类型
    @Default(TagGroupSourceType.custom) TagGroupSourceType sourceType,

    /// 来源ID（Danbooru tag_group 名或 pool ID）
    String? sourceId,

    /// 是否启用
    @Default(true) bool enabled,

    /// 被选中的概率 (0.0 - 1.0)
    @Default(1.0) double probability,

    /// 选择模式
    @Default(SelectionMode.single) SelectionMode selectionMode,

    /// multiple_num 模式下选择的数量
    @Default(1) int multipleNum,

    /// 权重括号最小层数 (0-5)
    @Default(0) int bracketMin,

    /// 权重括号最大层数 (0-5)
    @Default(0) int bracketMax,

    /// 是否打乱输出顺序
    @Default(true) bool shuffle,

    /// 标签列表
    @Default([]) List<WeightedTag> tags,

    /// 最后同步时间（仅对 tagGroup/pool 类型有效）
    DateTime? lastSyncedAt,
  }) = _RandomTagGroup;

  factory RandomTagGroup.fromJson(Map<String, dynamic> json) =>
      _$RandomTagGroupFromJson(json);

  /// 创建自定义分组
  factory RandomTagGroup.custom({
    required String name,
    List<WeightedTag>? tags,
    SelectionMode selectionMode = SelectionMode.single,
    double probability = 1.0,
  }) {
    return RandomTagGroup(
      id: const Uuid().v4(),
      name: name,
      sourceType: TagGroupSourceType.custom,
      selectionMode: selectionMode,
      probability: probability,
      tags: tags ?? [],
    );
  }

  /// 从 Danbooru Tag Group 创建
  factory RandomTagGroup.fromTagGroup({
    required String name,
    required String tagGroupName,
    required List<WeightedTag> tags,
  }) {
    return RandomTagGroup(
      id: const Uuid().v4(),
      name: name,
      sourceType: TagGroupSourceType.tagGroup,
      sourceId: tagGroupName,
      tags: tags,
      lastSyncedAt: DateTime.now(),
    );
  }

  /// 从 Danbooru Pool 创建
  factory RandomTagGroup.fromPool({
    required String name,
    required String poolId,
    required List<WeightedTag> tags,
  }) {
    return RandomTagGroup(
      id: const Uuid().v4(),
      name: name,
      sourceType: TagGroupSourceType.pool,
      sourceId: poolId,
      tags: tags,
      lastSyncedAt: DateTime.now(),
    );
  }

  /// 获取标签数量
  int get tagCount => tags.length;

  /// 是否可同步（来自外部源）
  bool get isSyncable =>
      sourceType == TagGroupSourceType.tagGroup ||
      sourceType == TagGroupSourceType.pool;

  /// 深拷贝分组（生成新的ID）
  RandomTagGroup deepCopy() {
    return copyWith(
      id: const Uuid().v4(),
      tags: tags.map((t) => t.copyWith()).toList(),
    );
  }

  /// 更新同步时间
  RandomTagGroup markSynced() {
    return copyWith(lastSyncedAt: DateTime.now());
  }
}
