import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';

import '../../../../../data/models/prompt/conditional_branch.dart';
import '../diy_category_field.dart';
import '../diy_panel_header.dart';

/// 分支条件可引用的变量种类，决定条件值的输入提示
enum BranchConditionSourceKind {
  category,
  characterGender,
  characterCount,
  branch,
}

/// 分支条件可引用的变量：条件里保存 [id]，界面显示 [label]
@immutable
class BranchConditionSource {
  const BranchConditionSource({
    required this.id,
    required this.label,
    required this.kind,
  });

  final String id;
  final String label;
  final BranchConditionSourceKind kind;

  @override
  bool operator ==(Object other) =>
      other is BranchConditionSource &&
      other.id == id &&
      other.label == label &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(id, label, kind);
}

/// 编辑分支的触发条件：每行一个变量与期望值，多条时选择全部满足或任一满足
class BranchConditionsEditor extends StatelessWidget {
  const BranchConditionsEditor({
    super.key,
    required this.conditions,
    required this.logicType,
    required this.sources,
    required this.onChanged,
    this.readOnly = false,
  });

  final Map<String, String> conditions;
  final LogicType logicType;
  final List<BranchConditionSource> sources;
  final void Function(Map<String, String> conditions, LogicType logicType)
  onChanged;
  final bool readOnly;

  // 变量与期望值并排所需的最小宽度，放大文字或窄屏时改为上下排列
  static const double _sideBySideMinWidth = 520;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final unusedSources = sources
        .where((source) => !conditions.containsKey(source.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DiySectionTitle(
          icon: Icons.rule_rounded,
          accent: colorScheme.tertiary,
          container: colorScheme.tertiaryContainer,
          title: l10n.diy_branchConditions,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.diy_branchConditionsHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (conditions.length > 1) ...[
          const SizedBox(height: 12),
          _buildLogicSelector(context),
        ],
        for (final entry in conditions.entries) ...[
          const SizedBox(height: 12),
          KeyedSubtree(
            // 输入框只在创建时读取初始值，按变量区分行，删除前一行不会串值
            key: ValueKey('branch-condition-${entry.key}'),
            child: _buildConditionRow(context, entry),
          ),
        ],
        if (!readOnly) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: unusedSources.isEmpty
                  ? null
                  : () => _emit({...conditions, unusedSources.first.id: ''}),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.diy_addCondition),
            ),
          ),
        ],
      ],
    );
  }

  // 两个选项用可换行的选择标签，放大文字的窄屏下不需要横向滚动
  Widget _buildLogicSelector(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (type, label) in [
          (LogicType.and, l10n.diy_conditionLogicAll),
          (LogicType.or, l10n.diy_conditionLogicAny),
        ])
          ChoiceChip(
            label: Text(label, softWrap: true),
            selected: logicType == type,
            onSelected: readOnly ? null : (_) => onChanged(conditions, type),
          ),
      ],
    );
  }

  Widget _buildConditionRow(
    BuildContext context,
    MapEntry<String, String> condition,
  ) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final source = sources.where((s) => s.id == condition.key).firstOrNull;
    final sourceField = DiyCategoryDropdown(
      value: condition.key,
      options: [
        for (final option in sources)
          if (option.id == condition.key || !conditions.containsKey(option.id))
            DiyCategoryOption(id: option.id, label: option.label),
      ],
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: l10n.diy_conditionSource,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onChanged: (id) => _emit({
        for (final entry in conditions.entries)
          if (entry.key == condition.key)
            id: entry.value
          else
            entry.key: entry.value,
      }),
    );
    final valueField = ThemedFormInput(
      initialValue: condition.value,
      readOnly: readOnly,
      labelText: l10n.diy_conditionValue,
      hintText: _valueHint(context, source?.kind),
      // 空值永远匹配不上，随输入即时提示
      autovalidateMode: AutovalidateMode.always,
      validator: (value) =>
          (value ?? '').trim().isEmpty ? l10n.diy_conditionValueRequired : null,
      onChanged: (value) => _emit({...conditions, condition.key: value}),
    );
    final deleteButton = readOnly
        ? null
        : IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: colorScheme.error.withValues(alpha: 0.7),
            ),
            tooltip: l10n.diy_deleteCondition,
            onPressed: () => _emit({
              for (final entry in conditions.entries)
                if (entry.key != condition.key) entry.key: entry.value,
            }),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _sideBySideMinWidth &&
            MediaQuery.textScalerOf(context).scale(1) < 2) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: sourceField),
              const SizedBox(width: 8),
              Expanded(flex: 6, child: valueField),
              if (deleteButton != null) deleteButton,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            sourceField,
            const SizedBox(height: 8),
            valueField,
            if (deleteButton != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: deleteButton,
              ),
          ],
        );
      },
    );
  }

  String? _valueHint(BuildContext context, BranchConditionSourceKind? kind) {
    final l10n = context.l10n;
    return switch (kind) {
      BranchConditionSourceKind.category => l10n.diy_conditionValueHintCategory,
      BranchConditionSourceKind.characterGender =>
        l10n.diy_conditionValueHintGender,
      BranchConditionSourceKind.characterCount =>
        l10n.diy_conditionValueHintCount,
      BranchConditionSourceKind.branch => l10n.diy_conditionValueHintBranch,
      null => null,
    };
  }

  void _emit(Map<String, String> next) => onChanged(next, logicType);
}
