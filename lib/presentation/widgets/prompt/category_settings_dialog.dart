import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/random_category.dart';

/// 类别设置对话框
///
/// 用于编辑类别级别的设置：
/// - 类别选取概率
/// - 词组选取模式/数量
/// - 打乱顺序
/// - 统一权重括号设置
/// - 批量设置下属词组
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
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
            ),

            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 类别选取概率
                    _buildSectionTitle(
                        l10n.categorySettings_probability, theme,),
                    const SizedBox(height: 8),
                    _buildProbabilitySlider(theme),

                    const SizedBox(height: 24),

                    // 词组选取模式
                    _buildSectionTitle(
                        l10n.categorySettings_groupSelectionMode, theme,),
                    const SizedBox(height: 8),
                    _buildSelectionModeSelector(theme),

                    // 词组选取数量（仅多选模式）
                    if (_groupSelectionMode == SelectionMode.multipleNum) ...[
                      const SizedBox(height: 16),
                      _buildSelectCountSlider(theme),
                    ],

                    const SizedBox(height: 24),

                    // 打乱顺序
                    _buildShuffleSwitch(theme),

                    const SizedBox(height: 24),

                    // 统一权重括号设置
                    _buildSectionTitle(
                        l10n.categorySettings_unifiedBracket, theme,),
                    const SizedBox(height: 8),
                    _buildUnifiedBracketSection(theme),

                    const SizedBox(height: 24),

                    // 批量设置下属词组
                    _buildSectionTitle(
                        l10n.categorySettings_batchSettings, theme,),
                    const SizedBox(height: 8),
                    _buildBatchSettingsSection(theme),
                  ],
                ),
              ),
            ),

            // 底部按钮
            Container(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildProbabilitySlider(ThemeData theme) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.categorySettings_probabilityDesc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _probability,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    label: '${(_probability * 100).round()}%',
                    onChanged: (value) {
                      setState(() {
                        _probability = value;
                        _markChanged();
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${(_probability * 100).round()}%',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionModeSelector(ThemeData theme) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.categorySettings_groupSelectionModeDesc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildModeChip(
                    SelectionMode.single, l10n.selectionMode_single, theme,),
                _buildModeChip(SelectionMode.multipleNum,
                    l10n.selectionMode_multipleNum, theme,),
                _buildModeChip(SelectionMode.multipleProb,
                    l10n.selectionMode_multipleProb, theme,),
                _buildModeChip(
                    SelectionMode.all, l10n.selectionMode_all, theme,),
                _buildModeChip(SelectionMode.sequential,
                    l10n.selectionMode_sequential, theme,),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(SelectionMode mode, String label, ThemeData theme) {
    final isSelected = _groupSelectionMode == mode;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _groupSelectionMode = mode;
            _markChanged();
          });
        }
      },
    );
  }

  Widget _buildSelectCountSlider(ThemeData theme) {
    final l10n = context.l10n;
    return Row(
      children: [
        Text(l10n.categorySettings_groupSelectCount),
        const SizedBox(width: 16),
        Expanded(
          child: Slider(
            value: _groupSelectCount.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$_groupSelectCount',
            onChanged: (value) {
              setState(() {
                _groupSelectCount = value.toInt();
                _markChanged();
              });
            },
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$_groupSelectCount',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildShuffleSwitch(ThemeData theme) {
    final l10n = context.l10n;
    return Card(
      child: SwitchListTile(
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
    );
  }

  Widget _buildUnifiedBracketSection(ThemeData theme) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
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
              const Divider(),
              const SizedBox(height: 8),
              Text(
                l10n.categorySettings_bracketRange,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n
                            .categorySettings_bracketMin(_unifiedBracketMin),),
                        Slider(
                          value: _unifiedBracketMin.toDouble(),
                          min: 0,
                          max: 5,
                          divisions: 5,
                          onChanged: (value) {
                            setState(() {
                              _unifiedBracketMin = value.toInt();
                              if (_unifiedBracketMax < _unifiedBracketMin) {
                                _unifiedBracketMax = _unifiedBracketMin;
                              }
                              _markChanged();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n
                            .categorySettings_bracketMax(_unifiedBracketMax),),
                        Slider(
                          value: _unifiedBracketMax.toDouble(),
                          min: 0,
                          max: 5,
                          divisions: 5,
                          onChanged: (value) {
                            setState(() {
                              _unifiedBracketMax = value.toInt();
                              if (_unifiedBracketMin > _unifiedBracketMax) {
                                _unifiedBracketMin = _unifiedBracketMax;
                              }
                              _markChanged();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_unifiedBracketMin > 0 || _unifiedBracketMax > 0)
                _buildBracketPreview(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBracketPreview(ThemeData theme) {
    final l10n = context.l10n;
    final examples = <String>[];
    for (int i = _unifiedBracketMin; i <= _unifiedBracketMax; i++) {
      final brackets = '{' * i;
      final closeBrackets = '}' * i;
      examples.add('${brackets}tag$closeBrackets');
    }
    return Container(
      margin: const EdgeInsets.only(top: 8),
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
    );
  }

  Widget _buildBatchSettingsSection(ThemeData theme) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.categorySettings_batchSettingsDesc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _batchEnableAllGroups,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(l10n.categorySettings_enableAllGroups),
                ),
                OutlinedButton.icon(
                  onPressed: _batchDisableAllGroups,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(l10n.categorySettings_disableAllGroups),
                ),
                OutlinedButton.icon(
                  onPressed: _batchResetGroupSettings,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: Text(l10n.categorySettings_resetGroupSettings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _batchEnableAllGroups() {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.categorySettings_batchEnableSuccess;

    final updatedGroups =
        widget.category.groups.map((g) => g.copyWith(enabled: true)).toList();
    final updatedCategory = widget.category.copyWith(groups: updatedGroups);
    widget.onSave(updatedCategory);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _batchDisableAllGroups() {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.categorySettings_batchDisableSuccess;

    final updatedGroups =
        widget.category.groups.map((g) => g.copyWith(enabled: false)).toList();
    final updatedCategory = widget.category.copyWith(groups: updatedGroups);
    widget.onSave(updatedCategory);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _batchResetGroupSettings() {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.categorySettings_batchResetSuccess;

    final updatedGroups = widget.category.groups
        .map((g) => g.copyWith(
              probability: 1.0,
              selectionMode: SelectionMode.single,
              multipleNum: 1,
              bracketMin: 0,
              bracketMax: 0,
              shuffle: true,
            ),)
        .toList();
    final updatedCategory = widget.category.copyWith(groups: updatedGroups);
    widget.onSave(updatedCategory);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
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
