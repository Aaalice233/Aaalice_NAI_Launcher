import 'package:flutter/foundation.dart';

import 'conditional_branch.dart';
import 'random_category.dart';
import 'random_tag_group.dart';

/// 一条指向同类别词组的条件分支：[owner] 的第 [branchIndex] 个分支
@immutable
class BranchReference {
  const BranchReference({required this.owner, required this.branchIndex});

  final RandomTagGroup owner;
  final int branchIndex;

  @override
  bool operator ==(Object other) =>
      other is BranchReference &&
      other.owner.id == owner.id &&
      other.branchIndex == branchIndex;

  @override
  int get hashCode => Object.hash(owner.id, branchIndex);
}

/// 条件分支对同类别其他词组的引用关系；只从分支配置推导，不单独存储
extension ConditionalBranchTargets on RandomCategory {
  /// 按被引用的词组 ID 汇总引用它的分支
  ///
  /// [activeOnly] 为 true 时只统计启用词组里启用配置的启用分支，
  /// 这些分支引用的词组只经由分支输出，不参与类别的常规抽取
  Map<String, List<BranchReference>> branchReferences({
    bool activeOnly = false,
  }) {
    final groupIds = {for (final group in groups) group.id};
    final references = <String, List<BranchReference>>{};
    for (final owner in groups) {
      final config = owner.conditionalBranchConfig;
      if (config == null) continue;
      if (activeOnly && (!owner.enabled || !config.enabled)) continue;
      for (final (index, branch) in config.branches.indexed) {
        if (activeOnly && !branch.enabled) continue;
        for (final targetId in branch.tagGroupIds.toSet()) {
          if (targetId == owner.id || !groupIds.contains(targetId)) continue;
          references
              .putIfAbsent(targetId, () => [])
              .add(BranchReference(owner: owner, branchIndex: index));
        }
      }
    }
    return references;
  }

  /// 只经由启用分支输出、不参与常规抽取的词组 ID
  Set<String> get branchOwnedGroupIds =>
      branchReferences(activeOnly: true).keys.toSet();

  /// 让 [ownerId] 的分支输出 [targetId] 是否会形成循环
  ///
  /// 目标经由各词组分支（含停用的分支，启用后同样会循环）能回到 [ownerId] 即为循环
  bool branchTargetCreatesCycle(String ownerId, String targetId) {
    if (ownerId == targetId) return true;
    final byId = {for (final group in groups) group.id: group};
    final visited = <String>{};
    final pending = [targetId];
    while (pending.isNotEmpty) {
      final current = byId[pending.removeLast()];
      if (current == null || !visited.add(current.id)) continue;
      final branches =
          current.conditionalBranchConfig?.branches ??
          const <ConditionalBranch>[];
      for (final branch in branches) {
        for (final next in branch.tagGroupIds) {
          if (next == ownerId) return true;
          pending.add(next);
        }
      }
    }
    return false;
  }
}
