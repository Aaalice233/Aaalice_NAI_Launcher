import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../data/models/prompt/random_category.dart';
import '../../../data/models/prompt/tag_scope.dart';
import '../settings/setting_tiles.dart';
import '../../widgets/common/themed_divider.dart';

/// 类别设置对话框
///
/// 用于编辑类别级别的设置：
/// - 类别选取概率
/// - 词组选取模式/数量
/// - 打乱顺序
/// - 统一权重括号设置
class CategorySettingsDialog extends StatefulWidget {
  final RandomCategory category;
  final ValueChanged<RandomCategory> onSave;
  final List<String> customSlotOptions;

  const CategorySettingsDialog({
    super.key,
    required this.category,
    required this.onSave,
    required this.customSlotOptions,
  });

  /// 显示对话框
  static Future<void> show({
    required BuildContext context,
    required RandomCategory category,
    required ValueChanged<RandomCategory> onSave,
    required List<String> customSlotOptions,
  }) {
    return showDialog(
      context: context,
      builder: (context) => CategorySettingsDialog(
        category: category,
        onSave: onSave,
        customSlotOptions: customSlotOptions,
      ),
    );
  }

  @override
  State<CategorySettingsDialog> createState() => _CategorySettingsDialogState();
}

class _CategorySettingsDialogState extends State<CategorySettingsDialog> {
  late double _probability;
  late SelectionMode _groupSelectionMode;
  late int _groupSelectCount;
  late bool _shuffle;
  late bool _useUnifiedBracket;
  late int _unifiedBracketMin;
  late int _unifiedBracketMax;
  late bool _genderRestrictionEnabled;
  late List<String> _applicableGenders;
  late TagScope _scope;

  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _probability = widget.category.probability;
    _groupSelectionMode = widget.category.groupSelectionMode;
    _groupSelectCount = widget.category.groupSelectCount;
    _shuffle = widget.category.shuffle;
    _useUnifiedBracket = widget.category.useUnifiedBracket;
    _unifiedBracketMin = widget.category.unifiedBracketMin;
    _unifiedBracketMax = widget.category.unifiedBracketMax;
    _genderRestrictionEnabled = widget.category.genderRestrictionEnabled;
    _applicableGenders = List.from(widget.category.applicableGenders);
    _scope = widget.category.scope;
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
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
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

                    // 类别选取概率
                    SliderSettingTile(
                      title: l10n.categorySettings_probability,
                      subtitle: l10n.categorySettings_probabilityDesc,
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

                    // 词组选取模式
                    ChipSelectTile<SelectionMode>(
                      title: l10n.categorySettings_groupSelectionMode,
                      subtitle: l10n.categorySettings_groupSelectionModeDesc,
                      value: _groupSelectionMode,
                      options: SelectionMode.values,
                      labelBuilder: _getSelectionModeLabel,
                      onChanged: (value) {
                        setState(() {
                          _groupSelectionMode = value;
                          _markChanged();
                        });
                      },
                    ),

                    // 词组选取数量（仅多选模式）
                    if (_groupSelectionMode == SelectionMode.multipleNum) ...[
                      IntSliderSettingTile(
                        title: l10n.categorySettings_groupSelectCount,
                        value: _groupSelectCount,
                        min: 1,
                        max: 10,
                        onChanged: (value) {
                          setState(() {
                            _groupSelectCount = value;
                            _markChanged();
                          });
                        },
                      ),
                    ],

                    const ThemedDivider(height: 1),

                    // 打乱顺序
                    SwitchListTile(
                      title: Text(l10n.categorySettings_shuffle),
                      subtitle: Text(l10n.categorySettings_shuffleDesc),
                      value: _shuffle,
                      onChanged: (value) {
                        setState(() {
                          _shuffle = value;
                          _markChanged();
                        });
                      },
                    ),

                    const ThemedDivider(height: 1),

                    // 作用域设置
                    _buildScopeSection(theme, l10n),

                    const ThemedDivider(height: 1),

                    // 性别限定设置
                    _buildGenderRestrictionSection(theme, l10n),

                    const ThemedDivider(height: 1),

                    // 统一权重括号设置
                    _buildUnifiedBracketSection(theme, l10n),

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
          Icon(Icons.category, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.categorySettings_title(widget.category.name),
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

  Widget _buildUnifiedBracketSection(ThemeData theme, dynamic l10n) {
    return ExpansionTile(
      title: Text(l10n.categorySettings_unifiedBracket),
      subtitle: Text(
        _useUnifiedBracket
            ? l10n.categorySettings_bracketRange
            : l10n.categorySettings_unifiedBracketDisabled,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      initiallyExpanded: _useUnifiedBracket,
      children: [
        SwitchListTile(
          title: Text(l10n.categorySettings_enableUnifiedBracket),
          subtitle: Text(l10n.categorySettings_enableUnifiedBracketDesc),
          value: _useUnifiedBracket,
          onChanged: (value) {
            setState(() {
              _useUnifiedBracket = value;
              _markChanged();
            });
          },
        ),
        if (_useUnifiedBracket) ...[
          RangeSliderSettingTile(
            title: l10n.categorySettings_bracketRange,
            start: _unifiedBracketMin,
            end: _unifiedBracketMax,
            min: -10,
            max: 10,
            valueFormatter: (start, end) =>
                _formatBracketRange(start, end, l10n),
            onChanged: (start, end) {
              setState(() {
                _unifiedBracketMin = start;
                _unifiedBracketMax = end;
                _markChanged();
              });
            },
          ),
          if (_unifiedBracketMin != 0 || _unifiedBracketMax != 0)
            _buildBracketPreview(theme, l10n),
        ],
      ],
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
    for (int i = _unifiedBracketMin; i <= _unifiedBracketMax; i++) {
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
              l10n.categorySettings_bracketPreview,
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

  void _saveSettings() {
    final updatedCategory = widget.category.copyWith(
      probability: _probability,
      groupSelectionMode: _groupSelectionMode,
      groupSelectCount: _groupSelectCount,
      shuffle: _shuffle,
      useUnifiedBracket: _useUnifiedBracket,
      unifiedBracketMin: _unifiedBracketMin,
      unifiedBracketMax: _unifiedBracketMax,
      genderRestrictionEnabled: _genderRestrictionEnabled,
      applicableGenders: _applicableGenders,
      scope: _scope,
    );
    widget.onSave(updatedCategory);
    Navigator.of(context).pop();
  }
}
