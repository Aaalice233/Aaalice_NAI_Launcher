import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/character_count_config.dart'
    show defaultSlotOptions;
import '../../../data/models/prompt/prompt_config.dart' as pc;
import '../../../data/models/prompt/random_prompt_result.dart'
    show RandomGenerationMode;
import '../../../data/models/prompt/tag_category.dart';
import '../../../data/models/prompt/random_category.dart';
import '../../../data/models/prompt/random_preset.dart';
import '../../providers/prompt_config_provider.dart';
import '../../providers/random_preset_provider.dart';
import '../../providers/random_mode_provider.dart';
import '../../providers/tag_group_sync_provider.dart';
import '../../providers/tag_library_provider.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/themed_divider.dart';
import '../../widgets/prompt/category_settings_dialog.dart';
import '../../widgets/prompt/new_preset_dialog.dart';
import 'dialogs/dialogs.dart';
import 'utils/preset_validators.dart';
import 'widgets/add_category_dialog.dart';
import 'widgets/category_detail_dialog.dart';
import 'widgets/config_detail_editor.dart';
import 'widgets/config_panel.dart';
import 'widgets/nai_detail_panel.dart';
import 'widgets/preset_list_item.dart';

/// 随机提示词配置页面 - 分栏布局
class PromptConfigScreen extends ConsumerStatefulWidget {
  const PromptConfigScreen({super.key});

  @override
  ConsumerState<PromptConfigScreen> createState() => _PromptConfigScreenState();
}

class _PromptConfigScreenState extends ConsumerState<PromptConfigScreen> {
  String? _selectedPresetId;
  String? _selectedConfigId;
  bool _hasUnsavedChanges = false;

  // 编辑状态
  late TextEditingController _presetNameController;
  List<pc.PromptConfig> _editingConfigs = [];

  // 分类展开状态
  final Set<TagSubCategory> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _presetNameController = TextEditingController();
  }

  @override
  void dispose() {
    _presetNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(promptConfigNotifierProvider);
    final theme = Theme.of(context);
    final currentMode = ref.watch(randomModeNotifierProvider);

    // 初始化选中状态（仅在自定义模式下）
    if (currentMode == RandomGenerationMode.custom &&
        _selectedPresetId == null &&
        state.presets.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectPreset(state.selectedPresetId ?? state.presets.first.id);
      });
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // 左侧预设列表
          _buildPresetPanel(theme),
          // 垂直分割线
          const ThemedDivider(height: 1, vertical: true),
          // NAI 模式：显示算法说明；自定义模式：显示配置组列表和详情
          if (currentMode == RandomGenerationMode.naiOfficial)
            Expanded(child: _buildNaiDetailPanel())
          else ...[
            // 中间配置组列表
            _buildConfigPanel(state),
            // 垂直分割线
            const ThemedDivider(height: 1, vertical: true),
            // 右侧详情编辑
            _buildDetailPanel(theme),
          ],
        ],
      ),
    );
  }

  // ==================== UI 构建方法 ====================

  /// 左侧预设面板
  Widget _buildPresetPanel(ThemeData theme) {
    final presetState = ref.watch(randomPresetNotifierProvider);
    final presets = presetState.presets;

    return Container(
      width: 220,
      color: theme.colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.l10n.config_title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const ThemedDivider(height: 1),

          // 预设列表
          Expanded(
            child: presetState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: [
                      ...presets.map(
                        (preset) => PresetListItem(
                          preset: preset,
                          isSelected: preset.id == presetState.selectedPresetId,
                          onTap: () => _selectRandomPreset(preset.id),
                          onRename: preset.isDefault
                              ? null
                              : () => _showRenameRandomPresetDialog(preset),
                          onDelete: preset.isDefault
                              ? null
                              : () => _showDeleteRandomPresetDialog(preset),
                        ),
                      ),
                      // 新建预设按钮
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: OutlinedButton.icon(
                          onPressed: _showNewPresetDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(context.l10n.config_newPreset),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// NAI 模式详情面板
  Widget _buildNaiDetailPanel() {
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final presetCategories = preset?.categories ?? [];

    return NaiDetailPanel(
      expandedCategories: _expandedCategories,
      onEditPresetName: () {
        if (preset != null) _showRenameRandomPresetDialog(preset);
      },
      onEditDescription: () {
        if (preset != null) _showEditPresetDescriptionDialog(preset);
      },
      onResetPreset: () => _showResetPresetConfirmDialog(context),
      onAddCategory: () => _showAddCategoryDialog(context),
      onSelectAll: _selectAllTagGroups,
      onDeselectAll: _deselectAllTagGroups,
      onToggleExpand: () => _toggleAllExpand(presetCategories),
      onExpandChanged: (category, expanded) {
        setState(() {
          if (expanded) {
            _expandedCategories.add(category);
          } else {
            _expandedCategories.remove(category);
          }
        });
      },
      onSyncCategory: _syncCategory,
      onShowDetail: (category, tags) {
        CategoryDetailDialog.show(
            context: context, category: category, tags: tags);
      },
      onSettings: _showCategorySettings,
      onEnabledChanged: _toggleCategoryEnabled,
      onRemove: _removeCategory,
    );
  }

  /// 中间配置组面板
  Widget _buildConfigPanel(PromptConfigState state) {
    final preset = _getSelectedPreset(state);

    return ConfigPanel(
      preset: preset,
      configs: _editingConfigs,
      selectedConfigId: _selectedConfigId,
      hasUnsavedChanges: _hasUnsavedChanges,
      presetNameController: _presetNameController,
      onAddConfig: _addConfig,
      onSavePreset: _savePreset,
      onSelectConfig: _selectConfig,
      onToggleConfigEnabled: _toggleConfigEnabled,
      onDeleteConfig: _deleteConfig,
      onReorderConfig: _reorderConfig,
      onPresetNameChanged: _markChanged,
    );
  }

  /// 右侧详情面板
  Widget _buildDetailPanel(ThemeData theme) {
    final config = _getSelectedConfig();

    return Expanded(
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: config == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 64,
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.preset_selectConfigToEdit,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              )
            : ConfigDetailEditor(
                key: ValueKey(config.id),
                config: config,
                onChanged: _updateConfig,
              ),
      ),
    );
  }

  // ==================== 预设操作方法 ====================

  /// 选择 RandomPreset
  void _selectRandomPreset(String presetId) async {
    if (_hasUnsavedChanges) {
      final discard = await UnsavedChangesDialog.show(context);
      if (discard != true) return;
      setState(() => _hasUnsavedChanges = false);
    }
    _doSelectRandomPreset(presetId);
  }

  void _doSelectRandomPreset(String presetId) {
    ref.read(randomPresetNotifierProvider.notifier).selectPreset(presetId);
    ref.read(randomModeNotifierProvider.notifier).setMode(
          RandomGenerationMode.naiOfficial,
        );
    setState(() {
      _selectedConfigId = null;
      _editingConfigs = [];
      _hasUnsavedChanges = false;
    });
  }

  /// 显示新建预设对话框
  Future<void> _showNewPresetDialog() async {
    final presets = ref.read(randomPresetNotifierProvider).presets;
    final presetName = await PresetNameDialog.show(
      context,
      validator: (name) => PresetValidators.validateRandomPresetName(
        context,
        name,
        presets,
      ),
    );

    if (presetName == null || presetName.isEmpty) return;

    if (!mounted) return;
    await NewPresetDialog.show(
      context: context,
      onModeSelected: (mode) async {
        switch (mode) {
          case PresetCreationMode.blank:
            await _createBlankPreset(presetName);
            break;
          case PresetCreationMode.template:
            await _createTemplatePreset(presetName);
            break;
        }

        if (mounted) {
          AppToast.success(context, context.l10n.preset_newPresetCreated);
        }
      },
    );
  }

  Future<void> _createBlankPreset(String name) async {
    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    final newPreset = await notifier.createPreset(
      name: name,
      copyFromCurrent: false,
    );
    await notifier.selectPreset(newPreset.id);
  }

  Future<void> _createTemplatePreset(String name) async {
    final state = ref.read(randomPresetNotifierProvider);
    final defaultPreset = state.presets.firstWhere(
      (p) => p.isDefault,
      orElse: () => state.presets.first,
    );
    final newPreset = RandomPreset.copyFrom(defaultPreset, name: name);
    await ref.read(randomPresetNotifierProvider.notifier).addPreset(newPreset);
  }

  /// 显示重命名 RandomPreset 对话框
  Future<void> _showRenameRandomPresetDialog(RandomPreset preset) async {
    final presets = ref.read(randomPresetNotifierProvider).presets;
    final newName = await RenamePresetDialog.show(
      context,
      currentName: preset.name,
      validator: (name) => PresetValidators.validateRandomPresetName(
        context,
        name,
        presets,
        excludePresetId: preset.id,
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != preset.name) {
      await ref
          .read(randomPresetNotifierProvider.notifier)
          .renamePreset(preset.id, newName);
      if (mounted) {
        AppToast.success(context, context.l10n.preset_saveSuccess);
      }
    }
  }

  /// 显示删除 RandomPreset 确认对话框
  Future<void> _showDeleteRandomPresetDialog(RandomPreset preset) async {
    final confirmed = await DeletePresetDialog.show(
      context,
      presetName: preset.name,
    );

    if (confirmed == true && mounted) {
      await ref
          .read(randomPresetNotifierProvider.notifier)
          .deletePreset(preset.id);
      if (mounted) {
        AppToast.success(context, context.l10n.preset_deleted);
      }
    }
  }

  /// 显示编辑预设描述对话框
  Future<void> _showEditPresetDescriptionDialog(RandomPreset preset) async {
    final newDescription = await EditDescriptionDialog.show(
      context,
      currentDescription: preset.description,
    );

    if (newDescription != null) {
      await ref
          .read(randomPresetNotifierProvider.notifier)
          .updatePresetDescription(preset.id, newDescription);
      if (mounted) {
        AppToast.success(context, '描述已更新');
      }
    }
  }

  /// 显示重置预设确认对话框
  Future<void> _showResetPresetConfirmDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.preset_resetConfirmTitle),
        content: Text(context.l10n.preset_resetConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.common_confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref
          .read(randomPresetNotifierProvider.notifier)
          .resetCurrentPreset();
      await ref
          .read(tagLibraryNotifierProvider.notifier)
          .setAllBuiltinEnabled(true);

      if (context.mounted) {
        AppToast.success(context, context.l10n.preset_resetSuccess);
      }
    }
  }

  // ==================== 类别操作方法 ====================

  /// 显示新增类别对话框
  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final presetState = ref.read(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final existingKeys = preset?.categories.map((c) => c.key).toList() ?? [];

    final result = await AddCategoryDialog.show(
      context,
      existingKeys: existingKeys,
    );

    if (result == null) return;

    final newCategory = RandomCategory.create(
      name: result.name,
      key: result.key,
      emoji: result.emoji,
    ).copyWith(probability: result.probability);

    await ref
        .read(randomPresetNotifierProvider.notifier)
        .addCategory(newCategory);

    if (context.mounted) {
      AppToast.success(context, context.l10n.category_createSuccess);
    }
  }

  /// 显示类别设置对话框
  void _showCategorySettings(RandomCategory category) {
    final preset = ref.read(randomPresetNotifierProvider).selectedPreset;
    final customSlotOptions =
        preset?.algorithmConfig.characterCountConfig?.customSlotOptions ??
            defaultSlotOptions;

    CategorySettingsDialog.show(
      context: context,
      category: category,
      customSlotOptions: customSlotOptions,
      onSave: (updatedCategory) async {
        final notifier = ref.read(randomPresetNotifierProvider.notifier);
        final currentPreset =
            ref.read(randomPresetNotifierProvider).selectedPreset;

        final existingCategory = currentPreset?.categories.any(
          (c) => c.id == updatedCategory.id,
        );

        if (existingCategory == true) {
          await notifier.updateCategory(updatedCategory);
        } else {
          await notifier.addCategory(updatedCategory);
        }

        if (mounted) {
          AppToast.success(context, context.l10n.common_saved);
        }
      },
    );
  }

  /// 切换类别启用/禁用状态
  Future<void> _toggleCategoryEnabled(
    RandomCategory category,
    bool enabled,
  ) async {
    await ref
        .read(randomPresetNotifierProvider.notifier)
        .upsertCategoryByKey(category.copyWith(enabled: enabled));
  }

  /// 移除类别
  Future<void> _removeCategory(RandomCategory category) async {
    final l10n = context.l10n;
    final categoryName = TagSubCategoryHelper.getDisplayName(
      TagSubCategory.values.firstWhere(
        (e) => e.name == category.key,
        orElse: () => TagSubCategory.hairColor,
      ),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.common_confirmDelete),
        content: Text(l10n.promptConfig_confirmRemoveCategory(categoryName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.common_delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(randomPresetNotifierProvider.notifier)
          .removeCategoryByKey(category.key);
    }
  }

  /// 同步指定类别的扩展标签
  Future<void> _syncCategory(TagSubCategory category) async {
    final success = await ref
        .read(tagGroupSyncNotifierProvider.notifier)
        .syncCategoryTagGroups(category);
    if (mounted) {
      if (success) {
        AppToast.success(context, context.l10n.tagLibrary_syncSuccess);
      } else {
        AppToast.error(context, context.l10n.tagLibrary_syncFailed);
      }
    }
  }

  /// 全选所有 tag groups
  Future<void> _selectAllTagGroups() async {
    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    final presetState = ref.read(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    if (preset == null) return;

    final existingGroupTitles =
        preset.tagGroupMappings.map((m) => m.groupTitle).toSet();

    final existingGroupInfoMap = <String,
        ({
      String displayName,
      TagSubCategory category,
      bool includeChildren
    })>{};
    for (final mapping in preset.tagGroupMappings) {
      existingGroupInfoMap[mapping.groupTitle] = (
        displayName: mapping.displayName,
        category: mapping.targetCategory,
        includeChildren: mapping.includeChildren,
      );
    }

    await notifier.updateSelectedGroupsWithTree(
      existingGroupTitles,
      existingGroupInfoMap,
    );
    await ref
        .read(tagLibraryNotifierProvider.notifier)
        .setAllBuiltinEnabled(true);
  }

  /// 取消选择所有 tag groups
  Future<void> _deselectAllTagGroups() async {
    await ref
        .read(randomPresetNotifierProvider.notifier)
        .updateSelectedGroupsWithTree({}, {});
    await ref
        .read(tagLibraryNotifierProvider.notifier)
        .setAllBuiltinEnabled(false);
  }

  /// 切换全部展开/收起状态
  void _toggleAllExpand(List<RandomCategory> presetCategories) {
    final categorySet = presetCategories.map((c) {
      return TagSubCategory.values.firstWhere(
        (e) => e.name == c.key,
        orElse: () => TagSubCategory.hairColor,
      );
    }).toSet();

    setState(() {
      if (_expandedCategories.length == categorySet.length) {
        _expandedCategories.clear();
      } else {
        _expandedCategories.addAll(categorySet);
      }
    });
  }

  // ==================== 配置组操作方法 ====================

  pc.RandomPromptPreset? _getSelectedPreset(PromptConfigState state) {
    if (_selectedPresetId == null) return null;
    try {
      return state.presets.firstWhere((p) => p.id == _selectedPresetId);
    } catch (_) {
      return null;
    }
  }

  pc.PromptConfig? _getSelectedConfig() {
    if (_selectedConfigId == null) return null;
    try {
      return _editingConfigs.firstWhere((c) => c.id == _selectedConfigId);
    } catch (_) {
      return null;
    }
  }

  void _selectPreset(String presetId) async {
    if (_hasUnsavedChanges) {
      final discard = await UnsavedChangesDialog.show(context);
      if (discard != true) return;
      setState(() => _hasUnsavedChanges = false);
    }
    _doSelectPreset(presetId);
  }

  void _doSelectPreset(String presetId) {
    final state = ref.read(promptConfigNotifierProvider);
    final preset = state.presets.cast<pc.RandomPromptPreset?>().firstWhere(
          (p) => p?.id == presetId,
          orElse: () => null,
        );

    if (preset == null) return;

    ref.read(randomModeNotifierProvider.notifier).setMode(
          RandomGenerationMode.custom,
        );

    setState(() {
      _selectedPresetId = presetId;
      _presetNameController.text = preset.name;
      _editingConfigs = List.from(preset.configs);
      _selectedConfigId =
          _editingConfigs.isNotEmpty ? _editingConfigs.first.id : null;
      _hasUnsavedChanges = false;
    });
  }

  void _selectConfig(String configId) {
    setState(() {
      _selectedConfigId = configId;
    });
  }

  void _markChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  void _addConfig() {
    final newConfig =
        pc.PromptConfig.create(name: context.l10n.presetEdit_newConfigGroup);
    setState(() {
      _editingConfigs.add(newConfig);
      _selectedConfigId = newConfig.id;
      _hasUnsavedChanges = true;
    });
  }

  void _deleteConfig(int index) {
    setState(() {
      final removed = _editingConfigs.removeAt(index);
      if (_selectedConfigId == removed.id) {
        _selectedConfigId = null;
      }
      _hasUnsavedChanges = true;
    });
  }

  void _toggleConfigEnabled(int index) {
    setState(() {
      _editingConfigs[index] = _editingConfigs[index].copyWith(
        enabled: !_editingConfigs[index].enabled,
      );
      _hasUnsavedChanges = true;
    });
  }

  void _reorderConfig(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _editingConfigs.removeAt(oldIndex);
      _editingConfigs.insert(newIndex, item);
      _hasUnsavedChanges = true;
    });
  }

  void _updateConfig(pc.PromptConfig updated) {
    final index = _editingConfigs.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      setState(() {
        _editingConfigs[index] = updated;
        _hasUnsavedChanges = true;
      });
    }
  }

  void _savePreset() async {
    if (_selectedPresetId == null) return;

    final state = ref.read(promptConfigNotifierProvider);
    final preset =
        state.presets.where((p) => p.id == _selectedPresetId).firstOrNull;
    if (preset == null) return;

    final newName = _presetNameController.text.trim();
    final error = PresetValidators.validatePresetName(
      context,
      newName,
      state.presets,
      excludePresetId: preset.id,
    );
    if (error != null) {
      if (mounted) {
        AppToast.error(context, error);
      }
      return;
    }

    final updated = preset.copyWith(
      name: newName,
      configs: _editingConfigs,
      updatedAt: DateTime.now(),
    );

    await ref.read(promptConfigNotifierProvider.notifier).updatePreset(updated);
    setState(() => _hasUnsavedChanges = false);
    if (mounted) {
      AppToast.success(context, context.l10n.preset_saveSuccess);
    }
  }
}
