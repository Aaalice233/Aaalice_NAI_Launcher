import 'dart:math';

import '../models/prompt/weighted_tag.dart';

/// 加权随机选择器
///
/// 提供可复现、无偏且能安全处理重复项和无效权重的随机选择算法。
///
/// 主要功能：
/// - 从标签列表中进行加权随机选择（支持条件过滤）
/// - 从整数权重列表中选择（用于角色数量等场景）
/// - 支持动态类型权重选择
///
/// ## 算法原理
///
/// 使用累积权重分布算法（Cumulative Distribution Function）：
/// 1. 计算所有选项的总权重
/// 2. 生成 [1, totalWeight] 范围内的随机数
/// 3. 累加权重直到超过随机数，返回对应选项
///
/// ## 性能特性
///
/// - 时间复杂度: O(n)，其中 n 为选项数量
/// - 空间复杂度: O(1)
/// - 适合中小规模数据集（< 1000 项）
/// - 对于大规模数据，建议使用预构建的索引结构
///
/// ## 使用示例
///
/// ```dart
/// final selector = WeightedSelector();
///
/// // 从标签列表选择
/// final tags = [
///   WeightedTag(tag: 'blonde', weight: 100),
///   WeightedTag(tag: 'brunette', weight: 80),
/// ];
/// final selected = selector.select(tags);
///
/// // 从整数权重列表选择（角色数量）
/// final weights = [[1, 70], [2, 20], [3, 7], [0, 5]];
/// final count = selector.selectInt(weights);
/// ```
class WeightedSelector {
  /// 基于整数累积权重的无偏随机选择算法
  ///
  /// 从标签列表中基于权重随机选择一个标签，支持条件过滤。
  /// 权重越高，被选中的概率越大。
  ///
  /// [tags] 标签列表，不能为空
  /// [context] 当前上下文标签列表（用于条件过滤），可选
  /// [random] 随机数生成器，可选（默认创建新实例）
  ///
  /// 返回选中的标签名称
  ///
  /// 抛出 [ArgumentError] 当标签列表为空时
  ///
  /// 示例：
  /// ```dart
  /// final tags = [
  ///   WeightedTag(tag: 'blonde', weight: 100),
  ///   WeightedTag(tag: 'brunette', weight: 80),
  ///   WeightedTag(tag: 'red hair', weight: 30),
  /// ];
  /// final selector = WeightedSelector();
  /// final selected = selector.select(tags);
  /// ```
  String select(
    List<WeightedTag> tags, {
    List<String>? context,
    Random? random,
  }) {
    if (tags.isEmpty) {
      throw ArgumentError('Tags list cannot be empty');
    }

    random ??= Random();

    final mergedWeights = <String, ({String tag, int weight})>{};
    for (final candidate in tags) {
      final conditions = candidate.conditions;
      final isEligible =
          conditions == null ||
          conditions.isEmpty ||
          conditions.any((condition) => context?.contains(condition) ?? false);
      if (!isEligible || candidate.weight <= 0) continue;

      final key = candidate.tag.trim().toLowerCase();
      if (key.isEmpty) continue;
      final existing = mergedWeights[key];
      mergedWeights[key] = (
        tag: existing?.tag ?? candidate.tag,
        weight: (existing?.weight ?? 0) + candidate.weight,
      );
    }
    if (mergedWeights.isEmpty) {
      throw StateError('No eligible tags with a positive weight');
    }

    final candidates = mergedWeights.values.toList(growable: false);
    final totalWeight = candidates.fold<int>(0, (sum, tag) => sum + tag.weight);
    var target = random.nextInt(totalWeight);
    for (final candidate in candidates) {
      if (target < candidate.weight) return candidate.tag;
      target -= candidate.weight;
    }
    throw StateError('Weighted selection exhausted unexpectedly');
  }

  /// 从整数权重列表中选择（用于角色数量等）
  ///
  /// 从格式为 [[value, weight], ...] 的列表中基于权重随机选择一个值。
  /// 常用于角色数量选择：[[1, 70], [2, 20], [3, 7], [0, 5]]
  /// 表示：1人70%，2人20%，3人7%，无人5%
  ///
  /// [weights] 权重列表，格式为 [[值, 权重], ...]，不能为空
  /// [random] 随机数生成器，可选（默认创建新实例）
  ///
  /// 返回选中的值
  ///
  /// 抛出 [ArgumentError] 当权重列表为空时
  ///
  /// 示例：
  /// ```dart
  /// final weights = [
  ///   [1, 70],  // 1人 70%
  ///   [2, 20],  // 2人 20%
  ///   [3, 7],   // 3人 7%
  ///   [0, 5],   // 无人 5%
  /// ];
  /// final selector = WeightedSelector();
  /// final characterCount = selector.selectInt(weights);
  /// ```
  int selectInt(List<List<int>> weights, {Random? random}) {
    if (weights.isEmpty) {
      throw ArgumentError('Weights list cannot be empty');
    }

    random ??= Random();

    final eligible = weights
        .where((entry) => entry.length >= 2 && entry[1] > 0)
        .toList(growable: false);
    if (eligible.isEmpty) {
      throw StateError('No integer choices with a positive weight');
    }
    final totalWeight = eligible.fold<int>(0, (sum, entry) => sum + entry[1]);
    var target = random.nextInt(totalWeight);
    for (final entry in eligible) {
      if (target < entry[1]) return entry[0];
      target -= entry[1];
    }
    throw StateError('Integer weighted selection exhausted unexpectedly');
  }

  /// 从整数权重列表中选择动态类型（用于性别等）
  ///
  /// 从格式为 [[value, weight], ...] 的列表中基于权重随机选择一个值。
  /// 支持任意类型的值（如字符串表示性别）。
  ///
  /// [weights] 权重列表，格式为 [[值, 权重], ...]，不能为空
  /// [random] 随机数生成器，可选（默认创建新实例）
  ///
  /// 返回选中的值
  ///
  /// 抛出 [ArgumentError] 当权重列表为空时
  ///
  /// 示例：
  /// ```dart
  /// final weights = [
  ///   ['m', 45],  // 男性 45%
  ///   ['f', 45],  // 女性 45%
  ///   ['o', 10],  // 其他 10%
  /// ];
  /// final selector = WeightedSelector();
  /// final gender = selector.selectDynamic(weights);
  /// ```
  T selectDynamic<T>(List<List<dynamic>> weights, {Random? random}) {
    if (weights.isEmpty) {
      throw ArgumentError('Weights list cannot be empty');
    }

    random ??= Random();

    final eligible = weights
        .where((entry) {
          return entry.length >= 2 && entry[1] is int && (entry[1] as int) > 0;
        })
        .toList(growable: false);
    if (eligible.isEmpty) {
      throw StateError('No dynamic choices with a positive weight');
    }
    final totalWeight = eligible.fold<int>(
      0,
      (sum, entry) => sum + entry[1] as int,
    );
    var target = random.nextInt(totalWeight);
    for (final entry in eligible) {
      final weight = entry[1] as int;
      if (target < weight) return entry[0] as T;
      target -= weight;
    }
    throw StateError('Dynamic weighted selection exhausted unexpectedly');
  }
}
