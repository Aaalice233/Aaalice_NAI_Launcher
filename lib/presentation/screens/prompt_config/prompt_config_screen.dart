import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/datasources/remote/danbooru_tag_group_service.dart';
import '../../../data/models/prompt/danbooru_tag_group_tree.dart';
import '../../../data/models/prompt/prompt_config.dart';
import '../../../data/models/prompt/random_prompt_result.dart';
import '../../../data/models/prompt/sync_config.dart';
import '../../../data/models/prompt/tag_category.dart';
import '../../../data/models/prompt/tag_group.dart';
import '../../../data/models/prompt/tag_group_mapping.dart';
import '../../../data/models/prompt/weighted_tag.dart';
import '../../providers/prompt_config_provider.dart';
import '../../providers/random_mode_provider.dart';
import '../../providers/tag_group_mapping_provider.dart';
import '../../providers/tag_library_provider.dart';
import '../../widgets/common/app_toast.dart';

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
  List<PromptConfig> _editingConfigs = [];

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
    // 监听 TagGroup 同步状态
    final tagGroupState = ref.watch(tagGroupMappingNotifierProvider);
    final isSyncing = state.isSyncing || tagGroupState.isSyncing;
    // 计算已启用的 tag group 数量
    final enabledMappingCount = tagGroupState.config.mappings
        .where((m) => m.enabled)
        .length;

    // 计算总标签数：内置词库 + TagGroup
    int tagCount = 0;
    final categoryConfig = _getNaiCategoryConfig();
    for (final category in categoryConfig.keys) {
      // 1. 内置词库启用时计入
      if (state.categoryFilterConfig.isBuiltinEnabled(category) && library != null) {
        tagCount += library.getCategory(category)
            .where((t) => !t.isDanbooruSupplement)
            .length;
      }
      // 2. 启用的 TagGroup 标签数
      for (final mapping in tagGroupState.config.mappings.where((m) => m.enabled)) {
        if (mapping.targetCategory == category) {
          tagCount += mapping.lastSyncedTagCount;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 热度阈值控制 + 统计信息 + 同步按钮
          _GlobalPostCountToolbar(
            tagCount: tagCount,
            enabledMappingCount: enabledMappingCount,
            isSyncing: isSyncing,
            onSync: () => _syncAll(context),
            onSelectAll: _selectAllTagGroups,
            onDeselectAll: _deselectAllTagGroups,
            allExpanded: _expandedCategories.length == _getNaiCategoryConfig().length,
            onToggleExpand: _toggleAllExpand,
          ),

          // 同步进度（TagLibrary 或 TagGroup 同步）
          if (state.isSyncing && state.syncProgress != null) ...[
            const SizedBox(height: 16),
            _buildNaiSyncProgress(theme, state.syncProgress!),
          ],
          if (tagGroupState.isSyncing && tagGroupState.syncProgress != null) ...[
            const SizedBox(height: 16),
            _buildTagGroupSyncProgress(theme, tagGroupState.syncProgress!),
          ],
        ],
      ),
    );
  }

  /// 执行全部同步
  Future<void> _syncAll(BuildContext context) async {
    final tagLibraryNotifier = ref.read(tagLibraryNotifierProvider.notifier);
    final tagGroupNotifier = ref.read(tagGroupMappingNotifierProvider.notifier);
    final tagGroupState = ref.read(tagGroupMappingNotifierProvider);

    // 先同步 Danbooru 标签库
    final tagSuccess = await tagLibraryNotifier.syncLibrary();
    if (!tagSuccess) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.tagLibrary_syncFailed);
      }
      return;
    }

    // 然后同步 TagGroup 映射
    if (tagGroupState.config.enabled && tagGroupState.config.mappings.isNotEmpty) {
      final groupSuccess = await tagGroupNotifier.syncTagGroups();
      if (!groupSuccess) {
        if (context.mounted) {
          AppToast.error(context, context.l10n.tagGroup_syncFailed(''));
        }
        return;
      }
    }

    if (context.mounted) {
      AppToast.success(context, context.l10n.tagLibrary_syncSuccess);
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
                progress.message,
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
  Widget _buildTagGroupSyncProgress(ThemeData theme, TagGroupSyncProgress progress) {
    final message = progress.currentGroup != null
        ? context.l10n.tagGroup_syncFetching(
            progress.currentGroup!,
            progress.completedGroups.toString(),
            progress.totalGroups.toString(),
          )
        : progress.message;

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

    final categoryConfig = _getNaiCategoryConfig();
    final filterConfig = state.categoryFilterConfig;

    // 直接返回类别列表，使用可展开的分类卡片
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: categoryConfig.length,
      itemBuilder: (context, index) {
        final entry = categoryConfig.entries.elementAt(index);
        final category = entry.key;
        final probability = entry.value;
        final includeSupplement = filterConfig.isEnabled(category);
        final tags = library.getFilteredCategory(
          category,
          includeDanbooruSupplement: includeSupplement,
        );

        return _ExpandableCategoryTile(
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
        );
      },
    );
  }

  /// 显示类别详情对话框
  void _showCategoryDetailDialog(TagSubCategory category, List<WeightedTag> tags) {
    showDialog(
      context: context,
      builder: (ctx) => _CategoryDetailDialog(
        category: category,
        tags: tags,
      ),
    );
  }

  /// 同步指定类别的扩展标签
  Future<void> _syncCategory(TagSubCategory category) async {
    final tagGroupNotifier = ref.read(tagGroupMappingNotifierProvider.notifier);
    final success = await tagGroupNotifier.syncCategoryTagGroups(category);
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
    final notifier = ref.read(tagGroupMappingNotifierProvider.notifier);

    final allGroups = <String, ({String displayName, TagSubCategory category, bool includeChildren})>{};
    final locale = Localizations.localeOf(context).languageCode;

    for (final category in _getNaiCategoryConfig().keys) {
      final categoryNode = DanbooruTagGroupTree.tree.firstWhere(
        (n) => n.category == category,
        orElse: () => const TagGroupTreeNode(
          title: '',
          displayNameZh: '',
          displayNameEn: '',
        ),
      );
      for (final group in categoryNode.children) {
        // 递归收集所有叶子节点
        final leafNodes = _collectLeafNodes(group);
        for (final leaf in leafNodes) {
          allGroups[leaf.title] = (
            displayName: locale == 'zh' ? leaf.displayNameZh : leaf.displayNameEn,
            category: category,
            includeChildren: true,
          );
        }
      }
    }

    final selectedTitles = allGroups.keys.toSet();
    await notifier.updateSelectedGroupsWithTree(selectedTitles, allGroups);
  }

  /// 递归收集所有叶子节点
  List<TagGroupTreeNode> _collectLeafNodes(TagGroupTreeNode node) {
    final result = <TagGroupTreeNode>[];
    if (node.isTagGroup) {
      result.add(node);
    }
    for (final child in node.children) {
      result.addAll(_collectLeafNodes(child));
    }
    return result;
  }

  /// 取消选择所有 tag groups
  Future<void> _deselectAllTagGroups() async {
    final notifier = ref.read(tagGroupMappingNotifierProvider.notifier);
    final currentState = ref.read(tagGroupMappingNotifierProvider);

    // 禁用所有映射
    for (final mapping in currentState.config.mappings.where((m) => m.enabled)) {
      await notifier.removeMapping(mapping.id);
    }
  }

  /// 切换全部展开/收起状态
  void _toggleAllExpand() {
    final categories = _getNaiCategoryConfig().keys.toSet();
    setState(() {
      if (_expandedCategories.length == categories.length) {
        _expandedCategories.clear();
      } else {
        _expandedCategories.addAll(categories);
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
    final currentMode = ref.watch(randomModeNotifierProvider);
    final isNaiMode = currentMode == RandomGenerationMode.naiOfficial;

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
                const Spacer(),
                _buildPresetMenu(theme),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),

          // 预设列表（包含固定的 NAI 官方模式）
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: [
                      // NAI 官方模式（固定项）
                      _buildNaiPresetItem(isNaiMode, theme),
                      // 分隔线
                      if (state.presets.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  height: 1,
                                  color: theme.dividerColor,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  context.l10n.config_presets,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  height: 1,
                                  color: theme.dividerColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // 自定义预设列表
                      ...state.presets.map(
                        (preset) => _buildPresetItem(preset, state, theme),
                      ),
                      // 新建预设按钮（列表末尾）
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: OutlinedButton.icon(
                          onPressed: _createNewPreset,
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
    final tagGroupState = ref.watch(tagGroupMappingNotifierProvider);
    final library = libraryState.library;

    // 计算总标签数：内置词库 + TagGroup
    int tagCount = 0;
    final categoryConfig = _getNaiCategoryConfig();
    for (final category in categoryConfig.keys) {
      // 1. 内置词库启用时计入
      if (libraryState.categoryFilterConfig.isBuiltinEnabled(category) && library != null) {
        tagCount += library.getCategory(category)
            .where((t) => !t.isDanbooruSupplement)
            .length;
      }
      // 2. 启用的 TagGroup 标签数
      for (final mapping in tagGroupState.config.mappings.where((m) => m.enabled)) {
        if (mapping.targetCategory == category) {
          tagCount += mapping.lastSyncedTagCount;
        }
      }
    }

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
    setState(() {
      _selectedPresetId = null;
      _selectedConfigId = null;
      _editingConfigs = [];
      _hasUnsavedChanges = false;
    });
  }

  Widget _buildPresetMenu(ThemeData theme) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      padding: EdgeInsets.zero,
      tooltip: context.l10n.preset_moreActions,
      onSelected: _handlePresetMenuAction,
      itemBuilder: (menuContext) => [
        PopupMenuItem(
          value: 'import',
          child: Text(context.l10n.config_importConfig),
        ),
      ],
    );
  }

  Widget _buildPresetItem(
    RandomPromptPreset preset,
    PromptConfigState state,
    ThemeData theme,
  ) {
    final isSelected = preset.id == _selectedPresetId;
    final isActive = preset.id == state.selectedPresetId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
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
                // 右键菜单
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                  padding: EdgeInsets.zero,
                  onSelected: (action) =>
                      _handlePresetItemAction(preset, action),
                  itemBuilder: (menuContext) => [
                    PopupMenuItem(
                      value: 'activate',
                      enabled: !isActive,
                      child: Text(context.l10n.preset_setAsCurrent),
                    ),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Text(context.l10n.preset_duplicate),
                    ),
                    PopupMenuItem(
                      value: 'export',
                      child: Text(context.l10n.preset_export),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        context.l10n.preset_delete,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  Widget _buildConfigItem(PromptConfig config, int index, ThemeData theme) {
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
            : _ConfigDetailEditor(
                key: ValueKey(config.id),
                config: config,
                onChanged: (updated) => _updateConfig(updated),
              ),
      ),
    );
  }

  // ==================== 辅助方法 ====================
  RandomPromptPreset? _getSelectedPreset(PromptConfigState state) {
    if (_selectedPresetId == null) return null;
    try {
      return state.presets.firstWhere((p) => p.id == _selectedPresetId);
    } catch (_) {
      return null;
    }
  }

  PromptConfig? _getSelectedConfig() {
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
    final preset = state.presets.firstWhere((p) => p.id == presetId);

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

  void _createNewPreset() {
    if (_hasUnsavedChanges) {
      _showUnsavedDialog(_doCreateNewPreset);
      return;
    }
    _doCreateNewPreset();
  }

  void _doCreateNewPreset() async {
    final presetName = context.l10n.config_newPreset;
    final successMessage = context.l10n.preset_newPresetCreated;
    final newPreset = RandomPromptPreset.create(name: presetName);
    await ref.read(promptConfigNotifierProvider.notifier).addPreset(newPreset);
    _doSelectPreset(newPreset.id);
    if (mounted) {
      AppToast.success(context, successMessage);
    }
  }

  void _addConfig() {
    final newConfig =
        PromptConfig.create(name: context.l10n.presetEdit_newConfigGroup);
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

  void _updateConfig(PromptConfig updated) {
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
    final preset = state.presets.firstWhere((p) => p.id == _selectedPresetId);
    final updated = preset.copyWith(
      name: _presetNameController.text.trim(),
      configs: _editingConfigs,
      updatedAt: DateTime.now(),
    );

    await ref.read(promptConfigNotifierProvider.notifier).updatePreset(updated);
    setState(() => _hasUnsavedChanges = false);
    if (mounted) {
      AppToast.success(context, successMessage);
    }
  }

  void _handlePresetMenuAction(String action) {
    switch (action) {
      case 'import':
        _showImportDialog();
        break;
    }
  }

  void _handlePresetItemAction(RandomPromptPreset preset, String action) {
    switch (action) {
      case 'activate':
        ref.read(promptConfigNotifierProvider.notifier).selectPreset(preset.id);
        AppToast.success(context, context.l10n.preset_setAsCurrentSuccess);
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
      case 'delete':
        _showDeletePresetDialog(preset);
        break;
    }
  }

  String _getConfigSummary(PromptConfig config) {
    final parts = <String>[];
    if (config.contentType == ContentType.string) {
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

  String _getSelectionModeShort(SelectionMode mode) {
    switch (mode) {
      case SelectionMode.singleRandom:
        return context.l10n.preset_random;
      case SelectionMode.singleSequential:
        return context.l10n.preset_sequential;
      case SelectionMode.singleProbability:
        return context.l10n.preset_probability;
      case SelectionMode.multipleCount:
        return context.l10n.preset_multiple;
      case SelectionMode.multipleProbability:
        return context.l10n.preset_probability;
      case SelectionMode.all:
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

  void _showDeletePresetDialog(RandomPromptPreset preset) {
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

  void _showImportDialog() {
    final controller = TextEditingController();
    // 预先捕获本地化字符串，避免异步间隙问题
    final titleText = context.l10n.preset_importConfig;
    final hintText = context.l10n.preset_pasteJson;
    final cancelText = context.l10n.common_cancel;
    final importText = context.l10n.common_import;
    final successText = context.l10n.preset_importSuccess;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titleText),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: hintText,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(promptConfigNotifierProvider.notifier)
                    .importPreset(controller.text);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (mounted) {
                  AppToast.success(context, successText);
                }
              } catch (e) {
                if (mounted) {
                  AppToast.error(
                    context,
                    context.l10n.preset_importFailed(e.toString()),
                  );
                }
              }
            },
            child: Text(importText),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }
}

// ==================== 配置详情编辑器 ====================
class _ConfigDetailEditor extends StatefulWidget {
  final PromptConfig config;
  final ValueChanged<PromptConfig> onChanged;

  const _ConfigDetailEditor({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  State<_ConfigDetailEditor> createState() => _ConfigDetailEditorState();
}

class _ConfigDetailEditorState extends State<_ConfigDetailEditor> {
  late TextEditingController _nameController;
  late TextEditingController _contentsController;
  late SelectionMode _selectionMode;
  late int _selectCount;
  late double _selectProbability;
  late int _bracketMin;
  late int _bracketMax;
  late bool _shuffle;

  @override
  void initState() {
    super.initState();
    _initFromConfig();
  }

  @override
  void didUpdateWidget(_ConfigDetailEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.id != widget.config.id) {
      _initFromConfig();
    }
  }

  void _initFromConfig() {
    _nameController = TextEditingController(text: widget.config.name);
    _contentsController = TextEditingController(
      text: widget.config.stringContents.join('\n'),
    );
    _selectionMode = widget.config.selectionMode;
    _selectCount = widget.config.selectCount ?? 1;
    _selectProbability =
        (widget.config.selectProbability ?? 0.5).clamp(0.05, 1.0);
    _bracketMin = widget.config.bracketMin;
    _bracketMax = widget.config.bracketMax;
    _shuffle = widget.config.shuffle;
  }

  void _notifyChanged() {
    final stringContents = _contentsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    widget.onChanged(
      widget.config.copyWith(
        name: _nameController.text.trim(),
        selectionMode: _selectionMode,
        selectCount: _selectCount,
        selectProbability: _selectProbability,
        bracketMin: _bracketMin,
        bracketMax: _bracketMax,
        shuffle: _shuffle,
        stringContents: stringContents,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Icon(Icons.edit_note, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                context.l10n.configEditor_editConfigGroup,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 配置名称
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.l10n.configEditor_configName,
              prefixIcon: const Icon(Icons.label_outline),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (_) => _notifyChanged(),
          ),
          const SizedBox(height: 24),

          // 选取方式 - 使用卡片式单选
          _buildSectionTitle(theme, context.l10n.configEditor_selectionMode),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SelectionMode.values.map((mode) {
              final isSelected = _selectionMode == mode;
              return ChoiceChip(
                label: Text(_getSelectionModeName(mode)),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectionMode = mode);
                    _notifyChanged();
                  }
                },
              );
            }).toList(),
          ),

          // 附加参数
          if (_selectionMode == SelectionMode.multipleCount) ...[
            const SizedBox(height: 16),
            _buildSliderRow(
              label: context.l10n.config_selectCount,
              value: _selectCount.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              displayValue: '$_selectCount',
              onChanged: (v) {
                setState(() => _selectCount = v.toInt());
                _notifyChanged();
              },
            ),
          ],
          if (_selectionMode == SelectionMode.singleProbability ||
              _selectionMode == SelectionMode.multipleProbability) ...[
            const SizedBox(height: 16),
            _buildSliderRow(
              label: context.l10n.config_selectProbability,
              value: _selectProbability,
              min: 0.05,
              max: 1.0,
              divisions: 19,
              displayValue: '${(_selectProbability * 100).toInt()}%',
              onChanged: (v) {
                setState(() => _selectProbability = v);
                _notifyChanged();
              },
            ),
          ],
          if (_selectionMode == SelectionMode.multipleProbability ||
              _selectionMode == SelectionMode.all) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              title: Text(context.l10n.configEditor_shuffleOrder),
              subtitle: Text(context.l10n.configEditor_shuffleOrderHint),
              value: _shuffle,
              onChanged: (v) {
                setState(() => _shuffle = v);
                _notifyChanged();
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // 权重括号
          _buildSectionTitle(theme, context.l10n.configEditor_weightBrackets),
          const SizedBox(height: 8),
          Text(
            context.l10n.configEditor_weightBracketsHint,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSliderRow(
                  label: context.l10n.config_min,
                  value: _bracketMin.toDouble(),
                  min: 0,
                  max: 5,
                  divisions: 5,
                  displayValue: '$_bracketMin',
                  onChanged: (v) {
                    setState(() {
                      _bracketMin = v.toInt();
                      if (_bracketMax < _bracketMin) _bracketMax = _bracketMin;
                    });
                    _notifyChanged();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSliderRow(
                  label: context.l10n.config_max,
                  value: _bracketMax.toDouble(),
                  min: 0,
                  max: 5,
                  divisions: 5,
                  displayValue: '$_bracketMax',
                  onChanged: (v) {
                    setState(() {
                      _bracketMax = v.toInt();
                      if (_bracketMin > _bracketMax) _bracketMin = _bracketMax;
                    });
                    _notifyChanged();
                  },
                ),
              ),
            ],
          ),
          if (_bracketMin > 0 || _bracketMax > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.preview,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.config_preview(_getBracketPreview()),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // 标签内容
          _buildSectionTitle(theme, context.l10n.config_tagContent),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                context.l10n.config_tagContentHint(
                  _contentsController.text
                      .split('\n')
                      .where((s) => s.trim().isNotEmpty)
                      .length,
                ),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _formatContents,
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: Text(context.l10n.config_format),
                style:
                    TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              TextButton.icon(
                onPressed: _sortContents,
                icon: const Icon(Icons.sort_by_alpha, size: 16),
                label: Text(context.l10n.config_sort),
                style:
                    TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _contentsController,
            maxLines: 15,
            minLines: 8,
            decoration: InputDecoration(
              hintText: context.l10n.config_inputTags,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            onChanged: (_) {
              setState(() {});
              _notifyChanged();
            },
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(displayValue, textAlign: TextAlign.end),
        ),
      ],
    );
  }

  String _getSelectionModeName(SelectionMode mode) {
    switch (mode) {
      case SelectionMode.singleRandom:
        return context.l10n.config_singleRandom;
      case SelectionMode.singleSequential:
        return context.l10n.config_singleSequential;
      case SelectionMode.singleProbability:
        return context.l10n.configEditor_singleProbability;
      case SelectionMode.multipleCount:
        return context.l10n.config_multipleCount;
      case SelectionMode.multipleProbability:
        return context.l10n.config_probability;
      case SelectionMode.all:
        return context.l10n.config_all;
    }
  }

  String _getBracketPreview() {
    final examples = <String>[];
    for (int i = _bracketMin; i <= _bracketMax; i++) {
      examples.add('${'{' * i}tag${'}' * i}');
    }
    return examples.join(context.l10n.configEditor_or);
  }

  void _formatContents() {
    final lines = _contentsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _contentsController.text = lines.join('\n');
    _notifyChanged();
  }

  void _sortContents() {
    final lines = _contentsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();
    _contentsController.text = lines.join('\n');
    _notifyChanged();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentsController.dispose();
    super.dispose();
  }
}

/// 类别详情对话框
class _CategoryDetailDialog extends StatelessWidget {
  final TagSubCategory category;
  final List<WeightedTag> tags;

  const _CategoryDetailDialog({
    required this.category,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryName = TagSubCategoryHelper.getDisplayName(category);
    final sortedTags = List<WeightedTag>.from(tags)
      ..sort((a, b) => b.weight.compareTo(a.weight));

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: Row(
        children: [
          Icon(
            _getCategoryIconStatic(category),
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(categoryName),
                Text(
                  context.l10n.naiMode_tagCount(tags.length.toString()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 分类描述
            Text(
              _getCategoryDescription(context, category),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            // 标签列表标题
            Text(
              context.l10n.naiMode_tagListTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // 可滚动标签列表
            Expanded(
              child: sortedTags.isEmpty
                  ? Center(
                      child: Text(
                        context.l10n.naiMode_noTags,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: sortedTags.map((tag) {
                          return _buildTagChip(theme, tag);
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_close),
        ),
      ],
    );
  }

  Widget _buildTagChip(ThemeData theme, WeightedTag tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Text(
        tag.tag,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  String _getCategoryDescription(BuildContext context, TagSubCategory category) {
    return switch (category) {
      TagSubCategory.hairColor => context.l10n.naiMode_desc_hairColor,
      TagSubCategory.eyeColor => context.l10n.naiMode_desc_eyeColor,
      TagSubCategory.hairStyle => context.l10n.naiMode_desc_hairStyle,
      TagSubCategory.expression => context.l10n.naiMode_desc_expression,
      TagSubCategory.pose => context.l10n.naiMode_desc_pose,
      TagSubCategory.clothing => context.l10n.naiMode_desc_clothing,
      TagSubCategory.accessory => context.l10n.naiMode_desc_accessory,
      TagSubCategory.bodyFeature => context.l10n.naiMode_desc_bodyFeature,
      TagSubCategory.background => context.l10n.naiMode_desc_background,
      TagSubCategory.scene => context.l10n.naiMode_desc_scene,
      TagSubCategory.style => context.l10n.naiMode_desc_style,
      TagSubCategory.characterCount => context.l10n.naiMode_desc_characterCount,
      _ => '',
    };
  }

  static IconData _getCategoryIconStatic(TagSubCategory category) {
    return switch (category) {
      TagSubCategory.hairColor => Icons.palette,
      TagSubCategory.eyeColor => Icons.remove_red_eye,
      TagSubCategory.hairStyle => Icons.face,
      TagSubCategory.expression => Icons.emoji_emotions,
      TagSubCategory.pose => Icons.accessibility_new,
      TagSubCategory.clothing => Icons.checkroom,
      TagSubCategory.accessory => Icons.watch,
      TagSubCategory.bodyFeature => Icons.accessibility,
      TagSubCategory.background => Icons.landscape,
      TagSubCategory.scene => Icons.photo_camera,
      TagSubCategory.style => Icons.brush,
      TagSubCategory.characterCount => Icons.group,
      _ => Icons.label,
    };
  }
}

/// 全局热度阈值工具栏
class _GlobalPostCountToolbar extends ConsumerStatefulWidget {
  final int tagCount;
  final int enabledMappingCount;
  final bool isSyncing;
  final VoidCallback onSync;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final bool allExpanded;
  final VoidCallback onToggleExpand;

  const _GlobalPostCountToolbar({
    required this.tagCount,
    required this.enabledMappingCount,
    required this.isSyncing,
    required this.onSync,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.allExpanded,
    required this.onToggleExpand,
  });

  @override
  ConsumerState<_GlobalPostCountToolbar> createState() => _GlobalPostCountToolbarState();
}

class _GlobalPostCountToolbarState extends ConsumerState<_GlobalPostCountToolbar> {
  double? _draggingValue;

  double _postCountToSlider(int postCount) {
    const minLog = 2.0;
    const maxLog = 4.699;
    final log = math.log(postCount.clamp(100, 50000).toDouble()) / math.ln10;
    return ((log - minLog) / (maxLog - minLog)).clamp(0.0, 1.0);
  }

  int _sliderToPostCount(double value) {
    const minLog = 2.0;
    const maxLog = 4.699;
    final log = minLog + value * (maxLog - minLog);
    final count = math.pow(10, log).round();
    return _snapToCommonValue(count);
  }

  int _snapToCommonValue(int value) {
    const commonValues = [100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000];
    for (final cv in commonValues) {
      if ((value - cv).abs() < cv * 0.15) {
        return cv;
      }
    }
    return ((value / 100).round() * 100).clamp(100, 50000);
  }

  String _formatPostCount(int count) {
    if (count >= 10000) {
      return '${count ~/ 1000}K';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(tagGroupMappingNotifierProvider);
    final currentValue = state.config.minPostCount;
    final displayValue = _draggingValue ?? _postCountToSlider(currentValue);
    final displayPostCount = _sliderToPostCount(displayValue);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：热度阈值 + 统计信息 + 同步按钮
          Row(
            children: [
              // 热度阈值标签
              Text(
                context.l10n.tagGroup_minPostCount,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(width: 8),
              // 当前值徽章
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatPostCount(displayPostCount),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 预设按钮
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [100, 500, 1000, 5000, 10000].map((value) {
                      final isSelected = currentValue == value;
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: InkWell(
                          onTap: () {
                            ref.read(tagGroupMappingNotifierProvider.notifier)
                                .setMinPostCount(value);
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary.withOpacity(0.5)
                                    : theme.colorScheme.outline.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _formatPostCount(value),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 已选择的组数量
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  context.l10n.tagGroup_selectedCount(widget.enabledMappingCount.toString()),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 总tag数量
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  context.l10n.naiMode_totalTags(widget.tagCount.toString()),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              // 全选/取消选择按钮（二合一）
              _buildCompactToggleButton(
                theme: theme,
                icon: Icons.check_box_outlined,
                label: context.l10n.common_selectAll,
                onTap: widget.onSelectAll,
              ),
              const SizedBox(width: 4),
              _buildCompactToggleButton(
                theme: theme,
                icon: Icons.check_box_outline_blank,
                label: context.l10n.common_deselectAll,
                onTap: widget.onDeselectAll,
              ),
              const SizedBox(width: 8),
              // 展开/收起按钮
              _buildCompactToggleButton(
                theme: theme,
                icon: widget.allExpanded ? Icons.unfold_less : Icons.unfold_more,
                label: widget.allExpanded
                    ? context.l10n.common_collapseAll
                    : context.l10n.common_expandAll,
                onTap: widget.onToggleExpand,
              ),
              const SizedBox(width: 12),
              // 同步按钮
              FilledButton.icon(
                onPressed: widget.isSyncing ? null : widget.onSync,
                icon: widget.isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync, size: 18),
                label: Text(context.l10n.tagLibrary_syncNow),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 滑块
          SizedBox(
            height: 24,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: theme.colorScheme.primary,
                inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
                thumbColor: theme.colorScheme.primary,
                overlayColor: theme.colorScheme.primary.withOpacity(0.1),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: displayValue,
                min: 0,
                max: 1,
                onChanged: (value) {
                  setState(() {
                    _draggingValue = value;
                  });
                },
                onChangeEnd: (value) {
                  final postCount = _sliderToPostCount(value);
                  ref.read(tagGroupMappingNotifierProvider.notifier)
                      .setMinPostCount(postCount);
                  setState(() {
                    _draggingValue = null;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactToggleButton({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 可展开的分类卡片
class _ExpandableCategoryTile extends ConsumerStatefulWidget {
  final TagSubCategory category;
  final int probability;
  final List<WeightedTag> tags;
  final VoidCallback onSyncCategory;
  final VoidCallback onShowDetail;
  final bool isExpanded;
  final ValueChanged<bool> onExpandChanged;

  const _ExpandableCategoryTile({
    required this.category,
    required this.probability,
    required this.tags,
    required this.onSyncCategory,
    required this.onShowDetail,
    required this.isExpanded,
    required this.onExpandChanged,
  });

  @override
  ConsumerState<_ExpandableCategoryTile> createState() => _ExpandableCategoryTileState();
}

class _ExpandableCategoryTileState extends ConsumerState<_ExpandableCategoryTile> {
  /// 标签预览缓存
  final Map<String, List<String>> _previewCache = {};
  final Map<String, int> _totalCountCache = {};
  final Set<String> _loadingGroups = {};

  /// 获取分类对应的 tag groups
  List<TagGroupTreeNode> _getTagGroupsForCategory(TagSubCategory category) {
    final categoryNode = DanbooruTagGroupTree.tree.firstWhere(
      (n) => n.category == category,
      orElse: () => const TagGroupTreeNode(
        title: '',
        displayNameZh: '',
        displayNameEn: '',
      ),
    );
    return categoryNode.children;
  }

  /// 递归收集所有叶子节点
  List<TagGroupTreeNode> _collectLeafNodes(TagGroupTreeNode node) {
    final result = <TagGroupTreeNode>[];
    if (node.isTagGroup) {
      result.add(node);
    }
    for (final child in node.children) {
      result.addAll(_collectLeafNodes(child));
    }
    return result;
  }

  /// 收集节点下所有叶子节点的 title
  List<String> _collectLeafTitles(TagGroupTreeNode node) {
    return _collectLeafNodes(node).map((n) => n.title).toList();
  }

  /// 判断分类是否包含子分组
  bool _hasSubGroups(TagSubCategory category) {
    final groups = _getTagGroupsForCategory(category);
    return groups.any((node) => !node.isTagGroup);
  }

  /// 获取显示名称
  String _getDisplayName(TagGroupTreeNode node) {
    final locale = Localizations.localeOf(context).languageCode;
    return locale == 'zh' ? node.displayNameZh : node.displayNameEn;
  }

  /// 构建已选择的 tag 组预览（显示在头部行）
  Widget _buildSelectedTagGroupsPreview(ThemeData theme, TagGroupMappingState state) {
    final tagGroups = _getTagGroupsForCategory(widget.category);
    final enabledTitles = state.config.mappings
        .where((m) => m.enabled)
        .map((m) => m.groupTitle)
        .toSet();

    // 获取内置词库状态
    final libraryState = ref.watch(tagLibraryNotifierProvider);
    final isBuiltinEnabled = libraryState.categoryFilterConfig.isBuiltinEnabled(widget.category);

    // 收集当前分类下已选择的 tag group 显示名称
    final selectedNames = <String>[];

    // 如果内置词库启用，首先添加"内置"
    if (isBuiltinEnabled) {
      selectedNames.add(context.l10n.tagGroup_builtin);
    }

    for (final group in tagGroups) {
      if (group.isTagGroup) {
        if (enabledTitles.contains(group.title)) {
          selectedNames.add(_getDisplayName(group));
        }
      } else {
        // 子分组：检查其叶子节点
        final leafNodes = _collectLeafNodes(group);
        for (final leaf in leafNodes) {
          if (enabledTitles.contains(leaf.title)) {
            selectedNames.add(_getDisplayName(leaf));
          }
        }
      }
    }

    if (selectedNames.isEmpty) {
      return const SizedBox.shrink();
    }

    // 显示为逗号分隔的文本
    return Text(
      selectedNames.join(', '),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.primary.withOpacity(0.8),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 加载标签预览
  Future<void> _loadTagPreview(String groupTitle) async {
    if (_previewCache.containsKey(groupTitle) || _loadingGroups.contains(groupTitle)) {
      return;
    }

    _loadingGroups.add(groupTitle);
    if (mounted) setState(() {});

    try {
      final service = ref.read(danbooruTagGroupServiceProvider);
      final group = await service.getTagGroup(groupTitle, fetchPostCounts: false);

      if (mounted) {
        if (group != null) {
          final actualTags = group.tags
              .where((t) => !t.name.startsWith('tag_group'))
              .toList();
          _totalCountCache[groupTitle] = actualTags.length;
          _previewCache[groupTitle] = actualTags.take(20).map((t) => t.name).toList();
        } else {
          // 获取失败，缓存空列表以避免重复请求
          _previewCache[groupTitle] = [];
          _totalCountCache[groupTitle] = 0;
        }
        setState(() {});
      }
    } catch (e) {
      // 发生异常，缓存空列表
      if (mounted) {
        _previewCache[groupTitle] = [];
        _totalCountCache[groupTitle] = 0;
        setState(() {});
      }
    } finally {
      _loadingGroups.remove(groupTitle);
      if (mounted) setState(() {});
    }
  }

  /// 获取预览文本
  InlineSpan _getPreviewSpan(TagGroupTreeNode node) {
    final tags = _previewCache[node.title];
    final totalCount = _totalCountCache[node.title];
    final isLoading = _loadingGroups.contains(node.title);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final theme = Theme.of(context);

    if (isLoading) {
      final loadingText = isZh ? '加载中...' : 'Loading...';
      return WidgetSpan(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            loadingText,
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ),
      );
    } else if (tags == null) {
      // 尚未加载，显示提示信息
      final hintText = isZh ? '悬浮以加载预览...' : 'Hover to load preview...';
      return WidgetSpan(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            hintText,
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ),
      );
    } else if (tags.isEmpty) {
      // 加载完成但没有标签
      final emptyText = isZh ? '该分组暂无标签数据' : 'No tags in this group';
      return WidgetSpan(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            emptyText,
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ),
      );
    } else {
      final tagText = tags.join(', ');
      final count = totalCount ?? tags.length;
      final omittedCount = count - tags.length;
      final countLabel = isZh
          ? 'Tag数量：$count | 来源：Danbooru'
          : 'Tag count: $count | Source: Danbooru';
      final omittedLabel = omittedCount > 0
          ? (isZh ? '\n（省略了 $omittedCount 个）' : '\n($omittedCount more omitted)')
          : '';

      return WidgetSpan(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$countLabel\n',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: tagText,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (omittedCount > 0)
                  TextSpan(
                    text: omittedLabel,
                    style: TextStyle(
                      color: theme.colorScheme.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
  }

  /// 切换 tag group 选中状态
  Future<void> _toggleTagGroup(
    TagGroupTreeNode node,
    TagSubCategory category,
    bool currentlyEnabled,
  ) async {
    final notifier = ref.read(tagGroupMappingNotifierProvider.notifier);
    final state = ref.read(tagGroupMappingNotifierProvider);

    if (currentlyEnabled) {
      final mapping = state.config.mappings.firstWhere(
        (m) => m.groupTitle == node.title && m.enabled,
        orElse: () => TagGroupMapping(
          id: '',
          groupTitle: '',
          displayName: '',
          targetCategory: category,
          createdAt: DateTime.now(),
        ),
      );
      if (mapping.id.isNotEmpty) {
        await notifier.removeMapping(mapping.id);
      }
    } else {
      await notifier.addMapping(
        groupTitle: node.title,
        displayName: _getDisplayName(node),
        targetCategory: category,
        includeChildren: true,
      );
    }
  }

  /// 全选子分组
  Future<void> _selectAllInSubGroup(TagGroupTreeNode subGroup) async {
    final notifier = ref.read(tagGroupMappingNotifierProvider.notifier);
    final leafNodes = _collectLeafNodes(subGroup);

    final allGroups = <String, ({String displayName, TagSubCategory category, bool includeChildren})>{};
    for (final leaf in leafNodes) {
      allGroups[leaf.title] = (
        displayName: _getDisplayName(leaf),
        category: widget.category,
        includeChildren: true,
      );
    }

    final state = ref.read(tagGroupMappingNotifierProvider);
    final existingTitles = state.config.mappings
        .where((m) => m.enabled)
        .map((m) => m.groupTitle)
        .toSet();

    final newTitles = {...existingTitles, ...allGroups.keys};
    await notifier.updateSelectedGroupsWithTree(newTitles, allGroups);
  }

  /// 取消选择子分组
  Future<void> _deselectAllInSubGroup(TagGroupTreeNode subGroup) async {
    final notifier = ref.read(tagGroupMappingNotifierProvider.notifier);
    final state = ref.read(tagGroupMappingNotifierProvider);
    final leafTitles = _collectLeafTitles(subGroup).toSet();

    for (final mapping in state.config.mappings.where((m) => m.enabled)) {
      if (leafTitles.contains(mapping.groupTitle)) {
        await notifier.removeMapping(mapping.id);
      }
    }
  }

  /// 计算当前分类的动态标签总数
  int _calculateDynamicTagCount() {
    int count = 0;

    // 1. 内置词库标签数量
    final libraryState = ref.watch(tagLibraryNotifierProvider);
    final isBuiltinEnabled = libraryState.categoryFilterConfig.isBuiltinEnabled(widget.category);
    if (isBuiltinEnabled && libraryState.library != null) {
      // 获取内置标签（非 Danbooru 补充的标签）
      count += libraryState.library!.getCategory(widget.category)
          .where((t) => !t.isDanbooruSupplement)
          .length;
    }

    // 2. 已启用的 TagGroup 标签数量
    final tagGroupState = ref.watch(tagGroupMappingNotifierProvider);
    for (final mapping in tagGroupState.config.mappings.where((m) => m.enabled)) {
      if (mapping.targetCategory == widget.category) {
        count += mapping.lastSyncedTagCount;
      }
    }

    return count;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagGroupState = ref.watch(tagGroupMappingNotifierProvider);
    final categoryName = TagSubCategoryHelper.getDisplayName(widget.category);
    final dynamicTagCount = _calculateDynamicTagCount();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 头部（始终显示）
          InkWell(
            onTap: () => widget.onExpandChanged(!widget.isExpanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: widget.isExpanded ? Radius.zero : const Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 分类图标
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(widget.category),
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 分类名称和标签数
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.naiMode_tagCount(dynamicTagCount.toString()),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // 已选择的 tag 组名称列表
                  Expanded(
                    child: _buildSelectedTagGroupsPreview(theme, tagGroupState),
                  ),
                  const SizedBox(width: 8),
                  // 展开/收起按钮
                  Icon(
                    widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          // 展开内容
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: widget.isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(theme, tagGroupState),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(ThemeData theme, TagGroupMappingState state) {
    final tagGroups = _getTagGroupsForCategory(widget.category);
    final hasSubGroups = _hasSubGroups(widget.category);
    final enabledTitles = state.config.mappings
        .where((m) => m.enabled)
        .map((m) => m.groupTitle)
        .toSet();

    // 获取内置词库状态
    final libraryState = ref.watch(tagLibraryNotifierProvider);
    final isBuiltinEnabled = libraryState.categoryFilterConfig.isBuiltinEnabled(widget.category);

    return Column(
      children: [
        Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.1)),
        // Tag Group Chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // 内置词库 chip（始终在最前面）
                _buildBuiltinChip(theme, isBuiltinEnabled),
                // Danbooru tag group chips
                if (hasSubGroups)
                  ..._buildSubGroupChipsList(theme, tagGroups, enabledTitles)
                else
                  ..._buildFlatTagGroupChipsList(theme, tagGroups, enabledTitles),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建内置词库 chip
  Widget _buildBuiltinChip(ThemeData theme, bool isEnabled) {
    return Tooltip(
      richMessage: _getBuiltinPreviewSpan(),
      waitDuration: const Duration(milliseconds: 300),
      preferBelow: false,
      child: FilterChip(
        selected: isEnabled,
        label: Text(
          context.l10n.tagGroup_builtin,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isEnabled
                ? theme.colorScheme.onTertiaryContainer
                : theme.colorScheme.onSurface,
          ),
        ),
        avatar: Icon(
          Icons.inventory_2_outlined,
          size: 16,
          color: isEnabled
              ? theme.colorScheme.onTertiaryContainer
              : theme.colorScheme.outline,
        ),
        onSelected: (selected) {
          ref.read(tagLibraryNotifierProvider.notifier)
              .setBuiltinEnabled(widget.category, selected);
        },
        selectedColor: theme.colorScheme.tertiaryContainer,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  /// 获取内置词库预览文本
  InlineSpan _getBuiltinPreviewSpan() {
    final libraryState = ref.watch(tagLibraryNotifierProvider);
    final library = libraryState.library;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final theme = Theme.of(context);

    if (library == null) {
      final noDataText = isZh ? '暂无数据' : 'No data';
      return WidgetSpan(
        child: Text(noDataText, style: TextStyle(color: theme.colorScheme.outline)),
      );
    }

    // 获取内置标签（非 Danbooru 补充的标签）
    final builtinTags = library.getCategory(widget.category)
        .where((t) => !t.isDanbooruSupplement)
        .toList();

    if (builtinTags.isEmpty) {
      final emptyText = isZh ? '该分类暂无内置标签' : 'No built-in tags for this category';
      return WidgetSpan(
        child: Text(emptyText, style: TextStyle(color: theme.colorScheme.outline)),
      );
    }

    final count = builtinTags.length;
    final previewTags = builtinTags.take(20).map((t) => t.tag).toList();
    final tagText = previewTags.join(', ');
    final omittedCount = count - previewTags.length;
    final countLabel = isZh
        ? 'Tag数量：$count | 来源：内置词库'
        : 'Tag count: $count | Source: Built-in';
    final omittedLabel = omittedCount > 0
        ? (isZh ? '\n（省略了 $omittedCount 个）' : '\n($omittedCount more omitted)')
        : '';

    return WidgetSpan(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$countLabel\n',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              TextSpan(
                text: tagText,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (omittedCount > 0)
                TextSpan(
                  text: omittedLabel,
                  style: TextStyle(
                    color: theme.colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建扁平 tag_group chips 列表
  List<Widget> _buildFlatTagGroupChipsList(
    ThemeData theme,
    List<TagGroupTreeNode> tagGroups,
    Set<String> enabledTitles,
  ) {
    return tagGroups.where((node) => node.isTagGroup).map((node) {
      final isEnabled = enabledTitles.contains(node.title);
      return _buildTagGroupChip(theme, node, isEnabled);
    }).toList();
  }

  /// 构建子分组 chips 列表
  List<Widget> _buildSubGroupChipsList(
    ThemeData theme,
    List<TagGroupTreeNode> subGroups,
    Set<String> enabledTitles,
  ) {
    return subGroups.map((subGroup) {
      if (subGroup.isTagGroup) {
        final isEnabled = enabledTitles.contains(subGroup.title);
        return _buildTagGroupChip(theme, subGroup, isEnabled);
      }
      return _buildSubGroupPopoverChip(theme, subGroup, enabledTitles);
    }).toList();
  }

  /// 构建单个 TagGroup Chip
  Widget _buildTagGroupChip(
    ThemeData theme,
    TagGroupTreeNode node,
    bool isEnabled,
  ) {
    return MouseRegion(
      onEnter: (_) => _loadTagPreview(node.title),
      child: Tooltip(
        richMessage: _getPreviewSpan(node),
        waitDuration: const Duration(milliseconds: 300),
        preferBelow: false,
        child: FilterChip(
          selected: isEnabled,
          label: Text(
            _getDisplayName(node),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isEnabled
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface,
            ),
          ),
          onSelected: (_) => _toggleTagGroup(node, widget.category, isEnabled),
          selectedColor: theme.colorScheme.primaryContainer,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
    );
  }

  /// 构建子分组 Popover Chip
  Widget _buildSubGroupPopoverChip(
    ThemeData theme,
    TagGroupTreeNode subGroup,
    Set<String> enabledTitles,
  ) {
    final childTitles = _collectLeafTitles(subGroup);
    final enabledChildCount = childTitles.where((t) => enabledTitles.contains(t)).length;
    final totalChildCount = childTitles.length;
    final allChildrenEnabled = enabledChildCount == totalChildCount && totalChildCount > 0;
    final someChildrenEnabled = enabledChildCount > 0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showSubGroupDialog(subGroup, enabledTitles),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: allChildrenEnabled
                ? theme.colorScheme.primaryContainer
                : someChildrenEnabled
                    ? theme.colorScheme.primaryContainer.withOpacity(0.5)
                    : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_outlined,
                size: 18,
                color: someChildrenEnabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Text(
                '${_getDisplayName(subGroup)} ($enabledChildCount/$totalChildCount)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: someChildrenEnabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: someChildrenEnabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示子分组选择对话框
  void _showSubGroupDialog(TagGroupTreeNode subGroup, Set<String> enabledTitles) {
    showDialog(
      context: context,
      builder: (dialogContext) => _SubGroupSelectionDialog(
        subGroup: subGroup,
        category: widget.category,
        enabledTitles: enabledTitles,
        onToggle: (child, isEnabled) => _toggleTagGroup(child, widget.category, isEnabled),
        onSelectAll: () => _selectAllInSubGroup(subGroup),
        onDeselectAll: () => _deselectAllInSubGroup(subGroup),
        getDisplayName: _getDisplayName,
        loadTagPreview: _loadTagPreview,
        getPreviewSpan: _getPreviewSpan,
      ),
    );
  }

  IconData _getCategoryIcon(TagSubCategory category) {
    return switch (category) {
      TagSubCategory.hairColor => Icons.palette,
      TagSubCategory.eyeColor => Icons.remove_red_eye,
      TagSubCategory.hairStyle => Icons.face,
      TagSubCategory.expression => Icons.emoji_emotions,
      TagSubCategory.pose => Icons.accessibility_new,
      TagSubCategory.clothing => Icons.checkroom,
      TagSubCategory.accessory => Icons.watch,
      TagSubCategory.bodyFeature => Icons.accessibility,
      TagSubCategory.background => Icons.landscape,
      TagSubCategory.scene => Icons.photo_camera,
      TagSubCategory.style => Icons.brush,
      TagSubCategory.characterCount => Icons.group,
      _ => Icons.label,
    };
  }
}

/// 子分组选择对话框
class _SubGroupSelectionDialog extends ConsumerWidget {
  final TagGroupTreeNode subGroup;
  final TagSubCategory category;
  final Set<String> enabledTitles;
  final void Function(TagGroupTreeNode child, bool isEnabled) onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final String Function(TagGroupTreeNode node) getDisplayName;
  final Future<void> Function(String groupTitle) loadTagPreview;
  final InlineSpan Function(TagGroupTreeNode node) getPreviewSpan;

  const _SubGroupSelectionDialog({
    required this.subGroup,
    required this.category,
    required this.enabledTitles,
    required this.onToggle,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.getDisplayName,
    required this.loadTagPreview,
    required this.getPreviewSpan,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final state = ref.watch(tagGroupMappingNotifierProvider);
    final currentEnabledTitles = state.config.mappings
        .where((m) => m.enabled)
        .map((m) => m.groupTitle)
        .toSet();

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              getDisplayName(subGroup),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              onSelectAll();
            },
            icon: const Icon(Icons.check_box_outlined, size: 20),
            tooltip: context.l10n.common_selectAll,
            color: theme.colorScheme.primary,
          ),
          IconButton(
            onPressed: () {
              onDeselectAll();
            },
            icon: const Icon(Icons.check_box_outline_blank, size: 20),
            tooltip: context.l10n.common_deselectAll,
            color: theme.colorScheme.outline,
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: subGroup.children.map((child) {
            final isEnabled = currentEnabledTitles.contains(child.title);
            return MouseRegion(
              onEnter: (_) => loadTagPreview(child.title),
              child: Tooltip(
                richMessage: getPreviewSpan(child),
                waitDuration: const Duration(milliseconds: 300),
                preferBelow: false,
                child: ListTile(
                  leading: Icon(
                    isEnabled ? Icons.check_box : Icons.check_box_outline_blank,
                    color: isEnabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  title: Text(
                    locale == 'zh' ? child.displayNameZh : child.displayNameEn,
                    style: TextStyle(
                      color: isEnabled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontWeight: isEnabled ? FontWeight.w500 : null,
                    ),
                  ),
                  onTap: () => onToggle(child, isEnabled),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_close),
        ),
      ],
    );
  }
}
