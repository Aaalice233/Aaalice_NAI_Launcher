import 'dart:math';

import '../../models/prompt/weighted_tag.dart';
import '../../models/prompt/wordlist_entry.dart';
import '../weighted_selector.dart';

/// 词库生成策略
///
/// 负责从 CSV 词库生成标签。
/// 支持按变量名和分类选择标签，应用 exclude/require 规则，
/// 并进行加权随机选择。
/// 从 RandomPromptGenerator._selectFromWordlist 提取。
class WordlistGeneratorStrategy {
  /// 加权选择器
  final WeightedSelector _weightedSelector;

  /// 创建词库生成策略
  ///
  /// [weightedSelector] 加权选择器（可选，默认创建新实例）
  WordlistGeneratorStrategy({
    WeightedSelector? weightedSelector,
  }) : _weightedSelector = weightedSelector ?? WeightedSelector();

  /// 从词库条目列表中选择标签
  ///
  /// [entries] 词库条目列表
  /// [random] 随机数生成器
  /// [context] 已选择的标签上下文（用于应用 exclude/require 规则）
  ///
  /// 返回选中的标签文本，如果列表为空或规则过滤后无可用标签则返回 null
  ///
  /// 示例：
  /// ```dart
  /// final strategy = WordlistGeneratorStrategy();
  /// final entries = [
  ///   WordlistEntry(
  ///     variable: 'char',
  ///     category: 'hair_color',
  ///     tag: 'blonde hair',
  ///     weight: 10,
  ///   ),
  /// ];
  /// final tag = strategy.select(
  ///   entries: entries,
  ///   random: Random(42),
  /// );
  /// // 'blonde hair'
  /// ```
  String? select({
    required List<WordlistEntry> entries,
    required Random random,
    Map<String, List<String>>? context,
  }) {
    if (entries.isEmpty) return null;

    // 应用 exclude/require 规则
    final filtered = _applyWordlistRules(entries, context);
    if (filtered.isEmpty) return null;

    // 转换为 WeightedTag 进行加权随机选择
    final weightedTags = filtered.map((e) => WeightedTag(
      tag: e.tag,
      weight: e.weight,
    ),).toList();

    return _weightedSelector.select(weightedTags, random: random);
  }

  /// 从词库条目列表中选择多个标签（不重复）
  ///
  /// [entries] 词库条目列表
  /// [count] 选择数量
  /// [random] 随机数生成器
  /// [context] 已选择的标签上下文
  ///
  /// 返回选中的标签文本列表
  ///
  /// 示例：
  /// ```dart
  /// final strategy = WordlistGeneratorStrategy();
  /// final entries = [/* ... */];
  /// final tags = strategy.selectMultiple(
  ///   entries: entries,
  ///   count: 3,
  ///   random: Random(42),
  /// );
  /// ```
  List<String> selectMultiple({
    required List<WordlistEntry> entries,
    required int count,
    required Random random,
    Map<String, List<String>>? context,
  }) {
    if (entries.isEmpty) return [];

    // 应用 exclude/require 规则
    var filtered = _applyWordlistRules(entries, context);
    if (filtered.isEmpty) return [];

    final selected = <String>[];
    final actualCount = count.clamp(1, filtered.length);

    for (int i = 0; i < actualCount && filtered.isNotEmpty; i++) {
      // 转换为 WeightedTag 进行加权随机选择
      final weightedTags = filtered.map((e) => WeightedTag(
        tag: e.tag,
        weight: e.weight,
      ),).toList();

      final tag = _weightedSelector.select(weightedTags, random: random);
      selected.add(tag);

      // 移除已选标签（避免重复）
      filtered = filtered.where((e) => e.tag != tag).toList();
    }

    return selected;
  }

  /// 应用词库条目的 exclude/require 规则
  ///
  /// [entries] 词库条目列表
  /// [context] 已选择的标签上下文（类别 -> 标签列表）
  ///
  /// 返回符合规则的条目列表
  ///
  /// 规则说明：
  /// - require: 只有当上下文中包含 require 列表中的任一标签时，此条目才会被选中
  /// - exclude: 如果上下文中包含 exclude 列表中的任一标签，此条目不会被选中
  List<WordlistEntry> _applyWordlistRules(
    List<WordlistEntry> entries,
    Map<String, List<String>>? context,
  ) {
    if (context == null || context.isEmpty) return entries;

    // 收集所有已选择的标签
    final selectedTags = context.values.expand((v) => v).toSet();

    return entries.where((entry) {
      // 检查 require 规则
      if (entry.hasRequireRules) {
        final hasRequired = entry.require.any(
          (req) => selectedTags.contains(req),
        );
        if (!hasRequired) return false;
      }

      // 检查 exclude 规则
      if (entry.hasExcludeRules) {
        final hasExcluded = entry.exclude.any(
          (exc) => selectedTags.contains(exc),
        );
        if (hasExcluded) return false;
      }

      return true;
    }).toList();
  }

  /// 检查指定条目在给定上下文中是否可用
  ///
  /// [entry] 词库条目
  /// [context] 已选择的标签上下文
  ///
  /// 返回是否可用
  bool isEntryAvailable(
    WordlistEntry entry,
    Map<String, List<String>>? context,
  ) {
    if (context == null || context.isEmpty) return true;

    final filtered = _applyWordlistRules([entry], context);
    return filtered.isNotEmpty;
  }

  /// 获取指定上下文中可用的条目数量
  ///
  /// [entries] 词库条目列表
  /// [context] 已选择的标签上下文
  ///
  /// 返回可用条目数量
  int getAvailableEntryCount(
    List<WordlistEntry> entries,
    Map<String, List<String>>? context,
  ) {
    return _applyWordlistRules(entries, context).length;
  }
}
