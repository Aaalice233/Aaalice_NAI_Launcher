import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import 'pool_output_config.dart';
import 'tag_scope.dart';
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

  /// 来自内置词库（NAI官方标签）
  @JsonValue('builtin')
  builtin,
}

/// 节点类型
enum TagGroupNodeType {
  /// 字符串列表（标签）
  @JsonValue('str')
  str,

  /// 嵌套配置
  @JsonValue('config')
  config,
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

    /// emoji 图标（用于 UI 显示）
    @Default('') String emoji,

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

    /// 节点类型：str = 标签列表，config = 嵌套配置
    @Default(TagGroupNodeType.str) TagGroupNodeType nodeType,

    /// 嵌套的子词组（当 nodeType = config 时使用）
    @Default([]) List<RandomTagGroup> children,

    /// 最后同步时间（仅对 tagGroup/pool 类型有效）
    DateTime? lastSyncedAt,

    /// Pool 输出配置（仅对 pool 类型有效）
    @Default(PoolOutputConfig()) PoolOutputConfig poolOutputConfig,

    /// Pool 选择的帖子数量（用于 multipleNum 模式时的 post 数量）
    @Default(1) int poolPostCount,

    /// 是否启用性别限定
    @Default(false) bool genderRestrictionEnabled,

    /// 适用的性别列表（槽位名称，如 'girl', 'boy'，空表示全部适用）
    @Default([]) List<String> applicableGenders,

    /// 作用域
    @Default(TagScope.all) TagScope scope,

    /// 是否继承类别设置（用于"重置为类别设置"功能）
    @Default(true) bool inheritCategorySettings,
  }) = _RandomTagGroup;

  factory RandomTagGroup.fromJson(Map<String, dynamic> json) =>
      _$RandomTagGroupFromJson(json);

  /// 创建自定义分组
  factory RandomTagGroup.custom({
    required String name,
    String emoji = '',
    List<WeightedTag>? tags,
    SelectionMode selectionMode = SelectionMode.single,
    double probability = 1.0,
  }) {
    return RandomTagGroup(
      id: const Uuid().v4(),
      name: name,
      emoji: emoji,
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
    String emoji = '',
  }) {
    return RandomTagGroup(
      id: const Uuid().v4(),
      name: name,
      emoji: emoji,
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
    required int postCount,
    String emoji = '',
    PoolOutputConfig? outputConfig,
  }) {
    return RandomTagGroup(
      id: const Uuid().v4(),
      name: name,
      emoji: emoji,
      sourceType: TagGroupSourceType.pool,
      sourceId: poolId,
      tags: [], // Pool 不使用 tags 字段
      poolOutputConfig: outputConfig ?? const PoolOutputConfig(),
      lastSyncedAt: DateTime.now(),
    );
  }

  /// 从内置词库分类创建
  ///
  /// [builtinCategoryKey] 为 TagSubCategory 的 name，如 'hairColor', 'eyeColor' 等
  /// 实际标签从 TagLibrary 动态获取，不存储在 tags 字段中
  factory RandomTagGroup.fromBuiltin({
    required String name,
    required String builtinCategoryKey,
    String emoji = '✨',
  }) {
    return RandomTagGroup(
      id: const Uuid().v4(),
      name: name,
      emoji: emoji,
      sourceType: TagGroupSourceType.builtin,
      sourceId: builtinCategoryKey,
      tags: [], // 实际标签从 TagLibrary 动态获取
    );
  }

  /// 获取标签数量（包含嵌套）
  int get tagCount {
    if (nodeType == TagGroupNodeType.config) {
      return children.fold(0, (sum, child) => sum + child.tagCount);
    }
    return tags.length;
  }

  /// 是否可同步（来自外部源）
  bool get isSyncable =>
      sourceType == TagGroupSourceType.tagGroup ||
      sourceType == TagGroupSourceType.pool;

  /// 是否为内置词库类型
  bool get isBuiltin => sourceType == TagGroupSourceType.builtin;

  /// 是否为嵌套配置
  bool get isNested => nodeType == TagGroupNodeType.config;

  /// 深拷贝分组（生成新的ID，包含嵌套）
  RandomTagGroup deepCopy() {
    return copyWith(
      id: const Uuid().v4(),
      tags: tags.map((t) => t.copyWith()).toList(),
      children: children.map((c) => c.deepCopy()).toList(),
    );
  }

  /// 更新同步时间
  RandomTagGroup markSynced() {
    return copyWith(lastSyncedAt: DateTime.now());
  }

  /// 检查是否适用于指定性别（槽位名称）
  ///
  /// 如果未启用性别限定或适用性别列表为空，则适用于所有性别
  bool isApplicableToGender(String gender) {
    if (!genderRestrictionEnabled || applicableGenders.isEmpty) {
      return true;
    }
    return applicableGenders.contains(gender);
  }

  /// 检查是否适用于指定作用域
  bool isApplicableToScope(TagScope targetScope) {
    return scope.isApplicableTo(targetScope);
  }

  /// 从类别继承设置
  ///
  /// 将性别限定和作用域设置重置为所属类别的配置
  RandomTagGroup inheritFromCategory({
    required bool categoryGenderRestrictionEnabled,
    required List<String> categoryApplicableGenders,
    required TagScope categoryScope,
  }) {
    return copyWith(
      genderRestrictionEnabled: categoryGenderRestrictionEnabled,
      applicableGenders: categoryApplicableGenders,
      scope: categoryScope,
      inheritCategorySettings: true,
    );
  }
}
