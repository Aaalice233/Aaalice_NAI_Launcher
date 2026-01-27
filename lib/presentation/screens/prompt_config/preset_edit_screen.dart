import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/prompt_config.dart';
import '../../providers/prompt_config_provider.dart';
import '../../widgets/common/themed_switch.dart';
import 'config_item_editor.dart';
import 'import_nai_category_dialog.dart';

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
          title: Text(
            widget.isNew
                ? context.l10n.presetEdit_newPreset
                : context.l10n.presetEdit_editPreset,
          ),
          actions: [
            if (_hasChanges || widget.isNew)
              TextButton.icon(
                onPressed: _savePreset,
                icon: const Icon(Icons.check),
                label: Text(context.l10n.common_save),
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
                  labelText: context.l10n.presetEdit_presetName,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.label_outline),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.preview),
                    tooltip: context.l10n.tooltip_previewGenerate,
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
                    context.l10n.presetEdit_configGroups(_configs.length),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.download, size: 20),
                        tooltip: context.l10n.importNai_title,
                        onPressed: _importFromNai,
                      ),
                      IconButton(
                        icon: const Icon(Icons.help_outline, size: 20),
                        tooltip: context.l10n.tooltip_help,
                        onPressed: _showHelpDialog,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: context.l10n.tooltip_addConfigGroup,
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
            context.l10n.presetEdit_noConfigGroups,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.presetEdit_addConfigGroupHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _addConfig,
            icon: const Icon(Icons.add),
            label: Text(context.l10n.presetEdit_addConfigGroup),
          ),
        ],
      ),
    );
  }

  /// 从NAI词库导入类别
  Future<void> _importFromNai() async {
    final result = await ImportNaiCategoryDialog.show(context);
    if (result != null && result.isNotEmpty) {
      setState(() {
        _configs.addAll(result);
        _markChanged();
      });
    }
  }

  void _addConfig() async {
    final newConfig =
        PromptConfig.create(name: context.l10n.presetEdit_newConfigGroup);
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
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(context.l10n.common_confirmDelete),
          content: Text(
            context.l10n.presetEdit_deleteConfigConfirm(_configs[index].name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _configs.removeAt(index);
                  _markChanged();
                });
              },
              child: Text(context.l10n.common_delete),
            ),
          ],
        );
      },
    );
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
        SnackBar(content: Text(context.l10n.presetEdit_enterPresetName)),
      );
      return;
    }

    final updatedPreset = widget.preset.copyWith(
      name: _nameController.text.trim(),
      configs: _configs,
      updatedAt: DateTime.now(),
    );

    try {
      final notifier = ref.read(promptConfigNotifierProvider.notifier);
      if (widget.isNew) {
        await notifier.addPreset(updatedPreset);
      } else {
        await notifier.updatePreset(updatedPreset);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.presetEdit_saveSuccess)),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.presetEdit_saveError),
            action: SnackBarAction(
              label: context.l10n.common_retry,
              onPressed: _savePreset,
            ),
          ),
        );
      }
    }
  }

  void _previewGenerate() {
    final tempPreset = widget.preset.copyWith(
      name: _nameController.text.trim(),
      configs: _configs,
    );
    final result = tempPreset.generate();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(context.l10n.presetEdit_previewTitle),
          content: SizedBox(
            width: 400,
            child: SelectableText(
              result.isEmpty ? context.l10n.presetEdit_emptyResult : result,
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.common_close),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _previewGenerate(); // 重新生成
              },
              child: Text(context.l10n.presetEdit_regenerate),
            ),
          ],
        );
      },
    );
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(context.l10n.presetEdit_helpTitle),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.presetEdit_helpConfigGroup,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(context.l10n.presetEdit_helpConfigGroupContent),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.presetEdit_helpSelectionMode,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(context.l10n.presetEdit_helpSingleRandom),
                  Text(context.l10n.presetEdit_helpSingleSequential),
                  Text(context.l10n.presetEdit_helpMultipleCount),
                  Text(context.l10n.presetEdit_helpMultipleProbability),
                  Text(context.l10n.presetEdit_helpAll),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.presetEdit_helpWeightBrackets,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(context.l10n.presetEdit_helpWeightBracketsContent),
                  Text(context.l10n.presetEdit_helpWeightBracketsExample),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.presetEdit_helpNestedConfig,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(context.l10n.presetEdit_helpNestedConfigContent),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.presetEdit_gotIt),
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
      clipBehavior: Clip.antiAlias,
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
              ThemedSwitch(
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
                        _getConfigDescription(context),
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

  String _getConfigDescription(BuildContext context) {
    final parts = <String>[];

    // 内容类型和数量
    if (config.contentType == ContentType.string) {
      parts.add(context.l10n.presetEdit_tagCount(config.stringContents.length));
    } else {
      parts.add(
        context.l10n.configEditor_subConfigCount(config.nestedConfigs.length),
      );
    }

    // 选取方式
    parts.add(_getSelectionModeText(context));

    // 括号权重
    if (config.bracketMin > 0 || config.bracketMax > 0) {
      if (config.bracketMin == config.bracketMax) {
        parts.add(context.l10n.presetEdit_bracketLayers(config.bracketMin));
      } else {
        parts.add(
          context.l10n
              .presetEdit_bracketRange(config.bracketMin, config.bracketMax),
        );
      }
    }

    return parts.join(' · ');
  }

  String _getSelectionModeText(BuildContext context) {
    switch (config.selectionMode) {
      case SelectionMode.singleRandom:
        return context.l10n.config_singleRandom;
      case SelectionMode.singleSequential:
        return context.l10n.config_singleSequential;
      case SelectionMode.singleProbability:
        return context.l10n.configEditor_probabilityPercent(
          ((config.selectProbability ?? 0.5) * 100).toInt(),
        );
      case SelectionMode.multipleCount:
        return context.l10n.configEditor_randomCount(config.selectCount ?? 1);
      case SelectionMode.multipleProbability:
        return context.l10n.configEditor_probabilityPercent(
          ((config.selectProbability ?? 0.5) * 100).toInt(),
        );
      case SelectionMode.all:
        return context.l10n.config_all;
    }
  }
}
