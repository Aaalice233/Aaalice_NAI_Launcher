import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/prompt/prompt_config.dart';
import '../../providers/prompt_config_provider.dart';
import 'config_item_editor.dart';

/// 预设编辑页面
class PresetEditScreen extends ConsumerStatefulWidget {
  final RandomPromptPreset preset;
  final bool isNew;

  const PresetEditScreen({
    super.key,
    required this.preset,
    this.isNew = false,
  });

  @override
  ConsumerState<PresetEditScreen> createState() => _PresetEditScreenState();
}

class _PresetEditScreenState extends ConsumerState<PresetEditScreen> {
  late TextEditingController _nameController;
  late List<PromptConfig> _configs;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.preset.name);
    _configs = List.from(widget.preset.configs);
  }

  @override
  void dispose() {
    _nameController.dispose();
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
          title: Text(widget.isNew ? '新建预设' : '编辑预设'),
          actions: [
            if (_hasChanges || widget.isNew)
              TextButton.icon(
                onPressed: _savePreset,
                icon: const Icon(Icons.check),
                label: const Text('保存'),
              ),
          ],
        ),
        body: Column(
          children: [
            // 预设名称
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '预设名称',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.label_outline),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.preview),
                    tooltip: '预览生成',
                    onPressed: _previewGenerate,
                  ),
                ),
                onChanged: (_) => _markChanged(),
              ),
            ),
            // 配置组列表标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '配置组 (${_configs.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.help_outline, size: 20),
                        tooltip: '帮助',
                        onPressed: _showHelpDialog,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: '添加配置组',
                        onPressed: _addConfig,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 配置组列表
            Expanded(
              child: _configs.isEmpty
                  ? _buildEmptyConfigs(theme)
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _configs.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = _configs.removeAt(oldIndex);
                          _configs.insert(newIndex, item);
                          _markChanged();
                        });
                      },
                      itemBuilder: (context, index) {
                        final config = _configs[index];
                        return _ConfigCard(
                          key: ValueKey(config.id),
                          config: config,
                          index: index,
                          onEdit: () => _editConfig(index),
                          onDelete: () => _deleteConfig(index),
                          onToggleEnabled: () => _toggleConfigEnabled(index),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyConfigs(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.playlist_add,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有配置组',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 添加配置组',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _addConfig,
            icon: const Icon(Icons.add),
            label: const Text('添加配置组'),
          ),
        ],
      ),
    );
  }

  void _addConfig() async {
    final newConfig = PromptConfig.create(name: '新配置组');
    final result = await Navigator.of(context).push<PromptConfig>(
      MaterialPageRoute(
        builder: (context) => ConfigItemEditor(config: newConfig, isNew: true),
      ),
    );
    if (result != null) {
      setState(() {
        _configs.add(result);
        _markChanged();
      });
    }
  }

  void _editConfig(int index) async {
    final result = await Navigator.of(context).push<PromptConfig>(
      MaterialPageRoute(
        builder: (context) => ConfigItemEditor(config: _configs[index]),
      ),
    );
    if (result != null) {
      setState(() {
        _configs[index] = result;
        _markChanged();
      });
    }
  }

  void _deleteConfig(int index) {
    setState(() {
      _configs.removeAt(index);
      _markChanged();
    });
  }

  void _toggleConfigEnabled(int index) {
    setState(() {
      _configs[index] = _configs[index].copyWith(
        enabled: !_configs[index].enabled,
      );
      _markChanged();
    });
  }

  void _savePreset() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入预设名称')),
      );
      return;
    }

    final updatedPreset = widget.preset.copyWith(
      name: _nameController.text.trim(),
      configs: _configs,
      updatedAt: DateTime.now(),
    );

    final notifier = ref.read(promptConfigNotifierProvider.notifier);
    if (widget.isNew) {
      await notifier.addPreset(updatedPreset);
    } else {
      await notifier.updatePreset(updatedPreset);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功')),
      );
      Navigator.of(context).pop();
    }
  }

  void _previewGenerate() {
    final tempPreset = widget.preset.copyWith(
      name: _nameController.text,
      configs: _configs,
    );
    final result = tempPreset.generate();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('预览生成结果'),
          content: SizedBox(
            width: 400,
            child: SelectableText(
              result.isEmpty ? '(空结果，请检查配置)' : result,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _previewGenerate(); // 重新生成
              },
              child: const Text('重新生成'),
            ),
          ],
        );
      },
    );
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('帮助'),
          content: const SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('配置组说明', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('每个配置组会按顺序生成内容，最终结果由逗号连接。'),
                  SizedBox(height: 16),
                  Text('选取方式', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• 单个-随机：随机选择一项'),
                  Text('• 单个-顺序：按顺序循环选择'),
                  Text('• 多个-数量：随机选择指定数量'),
                  Text('• 多个-概率：每项按概率独立选择'),
                  Text('• 全部：选择所有项'),
                  SizedBox(height: 16),
                  Text('权重括号', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('括号 {} 用于增加权重，括号越多权重越高。'),
                  Text('例如：{tag} 是 1.05 倍权重，{{tag}} 是 1.1 倍。'),
                  SizedBox(height: 16),
                  Text('嵌套配置', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('配置可以嵌套，用于创建复杂的分层随机逻辑。'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }
}

/// 配置卡片
class _ConfigCard extends StatelessWidget {
  final PromptConfig config;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleEnabled;

  const _ConfigCard({
    super.key,
    required this.config,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 拖拽手柄
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              ),
              const SizedBox(width: 12),
              // 启用开关
              Switch(
                value: config.enabled,
                onChanged: (_) => onToggleEnabled(),
              ),
              const SizedBox(width: 8),
              // 配置信息
              Expanded(
                child: Opacity(
                  opacity: config.enabled ? 1.0 : 0.5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getConfigDescription(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 删除按钮
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
                color: theme.colorScheme.error,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getConfigDescription() {
    final parts = <String>[];

    // 内容类型和数量
    if (config.contentType == ContentType.string) {
      parts.add('${config.stringContents.length} 项标签');
    } else {
      parts.add('${config.nestedConfigs.length} 个子配置');
    }

    // 选取方式
    parts.add(_getSelectionModeText());

    // 括号权重
    if (config.bracketMin > 0 || config.bracketMax > 0) {
      if (config.bracketMin == config.bracketMax) {
        parts.add('${config.bracketMin} 层括号');
      } else {
        parts.add('${config.bracketMin}-${config.bracketMax} 层括号');
      }
    }

    return parts.join(' · ');
  }

  String _getSelectionModeText() {
    switch (config.selectionMode) {
      case SelectionMode.singleRandom:
        return '随机单选';
      case SelectionMode.singleSequential:
        return '顺序单选';
      case SelectionMode.multipleCount:
        return '随机 ${config.selectCount ?? 1} 个';
      case SelectionMode.multipleProbability:
        return '${((config.selectProbability ?? 0.5) * 100).toInt()}% 概率';
      case SelectionMode.all:
        return '全部';
    }
  }
}
