import 'dart:math';

import '../models/prompt/weighted_tag.dart';

/// 加权随机选择器
///
/// 提供基于权重的随机选择算法，复刻 NovelAI 官网的随机提示词功能
/// 参考: docs/NAI随机提示词功能分析.md
///
/// 主要功能：
/// - 从标签列表中进行加权随机选择（支持条件过滤）
/// - 从整数权重列表中选择（用于角色数量等场景）
///
/// 算法原理：
/// 1. 计算所有选项的总权重
/// 2. 生成 [1, totalWeight] 范围内的随机数
/// 3. 累加权重直到超过随机数，返回对应选项
class WeightedSelector {
  /// 加权随机选择算法（复刻官网 ty 函数）
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

    // 1. 过滤符合条件的标签
    final filtered = tags.where((t) {
      if (t.conditions == null || t.conditions!.isEmpty) return true;
      return t.conditions!.any((c) => context?.contains(c) ?? false);
    }).toList();

    if (filtered.isEmpty) {
      // 如果没有符合条件的标签，返回第一个标签
      return tags.first.tag;
    }

    // 2. 计算总权重
    final totalWeight = filtered.fold<int>(0, (sum, t) => sum + t.weight);

    // 3. 生成 [1, totalWeight] 范围内的随机数
    final target = random.nextInt(totalWeight) + 1;

    // 4. 累加权重直到超过随机数
    var cumulative = 0;
    for (final tag in filtered) {
      cumulative += tag.weight;
      if (target <= cumulative) {
        return tag.tag;
      }
    }

    // 不应该到达这里，但作为防御性编程
    return filtered.last.tag;
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

    final totalWeight = weights.fold<int>(0, (sum, w) => sum + w[1]);
    final target = random.nextInt(totalWeight) + 1;

    var cumulative = 0;
    for (final w in weights) {
      cumulative += w[1];
      if (target <= cumulative) {
        return w[0];
      }
    }

    return weights.last[0];
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

    final totalWeight = weights.fold<int>(0, (sum, w) => sum + w[1] as int);
    final target = random.nextInt(totalWeight) + 1;

    var cumulative = 0;
    for (final w in weights) {
      cumulative += w[1] as int;
      if (target <= cumulative) {
        return w[0] as T;
      }
    }

    return weights.last[0] as T;
  }
}
