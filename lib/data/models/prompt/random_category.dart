import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import 'random_tag_group.dart';
import 'tag_scope.dart';

// 从 random_tag_group.dart 重新导出 SelectionMode 以便使用
export 'random_tag_group.dart' show SelectionMode;

part 'random_category.freezed.dart';
part 'random_category.g.dart';

/// 随机类别
///
/// 表示随机提示词中的一个大类别（如发色、瞳色等），
/// 每个类别包含多个标签分组。
@freezed
class RandomCategory with _$RandomCategory {
  const RandomCategory._();

  const factory RandomCategory({
    /// 类别ID
    required String id,

    /// 显示名称（如"发色"）
    required String name,

    /// 类别键名（如"hairColor"，用于程序内部标识）
    required String key,

    /// emoji 图标（用于 UI 显示）
    @Default('') String emoji,

    /// 是否为内置类别（不可删除，不可修改 emoji）
    @Default(false) bool isBuiltin,

    /// 是否启用该类别
    @Default(true) bool enabled,

    /// 类别被选中的概率 (0.0 - 1.0)
    @Default(1.0) double probability,

    /// 词组选取模式（从下属词组中如何选取）
    @Default(SelectionMode.single) SelectionMode groupSelectionMode,

    /// 词组选取数量（多选模式下选择几个词组）
    @Default(1) int groupSelectCount,

    /// 是否打乱输出顺序
    @Default(true) bool shuffle,

    /// 统一权重括号最小层数 (0-5)，应用于所有下属词组
    @Default(0) int unifiedBracketMin,

    /// 统一权重括号最大层数 (0-5)，应用于所有下属词组
    @Default(0) int unifiedBracketMax,

    /// 是否启用统一权重括号设置（false则使用各词组自己的设置）
    @Default(false) bool useUnifiedBracket,

    /// 标签分组列表
    @Default([]) List<RandomTagGroup> groups,

    /// 是否启用性别限定
    @Default(false) bool genderRestrictionEnabled,

    /// 适用的性别列表（槽位名称，如 'girl', 'boy'，空表示全部适用）
    @Default([]) List<String> applicableGenders,

    /// 作用域
    @Default(TagScope.all) TagScope scope,
  }) = _RandomCategory;

  factory RandomCategory.fromJson(Map<String, dynamic> json) =>
      _$RandomCategoryFromJson(json);

  /// 创建新类别
  factory RandomCategory.create({
    required String name,
    required String key,
    String emoji = '',
    bool isBuiltin = false,
    List<RandomTagGroup>? groups,
  }) {
    return RandomCategory(
      id: const Uuid().v4(),
      name: name,
      key: key,
      emoji: emoji,
      isBuiltin: isBuiltin,
      groups: groups ?? [],
    );
  }

  /// 获取分组数量
  int get groupCount => groups.length;

  /// 获取启用的分组数量
  int get enabledGroupCount => groups.where((g) => g.enabled).length;

  /// 获取所有标签总数
  int get totalTagCount => groups.fold(0, (sum, group) => sum + group.tagCount);

  /// 获取启用分组的标签总数
  int get enabledTagCount => enabled
      ? groups
          .where((g) => g.enabled)
          .fold(0, (sum, group) => sum + group.tagCount)
      : 0;

  /// 深拷贝类别（生成新的ID）
  RandomCategory deepCopy() {
    return copyWith(
      id: const Uuid().v4(),
      groups: groups.map((g) => g.deepCopy()).toList(),
    );
  }

  /// 添加分组
  RandomCategory addGroup(RandomTagGroup group) {
    return copyWith(groups: [...groups, group]);
  }

  /// 删除分组
  RandomCategory removeGroup(String groupId) {
    return copyWith(
      groups: groups.where((g) => g.id != groupId).toList(),
    );
  }

  /// 更新分组
  RandomCategory updateGroup(RandomTagGroup updatedGroup) {
    final index = groups.indexWhere((g) => g.id == updatedGroup.id);
    if (index == -1) return this;

    final newGroups = [...groups];
    newGroups[index] = updatedGroup;
    return copyWith(groups: newGroups);
  }

  /// 通过ID查找分组
  RandomTagGroup? findGroupById(String groupId) {
    for (final group in groups) {
      if (group.id == groupId) return group;
    }
    return null;
  }

  /// 重新排序分组
  RandomCategory reorderGroups(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= groups.length ||
        newIndex < 0 ||
        newIndex > groups.length) {
      return this;
    }

    final newGroups = [...groups];
    final item = newGroups.removeAt(oldIndex);
    // 如果 newIndex 在 removeAt 之后仍然有效，直接插入
    final insertIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    newGroups.insert(insertIndex.clamp(0, newGroups.length), item);
    return copyWith(groups: newGroups);
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
}
