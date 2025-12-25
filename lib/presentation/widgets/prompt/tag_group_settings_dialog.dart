import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/random_tag_group.dart';

/// 词组设置对话框
///
/// 用于编辑词组级别的设置：
/// - 选取概率
/// - 选取模式
/// - 选取数量（多选模式）
/// - 权重括号范围
/// - 打乱顺序
class TagGroupSettingsDialog extends StatefulWidget {
  final RandomTagGroup tagGroup;
  final ValueChanged<RandomTagGroup> onSave;

  const TagGroupSettingsDialog({
    super.key,
    required this.tagGroup,
    required this.onSave,
  });

  /// 显示对话框
  static Future<void> show({
    required BuildContext context,
    required RandomTagGroup tagGroup,
    required ValueChanged<RandomTagGroup> onSave,
  }) {
    return showDialog(
      context: context,
      builder: (context) => TagGroupSettingsDialog(
        tagGroup: tagGroup,
        onSave: onSave,
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
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 650),
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
            ),

            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 选取概率
                    _buildSectionTitle(l10n.tagGroupSettings_probability, theme),
                    const SizedBox(height: 8),
                    _buildProbabilitySlider(theme),

                    const SizedBox(height: 24),

                    // 选取模式
                    _buildSectionTitle(l10n.tagGroupSettings_selectionMode, theme),
                    const SizedBox(height: 8),
                    _buildSelectionModeSelector(theme),

                    // 选取数量（仅多选模式）
                    if (_selectionMode == SelectionMode.multipleNum) ...[
                      const SizedBox(height: 16),
                      _buildSelectCountSlider(theme),
                    ],

                    const SizedBox(height: 24),

                    // 打乱顺序
                    _buildShuffleSwitch(theme),

                    const SizedBox(height: 24),

                    // 权重括号
                    _buildSectionTitle(l10n.tagGroupSettings_bracket, theme),
                    const SizedBox(height: 8),
                    _buildBracketSection(theme),
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
              l10n.tagGroupSettings_probabilityDesc,
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
              l10n.tagGroupSettings_selectionModeDesc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildModeChip(SelectionMode.single, l10n.selectionMode_single, theme),
                _buildModeChip(SelectionMode.multipleNum, l10n.selectionMode_multipleNum, theme),
                _buildModeChip(SelectionMode.multipleProb, l10n.selectionMode_multipleProb, theme),
                _buildModeChip(SelectionMode.all, l10n.selectionMode_all, theme),
                _buildModeChip(SelectionMode.sequential, l10n.selectionMode_sequential, theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(SelectionMode mode, String label, ThemeData theme) {
    final isSelected = _selectionMode == mode;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectionMode = mode;
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
        Text(l10n.tagGroupSettings_selectCount),
        const SizedBox(width: 16),
        Expanded(
          child: Slider(
            value: _multipleNum.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$_multipleNum',
            onChanged: (value) {
              setState(() {
                _multipleNum = value.toInt();
                _markChanged();
              });
            },
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$_multipleNum',
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
    );
  }

  Widget _buildBracketSection(ThemeData theme) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tagGroupSettings_bracketDesc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.tagGroupSettings_bracketMin(_bracketMin)),
                      Slider(
                        value: _bracketMin.toDouble(),
                        min: 0,
                        max: 5,
                        divisions: 5,
                        onChanged: (value) {
                          setState(() {
                            _bracketMin = value.toInt();
                            if (_bracketMax < _bracketMin) {
                              _bracketMax = _bracketMin;
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
                      Text(l10n.tagGroupSettings_bracketMax(_bracketMax)),
                      Slider(
                        value: _bracketMax.toDouble(),
                        min: 0,
                        max: 5,
                        divisions: 5,
                        onChanged: (value) {
                          setState(() {
                            _bracketMax = value.toInt();
                            if (_bracketMin > _bracketMax) {
                              _bracketMin = _bracketMax;
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
            if (_bracketMin > 0 || _bracketMax > 0) _buildBracketPreview(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBracketPreview(ThemeData theme) {
    final l10n = context.l10n;
    final examples = <String>[];
    for (int i = _bracketMin; i <= _bracketMax; i++) {
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
    );
  }

  void _saveSettings() {
    final updatedTagGroup = widget.tagGroup.copyWith(
      probability: _probability,
      selectionMode: _selectionMode,
      multipleNum: _multipleNum,
      bracketMin: _bracketMin,
      bracketMax: _bracketMax,
      shuffle: _shuffle,
    );
    widget.onSave(updatedTagGroup);
    Navigator.of(context).pop();
  }
}
