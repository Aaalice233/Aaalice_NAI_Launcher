import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/character_count_config.dart'
    show defaultSlotOptions;
import '../../../data/models/prompt/prompt_config.dart' as pc;
import '../../../data/models/prompt/random_prompt_result.dart'
    show RandomGenerationMode;
import '../../../data/models/prompt/sync_config.dart' show SyncProgress;
import '../../../data/models/prompt/tag_category.dart';
import '../../../data/models/prompt/tag_group.dart';
import '../../../data/models/prompt/weighted_tag.dart';
import '../../../data/models/prompt/tag_library.dart';
import '../../../data/models/prompt/category_filter_config.dart';
import '../../providers/prompt_config_provider.dart';
import '../../providers/random_preset_provider.dart';
import '../../widgets/prompt/category_settings_dialog.dart';
import '../../../data/models/prompt/random_category.dart';
import '../../../data/models/prompt/random_preset.dart';
import '../../providers/random_mode_provider.dart';
import '../../providers/tag_group_sync_provider.dart';
import '../../providers/tag_library_provider.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/prompt/new_preset_dialog.dart';
import '../../../core/services/tag_counting_service.dart';
import 'widgets/add_category_dialog.dart';
import 'widgets/category_detail_dialog.dart';
import 'widgets/config_detail_editor.dart';
import 'widgets/expandable_category_tile.dart';
import 'widgets/global_post_count_toolbar.dart';

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
          _buildPresetPanel(state, theme),
          // 垂直分割线
          VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
          // NAI 模式：显示算法说明；自定义模式：显示配置组列表和详情
          if (currentMode == RandomGenerationMode.naiOfficial)
            Expanded(child: _buildNaiDetailPanel(theme))
          else ...[
            // 中间配置组列表
            _buildConfigPanel(state, theme),
            // 垂直分割线
            VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
            // 右侧详情编辑
            _buildDetailPanel(state, theme),
          ],
        ],
      ),
    );
  }

  /// NAI 模式详情面板 - 直接展示完整内容
  Widget _buildNaiDetailPanel(ThemeData theme) {
    final libraryState = ref.watch(tagLibraryNotifierProvider);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // 信息卡片（包含操作按钮）
          _buildNaiInfoCard(theme, libraryState),

          // 类别列表
          Expanded(
            child: libraryState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildNaiCategoryList(theme, libraryState),
          ),
        ],
      ),
    );
  }

  /// NAI 模式头部区域
  Widget _buildNaiInfoCard(ThemeData theme, TagLibraryState state) {
    final library = state.library;
    // 监听 TagGroup 同步状态和预设状态
    final syncState = ref.watch(tagGroupSyncNotifierProvider);
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final tagGroupMappings = preset?.tagGroupMappings ?? [];
    final tagCountingService = ref.watch(tagCountingServiceProvider);

    // 获取预设中的类别列表（动态列表）
    final categories = preset?.categories ?? [];

    // 计算已启用的 tag group 数量（使用 TagCountingService）
    final builtinGroupCount =
        tagCountingService.calculateEnabledBuiltinCategoryCount(
      categories,
      state.categoryFilterConfig.isBuiltinEnabled,
    );
    final syncGroupCount = tagCountingService.calculateEnabledSyncGroupCount(
      tagGroupMappings,
      categories,
    );
    final enabledMappingCount = builtinGroupCount + syncGroupCount;

    // 计算总标签数：内置词库 + TagGroup（使用 helper 和 service）
    final builtinTagCount = _calculateBuiltinLibraryTagCount(
      library,
      categories,
      state.categoryFilterConfig,
    );
    final tagCount = builtinTagCount +
        tagCountingService.calculateTotalTagCount(
          tagGroupMappings,
          categories,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 预设名称和编辑按钮
          if (preset != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    preset.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: preset.isDefault
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                // 编辑按钮（仅非默认预设）
                if (!preset.isDefault)
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    onPressed: () => _showRenameRandomPresetDialog(preset),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: context.l10n.preset_rename,
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // 预设描述（如果有）
          if (preset != null && preset.description != null && preset.description!.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    preset.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                // 编辑描述按钮（仅非默认预设）
                if (!preset.isDefault)
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    onPressed: () => _showEditPresetDescriptionDialog(preset),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: '编辑描述',
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // 添加描述按钮（仅非默认预设且无描述时）
          if (preset != null && !preset.isDefault && (preset.description == null || preset.description!.isEmpty))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextButton.icon(
                onPressed: () => _showEditPresetDescriptionDialog(preset),
                icon: Icon(Icons.add, size: 16),
                label: Text('添加描述'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ),
          // 统计信息和操作按钮
          GlobalPostCountToolbar(
            tagCount: tagCount,
            enabledMappingCount: enabledMappingCount,
            totalMappingCount: categories.length + tagGroupMappings.length,
            onToggleSelectAll: () {
              // 如果全选则执行全不选，否则执行全选
              final allSelected = builtinGroupCount == categories.length &&
                  tagGroupMappings.every((m) => m.enabled);
              if (allSelected) {
                _deselectAllTagGroups();
              } else {
                _selectAllTagGroups();
              }
            },
            allExpanded: _expandedCategories.length == categories.length,
            onToggleExpand: _toggleAllExpand,
            onResetPreset: () => _showResetPresetConfirmDialog(context),
            onAddCategory: () => _showAddCategoryDialog(context),
            showResetPreset: preset?.isDefault ?? false,
          ),

          // 同步进度（TagLibrary 或 TagGroup 同步）
          if (state.isSyncing && state.syncProgress != null) ...[
            const SizedBox(height: 16),
            _buildNaiSyncProgress(theme, state.syncProgress!),
          ],
          if (syncState.isSyncing && syncState.syncProgress != null) ...[
            const SizedBox(height: 16),
            _buildTagGroupSyncProgress(theme, syncState.syncProgress!),
          ],
        ],
      ),
    );
  }

  /// 显示预设名称输入对话框
  Future<String?> _showPresetNameInputDialog() async {
    final controller = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.presetEdit_presetName),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.presetEdit_presetName,
              hintText: context.l10n.presetEdit_enterPresetName,
              border: const OutlineInputBorder(),
              errorText: errorText,
            ),
            onChanged: (value) {
              final error = _validatePresetName(value);
              setState(() => errorText = error);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: errorText == null && controller.text.trim().isNotEmpty
                  ? () => Navigator.of(context).pop(controller.text.trim())
                  : null,
              child: Text(context.l10n.common_confirm),
            ),
          ],
        ),
      ),
    );
  }

  /// 创建空白预设
  Future<void> _createBlankPreset(String name) async {
    final notifier = ref.read(randomPresetNotifierProvider.notifier);

    final newPreset = await notifier.createPreset(
      name: name,
      copyFromCurrent: false,
    );

    // 选中新创建的预设
    await notifier.selectPreset(newPreset.id);
  }

  /// 创建模板预设（基于默认预设）
  Future<void> _createTemplatePreset(String name) async {
    final state = ref.read(randomPresetNotifierProvider);
    final defaultPreset = state.presets.firstWhere(
      (p) => p.isDefault,
      orElse: () => state.presets.first,
    );

    // 使用 RandomPreset.copyFrom() 创建新预设
    final newPreset = RandomPreset.copyFrom(
      defaultPreset,
      name: name,
    );

    // 使用 provider 的 addPreset 方法添加到状态并保存
    await ref.read(randomPresetNotifierProvider.notifier).addPreset(newPreset);
  }

  /// 显示新建预设对话框
  Future<void> _showNewPresetDialog() async {
    // 首先显示名称输入对话框
    final presetName = await _showPresetNameInputDialog();

    // 如果用户取消输入，直接返回
    if (presetName == null || presetName.isEmpty) {
      return;
    }

    // 显示创建模式选择对话框
    await NewPresetDialog.show(
      context: context,
      onModeSelected: (mode) async {
        switch (mode) {
          case PresetCreationMode.blank:
            // 创建完全空白的预设
            await _createBlankPreset(presetName);
            break;

          case PresetCreationMode.template:
            // 基于默认预设创建
            await _createTemplatePreset(presetName);
            break;
        }

        if (mounted) {
          AppToast.success(context, context.l10n.preset_newPresetCreated);
        }
      },
    );
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
      // 重置预设（包括类别参数、词组参数、第三方词组映射）
      await ref
          .read(randomPresetNotifierProvider.notifier)
          .resetCurrentPreset();

      // 同时重置内置词组的启用状态为全部启用
      await ref
          .read(tagLibraryNotifierProvider.notifier)
          .setAllBuiltinEnabled(true);

      if (context.mounted) {
        AppToast.success(context, context.l10n.preset_resetSuccess);
      }
    }
  }

  /// 删除 RandomPreset
  Future<void> _deletePreset(RandomPreset preset) async {
    await ref.read(randomPresetNotifierProvider.notifier).deletePreset(preset.id);
    if (mounted) {
      AppToast.success(context, context.l10n.preset_deleted);
    }
  }

  /// 重命名 RandomPreset
  Future<void> _renamePreset(RandomPreset preset, String newName) async {
    await ref.read(randomPresetNotifierProvider.notifier).renamePreset(preset.id, newName);
    if (mounted) {
      AppToast.success(context, context.l10n.preset_saveSuccess);
    }
  }

  /// 显示删除 RandomPreset 确认对话框
  Future<void> _showDeleteRandomPresetDialog(RandomPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.preset_deletePreset),
        content: Text(context.l10n.preset_deletePresetConfirm(preset.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deletePreset(preset);
    }
  }

  /// 显示重命名 RandomPreset 对话框
  Future<void> _showRenameRandomPresetDialog(RandomPreset preset) async {
    final controller = TextEditingController(text: preset.name);
    String? errorText;

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.preset_rename),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.preset_presetName,
              hintText: context.l10n.presetEdit_enterPresetName,
              border: const OutlineInputBorder(),
              errorText: errorText,
            ),
            onChanged: (value) {
              final error = _validateRandomPresetName(value, excludePresetId: preset.id);
              setState(() => errorText = error);
            },
            onSubmitted: (value) {
              final error = _validateRandomPresetName(value, excludePresetId: preset.id);
              if (error == null) {
                Navigator.pop(ctx, value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () {
                final error = _validateRandomPresetName(controller.text, excludePresetId: preset.id);
                if (error == null) {
                  Navigator.pop(ctx, controller.text.trim());
                } else {
                  setState(() => errorText = error);
                }
              },
              child: Text(context.l10n.common_confirm),
            ),
          ],
        ),
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != preset.name) {
      await _renamePreset(preset, newName);
    }
  }

  /// 显示编辑预设描述对话框
  Future<void> _showEditPresetDescriptionDialog(RandomPreset preset) async {
    final controller = TextEditingController(text: preset.description ?? '');

    final newDescription = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑描述'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '预设描述',
            hintText: '输入此预设的用途或特点...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          textInputAction: TextInputAction.newline,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(context.l10n.common_confirm),
          ),
        ],
      ),
    );

    if (newDescription != null) {
      // Update preset description
      final notifier = ref.read(randomPresetNotifierProvider.notifier);
      await notifier.updatePresetDescription(preset.id, newDescription);

      if (mounted) {
        AppToast.success(context, '描述已更新');
      }
    }
  }

  /// 显示新增类别对话框
  Future<void> _showAddCategoryDialog(BuildContext context) async {
    // 获取现有类别的 key 列表，用于唯一性校验
    final presetState = ref.read(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final existingKeys = preset?.categories.map((c) => c.key).toList() ?? [];

    final result = await AddCategoryDialog.show(
      context,
      existingKeys: existingKeys,
    );

    if (result == null) return;

    // 创建新类别
    final newCategory = RandomCategory.create(
      name: result.name,
      key: result.key,
      emoji: result.emoji,
    ).copyWith(probability: result.probability);

    // 添加到预设
    await ref
        .read(randomPresetNotifierProvider.notifier)
        .addCategory(newCategory);

    if (context.mounted) {
      AppToast.success(context, context.l10n.category_createSuccess);
    }
  }

  Widget _buildNaiSyncProgress(ThemeData theme, SyncProgress progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                progress.localizedMessage(context),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        if (progress.totalEstimate > 0) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ],
    );
  }

  /// 外部 TagGroup 同步进度显示
  Widget _buildTagGroupSyncProgress(
    ThemeData theme,
    TagGroupSyncProgress progress,
  ) {
    final message = progress.currentGroup != null
        ? context.l10n.tagGroup_syncFetching(
            progress.currentGroup!,
            progress.completedGroups.toString(),
            progress.totalGroups.toString(),
          )
        : progress.localizedMessage(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        if (progress.totalGroups > 0) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ],
    );
  }

  /// NAI 类别列表
  Widget _buildNaiCategoryList(ThemeData theme, TagLibraryState state) {
    final library = state.library;
    if (library == null) {
      return Center(child: Text(context.l10n.naiMode_noLibrary));
    }

    final filterConfig = state.categoryFilterConfig;

    // 获取当前预设的类别列表（作为动态渲染源）
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final presetCategories = preset?.categories ?? [];

    // 如果类别列表为空，显示空状态
    if (presetCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.naiMode_noCategories,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    // 使用预设中的类别列表进行渲染
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: presetCategories.length,
      itemBuilder: (context, index) {
        final randomCategory = presetCategories[index];

        // 从 key 获取 TagSubCategory 枚举
        final category = TagSubCategory.values.firstWhere(
          (e) => e.name == randomCategory.key,
          orElse: () => TagSubCategory.hairColor,
        );

        final probability = (randomCategory.probability * 100).round();
        final includeSupplement = filterConfig.isEnabled(category);
        final tags = library.getFilteredCategory(
          category,
          includeDanbooruSupplement: includeSupplement,
        );

        return ExpandableCategoryTile(
          category: category,
          probability: probability,
          tags: tags,
          onSyncCategory: () => _syncCategory(category),
          onShowDetail: () => _showCategoryDetailDialog(category, tags),
          isExpanded: _expandedCategories.contains(category),
          onExpandChanged: (expanded) {
            setState(() {
              if (expanded) {
                _expandedCategories.add(category);
              } else {
                _expandedCategories.remove(category);
              }
            });
          },
          onSettings: () => _showCategorySettings(randomCategory),
          isEnabled: randomCategory.enabled,
          onEnabledChanged: (enabled) =>
              _toggleCategoryEnabled(randomCategory, enabled),
          onRemove: () => _removeCategory(randomCategory),
        );
      },
    );
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

        // 检查类别是否已存在于预设中
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
    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    // 使用 upsertCategoryByKey 确保即使类别不存在也能正确处理
    await notifier.upsertCategoryByKey(category.copyWith(enabled: enabled));
  }

  /// 移除类别（从列表中彻底删除）
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
      // 真正删除类别
      await ref
          .read(randomPresetNotifierProvider.notifier)
          .removeCategoryByKey(category.key);
    }
  }

  /// 显示类别详情对话框
  void _showCategoryDetailDialog(
    TagSubCategory category,
    List<WeightedTag> tags,
  ) {
    CategoryDetailDialog.show(
      context: context,
      category: category,
      tags: tags,
    );
  }

  /// 同步指定类别的扩展标签
  Future<void> _syncCategory(TagSubCategory category) async {
    final tagGroupSyncNotifier =
        ref.read(tagGroupSyncNotifierProvider.notifier);
    final success = await tagGroupSyncNotifier.syncCategoryTagGroups(category);
    if (mounted) {
      if (success) {
        AppToast.success(context, context.l10n.tagLibrary_syncSuccess);
      } else {
        AppToast.error(context, context.l10n.tagLibrary_syncFailed);
      }
    }
  }

  /// 全选所有 tag groups（只启用现有的分组，不添加新分组）
  Future<void> _selectAllTagGroups() async {
    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    final presetState = ref.read(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    if (preset == null) return;

    // 只启用现有的所有分组，不添加新分组
    final existingGroupTitles =
        preset.tagGroupMappings.map((m) => m.groupTitle).toSet();

    // 构建现有分组的 info map（用于 updateSelectedGroupsWithTree）
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

    // 全选 = 选中所有现有分组
    await notifier.updateSelectedGroupsWithTree(
      existingGroupTitles,
      existingGroupInfoMap,
    );

    // 同时启用所有内置词库（使用批量操作，只写一次磁盘）
    await ref
        .read(tagLibraryNotifierProvider.notifier)
        .setAllBuiltinEnabled(true);
  }

  /// 取消选择所有 tag groups（禁用所有分组，但不删除）
  Future<void> _deselectAllTagGroups() async {
    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    // 调用批量更新方法，传入空集合表示全部取消选择（只执行一次磁盘 IO）
    await notifier.updateSelectedGroupsWithTree({}, {});

    // 同时禁用所有内置词库（使用批量操作，只写一次磁盘）
    await ref
        .read(tagLibraryNotifierProvider.notifier)
        .setAllBuiltinEnabled(false);
  }

  /// 切换全部展开/收起状态
  void _toggleAllExpand() {
    final presetState = ref.read(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final presetCategories = preset?.categories ?? [];

    // 获取所有类别对应的 TagSubCategory 集合
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

  // NAI 模式辅助方法

  /// NAI 官方类别及其选中概率配置
  /// 参考: docs/NAI随机提示词功能分析.md
  Map<TagSubCategory, int> _getNaiCategoryConfig() {
    return {
      // 角色特征类（概率约50%）
      TagSubCategory.hairColor: 50,
      TagSubCategory.eyeColor: 50,
      TagSubCategory.hairStyle: 50,
      TagSubCategory.expression: 50,
      TagSubCategory.pose: 50,
      TagSubCategory.clothing: 50,
      TagSubCategory.accessory: 50,
      TagSubCategory.bodyFeature: 30,
      // 场景/画风类
      TagSubCategory.background: 90,
      TagSubCategory.scene: 50,
      TagSubCategory.style: 30,
      // 人数（由算法决定，显示供参考）
      TagSubCategory.characterCount: 100,
    };
  }

  // ==================== 左侧预设面板 ====================
  Widget _buildPresetPanel(PromptConfigState state, ThemeData theme) {
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
            child: Row(
              children: [
                Icon(
                  Icons.shuffle,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.config_title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),

          // 预设列表（所有 RandomPresets）
          Expanded(
            child: presetState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: [
                      // 预设列表（默认预设 + 自定义预设）
                      ...presets.map(
                        (preset) => _buildRandomPresetItem(
                          preset,
                          presetState,
                          theme,
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

  /// NAI 官方模式预设项（固定）
  Widget _buildNaiPresetItem(bool isSelected, ThemeData theme) {
    final libraryState = ref.watch(tagLibraryNotifierProvider);
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final tagGroupMappings = preset?.tagGroupMappings ?? [];
    final library = libraryState.library;
    final categories = preset?.categories ?? [];
    final tagCountingService = ref.watch(tagCountingServiceProvider);

    // 计算总标签数：内置词库 + TagGroup（使用 helper 和 service）
    final builtinTagCount = _calculateNaiBuiltinTagCount(
      library,
      categories,
      libraryState.categoryFilterConfig,
    );
    final tagCount = builtinTagCount +
        tagCountingService.calculateTotalTagCount(
          tagGroupMappings,
          categories,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _selectNaiMode(),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 激活指示器
                if (isSelected)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(width: 16),
                // 图标
                Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                // 预设信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.naiMode_title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : null,
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        context.l10n.naiMode_totalTags(tagCount.toString()),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// RandomPreset 预设项（支持默认预设和自定义预设）
  Widget _buildRandomPresetItem(
    RandomPreset preset,
    RandomPresetState presetState,
    ThemeData theme,
  ) {
    final isSelected = preset.id == presetState.selectedPresetId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _selectRandomPreset(preset.id),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 激活指示器
                if (isSelected)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(width: 16),
                // 图标
                Icon(
                  preset.isDefault ? Icons.auto_awesome : Icons.tune_outlined,
                  size: 18,
                  color: preset.isDefault
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                // 预设信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : null,
                          color: preset.isDefault
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        preset.isDefault
                            ? context.l10n.naiMode_totalTags(
                                preset.enabledCategoryCount.toString(),
                              )
                            : context.l10n.preset_configGroupCount(
                                preset.categoryCount.toString(),
                              ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                // 操作按钮（仅非默认预设）
                if (!preset.isDefault) ...[
                  // 重命名按钮
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    onPressed: () => _showRenameRandomPresetDialog(preset),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: context.l10n.preset_rename,
                  ),
                  // 删除按钮
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: theme.colorScheme.error.withOpacity(0.7),
                    ),
                    onPressed: () => _showDeleteRandomPresetDialog(preset),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: context.l10n.common_delete,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 选择 RandomPreset
  void _selectRandomPreset(String presetId) async {
    if (_hasUnsavedChanges) {
      _showUnsavedDialog(() => _doSelectRandomPreset(presetId));
      return;
    }
    _doSelectRandomPreset(presetId);
  }

  void _doSelectRandomPreset(String presetId) {
    // 使用 provider 作为 RandomPreset 选择的唯一数据源
    ref.read(randomPresetNotifierProvider.notifier).selectPreset(presetId);
    ref.read(randomModeNotifierProvider.notifier).setMode(
          RandomGenerationMode.naiOfficial,
        );
    // 清除自定义模式相关的本地状态
    setState(() {
      _selectedConfigId = null;
      _editingConfigs = [];
      _hasUnsavedChanges = false;
    });
  }

  /// 选择 NAI 官方模式
  void _selectNaiMode() {
    if (_hasUnsavedChanges) {
      _showUnsavedDialog(() => _doSelectNaiMode());
      return;
    }
    _doSelectNaiMode();
  }

  void _doSelectNaiMode() {
    ref.read(randomModeNotifierProvider.notifier).setMode(
          RandomGenerationMode.naiOfficial,
        );
    // 清除自定义模式相关的本地状态
    setState(() {
      _selectedConfigId = null;
      _editingConfigs = [];
      _hasUnsavedChanges = false;
    });
  }

  Widget _buildPresetItem(
    pc.RandomPromptPreset preset,
    PromptConfigState state,
    ThemeData theme,
  ) {
    final isSelected = preset.id == _selectedPresetId;
    final isActive = preset.id == state.selectedPresetId;
    final presetIndex = state.presets.indexWhere((p) => p.id == preset.id);
    final isFirst = presetIndex == 0;
    final isLast = presetIndex == state.presets.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          onSecondaryTapDown: (details) => _showPresetContextMenu(
            details.globalPosition,
            preset,
            isActive,
            isFirst,
            isLast,
          ),
          onLongPressStart: (details) => _showPresetContextMenu(
            details.globalPosition,
            preset,
            isActive,
            isFirst,
            isLast,
          ),
          child: InkWell(
            onTap: () => _selectPreset(preset.id),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // 激活指示器
                  if (isActive)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const SizedBox(width: 16),
                  // 预设名称
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.w600 : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          context.l10n.preset_configGroupCount(
                            preset.configs.length.toString(),
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 显示预设上下文菜单
  Future<void> _showPresetContextMenu(
    Offset position,
    pc.RandomPromptPreset preset,
    bool isActive,
    bool isFirst,
    bool isLast,
  ) async {
    final theme = Theme.of(context);
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'activate',
          enabled: !isActive,
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 18),
              const SizedBox(width: 12),
              Text(context.l10n.preset_setAsCurrent),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 18),
              const SizedBox(width: 12),
              Text(context.l10n.preset_rename),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'moveUp',
          enabled: !isFirst,
          child: Row(
            children: [
              const Icon(Icons.arrow_upward, size: 18),
              const SizedBox(width: 12),
              Text(context.l10n.preset_moveUp),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'moveDown',
          enabled: !isLast,
          child: Row(
            children: [
              const Icon(Icons.arrow_downward, size: 18),
              const SizedBox(width: 12),
              Text(context.l10n.preset_moveDown),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              const Icon(Icons.copy_outlined, size: 18),
              const SizedBox(width: 12),
              Text(context.l10n.preset_duplicate),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              const Icon(Icons.file_download_outlined, size: 18),
              const SizedBox(width: 12),
              Text(context.l10n.preset_export),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'reset',
          child: Row(
            children: [
              const Icon(Icons.restart_alt, size: 18),
              const SizedBox(width: 12),
              Text(context.l10n.config_restoreDefaults),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 18,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 12),
              Text(
                context.l10n.preset_delete,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );

    if (action != null) {
      _handlePresetItemAction(preset, action);
    }
  }

  // ==================== 中间配置组面板 ====================
  Widget _buildConfigPanel(PromptConfigState state, ThemeData theme) {
    final preset = _getSelectedPreset(state);

    return Container(
      width: 280,
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          Container(
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
                  context.l10n.config_configGroups,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (preset != null)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    tooltip: context.l10n.preset_addConfigGroup,
                    onPressed: _addConfig,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          // 预设名称编辑
          if (preset != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _presetNameController,
                decoration: InputDecoration(
                  labelText: context.l10n.preset_presetName,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: theme.textTheme.bodyMedium,
                onChanged: (_) => _markChanged(),
              ),
            ),
          // 配置组列表
          Expanded(
            child: preset == null
                ? Center(
                    child: Text(
                      context.l10n.preset_selectPreset,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  )
                : _editingConfigs.isEmpty
                    ? _buildEmptyConfigs(theme)
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        buildDefaultDragHandles: false,
                        itemCount: _editingConfigs.length,
                        onReorder: _reorderConfig,
                        itemBuilder: (context, index) {
                          final config = _editingConfigs[index];
                          return _buildConfigItem(config, index, theme);
                        },
                      ),
          ),
          // 保存按钮
          if (_hasUnsavedChanges && preset != null) ...[
            Divider(height: 1, color: theme.dividerColor),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _savePreset,
                icon: const Icon(Icons.save, size: 18),
                label: Text(context.l10n.config_saveChanges),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyConfigs(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_add, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            context.l10n.preset_noConfigGroups,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _addConfig,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.preset_addConfigGroup),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigItem(pc.PromptConfig config, int index, ThemeData theme) {
    final isSelected = config.id == _selectedConfigId;

    return Padding(
      key: ValueKey(config.id),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.5)
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _selectConfig(config.id),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 拖拽手柄
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_indicator,
                    size: 20,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(width: 8),
                // 启用开关
                SizedBox(
                  width: 36,
                  height: 20,
                  child: Switch(
                    value: config.enabled,
                    onChanged: (_) => _toggleConfigEnabled(index),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getConfigSummary(config),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                // 删除按钮
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.error.withOpacity(0.7),
                  ),
                  onPressed: () => _deleteConfig(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: context.l10n.common_delete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 右侧详情面板 ====================
  Widget _buildDetailPanel(PromptConfigState state, ThemeData theme) {
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
                onChanged: (updated) => _updateConfig(updated),
              ),
      ),
    );
  }

  // ==================== 辅助方法 ====================
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

  void _selectPreset(String presetId) {
    if (_hasUnsavedChanges) {
      _showUnsavedDialog(() => _doSelectPreset(presetId));
      return;
    }
    _doSelectPreset(presetId);
  }

  void _doSelectPreset(String presetId) {
    final state = ref.read(promptConfigNotifierProvider);
    final preset = state.presets.cast<pc.RandomPromptPreset?>().firstWhere(
          (p) => p?.id == presetId,
          orElse: () => null,
        );

    // 如果找不到预设，不执行任何操作
    if (preset == null) return;

    // 切换到自定义模式
    ref.read(randomModeNotifierProvider.notifier).setMode(
          RandomGenerationMode.custom,
        );

    setState(() {
      _selectedPresetId = presetId;
      _presetNameController.text = preset.name;
      _editingConfigs = List.from(preset.configs);
      // 默认选中第一个配置组
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

  // 新建预设功能暂时禁用 - 预设管理功能待完善
  // TODO(feature): 自定义预设创建功能 - 需要完成预设编辑器和验证逻辑
  // void _createNewPreset() {
  //   if (_hasUnsavedChanges) {
  //     _showUnsavedDialog(_doCreateNewPreset);
  //     return;
  //   }
  //   _doCreateNewPreset();
  // }

  // void _doCreateNewPreset() async {
  //   final presetName = context.l10n.config_newPreset;
  //   final successMessage = context.l10n.preset_newPresetCreated;
  //   final newPreset = pc.RandomPromptPreset.create(name: presetName);
  //   await ref.read(promptConfigNotifierProvider.notifier).addPreset(newPreset);
  //   _doSelectPreset(newPreset.id);
  //   if (mounted) {
  //     AppToast.success(context, successMessage);
  //   }
  // }

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

    final successMessage = context.l10n.preset_saveSuccess;
    final state = ref.read(promptConfigNotifierProvider);
    final preset =
        state.presets.where((p) => p.id == _selectedPresetId).firstOrNull;
    if (preset == null) return;

    final newName = _presetNameController.text.trim();

    // 验证预设名称
    final error = _validatePresetName(newName, excludePresetId: preset.id);
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
      AppToast.success(context, successMessage);
    }
  }

  void _handlePresetItemAction(pc.RandomPromptPreset preset, String action) {
    switch (action) {
      case 'activate':
        ref.read(promptConfigNotifierProvider.notifier).selectPreset(preset.id);
        AppToast.success(context, context.l10n.preset_setAsCurrentSuccess);
        break;
      case 'rename':
        _showRenamePresetDialog(preset);
        break;
      case 'moveUp':
        ref
            .read(promptConfigNotifierProvider.notifier)
            .movePreset(preset.id, -1);
        break;
      case 'moveDown':
        ref
            .read(promptConfigNotifierProvider.notifier)
            .movePreset(preset.id, 1);
        break;
      case 'duplicate':
        ref
            .read(promptConfigNotifierProvider.notifier)
            .duplicatePreset(preset.id);
        AppToast.success(context, context.l10n.preset_duplicated);
        break;
      case 'export':
        final json = ref
            .read(promptConfigNotifierProvider.notifier)
            .exportPreset(preset.id);
        Clipboard.setData(ClipboardData(text: json));
        AppToast.success(context, context.l10n.preset_copiedToClipboard);
        break;
      case 'reset':
        _showResetPresetDialog(preset);
        break;
      case 'delete':
        _showDeletePresetDialog(preset);
        break;
    }
  }

  /// 验证预设名称
  /// 返回验证错误信息，如果验证通过则返回 null
  String? _validatePresetName(String name, {String? excludePresetId}) {
    if (name.trim().isEmpty) {
      return context.l10n.preset_presetName;
    }

    final state = ref.read(promptConfigNotifierProvider);
    final isDuplicate = state.presets.any((p) =>
        p.name.trim().toLowerCase() == name.trim().toLowerCase() &&
        p.id != excludePresetId,
      );

    if (isDuplicate) {
      return '预设名称已存在';
    }

    return null;
  }

  /// 验证 RandomPreset 预设名称
  /// 返回验证错误信息，如果验证通过则返回 null
  String? _validateRandomPresetName(String name, {String? excludePresetId}) {
    if (name.trim().isEmpty) {
      return context.l10n.preset_presetName;
    }

    final state = ref.read(randomPresetNotifierProvider);
    final isDuplicate = state.presets.any((p) =>
        p.name.trim().toLowerCase() == name.trim().toLowerCase() &&
        p.id != excludePresetId,
      );

    if (isDuplicate) {
      return '预设名称已存在';
    }

    return null;
  }

  /// 显示重命名预设对话框
  Future<void> _showRenamePresetDialog(pc.RandomPromptPreset preset) async {
    final controller = TextEditingController(text: preset.name);
    String? errorText;

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.preset_rename),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.preset_presetName,
              border: const OutlineInputBorder(),
              errorText: errorText,
            ),
            onChanged: (value) {
              final error = _validatePresetName(value, excludePresetId: preset.id);
              setState(() => errorText = error);
            },
            onSubmitted: (value) {
              final error = _validatePresetName(value, excludePresetId: preset.id);
              if (error == null) {
                Navigator.pop(ctx, value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () {
                final error = _validatePresetName(controller.text, excludePresetId: preset.id);
                if (error == null) {
                  Navigator.pop(ctx, controller.text.trim());
                } else {
                  setState(() => errorText = error);
                }
              },
              child: Text(context.l10n.common_confirm),
            ),
          ],
        ),
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != preset.name) {
      final updated = preset.copyWith(name: newName, updatedAt: DateTime.now());
      await ref
          .read(promptConfigNotifierProvider.notifier)
          .updatePreset(updated);
    }
  }

  String _getConfigSummary(pc.PromptConfig config) {
    final parts = <String>[];
    if (config.contentType == pc.ContentType.string) {
      parts.add(
        context.l10n.preset_itemCount(config.stringContents.length.toString()),
      );
    } else {
      parts.add(
        context.l10n
            .preset_subConfigCount(config.nestedConfigs.length.toString()),
      );
    }
    parts.add(_getSelectionModeShort(config.selectionMode));
    return parts.join(' · ');
  }

  String _getSelectionModeShort(pc.SelectionMode mode) {
    switch (mode) {
      case pc.SelectionMode.singleRandom:
        return context.l10n.preset_random;
      case pc.SelectionMode.singleSequential:
        return context.l10n.preset_sequential;
      case pc.SelectionMode.singleProbability:
        return context.l10n.preset_probability;
      case pc.SelectionMode.multipleCount:
        return context.l10n.preset_multiple;
      case pc.SelectionMode.multipleProbability:
        return context.l10n.preset_probability;
      case pc.SelectionMode.all:
        return context.l10n.preset_all;
    }
  }

  void _showUnsavedDialog(VoidCallback onDiscard) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.preset_unsavedChanges),
        content: Text(context.l10n.preset_unsavedChangesConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() => _hasUnsavedChanges = false);
              onDiscard();
            },
            child: Text(context.l10n.preset_discard),
          ),
        ],
      ),
    );
  }

  void _showResetPresetDialog(pc.RandomPromptPreset preset) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.config_restoreDefaults),
        content: Text(context.l10n.config_restoreDefaultsConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // 使用 PromptConfigNotifier 重置预设
              ref
                  .read(promptConfigNotifierProvider.notifier)
                  .resetPreset(preset.id);
              // 重新加载编辑状态
              _selectPreset(preset.id);
              AppToast.success(context, context.l10n.config_restored);
            },
            child: Text(context.l10n.common_confirm),
          ),
        ],
      ),
    );
  }

  void _showDeletePresetDialog(pc.RandomPromptPreset preset) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.preset_deletePreset),
        content: Text(context.l10n.preset_deletePresetConfirm(preset.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref
                  .read(promptConfigNotifierProvider.notifier)
                  .deletePreset(preset.id);
              if (_selectedPresetId == preset.id) {
                setState(() {
                  _selectedPresetId = null;
                  _selectedConfigId = null;
                  _editingConfigs = [];
                });
              }
              AppToast.success(context, context.l10n.preset_deleted);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );
  }

  /// 计算内置词库的标签数量
  ///
  /// [library] 标签库
  /// [categories] 随机类别列表
  /// [filterConfig] 过滤配置
  int _calculateBuiltinLibraryTagCount(
    TagLibrary? library,
    List<RandomCategory> categories,
    CategoryFilterConfig filterConfig,
  ) {
    if (library == null) return 0;

    int tagCount = 0;
    for (final randomCategory in categories) {
      final category = TagSubCategory.values.firstWhere(
        (e) => e.name == randomCategory.key,
        orElse: () => TagSubCategory.hairColor,
      );
      if (randomCategory.enabled && filterConfig.isBuiltinEnabled(category)) {
        tagCount += library
            .getCategory(category)
            .where((t) => !t.isDanbooruSupplement)
            .length;
      }
    }
    return tagCount;
  }

  /// 计算 NAI 模式下内置词库的标签数量
  ///
  /// 与 _calculateBuiltinLibraryTagCount 的区别是：
  /// - 这里使用 NAI 固定的类别配置作为遍历源
  /// - 需要额外检查对应的 RandomCategory 是否启用
  ///
  /// [library] 标签库
  /// [categories] 随机类别列表（用于检查启用状态）
  /// [filterConfig] 过滤配置
  int _calculateNaiBuiltinTagCount(
    TagLibrary? library,
    List<RandomCategory> categories,
    CategoryFilterConfig filterConfig,
  ) {
    if (library == null) return 0;

    int tagCount = 0;
    final categoryConfig = _getNaiCategoryConfig();

    for (final category in categoryConfig.keys) {
      // 查找对应的 RandomCategory
      final randomCategory = categories.cast<RandomCategory?>().firstWhere(
            (c) => c?.key == category.name,
            orElse: () => null,
          );
      final categoryEnabled = randomCategory?.enabled ?? true;
      if (categoryEnabled && filterConfig.isBuiltinEnabled(category)) {
        tagCount += library
            .getCategory(category)
            .where((t) => !t.isDanbooruSupplement)
            .length;
      }
    }
    return tagCount;
  }
}
