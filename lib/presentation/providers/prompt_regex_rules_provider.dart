import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/prompt/prompt_regex_rule.dart';

part 'prompt_regex_rules_provider.g.dart';

/// 提示词正则替换规则 Provider
///
/// 规则列表全局共享，始终按 [PromptRegexRule.sortOrder] 排序，
/// 每次变更立即持久化为 JSON 字符串列表。
@Riverpod(keepAlive: true)
class PromptRegexRules extends _$PromptRegexRules {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  List<PromptRegexRule> build() => _load();

  List<PromptRegexRule> _load() {
    final encoded = _storage.getPromptRegexRules();
    if (encoded.isEmpty) return const [];

    final rules = <PromptRegexRule>[];
    for (final raw in encoded) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) continue;
        rules.add(PromptRegexRule.fromJson(decoded));
      } catch (error, stackTrace) {
        // 单条损坏不应连累整个列表，跳过并继续
        AppLogger.e(
          'Failed to decode prompt regex rule',
          error,
          stackTrace,
          'PromptRegexRules',
        );
      }
    }
    return rules.sortedByOrder();
  }

  void _commit(List<PromptRegexRule> rules) {
    final reindexed = rules.reindex();
    state = reindexed;
    _storage.setPromptRegexRules(
      reindexed.map((rule) => jsonEncode(rule.toJson())).toList(),
    );
  }

  /// 追加一条规则到末尾
  void add(PromptRegexRule rule) => _commit([...state, rule]);

  /// 按 id 覆盖一条规则
  void update(PromptRegexRule rule) {
    _commit([
      for (final item in state)
        if (item.id == rule.id) rule else item,
    ]);
  }

  /// 删除一条规则
  void remove(String id) {
    _commit(state.where((rule) => rule.id != id).toList());
  }

  /// 切换启用状态
  void toggleEnabled(String id) {
    _commit([
      for (final rule in state)
        if (rule.id == id) rule.copyWith(enabled: !rule.enabled) else rule,
    ]);
  }

  /// 拖拽重排
  ///
  /// [newIndex] 是移除 [oldIndex] 之后的目标下标，与
  /// `ReorderableListView.onReorderItem` 的语义一致（框架已做过 -1 修正）。
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.length) return;
    final reordered = [...state];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex.clamp(0, reordered.length), moved);
    _commit(reordered);
  }

  /// 整体替换（导入等场景）
  void replaceAll(List<PromptRegexRule> rules) => _commit(rules);
}
