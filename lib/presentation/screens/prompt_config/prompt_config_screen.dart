import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/prompt/prompt_config.dart';
import '../../providers/prompt_config_provider.dart';
import 'preset_edit_screen.dart';

/// 随机提示词配置页面
class PromptConfigScreen extends ConsumerWidget {
  const PromptConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(promptConfigNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('随机提示词配置'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(context, ref, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text('导入配置'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  leading: Icon(Icons.restore),
                  title: Text('恢复默认'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.presets.isEmpty
              ? _buildEmptyState(context, ref)
              : _buildPresetList(context, ref, state, theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNewPreset(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新建预设'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shuffle,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有预设配置',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '创建一个新预设或恢复默认配置',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => ref.read(promptConfigNotifierProvider.notifier).resetToDefaults(),
            icon: const Icon(Icons.restore),
            label: const Text('恢复默认预设'),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetList(
    BuildContext context,
    WidgetRef ref,
    PromptConfigState state,
    ThemeData theme,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: state.presets.length,
      itemBuilder: (context, index) {
        final preset = state.presets[index];
        final isSelected = preset.id == state.selectedPresetId;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: isSelected ? theme.colorScheme.primaryContainer : null,
          child: InkWell(
            onTap: () => _editPreset(context, ref, preset),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 选中指示器
                      Radio<String>(
                        value: preset.id,
                        groupValue: state.selectedPresetId,
                        onChanged: (value) {
                          if (value != null) {
                            ref.read(promptConfigNotifierProvider.notifier).selectPreset(value);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      // 预设名称
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preset.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: isSelected ? FontWeight.bold : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${preset.configs.length} 个配置组',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 操作菜单
                      PopupMenuButton<String>(
                        onSelected: (value) => _handlePresetAction(context, ref, preset, value),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit),
                              title: Text('编辑'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'duplicate',
                            child: ListTile(
                              leading: Icon(Icons.copy),
                              title: Text('复制'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'export',
                            child: ListTile(
                              leading: Icon(Icons.file_upload),
                              title: Text('导出'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete, color: Colors.red),
                              title: Text('删除', style: TextStyle(color: Colors.red)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // 配置预览
                  if (preset.configs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: preset.configs.take(5).map((config) {
                        return Chip(
                          label: Text(config.name),
                          labelStyle: theme.textTheme.labelSmall,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                    if (preset.configs.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+${preset.configs.length - 5} 更多',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'import':
        _showImportDialog(context, ref);
        break;
      case 'reset':
        _showResetConfirmDialog(context, ref);
        break;
    }
  }

  void _handlePresetAction(
    BuildContext context,
    WidgetRef ref,
    RandomPromptPreset preset,
    String action,
  ) {
    switch (action) {
      case 'edit':
        _editPreset(context, ref, preset);
        break;
      case 'duplicate':
        ref.read(promptConfigNotifierProvider.notifier).duplicatePreset(preset.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已复制预设')),
        );
        break;
      case 'export':
        _exportPreset(context, ref, preset);
        break;
      case 'delete':
        _showDeleteConfirmDialog(context, ref, preset);
        break;
    }
  }

  void _editPreset(BuildContext context, WidgetRef ref, RandomPromptPreset preset) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PresetEditScreen(preset: preset),
      ),
    );
  }

  void _createNewPreset(BuildContext context, WidgetRef ref) {
    final newPreset = RandomPromptPreset.create(name: '新预设');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PresetEditScreen(preset: newPreset, isNew: true),
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('导入配置'),
          content: SizedBox(
            width: 400,
            child: TextField(
              controller: controller,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: '粘贴 JSON 配置...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await ref.read(promptConfigNotifierProvider.notifier).importPreset(controller.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('导入成功')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('导入失败: $e')),
                    );
                  }
                }
              },
              child: const Text('导入'),
            ),
          ],
        );
      },
    );
  }

  void _exportPreset(BuildContext context, WidgetRef ref, RandomPromptPreset preset) {
    final json = ref.read(promptConfigNotifierProvider.notifier).exportPreset(preset.id);
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('配置已复制到剪贴板')),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref, RandomPromptPreset preset) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除预设'),
          content: Text('确定要删除 "${preset.name}" 吗？此操作无法撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(promptConfigNotifierProvider.notifier).deletePreset(preset.id);
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  void _showResetConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('恢复默认'),
          content: const Text('确定要恢复默认预设吗？所有自定义配置将被删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(promptConfigNotifierProvider.notifier).resetToDefaults();
                Navigator.pop(context);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }
}
