import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    _selectProbability = widget.config.selectProbability ?? 0.5;
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
          title: Text(widget.isNew ? '新建配置组' : '编辑配置组'),
          actions: [
            TextButton.icon(
              onPressed: _saveConfig,
              icon: const Icon(Icons.check),
              label: const Text('保存'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 配置名称
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '配置名称',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
              onChanged: (_) => _markChanged(),
            ),
            const SizedBox(height: 24),

            // 启用开关
            SwitchListTile(
              title: const Text('启用此配置'),
              subtitle: const Text('禁用后不会参与生成'),
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
            _buildSectionHeader(theme, '内容类型'),
            const SizedBox(height: 8),
            SegmentedButton<ContentType>(
              segments: const [
                ButtonSegment(
                  value: ContentType.string,
                  label: Text('标签列表'),
                  icon: Icon(Icons.list),
                ),
                ButtonSegment(
                  value: ContentType.nested,
                  label: Text('嵌套配置'),
                  icon: Icon(Icons.account_tree),
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
            _buildSectionHeader(theme, '选取方式'),
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
                  const Text('选取数量：'),
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

            // 选取概率（仅多个-概率模式）
            if (_selectionMode == SelectionMode.multipleProbability) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('选取概率：'),
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
                title: const Text('打乱顺序'),
                subtitle: const Text('随机排列选中的内容'),
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
            _buildSectionHeader(theme, '权重括号'),
            const SizedBox(height: 8),
            Text(
              '括号用于增加权重，每层 {} 增加约 5% 权重',
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
                      Text('最少括号: $_bracketMin'),
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
                      Text('最多括号: $_bracketMax'),
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
                      Text('效果预览：', style: theme.textTheme.labelSmall),
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
            _buildSectionHeader(theme, '内容'),
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
    final lineCount = _contentsController.text.split('\n').where((s) => s.trim().isNotEmpty).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '每行一个标签，当前 $lineCount 项',
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
            hintText: '输入标签，每行一个...\n例如：\n1girl\nbeautiful eyes\nlong hair',
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
              label: const Text('格式化'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _sortContents,
              icon: const Icon(Icons.sort_by_alpha, size: 18),
              label: const Text('排序'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _removeDuplicates,
              icon: const Icon(Icons.filter_list, size: 18),
              label: const Text('去重'),
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
          '嵌套配置可以创建复杂的分层随机逻辑',
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
                      '还没有嵌套配置',
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
                      ? '${nested.stringContents.length} 项'
                      : '${nested.nestedConfigs.length} 个子配置',
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
            label: const Text('添加嵌套配置'),
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
    final newConfig = PromptConfig.create(name: '子配置');
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
        return '单个 - 随机';
      case SelectionMode.singleSequential:
        return '单个 - 顺序';
      case SelectionMode.multipleCount:
        return '多个 - 指定数量';
      case SelectionMode.multipleProbability:
        return '多个 - 指定概率';
      case SelectionMode.all:
        return '全部';
    }
  }

  String _getSelectionModeDescription(SelectionMode mode) {
    switch (mode) {
      case SelectionMode.singleRandom:
        return '每次随机选择一项';
      case SelectionMode.singleSequential:
        return '按顺序循环选择一项';
      case SelectionMode.multipleCount:
        return '随机选择指定数量的项';
      case SelectionMode.multipleProbability:
        return '每项按概率独立选择';
      case SelectionMode.all:
        return '选择所有项';
    }
  }

  String _getBracketPreview() {
    final examples = <String>[];
    for (int i = _bracketMin; i <= _bracketMax; i++) {
      final brackets = '{' * i;
      final closeBrackets = '}' * i;
      examples.add('${brackets}tag$closeBrackets');
    }
    return examples.join(' 或 ');
  }

  void _saveConfig() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入配置名称')),
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
      builder: (context) {
        return AlertDialog(
          title: const Text('未保存的更改'),
          content: const Text('有未保存的更改，确定要放弃吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('继续编辑'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(this.context);
              },
              child: const Text('放弃更改'),
            ),
          ],
        );
      },
    );
  }
}
