import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:flutter/material.dart';

import '../../../data/models/prompt/random_category.dart';
import '../../../data/models/prompt/random_tag_group.dart';
import '../../../data/models/prompt/tag_scope.dart';
import '../settings/setting_tiles.dart';
import '../../widgets/common/themed_divider.dart';

/// 词组设置对话框
///
/// 用于编辑词组级别的设置：
/// - 选取概率
/// - 选取模式
/// - 选取数量（多选模式）
/// - 权重括号范围
/// - 打乱顺序
/// - 性别限定
/// - 作用域控制
class TagGroupSettingsDialog extends StatefulWidget {
  final RandomTagGroup tagGroup;
  final ValueChanged<RandomTagGroup> onSave;

  /// 父类别（用于"重置为类别设置"功能）
  final RandomCategory? parentCategory;

  /// 自定义槽位选项（用于性别限定）
  final List<String> customSlotOptions;

  const TagGroupSettingsDialog({
    super.key,
    required this.tagGroup,
    required this.onSave,
    required this.customSlotOptions,
    this.parentCategory,
  });

  /// 显示对话框
  static Future<void> show({
    required BuildContext context,
    required RandomTagGroup tagGroup,
    required ValueChanged<RandomTagGroup> onSave,
    required List<String> customSlotOptions,
    RandomCategory? parentCategory,
  }) {
    return showDialog(
      context: context,
      builder: (context) => TagGroupSettingsDialog(
        tagGroup: tagGroup,
        onSave: onSave,
        customSlotOptions: customSlotOptions,
        parentCategory: parentCategory,
      ),
    );
  }

  @override
  State<TagGroupSettingsDialog> createState() => _TagGroupSettingsDialogState();
}

class _TagGroupSettingsDialogState extends State<TagGroupSettingsDialog> {
  late double _probability;
  late SelectionMode _selectionMode;
  late int _multipleNum;
  late int _bracketMin;
  late int _bracketMax;
  late bool _shuffle;
  late bool _genderRestrictionEnabled;
  late List<String> _applicableGenders;
  late TagScope _scope;

  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _probability = widget.tagGroup.probability;
    _selectionMode = widget.tagGroup.selectionMode;
    _multipleNum = widget.tagGroup.multipleNum;
    _bracketMin = widget.tagGroup.bracketMin;
    _bracketMax = widget.tagGroup.bracketMax;
    _shuffle = widget.tagGroup.shuffle;
    _genderRestrictionEnabled = widget.tagGroup.genderRestrictionEnabled;
    _applicableGenders = List.from(widget.tagGroup.applicableGenders);
    _scope = widget.tagGroup.scope;
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  String _getSelectionModeLabel(SelectionMode mode) {
    final l10n = context.l10n;
    return switch (mode) {
      SelectionMode.single => l10n.selectionMode_single,
      SelectionMode.multipleNum => l10n.selectionMode_multipleNum,
      SelectionMode.multipleProb => l10n.selectionMode_multipleProb,
      SelectionMode.all => l10n.selectionMode_all,
      SelectionMode.sequential => l10n.selectionMode_sequential,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(theme, l10n),

            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // 选取概率
                    SliderSettingTile(
                      title: l10n.tagGroupSettings_probability,
                      subtitle: l10n.tagGroupSettings_probabilityDesc,
                      value: _probability,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      valueFormatter: (v) => '${(v * 100).round()}%',
                      onChanged: (value) {
                        setState(() {
                          _probability = value;
                          _markChanged();
                        });
                      },
                    ),

                    const ThemedDivider(height: 1),

                    // 选取模式
                    ChipSelectTile<SelectionMode>(
                      title: l10n.tagGroupSettings_selectionMode,
                      subtitle: l10n.tagGroupSettings_selectionModeDesc,
                      value: _selectionMode,
                      options: SelectionMode.values,
                      labelBuilder: _getSelectionModeLabel,
                      onChanged: (value) {
                        setState(() {
                          _selectionMode = value;
                          _markChanged();
                        });
                      },
                    ),

                    // 选取数量（仅多选模式）
                    if (_selectionMode == SelectionMode.multipleNum) ...[
                      IntSliderSettingTile(
                        title: l10n.tagGroupSettings_selectCount,
                        value: _multipleNum,
                        min: 1,
                        max: 10,
                        onChanged: (value) {
                          setState(() {
                            _multipleNum = value;
                            _markChanged();
                          });
                        },
                      ),
                    ],

                    const ThemedDivider(height: 1),

                    // 打乱顺序
                    SwitchListTile(
                      title: Text(l10n.tagGroupSettings_shuffle),
                      subtitle: Text(l10n.tagGroupSettings_shuffleDesc),
                      value: _shuffle,
                      onChanged: (value) {
                        setState(() {
                          _shuffle = value;
                          _markChanged();
                        });
                      },
                    ),

                    const ThemedDivider(height: 1),

                    // 权重括号
                    RangeSliderSettingTile(
                      title: l10n.tagGroupSettings_bracket,
                      subtitle: l10n.tagGroupSettings_bracketDesc,
                      start: _bracketMin,
                      end: _bracketMax,
                      min: -10,
                      max: 10,
                      valueFormatter: (start, end) =>
                          _formatBracketRange(start, end, l10n),
                      onChanged: (start, end) {
                        setState(() {
                          _bracketMin = start;
                          _bracketMax = end;
                          _markChanged();
                        });
                      },
                    ),

                    // 括号预览
                    if (_bracketMin != 0 || _bracketMax != 0)
                      _buildBracketPreview(theme, l10n),

                    const ThemedDivider(height: 1),

                    // 作用域设置
                    _buildScopeSection(theme, l10n),

                    const ThemedDivider(height: 1),

                    // 性别限定设置
                    _buildGenderRestrictionSection(theme, l10n),

                    // 重置为类别设置按钮
                    if (widget.parentCategory != null)
                      _buildResetToCategoryButton(theme, l10n),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // 底部按钮
            _buildFooter(theme, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, dynamic l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(Icons.label, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.tagGroupSettings_title(widget.tagGroup.name),
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, dynamic l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border:
            Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.common_cancel),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _hasChanges ? _saveSettings : null,
            icon: const Icon(Icons.check, size: 18),
            label: Text(l10n.common_save),
          ),
        ],
      ),
    );
  }

  String _formatBracketRange(int start, int end, dynamic l10n) {
    String formatValue(int v) {
      if (v < 0) return '$v (${l10n.bracket_weaken})';
      if (v > 0) return '+$v (${l10n.bracket_enhance})';
      return '0';
    }

    if (start == end) return formatValue(start);
    return '${formatValue(start)} ~ ${formatValue(end)}';
  }

  Widget _buildBracketPreview(ThemeData theme, dynamic l10n) {
    final examples = <String>[];
    for (int i = _bracketMin; i <= _bracketMax; i++) {
      if (i < 0) {
        final count = -i;
        examples.add('${'[' * count}tag${']' * count}');
      } else if (i > 0) {
        examples.add('${'{' * i}tag${'}' * i}');
      } else {
        examples.add('tag');
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tagGroupSettings_bracketPreview,
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            Text(
              examples.join(' / '),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeSection(ThemeData theme, dynamic l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.scope_title,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.scope_titleDesc,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: TagScope.values.map((scope) {
              final isSelected = _scope == scope;
              final label = _getScopeLabel(scope, l10n);
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _scope = scope;
                      _markChanged();
                    });
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getScopeLabel(TagScope scope, dynamic l10n) {
    return switch (scope) {
      TagScope.global => l10n.scope_global,
      TagScope.character => l10n.scope_character,
      TagScope.all => l10n.scope_all,
    };
  }

  Widget _buildGenderRestrictionSection(ThemeData theme, dynamic l10n) {
    return ExpansionTile(
      title: Text(l10n.genderRestriction_enabled),
      subtitle: Text(
        _genderRestrictionEnabled
            ? l10n.genderRestriction_enabledActive(_applicableGenders.length)
            : l10n.genderRestriction_enabledDesc,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      initiallyExpanded: _genderRestrictionEnabled,
      children: [
        SwitchListTile(
          title: Text(l10n.genderRestriction_enable),
          subtitle: Text(l10n.genderRestriction_enableDesc),
          value: _genderRestrictionEnabled,
          onChanged: (value) {
            setState(() {
              _genderRestrictionEnabled = value;
              _markChanged();
            });
          },
        ),
        if (_genderRestrictionEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.genderRestriction_applicableGenders,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.customSlotOptions.map((slotOption) {
                    final isSelected = _applicableGenders.contains(slotOption);
                    return FilterChip(
                      label: Text(slotOption),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _applicableGenders.add(slotOption);
                          } else {
                            _applicableGenders.remove(slotOption);
                          }
                          _markChanged();
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildResetToCategoryButton(ThemeData theme, dynamic l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: OutlinedButton.icon(
        onPressed: _resetToCategorySettings,
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(l10n.tagGroupSettings_resetToCategory),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
        ),
      ),
    );
  }

  void _resetToCategorySettings() {
    final category = widget.parentCategory;
    if (category == null) return;

    setState(() {
      _genderRestrictionEnabled = category.genderRestrictionEnabled;
      _applicableGenders = List.from(category.applicableGenders);
      _scope = category.scope;
      _markChanged();
    });
  }

  void _saveSettings() {
    final updatedTagGroup = widget.tagGroup.copyWith(
      probability: _probability,
      selectionMode: _selectionMode,
      multipleNum: _multipleNum,
      bracketMin: _bracketMin,
      bracketMax: _bracketMax,
      shuffle: _shuffle,
      genderRestrictionEnabled: _genderRestrictionEnabled,
      applicableGenders: _applicableGenders,
      scope: _scope,
    );
    widget.onSave(updatedTagGroup);
    Navigator.of(context).pop();
  }
}
