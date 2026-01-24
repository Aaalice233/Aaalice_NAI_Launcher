import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/character_count_config.dart'
    show defaultSlotOptions;
import '../../../../data/models/prompt/danbooru_tag_group_tree.dart';
import '../../../../data/models/prompt/default_category_emojis.dart';
import '../../../../data/models/prompt/pool_mapping.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/random_tag_group.dart';
import '../../../../data/models/prompt/tag_category.dart';
import '../../../../data/models/prompt/tag_group_mapping.dart';
import '../../../../data/models/prompt/tag_group_preset_cache.dart';
import '../../../../data/models/prompt/tag_library.dart';
import '../../../../data/models/prompt/weighted_tag.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../providers/tag_group_sync_provider.dart';
import '../../../providers/tag_library_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/prompt/tag_group_settings_dialog.dart';
import 'add_group_dialog.dart';

/// 可展开的分类卡片
///
/// 用于显示 NAI 模式下的分类信息和分组管理
class ExpandableCategoryTile extends ConsumerStatefulWidget {
  final TagSubCategory category;
  final int probability;
  final List<WeightedTag> tags;
  final VoidCallback onSyncCategory;
  final VoidCallback onShowDetail;
  final bool isExpanded;
  final ValueChanged<bool> onExpandChanged;
  final bool isEnabled;
  final ValueChanged<bool>? onEnabledChanged;
  final VoidCallback? onSettings;
  final VoidCallback? onRemove;

  const ExpandableCategoryTile({
    super.key,
    required this.category,
    required this.probability,
    required this.tags,
    required this.onSyncCategory,
    required this.onShowDetail,
    required this.isExpanded,
    required this.onExpandChanged,
    this.isEnabled = true,
    this.onEnabledChanged,
    this.onSettings,
    this.onRemove,
  });

  @override
  ConsumerState<ExpandableCategoryTile> createState() =>
      _ExpandableCategoryTileState();
}

class _ExpandableCategoryTileState
    extends ConsumerState<ExpandableCategoryTile> {
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

  /// 获取显示名称
  String _getDisplayName(TagGroupTreeNode node) {
    final locale = Localizations.localeOf(context).languageCode;
    return locale == 'zh' ? node.displayNameZh : node.displayNameEn;
  }

  /// 构建已选择的 tag 组预览（显示在头部行）
  Widget _buildSelectedTagGroupsPreview(
    ThemeData theme,
    List<TagGroupMapping> mappings,
  ) {
    final tagGroups = _getTagGroupsForCategory(widget.category);
    final enabledTitles =
        mappings.where((m) => m.enabled).map((m) => m.groupTitle).toSet();

    // 获取当前预设和类别
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final randomCategory = preset?.findCategoryByKey(widget.category.name);

    // 收集当前分类下已选择的 tag group 显示名称
    final selectedNames = <String>[];

    // 添加 category.groups 中启用的分组名称（包括 builtin 和 custom 类型）
    if (randomCategory != null) {
      for (final group in randomCategory.groups) {
        if (group.enabled) {
          // builtin 类型自动添加后缀以区分
          final displayName = group.sourceType == TagGroupSourceType.builtin
              ? '${group.name}（${context.l10n.tagGroup_builtin}）'
              : group.name;
          selectedNames.add(displayName);
        }
      }
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

  /// 计算当前分类的动态标签总数（不受启用状态影响，始终显示实际数量）
  int _calculateDynamicTagCount() {
    int count = 0;

    final libraryState = ref.watch(tagLibraryNotifierProvider);
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;

    // 1. 从 RandomCategory.groups 中获取 builtin 类型分组的标签数
    final randomCategory = preset?.findCategoryByKey(widget.category.name);
    if (randomCategory != null && libraryState.library != null) {
      for (final group in randomCategory.groups) {
        if (group.sourceType == TagGroupSourceType.builtin &&
            group.sourceId != null) {
          // 根据 sourceId 获取对应的 TagSubCategory
          final builtinCategory =
              TagSubCategory.values.cast<TagSubCategory?>().firstWhere(
                    (c) => c?.name == group.sourceId,
                    orElse: () => null,
                  );
          if (builtinCategory != null) {
            count += libraryState.library!
                .getCategory(builtinCategory)
                .where((t) => !t.isDanbooruSupplement)
                .length;
          }
        }
      }
    }

    // 2. 向后兼容：如果没有 builtin 类型分组，仍然计入当前分类的内置标签（旧逻辑）
    if (randomCategory == null ||
        !randomCategory.groups
            .any((g) => g.sourceType == TagGroupSourceType.builtin)) {
      if (libraryState.library != null) {
        // 检查是否启用了当前分类的内置词库（旧逻辑）
        if (libraryState.categoryFilterConfig
            .isBuiltinEnabled(widget.category)) {
          count += libraryState.library!
              .getCategory(widget.category)
              .where((t) => !t.isDanbooruSupplement)
              .length;
        }
      }
    }

    // 3. TagGroup 标签数量（始终计入）
    final syncState = ref.watch(tagGroupSyncNotifierProvider);
    final tagGroupMappings = preset?.tagGroupMappings ?? [];
    for (final mapping in tagGroupMappings) {
      if (mapping.targetCategory == widget.category) {
        // 优先使用实时过滤数量，其次使用已同步数量，最后使用预缓存数量
        final tagCount = syncState.filteredTagCounts[mapping.groupTitle] ??
            (mapping.lastSyncedTagCount > 0
                ? mapping.lastSyncedTagCount
                : null) ??
            TagGroupPresetCache.getCount(mapping.groupTitle) ??
            0;
        count += tagCount;
      }
    }

    // 4. Pool 映射帖子数量（显示已缓存的帖子数量）
    final poolMappings = preset?.poolMappings ?? [];
    for (final poolMapping in poolMappings) {
      if (poolMapping.targetCategory == widget.category) {
        count += poolMapping.lastSyncedPostCount;
      }
    }

    return count;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final tagGroupMappings = preset?.tagGroupMappings ?? [];
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
              bottom:
                  widget.isExpanded ? Radius.zero : const Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 分类图标
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child: Text(
                        DefaultCategoryEmojis.getTagSubCategoryEmoji(
                            widget.category,),
                        style: const TextStyle(fontSize: 24),
                      ),
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
                          color: widget.isEnabled
                              ? null
                              : theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n
                            .naiMode_tagCount(dynamicTagCount.toString()),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // 已选择的 tag 组名称列表
                  Expanded(
                    child:
                        _buildSelectedTagGroupsPreview(theme, tagGroupMappings),
                  ),
                  // 操作按钮区域
                  if (widget.onSettings != null) ...[
                    TextButton.icon(
                      icon: Icon(
                        Icons.settings_outlined,
                        size: 16,
                        color: theme.colorScheme.outline,
                      ),
                      label: Text(
                        context.l10n.common_settings,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      onPressed: widget.onSettings,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8,),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (widget.onRemove != null) ...[
                    TextButton.icon(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: theme.colorScheme.error.withOpacity(0.7),
                      ),
                      label: Text(
                        context.l10n.common_delete,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error.withOpacity(0.7),
                        ),
                      ),
                      onPressed: widget.onRemove,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8,),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (widget.onEnabledChanged != null)
                    Tooltip(
                      message: widget.isEnabled
                          ? context.l10n.promptConfig_disableCategory
                          : context.l10n.promptConfig_enableCategory,
                      child: Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: widget.isEnabled,
                          onChanged: widget.onEnabledChanged,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  // 概率显示徽章
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.secondaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.probability}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
          // 展开内容（收起时不渲染，提升性能）
          if (widget.isExpanded) _buildExpandedContent(theme, tagGroupMappings),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(
    ThemeData theme,
    List<TagGroupMapping> mappings,
  ) {
    // 获取内置词库状态
    final libraryState = ref.watch(tagLibraryNotifierProvider);

    // 获取同步状态（用于 filteredTagCounts）
    final syncState = ref.watch(tagGroupSyncNotifierProvider);

    // 获取当前类别的所有 TagGroup 映射（包括禁用的）
    final categoryMappings =
        mappings.where((m) => m.targetCategory == widget.category).toList();

    // 获取预设状态，用于 Pool 映射
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final poolMappings = preset?.poolMappings ?? [];

    // 获取当前类别的所有 Pool 映射（包括禁用的）
    final categoryPoolMappings =
        poolMappings.where((m) => m.targetCategory == widget.category).toList();

    // 获取当前 RandomCategory 及其内部分组（包括 builtin 和 custom 类型）
    final randomCategory = preset?.findCategoryByKey(widget.category.name);
    final categoryGroups = randomCategory?.groups ?? [];

    // 计算分组总数（builtin分组 + TagGroup 映射数量 + Pool 映射数量）
    final totalGroupCount = categoryGroups.length +
        categoryMappings.length +
        categoryPoolMappings.length;

    // 计算当前类别是否全选（只考虑显示的分组）
    final allBuiltinGroupsEnabled =
        categoryGroups.isEmpty || categoryGroups.every((g) => g.enabled);
    final allTagGroupMappingsEnabled =
        categoryMappings.isEmpty || categoryMappings.every((m) => m.enabled);
    final allPoolMappingsEnabled = categoryPoolMappings.isEmpty ||
        categoryPoolMappings.every((m) => m.enabled);
    // 全选要考虑 builtin 分组、TagGroup 和 Pool 映射
    final allSelected = allBuiltinGroupsEnabled &&
        allTagGroupMappingsEnabled &&
        allPoolMappingsEnabled;

    return Column(
      children: [
        Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.1)),
        // 统一的分组管理区域
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 分组区域标题
              Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.promptConfig_groupList,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.promptConfig_groupCount(totalGroupCount),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline.withOpacity(0.7),
                    ),
                  ),
                  const Spacer(),
                  // 全选/全不选按钮
                  TextButton.icon(
                    onPressed: () => _toggleCategoryGroups(
                      categoryGroups,
                      categoryMappings,
                      categoryPoolMappings,
                      !allSelected,
                    ),
                    icon: Icon(
                      allSelected ? Icons.deselect : Icons.select_all,
                      size: 16,
                    ),
                    label: Text(
                      allSelected
                          ? context.l10n.common_deselectAll
                          : context.l10n.common_selectAll,
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 添加分组按钮
                  TextButton.icon(
                    onPressed: () => _showAddGroupDialog(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(context.l10n.promptConfig_addGroup),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 分组列表
              if (totalGroupCount == 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.promptConfig_noGroups,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    // Builtin 类型分组（从 category.groups 中获取）
                    ...categoryGroups.map((group) {
                      return _buildRandomTagGroupCard(
                        theme,
                        group,
                        libraryState.library,
                      );
                    }),
                    // TagGroup 映射分组
                    ...categoryMappings.map((mapping) {
                      final tagCount = syncState
                              .filteredTagCounts[mapping.groupTitle] ??
                          (mapping.lastSyncedTagCount > 0
                              ? mapping.lastSyncedTagCount
                              : null) ??
                          TagGroupPresetCache.getCount(mapping.groupTitle) ??
                          0;
                      return _buildTagGroupMappingCard(
                        theme,
                        mapping,
                        tagCount,
                      );
                    }),
                    // Pool 映射分组
                    ...categoryPoolMappings.map((poolMapping) {
                      return _buildPoolMappingCard(theme, poolMapping);
                    }),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建统一的分组卡片
  ///
  /// [countLabel] 数量显示文本（如 "10 个标签" 或 "20 帖子"）
  Widget _buildGroupCard({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required String emoji,
    required String countLabel,
    required bool isEnabled,
    required ValueChanged<bool> onToggleEnabled,
    required VoidCallback onDelete,
    VoidCallback? onSettings,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isEnabled
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEnabled
              ? theme.colorScheme.outline.withOpacity(0.2)
              : theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: SizedBox(
          width: 32,
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isEnabled ? null : theme.colorScheme.outline,
          ),
        ),
        subtitle: Text(
          '$countLabel · $subtitle',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 设置按钮
            if (onSettings != null)
              TextButton.icon(
                icon: Icon(
                  Icons.settings_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                label: Text(
                  context.l10n.common_settings,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: onSettings,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            // 删除按钮
            TextButton.icon(
              icon: Icon(
                Icons.delete_outline,
                size: 16,
                color: theme.colorScheme.error,
              ),
              label: Text(
                context.l10n.common_delete,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: onDelete,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            // 启用开关
            Switch(
              value: isEnabled,
              onChanged: onToggleEnabled,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建 RandomTagGroup 分组卡片（包括 builtin 和 custom 类型）
  Widget _buildRandomTagGroupCard(
    ThemeData theme,
    RandomTagGroup group,
    TagLibrary? library,
  ) {
    // 计算标签数量
    int tagCount = 0;
    String subtitle;

    if (group.sourceType == TagGroupSourceType.builtin) {
      // builtin 类型：从 TagLibrary 获取标签数量
      final sourceCategory =
          TagSubCategory.values.cast<TagSubCategory?>().firstWhere(
                (c) => c?.name == group.sourceId,
                orElse: () => null,
              );
      if (sourceCategory != null && library != null) {
        tagCount = library
            .getCategory(sourceCategory)
            .where((t) => !t.isDanbooruSupplement)
            .length;
      }
      subtitle = context.l10n.promptConfig_builtinLibrary;
    } else {
      // custom 类型：从 group.tags 获取标签数量
      tagCount = group.tags.length;
      subtitle = context.l10n.promptConfig_customGroup;
    }

    // 获取当前 RandomCategory
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final randomCategory = preset?.findCategoryByKey(widget.category.name);

    // builtin 类型自动添加后缀以区分
    final displayName = group.sourceType == TagGroupSourceType.builtin
        ? '${group.name}（${context.l10n.tagGroup_builtin}）'
        : group.name;

    return _buildGroupCard(
      theme: theme,
      title: displayName,
      subtitle: subtitle,
      emoji: group.emoji,
      countLabel: '$tagCount ${context.l10n.promptConfig_tagCountUnit}',
      isEnabled: group.enabled,
      onToggleEnabled: (enabled) async {
        await ref
            .read(randomPresetNotifierProvider.notifier)
            .toggleGroupEnabled(
              widget.category.name,
              group.id,
            );
      },
      onDelete: () async {
        await ref
            .read(randomPresetNotifierProvider.notifier)
            .removeGroupFromCategory(
              widget.category.name,
              group.id,
            );
      },
      onSettings: randomCategory != null
          ? () => _showTagGroupSettings(randomCategory, group)
          : null,
    );
  }

  /// 显示词组设置对话框
  void _showTagGroupSettings(
    RandomCategory category,
    RandomTagGroup tagGroup,
  ) {
    final preset = ref.read(randomPresetNotifierProvider).selectedPreset;
    final customSlotOptions =
        preset?.algorithmConfig.characterCountConfig?.customSlotOptions ??
            defaultSlotOptions;

    TagGroupSettingsDialog.show(
      context: context,
      tagGroup: tagGroup,
      customSlotOptions: customSlotOptions,
      parentCategory: category,
      onSave: (updatedTagGroup) async {
        final notifier = ref.read(randomPresetNotifierProvider.notifier);
        final currentPreset =
            ref.read(randomPresetNotifierProvider).selectedPreset;

        // 更新 RandomCategory 中的 RandomTagGroup
        final updatedCategory = category.updateGroup(updatedTagGroup);

        // 检查类别是否已存在于预设中
        final existingCategory = currentPreset?.categories.any(
          (c) => c.id == category.id,
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

  /// 构建 TagGroup 映射分组卡片
  Widget _buildTagGroupMappingCard(
    ThemeData theme,
    TagGroupMapping mapping,
    int tagCount,
  ) {
    // 获取对应的 RandomTagGroup 用于设置
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final categories = preset?.categories ?? [];

    // 查找对应的 RandomCategory
    final randomCategory = categories.cast<RandomCategory?>().firstWhere(
          (c) => c?.key == widget.category.name,
          orElse: () => null,
        );

    // 通过 groupTitle 查找对应的 RandomTagGroup
    final tagGroup = randomCategory?.groups.cast<RandomTagGroup?>().firstWhere(
          (g) =>
              g?.sourceId == mapping.groupTitle ||
              g?.name == mapping.displayName,
          orElse: () => null,
        );

    return _buildGroupCard(
      theme: theme,
      title: mapping.displayName,
      subtitle: context.l10n.promptConfig_danbooruTagGroup,
      emoji: '☁️',
      countLabel: '$tagCount ${context.l10n.promptConfig_tagCountUnit}',
      isEnabled: mapping.enabled,
      onToggleEnabled: (enabled) =>
          _toggleTagGroupMappingEnabled(mapping, enabled),
      onDelete: () => _deleteTagGroupMapping(mapping),
      onSettings: tagGroup != null && randomCategory != null
          ? () => _showTagGroupSettings(randomCategory, tagGroup)
          : () => _createAndShowTagGroupSettings(mapping),
    );
  }

  /// 为 TagGroupMapping 创建 RandomTagGroup 并显示设置对话框
  void _createAndShowTagGroupSettings(TagGroupMapping mapping) async {
    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    final preset = ref.read(randomPresetNotifierProvider).selectedPreset;
    if (preset == null) return;

    // 查找或创建 RandomCategory
    var randomCategory = preset.categories.cast<RandomCategory?>().firstWhere(
          (c) => c?.key == widget.category.name,
          orElse: () => null,
        );

    if (randomCategory == null) {
      // 创建新的 RandomCategory
      randomCategory = RandomCategory.create(
        name: widget.category.name,
        key: widget.category.name,
      );
      await notifier.addCategory(randomCategory);
    }

    // 创建新的 RandomTagGroup
    final newTagGroup = RandomTagGroup.fromTagGroup(
      name: mapping.displayName,
      tagGroupName: mapping.groupTitle,
      tags: [],
    );

    // 更新 RandomCategory，添加新的 RandomTagGroup
    final updatedCategory = randomCategory.addGroup(newTagGroup);
    await notifier.updateCategory(updatedCategory);

    // 显示设置对话框
    if (mounted) {
      final currentPreset =
          ref.read(randomPresetNotifierProvider).selectedPreset;
      final customSlotOptions = currentPreset
              ?.algorithmConfig.characterCountConfig?.customSlotOptions ??
          defaultSlotOptions;

      TagGroupSettingsDialog.show(
        context: context,
        tagGroup: newTagGroup,
        customSlotOptions: customSlotOptions,
        parentCategory: randomCategory,
        onSave: (updatedTagGroup) async {
          final latestCategory = ref
              .read(randomPresetNotifierProvider)
              .selectedPreset
              ?.categories
              .firstWhere((c) => c.key == widget.category.name);
          if (latestCategory != null) {
            final finalCategory = latestCategory.updateGroup(updatedTagGroup);
            await notifier.updateCategory(finalCategory);
            if (mounted) {
              AppToast.success(context, context.l10n.common_saved);
            }
          }
        },
      );
    }
  }

  /// 删除 TagGroup 映射
  Future<void> _deleteTagGroupMapping(TagGroupMapping mapping) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.common_confirmDelete),
        content:
            Text(l10n.promptConfig_confirmRemoveGroup(mapping.displayName)),
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
      ref
          .read(randomPresetNotifierProvider.notifier)
          .removeTagGroupMapping(mapping.id);
    }
  }

  /// 切换 TagGroup 映射启用状态
  void _toggleTagGroupMappingEnabled(TagGroupMapping mapping, bool enabled) {
    ref
        .read(randomPresetNotifierProvider.notifier)
        .toggleTagGroupMappingEnabled(mapping.id);
  }

  /// 构建 Pool 映射分组卡片
  Widget _buildPoolMappingCard(ThemeData theme, PoolMapping poolMapping) {
    // 获取对应的 RandomTagGroup 用于设置
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final categories = preset?.categories ?? [];

    // 查找对应的 RandomCategory
    final randomCategory = categories.cast<RandomCategory?>().firstWhere(
          (c) => c?.key == widget.category.name,
          orElse: () => null,
        );

    // 通过 poolId 查找对应的 RandomTagGroup
    final tagGroup = randomCategory?.groups.cast<RandomTagGroup?>().firstWhere(
          (g) =>
              g?.sourceId == poolMapping.poolId.toString() ||
              g?.name == poolMapping.poolDisplayName,
          orElse: () => null,
        );

    // Pool 使用通用的构建方法，显示帖子数量而非标签数量
    return _buildGroupCard(
      theme: theme,
      title: poolMapping.poolDisplayName,
      subtitle: context.l10n.promptConfig_danbooruPool,
      emoji: '🖼️',
      countLabel:
          '${poolMapping.lastSyncedPostCount} ${context.l10n.cache_posts}',
      isEnabled: poolMapping.enabled,
      onToggleEnabled: (enabled) =>
          _togglePoolMappingEnabled(poolMapping, enabled),
      onDelete: () => _deletePoolMapping(poolMapping),
      onSettings: tagGroup != null && randomCategory != null
          ? () => _showTagGroupSettings(randomCategory, tagGroup)
          : () => _createAndShowPoolSettings(poolMapping),
    );
  }

  /// 切换 Pool 映射启用状态
  void _togglePoolMappingEnabled(PoolMapping poolMapping, bool enabled) {
    ref
        .read(randomPresetNotifierProvider.notifier)
        .togglePoolMappingEnabled(poolMapping.id);
  }

  /// 删除 Pool 映射
  Future<void> _deletePoolMapping(PoolMapping poolMapping) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.common_confirmDelete),
        content: Text(
          l10n.promptConfig_confirmRemoveGroup(poolMapping.poolDisplayName),
        ),
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
      ref
          .read(randomPresetNotifierProvider.notifier)
          .removePoolMapping(poolMapping.id);
    }
  }

  /// 为 PoolMapping 创建 RandomTagGroup 并显示设置对话框
  void _createAndShowPoolSettings(PoolMapping poolMapping) async {
    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    final preset = ref.read(randomPresetNotifierProvider).selectedPreset;
    if (preset == null) return;

    // 查找或创建 RandomCategory
    var randomCategory = preset.categories.cast<RandomCategory?>().firstWhere(
          (c) => c?.key == widget.category.name,
          orElse: () => null,
        );

    if (randomCategory == null) {
      // 创建新的 RandomCategory
      randomCategory = RandomCategory.create(
        name: widget.category.name,
        key: widget.category.name,
      );
      await notifier.addCategory(randomCategory);
    }

    // 创建新的 RandomTagGroup（基于 Pool）
    final newTagGroup = RandomTagGroup.fromPool(
      name: poolMapping.poolDisplayName,
      poolId: poolMapping.poolId.toString(),
      postCount: poolMapping.lastSyncedPostCount,
    );

    // 更新 RandomCategory，添加新的 RandomTagGroup
    final updatedCategory = randomCategory.addGroup(newTagGroup);
    await notifier.updateCategory(updatedCategory);

    // 显示设置对话框
    if (mounted) {
      final customSlotOptions =
          preset.algorithmConfig.characterCountConfig?.customSlotOptions ??
              defaultSlotOptions;

      TagGroupSettingsDialog.show(
        context: context,
        tagGroup: newTagGroup,
        customSlotOptions: customSlotOptions,
        parentCategory: randomCategory,
        onSave: (updatedTagGroup) async {
          final latestCategory = ref
              .read(randomPresetNotifierProvider)
              .selectedPreset
              ?.categories
              .firstWhere((c) => c.key == widget.category.name);
          if (latestCategory != null) {
            final finalCategory = latestCategory.updateGroup(updatedTagGroup);
            await notifier.updateCategory(finalCategory);
            if (mounted) {
              AppToast.success(context, context.l10n.common_saved);
            }
          }
        },
      );
    }
  }

  /// 切换当前类别下所有分组的启用状态
  Future<void> _toggleCategoryGroups(
    List<RandomTagGroup> categoryGroups,
    List<TagGroupMapping> categoryMappings,
    List<PoolMapping> categoryPoolMappings,
    bool enabled,
  ) async {
    final notifier = ref.read(randomPresetNotifierProvider.notifier);

    // 切换所有 builtin 分组状态
    for (final group in categoryGroups) {
      if (group.enabled != enabled) {
        await notifier.toggleGroupEnabled(widget.category.name, group.id);
      }
    }

    // 切换所有 TagGroup 映射状态
    for (final mapping in categoryMappings) {
      if (mapping.enabled != enabled) {
        notifier.toggleTagGroupMappingEnabled(mapping.id);
      }
    }

    // 切换所有 Pool 映射状态
    for (final poolMapping in categoryPoolMappings) {
      if (poolMapping.enabled != enabled) {
        notifier.togglePoolMappingEnabled(poolMapping.id);
      }
    }
  }

  /// 显示添加分组对话框 (NAI 模式)
  Future<void> _showAddGroupDialog(BuildContext context) async {
    final category = widget.category;
    final presetNotifier = ref.read(randomPresetNotifierProvider.notifier);
    final libraryState = ref.read(tagLibraryNotifierProvider);
    final presetState = ref.read(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final tagGroupMappings = preset?.tagGroupMappings ?? [];

    // 获取所有已存在的 groupTitle 列表（用于去重，不限定分类）
    final existingGroupTitles =
        tagGroupMappings.map((m) => m.groupTitle).toSet();

    // 检查内置词库是否已启用
    final isBuiltinEnabled =
        libraryState.categoryFilterConfig.isBuiltinEnabled(category);

    // 捕获 context 引用
    final currentContext = context;
    final locale = Localizations.localeOf(context).languageCode;

    // 显示选择对话框
    final result = await AddGroupDialog.show(
      currentContext,
      theme: Theme.of(currentContext),
      category: category,
      isBuiltinEnabled: isBuiltinEnabled,
      existingGroupTitles: existingGroupTitles,
      locale: locale,
    );

    if (result == null || !mounted) return;

    try {
      switch (result.type) {
        case AddGroupType.builtin:
          // 创建内置词库分组并添加到类别
          final builtinGroup = RandomTagGroup.fromBuiltin(
            name: result.displayName ?? result.builtinCategoryKey ?? 'NAI内置',
            builtinCategoryKey: result.builtinCategoryKey!,
            emoji: result.emoji ?? '✨',
          );
          await presetNotifier.addGroupToCategory(
            category.name,
            builtinGroup,
          );
          break;
        case AddGroupType.tagGroup:
          // 添加 Tag Group 映射，使用用户选择的目标分类（如果有的话）
          final targetCategory = result.targetCategory ?? category;
          await presetNotifier.addTagGroupMapping(
            TagGroupMapping(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              groupTitle: result.groupTitle!,
              displayName: result.displayName!,
              targetCategory: targetCategory,
              createdAt: DateTime.now(),
              includeChildren: result.includeChildren,
            ),
          );
          break;
        case AddGroupType.danbooruPool:
          // 添加 Pool 映射
          final targetCategory = result.targetCategory ?? category;
          await presetNotifier.addPoolMapping(
            PoolMapping(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              poolId: result.poolId!,
              poolName: result.poolName!,
              postCount: result.postCount ?? 0,
              lastSyncedPostCount: result.postCount ?? 0,
              targetCategory: targetCategory,
              createdAt: DateTime.now(),
            ),
          );
          break;
        case AddGroupType.custom:
          // 添加自定义词组
          if (result.customGroup != null) {
            await presetNotifier.addGroupToCategory(
              category.name,
              result.customGroup!,
            );
          }
          break;
      }
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      AppToast.error(
          // ignore: use_build_context_synchronously
          currentContext,
          // ignore: use_build_context_synchronously
          currentContext.l10n.addGroup_addFailed(e.toString()),);
    }
  }
}
