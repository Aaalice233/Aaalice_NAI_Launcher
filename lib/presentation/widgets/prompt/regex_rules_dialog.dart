import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../core/utils/prompt_regex_replacer.dart';
import '../../../data/models/prompt/prompt_regex_rule.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../providers/prompt_regex_rules_provider.dart';

/// 正则替换规则管理对话框
///
/// 规则列表可拖拽排序（顺序即应用先后），底部提供实时试算区，
/// 用户可以在保存前直接看到整套规则作用在示例提示词上的结果。
class RegexRulesDialog extends ConsumerStatefulWidget {
  const RegexRulesDialog({super.key, this.scrollController});

  final ScrollController? scrollController;

  /// 显示对话框
  static Future<void> show(BuildContext context) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      titleBuilder: (context) => Text(
        context.l10n.regexRules_title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      dialogWidth: 600,
      builder: (context, scrollController) =>
          RegexRulesDialog(scrollController: scrollController),
    );
  }

  @override
  ConsumerState<RegexRulesDialog> createState() => _RegexRulesDialogState();
}

class _RegexRulesDialogState extends ConsumerState<RegexRulesDialog> {
  final _testController = TextEditingController();

  @override
  void dispose() {
    _testController.dispose();
    super.dispose();
  }

  Future<void> _createRule() async {
    final created = await _RuleEditDialog.show(context);
    if (created == null) return;
    ref.read(promptRegexRulesProvider.notifier).add(created);
  }

  Future<void> _editRule(PromptRegexRule rule) async {
    final edited = await _RuleEditDialog.show(context, rule: rule);
    if (edited == null) return;
    ref.read(promptRegexRulesProvider.notifier).update(edited);
  }

  Future<void> _deleteRule(PromptRegexRule rule) async {
    final l10n = context.l10n;
    final label = rule.displayLabel.isEmpty
        ? l10n.regexRules_unnamed
        : rule.displayLabel;

    final confirmed = await AdaptivePresenter.showPanel<bool>(
      context: context,
      title: l10n.regexRules_deleteConfirmTitle,
      initialChildSize: 0.46,
      minChildSize: 0.36,
      dialogWidth: 440,
      builder: (dialogContext, scrollController) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: ListView(
              controller: scrollController,
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [Text(l10n.regexRules_deleteConfirmMessage(label))],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.common_cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.common_delete),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    ref.read(promptRegexRulesProvider.notifier).remove(rule.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final rules = ref.watch(promptRegexRulesProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: ListView(
            controller: widget.scrollController,
            shrinkWrap: true,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            children: [
              Text(
                l10n.regexRules_hint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (rules.isEmpty)
                _buildEmptyState(theme, colorScheme, l10n.regexRules_empty)
              else
                _buildRuleList(rules),
              const SizedBox(height: 16),
              _buildTestSection(theme, colorScheme, rules),
              const SizedBox(height: 12),
              _buildFooter(theme, colorScheme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    ColorScheme colorScheme,
    String message,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildRuleList(List<PromptRegexRule> rules) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      buildDefaultDragHandles: false,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rules.length,
      onReorderItem: (oldIndex, newIndex) => ref
          .read(promptRegexRulesProvider.notifier)
          .reorder(oldIndex, newIndex),
      itemBuilder: (context, index) {
        final rule = rules[index];
        return _RuleTile(
          key: ValueKey(rule.id),
          rule: rule,
          index: index,
          onToggle: () => ref
              .read(promptRegexRulesProvider.notifier)
              .toggleEnabled(rule.id),
          onEdit: () => _editRule(rule),
          onDelete: () => _deleteRule(rule),
        );
      },
    );
  }

  Widget _buildTestSection(
    ThemeData theme,
    ColorScheme colorScheme,
    List<PromptRegexRule> rules,
  ) {
    final l10n = context.l10n;
    final source = _testController.text;
    final hasActiveRule = rules.any((rule) => rule.enabled);

    final String preview;
    Color? previewColor;
    if (source.isEmpty) {
      preview = '';
    } else if (!hasActiveRule) {
      preview = l10n.regexRules_testNoRules;
      previewColor = colorScheme.onSurfaceVariant;
    } else {
      final result = PromptRegexReplacer.apply(source, rules);
      if (result.changed) {
        preview = result.text;
      } else {
        preview = l10n.regexRules_testNoChange;
        previewColor = colorScheme.onSurfaceVariant;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.regexRules_testTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _testController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: l10n.regexRules_testInputHint,
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              preview,
              style: theme.textTheme.bodySmall?.copyWith(color: previewColor),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(1) >= 2;
          final add = FilledButton.icon(
            onPressed: _createRule,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.regexRules_add),
          );
          final close = TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.common_close),
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [add, close],
            );
          }
          return Row(children: [add, const Spacer(), close]);
        },
      ),
    );
  }
}

/// 规则列表项
class _RuleTile extends StatelessWidget {
  const _RuleTile({
    super.key,
    required this.rule,
    required this.index,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final PromptRegexRule rule;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final isValid = rule.isValid;
    final title = rule.displayLabel.isEmpty
        ? l10n.regexRules_unnamed
        : rule.displayLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 18,
                      color: colorScheme.outline,
                    ),
                  ),
                ),
                Checkbox(
                  value: rule.enabled,
                  onChanged: (_) => onToggle(),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: rule.enabled
                                    ? null
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (!isValid) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.regexRules_invalidBadge,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${rule.pattern}  →  ${rule.replacement}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: l10n.common_edit,
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: l10n.common_delete,
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 单条规则编辑对话框
class _RuleEditDialog extends StatefulWidget {
  const _RuleEditDialog({this.rule, this.scrollController});

  final PromptRegexRule? rule;
  final ScrollController? scrollController;

  static Future<PromptRegexRule?> show(
    BuildContext context, {
    PromptRegexRule? rule,
  }) {
    return AdaptivePresenter.showForm<PromptRegexRule>(
      context: context,
      titleBuilder: (context) => Text(
        rule == null
            ? context.l10n.regexRules_newTitle
            : context.l10n.regexRules_editTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      dialogWidth: 480,
      builder: (context, scrollController) =>
          _RuleEditDialog(rule: rule, scrollController: scrollController),
    );
  }

  @override
  State<_RuleEditDialog> createState() => _RuleEditDialogState();
}

class _RuleEditDialogState extends State<_RuleEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _patternController;
  late final TextEditingController _replacementController;
  late bool _caseSensitive;

  /// 正则语法错误信息，null 表示当前匹配式可用
  String? _patternError;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _nameController = TextEditingController(text: rule?.name ?? '');
    _patternController = TextEditingController(text: rule?.pattern ?? '');
    _replacementController = TextEditingController(
      text: rule?.replacement ?? '',
    );
    _caseSensitive = rule?.caseSensitive ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _patternController.dispose();
    _replacementController.dispose();
    super.dispose();
  }

  /// 校验当前匹配式，返回是否可用
  ///
  /// 空匹配式会命中所有位置，等于把替换内容插满全文，因此直接判为非法。
  bool _validatePattern({required bool showEmptyError}) {
    final pattern = _patternController.text;
    if (pattern.isEmpty) {
      setState(() {
        _patternError = showEmptyError
            ? context.l10n.regexRules_patternRequired
            : null;
      });
      return false;
    }

    try {
      RegExp(pattern, caseSensitive: _caseSensitive);
      setState(() => _patternError = null);
      return true;
    } on FormatException catch (error) {
      setState(() {
        _patternError = context.l10n.regexRules_patternInvalid(error.message);
      });
      return false;
    }
  }

  void _submit() {
    if (!_validatePattern(showEmptyError: true)) return;

    final existing = widget.rule;
    final result = existing == null
        ? PromptRegexRule.create(
            name: _nameController.text,
            pattern: _patternController.text,
            replacement: _replacementController.text,
            caseSensitive: _caseSensitive,
          )
        : existing.copyWith(
            name: _nameController.text.trim(),
            pattern: _patternController.text,
            replacement: _replacementController.text,
            caseSensitive: _caseSensitive,
          );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEditing = widget.rule != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: ListView(
            controller: widget.scrollController,
            shrinkWrap: true,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.regexRules_nameLabel,
                  hintText: l10n.regexRules_nameHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _patternController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.regexRules_patternLabel,
                  hintText: l10n.regexRules_patternHint,
                  errorText: _patternError,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => _validatePattern(showEmptyError: false),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _replacementController,
                decoration: InputDecoration(
                  labelText: l10n.regexRules_replacementLabel,
                  hintText: l10n.regexRules_replacementHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 4),
              CheckboxListTile(
                value: _caseSensitive,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text(l10n.regexRules_caseSensitive),
                onChanged: (value) {
                  setState(() => _caseSensitive = value ?? false);
                  _validatePattern(showEmptyError: false);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.common_cancel),
              ),
              FilledButton(
                onPressed: _submit,
                child: Text(isEditing ? l10n.common_save : l10n.common_create),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
