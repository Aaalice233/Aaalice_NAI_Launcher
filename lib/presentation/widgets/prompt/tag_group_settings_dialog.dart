import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/random_tag_group.dart';
import '../settings/setting_tiles.dart';

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

                    const Divider(height: 1),

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

                    const Divider(height: 1),

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

                    const Divider(height: 1),

                    // 权重括号
                    RangeSliderSettingTile(
                      title: l10n.tagGroupSettings_bracket,
                      subtitle: l10n.tagGroupSettings_bracketDesc,
                      start: _bracketMin,
                      end: _bracketMax,
                      min: -10,
                      max: 10,
                      valueFormatter: (start, end) =>
                          _formatBracketRange(start, end),
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
