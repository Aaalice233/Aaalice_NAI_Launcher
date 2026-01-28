import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/prompt_config.dart' as pc;
import 'config_list_item.dart';

/// 配置组面板组件
class ConfigPanel extends StatelessWidget {
  final pc.RandomPromptPreset? preset;
  final List<pc.PromptConfig> configs;
  final String? selectedConfigId;
  final bool hasUnsavedChanges;
  final TextEditingController presetNameController;
  final VoidCallback onAddConfig;
  final VoidCallback onSavePreset;
  final void Function(String configId) onSelectConfig;
  final void Function(int index) onToggleConfigEnabled;
  final void Function(int index) onDeleteConfig;
  final void Function(int oldIndex, int newIndex) onReorderConfig;
  final VoidCallback onPresetNameChanged;

  const ConfigPanel({
    super.key,
    required this.preset,
    required this.configs,
    required this.selectedConfigId,
    required this.hasUnsavedChanges,
    required this.presetNameController,
    required this.onAddConfig,
    required this.onSavePreset,
    required this.onSelectConfig,
    required this.onToggleConfigEnabled,
    required this.onDeleteConfig,
    required this.onReorderConfig,
    required this.onPresetNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Container(
      width: 280,
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          _buildHeader(context, theme),
          Divider(height: 1, color: theme.dividerColor),

          // 预设名称编辑
          if (preset != null) _buildPresetNameField(context, theme),

          // 配置组列表
          Expanded(
            child: preset == null
                ? Center(
                    child: Text(
                      l10n.preset_selectPreset,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  )
                : configs.isEmpty
                    ? _buildEmptyConfigs(context, theme)
                    : _buildConfigList(context, theme),
          ),

          // 保存按钮
          if (hasUnsavedChanges && preset != null) ...[
            Divider(height: 1, color: theme.dividerColor),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: onSavePreset,
                icon: const Icon(Icons.save, size: 18),
                label: Text(l10n.config_saveChanges),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.layers_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            l10n.config_configGroups,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (preset != null)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: l10n.preset_addConfigGroup,
              onPressed: onAddConfig,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildPresetNameField(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: presetNameController,
        decoration: InputDecoration(
          labelText: l10n.preset_presetName,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        style: theme.textTheme.bodyMedium,
        onChanged: (_) => onPresetNameChanged(),
      ),
    );
  }

  Widget _buildEmptyConfigs(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_add, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            l10n.preset_noConfigGroups,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAddConfig,
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.preset_addConfigGroup),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigList(BuildContext context, ThemeData theme) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      buildDefaultDragHandles: false,
      itemCount: configs.length,
      onReorder: onReorderConfig,
      itemBuilder: (context, index) {
        final config = configs[index];
        return ConfigListItem(
          key: ValueKey(config.id),
          config: config,
          index: index,
          isSelected: config.id == selectedConfigId,
          onTap: () => onSelectConfig(config.id),
          onToggleEnabled: () => onToggleConfigEnabled(index),
          onDelete: () => onDeleteConfig(index),
        );
      },
    );
  }
}
