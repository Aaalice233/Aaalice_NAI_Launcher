import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/random_category.dart';
import '../settings/setting_tiles.dart';

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

  const CategorySettingsDialog({
    super.key,
    required this.category,
    required this.onSave,
  });

  /// 显示对话框
  static Future<void> show({
    required BuildContext context,
    required RandomCategory category,
    required ValueChanged<RandomCategory> onSave,
  }) {
    return showDialog(
      context: context,
      builder: (context) => CategorySettingsDialog(
        category: category,
        onSave: onSave,
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

                    const Divider(height: 1),

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

                    const Divider(height: 1),

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

                    const Divider(height: 1),

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
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
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
                _formatBracketRange(start, end),
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

  String _formatBracketRange(int start, int end) {
    String formatValue(int v) {
      if (v < 0) return '$v (降权)';
      if (v > 0) return '+$v (增强)';
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
    );
    widget.onSave(updatedCategory);
    Navigator.of(context).pop();
  }
}
