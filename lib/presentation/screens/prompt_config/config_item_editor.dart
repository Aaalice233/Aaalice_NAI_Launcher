import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/prompt_config.dart';

/// 配置项编辑器
class ConfigItemEditor extends ConsumerStatefulWidget {
  final PromptConfig config;
  final bool isNew;

  const ConfigItemEditor({
    super.key,
    required this.config,
    this.isNew = false,
  });

  @override
  ConsumerState<ConfigItemEditor> createState() => _ConfigItemEditorState();
}

class _ConfigItemEditorState extends ConsumerState<ConfigItemEditor> {
  late TextEditingController _nameController;
  late TextEditingController _contentsController;
  late SelectionMode _selectionMode;
  late ContentType _contentType;
  late int _selectCount;
  late double _selectProbability;
  late int _bracketMin;
  late int _bracketMax;
  late bool _shuffle;
  late bool _enabled;
  late List<PromptConfig> _nestedConfigs;

  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.config.name);
    _contentsController = TextEditingController(
      text: widget.config.stringContents.join('\n'),
    );
    _selectionMode = widget.config.selectionMode;
    _contentType = widget.config.contentType;
    _selectCount = widget.config.selectCount ?? 1;
    _selectProbability =
        (widget.config.selectProbability ?? 0.5).clamp(0.1, 1.0);
    _bracketMin = widget.config.bracketMin;
    _bracketMax = widget.config.bracketMax;
    _shuffle = widget.config.shuffle;
    _enabled = widget.config.enabled;
    _nestedConfigs = List.from(widget.config.nestedConfigs);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentsController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _hasChanges) {
          _showUnsavedChangesDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isNew
              ? context.l10n.configEditor_newConfigGroup
              : context.l10n.configEditor_editConfigGroup,),
          actions: [
            TextButton.icon(
              onPressed: _saveConfig,
              icon: const Icon(Icons.check),
              label: Text(context.l10n.common_save),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 配置名称
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.l10n.configEditor_configName,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.label_outline),
              ),
              onChanged: (_) => _markChanged(),
            ),
            const SizedBox(height: 24),

            // 启用开关
            SwitchListTile(
              title: Text(context.l10n.configEditor_enableConfig),
              subtitle: Text(context.l10n.configEditor_enableConfigHint),
              value: _enabled,
              onChanged: (value) {
                setState(() {
                  _enabled = value;
                  _markChanged();
                });
              },
            ),
            const Divider(height: 32),

            // 内容类型
            _buildSectionHeader(theme, context.l10n.configEditor_contentType),
            const SizedBox(height: 8),
            SegmentedButton<ContentType>(
              segments: [
                ButtonSegment(
                  value: ContentType.string,
                  label: Text(context.l10n.configEditor_tagList),
                  icon: const Icon(Icons.list),
                ),
                ButtonSegment(
                  value: ContentType.nested,
                  label: Text(context.l10n.configEditor_nestedConfig),
                  icon: const Icon(Icons.account_tree),
                ),
              ],
              selected: {_contentType},
              onSelectionChanged: (value) {
                setState(() {
                  _contentType = value.first;
                  _markChanged();
                });
              },
            ),
            const SizedBox(height: 24),

            // 选取方式
            _buildSectionHeader(theme, context.l10n.configEditor_selectionMode),
            const SizedBox(height: 8),
            ...SelectionMode.values.map((mode) {
              return RadioListTile<SelectionMode>(
                title: Text(_getSelectionModeName(mode)),
                subtitle: Text(_getSelectionModeDescription(mode)),
                value: mode,
                groupValue: _selectionMode,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectionMode = value;
                      _markChanged();
                    });
                  }
                },
              );
            }),

            // 选取数量（仅多个-数量模式）
            if (_selectionMode == SelectionMode.multipleCount) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(context.l10n.configEditor_selectCount),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Slider(
                      value: _selectCount.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '$_selectCount',
                      onChanged: (value) {
                        setState(() {
                          _selectCount = value.toInt();
                          _markChanged();
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$_selectCount',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ],

            // 选取概率（概率模式）
            if (_selectionMode == SelectionMode.singleProbability ||
                _selectionMode == SelectionMode.multipleProbability) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(context.l10n.configEditor_selectProbability),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Slider(
                      value: _selectProbability,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      label: '${(_selectProbability * 100).toInt()}%',
                      onChanged: (value) {
                        setState(() {
                          _selectProbability = value;
                          _markChanged();
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${(_selectProbability * 100).toInt()}%',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ],

            // 打乱顺序（仅特定模式）
            if (_selectionMode == SelectionMode.multipleProbability ||
                _selectionMode == SelectionMode.all)
              SwitchListTile(
                title: Text(context.l10n.configEditor_shuffleOrder),
                subtitle: Text(context.l10n.configEditor_shuffleOrderHint),
                value: _shuffle,
                onChanged: (value) {
                  setState(() {
                    _shuffle = value;
                    _markChanged();
                  });
                },
              ),

            const Divider(height: 32),

            // 权重括号
            _buildSectionHeader(
                theme, context.l10n.configEditor_weightBrackets,),
            const SizedBox(height: 8),
            Text(
              context.l10n.configEditor_weightBracketsHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.configEditor_minBrackets(_bracketMin)),
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
                      Text(context.l10n.configEditor_maxBrackets(_bracketMax)),
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
            // 预览效果
            if (_bracketMin > 0 || _bracketMax > 0)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.configEditor_effectPreview,
                          style: theme.textTheme.labelSmall,),
                      const SizedBox(height: 4),
                      Text(
                        _getBracketPreview(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const Divider(height: 32),

            // 内容编辑
            _buildSectionHeader(theme, context.l10n.configEditor_content),
            const SizedBox(height: 8),
            if (_contentType == ContentType.string)
              _buildStringContentsEditor(theme)
            else
              _buildNestedConfigsEditor(theme),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildStringContentsEditor(ThemeData theme) {
    final lineCount = _contentsController.text
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.configEditor_tagCountHint(lineCount),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _contentsController,
          maxLines: 15,
          minLines: 5,
          decoration: const InputDecoration(
            hintText:
                'Enter tags, one per line...\ne.g.:\n1girl\nbeautiful eyes\nlong hair',
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(fontFamily: 'monospace'),
          onChanged: (_) {
            _markChanged();
            setState(() {}); // 更新行数
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _formatContents,
              icon: const Icon(Icons.auto_fix_high, size: 18),
              label: Text(context.l10n.configEditor_format),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _sortContents,
              icon: const Icon(Icons.sort_by_alpha, size: 18),
              label: Text(context.l10n.configEditor_sort),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _removeDuplicates,
              icon: const Icon(Icons.filter_list, size: 18),
              label: Text(context.l10n.configEditor_dedupe),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNestedConfigsEditor(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.configEditor_nestedConfigHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        if (_nestedConfigs.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.account_tree,
                      size: 48,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.configEditor_noNestedConfig,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...List.generate(_nestedConfigs.length, (index) {
            final nested = _nestedConfigs[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.subdirectory_arrow_right),
                title: Text(nested.name),
                subtitle: Text(
                  nested.contentType == ContentType.string
                      ? context.l10n
                          .configEditor_itemCount(nested.stringContents.length)
                      : context.l10n.configEditor_subConfigCount(
                          nested.nestedConfigs.length,),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editNestedConfig(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteNestedConfig(index),
                      color: theme.colorScheme.error,
                    ),
                  ],
                ),
                onTap: () => _editNestedConfig(index),
              ),
            );
          }),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton.icon(
            onPressed: _addNestedConfig,
            icon: const Icon(Icons.add),
            label: Text(context.l10n.configEditor_addNestedConfig),
          ),
        ),
      ],
    );
  }

  void _formatContents() {
    final lines = _contentsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _contentsController.text = lines.join('\n');
    _markChanged();
    setState(() {});
  }

  void _sortContents() {
    final lines = _contentsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();
    _contentsController.text = lines.join('\n');
    _markChanged();
    setState(() {});
  }

  void _removeDuplicates() {
    final lines = _contentsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    _contentsController.text = lines.join('\n');
    _markChanged();
    setState(() {});
  }

  void _addNestedConfig() async {
    final newConfig =
        PromptConfig.create(name: context.l10n.configEditor_subConfig);
    final result = await Navigator.of(context).push<PromptConfig>(
      MaterialPageRoute(
        builder: (context) => ConfigItemEditor(config: newConfig, isNew: true),
      ),
    );
    if (result != null) {
      setState(() {
        _nestedConfigs.add(result);
        _markChanged();
      });
    }
  }

  void _editNestedConfig(int index) async {
    final result = await Navigator.of(context).push<PromptConfig>(
      MaterialPageRoute(
        builder: (context) => ConfigItemEditor(config: _nestedConfigs[index]),
      ),
    );
    if (result != null) {
      setState(() {
        _nestedConfigs[index] = result;
        _markChanged();
      });
    }
  }

  void _deleteNestedConfig(int index) {
    setState(() {
      _nestedConfigs.removeAt(index);
      _markChanged();
    });
  }

  String _getSelectionModeName(SelectionMode mode) {
    switch (mode) {
      case SelectionMode.singleRandom:
        return context.l10n.configEditor_singleRandom;
      case SelectionMode.singleSequential:
        return context.l10n.configEditor_singleSequential;
      case SelectionMode.singleProbability:
        return context.l10n.configEditor_singleProbability;
      case SelectionMode.multipleCount:
        return context.l10n.configEditor_multipleCount;
      case SelectionMode.multipleProbability:
        return context.l10n.configEditor_multipleProbability;
      case SelectionMode.all:
        return context.l10n.configEditor_selectAll;
    }
  }

  String _getSelectionModeDescription(SelectionMode mode) {
    switch (mode) {
      case SelectionMode.singleRandom:
        return context.l10n.configEditor_singleRandomHint;
      case SelectionMode.singleSequential:
        return context.l10n.configEditor_singleSequentialHint;
      case SelectionMode.singleProbability:
        return context.l10n.configEditor_singleProbabilityHint;
      case SelectionMode.multipleCount:
        return context.l10n.configEditor_multipleCountHint;
      case SelectionMode.multipleProbability:
        return context.l10n.configEditor_multipleProbabilityHint;
      case SelectionMode.all:
        return context.l10n.configEditor_selectAllHint;
    }
  }

  String _getBracketPreview() {
    final examples = <String>[];
    for (int i = _bracketMin; i <= _bracketMax; i++) {
      final brackets = '{' * i;
      final closeBrackets = '}' * i;
      examples.add('${brackets}tag$closeBrackets');
    }
    return examples.join(context.l10n.configEditor_or);
  }

  void _saveConfig() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.configEditor_enterConfigName)),
      );
      return;
    }

    final stringContents = _contentsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final result = widget.config.copyWith(
      name: _nameController.text.trim(),
      selectionMode: _selectionMode,
      contentType: _contentType,
      selectCount: _selectCount,
      selectProbability: _selectProbability,
      bracketMin: _bracketMin,
      bracketMax: _bracketMax,
      shuffle: _shuffle,
      enabled: _enabled,
      stringContents: stringContents,
      nestedConfigs: _nestedConfigs,
    );

    Navigator.of(context).pop(result);
  }

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(context.l10n.config_unsavedChanges),
          content: Text(context.l10n.config_unsavedChangesContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.configEditor_continueEditing),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: Text(context.l10n.configEditor_discardChanges),
            ),
          ],
        );
      },
    );
  }
}
