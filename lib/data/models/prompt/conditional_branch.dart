import 'package:freezed_annotation/freezed_annotation.dart';

part 'conditional_branch.freezed.dart';
part 'conditional_branch.g.dart';

/// 逻辑类型枚举
enum LogicType {
  /// 与逻辑 - 所有条件都必须满足
  and,

  /// 或逻辑 - 任一条件满足即可
  or,
}

/// 条件分支模型
///
/// 实现 switch-case 逻辑，用于服装类型选择等场景
/// 例如: uniform 10%, swimsuit 5%, bodysuit 5%, normal 40%
@freezed
class ConditionalBranch with _$ConditionalBranch {
  const ConditionalBranch._();

  const factory ConditionalBranch({
    /// 分支名称
    required String name,

    /// 分支选择概率 (0-100)
    @Default(10) int probability,

    /// 该分支下的子标签组ID列表
    @Default([]) List<String> tagGroupIds,

    /// 触发条件 - 变量名到期望值的映射
    /// 例如: {"clothing_type": "uniform"}
    @Default({}) Map<String, String> conditions,

    /// 条件逻辑类型
    @Default(LogicType.and) LogicType logicType,

    /// 是否启用
    @Default(true) bool enabled,

    /// 描述
    String? description,
  }) = _ConditionalBranch;

  factory ConditionalBranch.fromJson(Map<String, dynamic> json) =>
      _$ConditionalBranchFromJson(json);

  /// 检查条件是否满足
  ///
  /// [context] 当前上下文变量值映射
  bool checkCondition(Map<String, String> context) {
    if (conditions.isEmpty) return true;

    if (logicType == LogicType.and) {
      // 所有条件都必须满足
      return conditions.entries.every(
        (entry) => context[entry.key] == entry.value,
      );
    } else {
      // 任一条件满足即可
      return conditions.entries.any(
        (entry) => context[entry.key] == entry.value,
      );
    }
  }

  /// 获取显示文本
  String get displayText => '$name ($probability%)';
}

/// 条件分支配置
///
/// 包含多个分支的完整配置
@freezed
class ConditionalBranchConfig with _$ConditionalBranchConfig {
  const ConditionalBranchConfig._();

  const factory ConditionalBranchConfig({
    /// 配置ID
    required String id,

    /// 配置名称
    required String name,

    /// 分支列表
    @Default([]) List<ConditionalBranch> branches,

    /// 默认分支（无条件匹配时使用）
    String? defaultBranchName,

    /// 是否启用
    @Default(true) bool enabled,
  }) = _ConditionalBranchConfig;

  factory ConditionalBranchConfig.fromJson(Map<String, dynamic> json) =>
      _$ConditionalBranchConfigFromJson(json);

  /// 根据上下文选择分支
  ///
  /// [context] 当前上下文变量值映射
  /// [randomInt] 随机数生成函数
  ConditionalBranch? selectBranch(
    Map<String, String> context,
    int Function() randomInt,
  ) {
    // 过滤出满足条件且启用的分支
    final eligibleBranches = branches
        .where((b) => b.enabled && b.checkCondition(context))
        .toList();

    if (eligibleBranches.isEmpty) {
      // 返回默认分支
      if (defaultBranchName != null) {
        return branches.firstWhere(
          (b) => b.name == defaultBranchName,
          orElse: () => branches.first,
        );
      }
      return null;
    }

    // 按概率加权随机选择
    final totalProbability =
        eligibleBranches.fold<int>(0, (sum, b) => sum + b.probability);

    if (totalProbability <= 0) {
      return eligibleBranches[randomInt() % eligibleBranches.length];
    }

    final target = (randomInt() % totalProbability) + 1;
    var cumulative = 0;

    for (final branch in eligibleBranches) {
      cumulative += branch.probability;
      if (target <= cumulative) {
        return branch;
      }
    }

    return eligibleBranches.last;
  }

  /// 获取所有分支的总概率
  int get totalProbability =>
      branches.fold<int>(0, (sum, b) => sum + b.probability);
}
