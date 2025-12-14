import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/datasources/remote/danbooru_tag_group_service.dart';
import '../../../data/models/prompt/danbooru_tag_group_tree.dart';
import '../../../data/models/prompt/tag_category.dart';
import '../../../data/models/prompt/tag_group_mapping.dart';
import '../../../data/models/prompt/tag_group.dart';
import '../../providers/tag_group_mapping_provider.dart';
import '../../widgets/common/app_toast.dart';

/// Tag Group 映射管理面板
/// 按类别分组显示，每个类别可展开选择 tag_group
class TagGroupMappingPanel extends ConsumerStatefulWidget {
  const TagGroupMappingPanel({super.key});

  @override
  ConsumerState<TagGroupMappingPanel> createState() =>
      _TagGroupMappingPanelState();
}

class _TagGroupMappingPanelState extends ConsumerState<TagGroupMappingPanel> {

  /// 标签预览缓存
  final Map<String, List<String>> _previewCache = {};

  /// 标签总数缓存（用于显示真实总数而非预览数量）
  final Map<String, int> _totalCountCache = {};

  /// 正在加载的组
  final Set<String> _loadingGroups = {};

  /// 支持的类别列表（按显示顺序）
  static const List<TagSubCategory> _supportedCategories = [
    TagSubCategory.hairColor,
    TagSubCategory.eyeColor,
    TagSubCategory.hairStyle,
    TagSubCategory.expression,
    TagSubCategory.pose,
    TagSubCategory.clothing,
    TagSubCategory.accessory,
    TagSubCategory.bodyFeature,
    TagSubCategory.background,
    TagSubCategory.scene,
    TagSubCategory.style,
    TagSubCategory.other, // 包含嵌套子分组：动物、物品、活动等
  ];

  /// 按类别分组映射
  Map<TagSubCategory, List<TagGroupMapping>> _groupMappingsByCategory(
    List<TagGroupMapping> mappings,
  ) {
    final result = <TagSubCategory, List<TagGroupMapping>>{};
    for (final mapping in mappings) {
      result.putIfAbsent(mapping.targetCategory, () => []).add(mapping);
    }
    return result;
  }

  /// 获取分类对应的 tag groups（直接子节点，保留层级结构）
  List<TagGroupTreeNode> _getTagGroupsForCategory(TagSubCategory category) {
    final categoryNode = DanbooruTagGroupTree.tree.firstWhere(
      (n) => n.category == category,
      orElse: () => const TagGroupTreeNode(
        title: '',
        displayNameZh: '',
        displayNameEn: '',
      ),
    );
    // 返回直接子节点而不是展平的叶子节点
    return categoryNode.children;
  }

  /// 递归收集所有叶子节点（用于统计）
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

  /// 收集节点下所有叶子节点的 title（用于批量操作）
  List<String> _collectLeafTitles(TagGroupTreeNode node) {
    return _collectLeafNodes(node).map((n) => n.title).toList();
  }

  /// 判断分类是否包含子分组（非叶子节点的子节点）
  bool _hasSubGroups(TagSubCategory category) {
    final groups = _getTagGroupsForCategory(category);
    return groups.any((node) => !node.isTagGroup);
  }

  /// 获取显示名称
  String _getDisplayName(TagGroupTreeNode node) {
    final locale = Localizations.localeOf(context).languageCode;
    return locale == 'zh' ? node.displayNameZh : node.displayNameEn;
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
      // 禁用：找到对应的 mapping 并移除
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
      // 启用：添加新映射
      await notifier.addMapping(
        groupTitle: node.title,
        displayName: _getDisplayName(node),
        targetCategory: category,
        includeChildren: true,
      );
    }
  }

  /// 全选所有 tag groups（包括嵌套的叶子节点）
  Future<void> _selectAll() async {
    final notifier = ref.read(tagGroupMappingNotifierProvider.notifier);

    final allGroups = <String, ({String displayName, TagSubCategory category, bool includeChildren})>{};

    for (final category in _supportedCategories) {
      final groups = _getTagGroupsForCategory(category);
      for (final group in groups) {
        // 递归收集所有叶子节点
        final leafNodes = _collectLeafNodes(group);
        for (final leaf in leafNodes) {
          allGroups[leaf.title] = (
            displayName: _getDisplayName(leaf),
            category: category,
            includeChildren: true,
          );
        }
      }
    }

    final selectedTitles = allGroups.keys.toSet();
    await notifier.updateSelectedGroupsWithTree(selectedTitles, allGroups);
  }

  /// 取消全选
  Future<void> _deselectAll() async {
    final notifier = ref.read(tagGroupMappingNotifierProvider.notifier);
    final currentState = ref.read(tagGroupMappingNotifierProvider);

    // 禁用所有映射
    for (final mapping in currentState.config.mappings.where((m) => m.enabled)) {
      await notifier.removeMapping(mapping.id);
    }
  }

  /// 确认恢复默认
  void _confirmResetToDefault() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.tagGroup_resetToDefault),
        content: Text(context.l10n.tagGroup_resetConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref
                  .read(tagGroupMappingNotifierProvider.notifier)
                  .resetToDefault();
              AppToast.success(context, context.l10n.tagGroup_resetSuccess);
            },
            child: Text(context.l10n.common_confirm),
          ),
        ],
      ),
    );
  }

  /// 加载标签预览数据
  Future<void> _loadTagPreview(String groupTitle) async {
    if (_previewCache.containsKey(groupTitle) ||
        _loadingGroups.contains(groupTitle)) {
      return;
    }

    _loadingGroups.add(groupTitle);
    if (mounted) setState(() {});

    try {
      final service = ref.read(danbooruTagGroupServiceProvider);
      final group =
          await service.getTagGroup(groupTitle, fetchPostCounts: false);

      if (group != null && mounted) {
        // 过滤掉子组引用（以 tag_group 开头的条目），只保留真正的标签
        final actualTags = group.tags
            .where((t) => !t.name.startsWith('tag_group'))
            .toList();
        // 缓存真实的总标签数
        _totalCountCache[groupTitle] = actualTags.length;
        // 预览只显示前20个
        _previewCache[groupTitle] =
            actualTags.take(20).map((t) => t.name).toList();
        setState(() {});
      }
    } catch (e) {
      // 静默失败
    } finally {
      _loadingGroups.remove(groupTitle);
      if (mounted) setState(() {});
    }
  }

  /// 加载已启用的 tag_group 的标签数量（用于分类标题显示）
  Future<void> _loadEnabledTagGroupCounts(TagGroupMappingState state) async {
    final enabledTitles = state.config.mappings
        .where((m) => m.enabled)
        .map((m) => m.groupTitle)
        .toSet();

    // 过滤掉已缓存的
    final titlesToLoad = enabledTitles
        .where((t) => !_totalCountCache.containsKey(t) && !_loadingGroups.contains(t))
        .toList();

    if (titlesToLoad.isEmpty) return;

    // 并行加载所有未缓存的 tag_group
    for (final title in titlesToLoad) {
      _loadTagPreview(title);
    }
  }

  /// 获取预览文本
  InlineSpan _getPreviewSpan(TagGroupTreeNode node) {
    final displayName = _getDisplayName(node);
    final tags = _previewCache[node.title];
    final totalCount = _totalCountCache[node.title];
    final isLoading = _loadingGroups.contains(node.title);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';

    String text;
    if (isLoading) {
      text = '$displayName\n${isZh ? '加载中...' : 'Loading...'}';
    } else if (tags == null || tags.isEmpty) {
      text = displayName;
    } else {
      final tagText = tags.join(', ');
      // 使用缓存的总数，而非预览列表的长度
      final count = totalCount ?? tags.length;
      final countLabel = isZh ? 'Tag数量：$count' : 'Tag count: $count';
      text = '$displayName | $countLabel\n$tagText';
    }

    return WidgetSpan(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(tagGroupMappingNotifierProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 初始加载已启用的 tag_group 数据
    // 每次 state 变化都检查是否有新启用的需要加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEnabledTagGroupCounts(state);
    });

    final mappingsByCategory = _groupMappingsByCategory(state.config.mappings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部：热度阈值滑块 + 工具按钮
        _ToolbarWithSlider(
          onResetToDefault: _confirmResetToDefault,
          onSelectAll: _selectAll,
          onDeselectAll: _deselectAll,
        ),

        const SizedBox(height: 8),

        // 类别列表 - 横向布局
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _supportedCategories.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: theme.colorScheme.outline.withOpacity(0.1),
              ),
              itemBuilder: (context, index) {
                final category = _supportedCategories[index];
                final mappings = mappingsByCategory[category] ?? [];
                return _buildCategoryRow(
                  theme,
                  category,
                  mappings,
                );
              },
            ),
          ),
        ),

        // 同步进度
        if (state.isSyncing && state.syncProgress != null) ...[
          const Divider(),
          const SizedBox(height: 8),
          _buildSyncProgress(theme, state.syncProgress!),
        ],

        // 错误提示
        if (state.error != null) ...[
          const SizedBox(height: 8),
          _buildErrorBanner(theme, state.error!),
        ],
      ],
    );
  }

  /// 构建分类行 - 横向布局
  Widget _buildCategoryRow(
    ThemeData theme,
    TagSubCategory category,
    List<TagGroupMapping> mappings,
  ) {
    final locale = Localizations.localeOf(context).languageCode;
    final categoryName = TagSubCategoryHelper.getDisplayName(category, locale: locale);
    final allTagGroups = _getTagGroupsForCategory(category);

    // 获取所有启用的 mapping titles（从全局 state 获取，确保状态一致）
    final state = ref.watch(tagGroupMappingNotifierProvider);
    final allEnabledTitles = state.config.mappings
        .where((m) => m.enabled)
        .map((m) => m.groupTitle)
        .toSet();

    // 统计所有叶子节点
    final allLeafNodes = allTagGroups.expand((n) => _collectLeafNodes(n)).toList();
    final allLeafTitles = allLeafNodes.map((n) => n.title).toSet();
    final totalLeafCount = allLeafNodes.length;

    // 只计算当前分类下的启用数量
    final enabledCount = allLeafTitles.intersection(allEnabledTitles).length;
    final hasEnabled = enabledCount > 0;
    final hasSubGroups = _hasSubGroups(category);

    // 计算已启用的 tag_group 的 tag 总数
    final enabledLeafTitles = allLeafTitles.intersection(allEnabledTitles);
    int totalTagCount = 0;
    for (final title in enabledLeafTitles) {
      totalTagCount += _totalCountCache[title] ?? 0;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分类标题行
          Row(
            children: [
              // 分类图标
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: hasEnabled
                      ? theme.colorScheme.primaryContainer.withOpacity(0.4)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _getCategoryIcon(category),
                  size: 16,
                  color: hasEnabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              ),
              const SizedBox(width: 10),
              // 分类名称
              Text(
                categoryName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: hasEnabled
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              // Tag 总数标签（紧跟名称，黄色）
              if (hasEnabled && totalTagCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.l10n.tagGroup_tagCount(totalTagCount.toString()),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 横向排列的 Chips
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: hasSubGroups
                ? _buildSubGroupChips(theme, category, allTagGroups, allEnabledTitles)
                : _buildFlatTagGroupChips(theme, category, allTagGroups, allEnabledTitles),
          ),
        ],
      ),
    );
  }

  /// 构建扁平分类的横向 Chips（直接是叶子节点）
  Widget _buildFlatTagGroupChips(
    ThemeData theme,
    TagSubCategory category,
    List<TagGroupTreeNode> tagGroups,
    Set<String> enabledTitles,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tagGroups.where((node) => node.isTagGroup).map((node) {
        final isEnabled = enabledTitles.contains(node.title);
        return _buildTagGroupChip(theme, node, category, isEnabled);
      }).toList(),
    );
  }

  /// 构建有子分组的分类（使用 Popover 管理子节点）
  Widget _buildSubGroupChips(
    ThemeData theme,
    TagSubCategory category,
    List<TagGroupTreeNode> subGroups,
    Set<String> enabledTitles,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: subGroups.map((subGroup) {
        if (subGroup.isTagGroup) {
          // 叶子节点直接显示为可选 Chip
          final isEnabled = enabledTitles.contains(subGroup.title);
          return _buildTagGroupChip(theme, subGroup, category, isEnabled);
        }
        // 非叶子节点：显示为带 Popover 的分组 Chip
        return _buildSubGroupPopoverChip(theme, subGroup, category, enabledTitles);
      }).toList(),
    );
  }

  /// 构建单个 TagGroup Chip（可选中，带 Tooltip 预览）
  Widget _buildTagGroupChip(
    ThemeData theme,
    TagGroupTreeNode node,
    TagSubCategory category,
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
            style: theme.textTheme.labelMedium?.copyWith(
              color: isEnabled
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface,
            ),
          ),
          onSelected: (_) => _toggleTagGroup(node, category, isEnabled),
          selectedColor: theme.colorScheme.primaryContainer,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  /// 构建子分组 Popover Chip
  Widget _buildSubGroupPopoverChip(
    ThemeData theme,
    TagGroupTreeNode subGroup,
    TagSubCategory category,
    Set<String> enabledTitles,
  ) {
    final childTitles = _collectLeafTitles(subGroup);
    final enabledChildCount = childTitles.where((t) => enabledTitles.contains(t)).length;
    final totalChildCount = childTitles.length;
    final allChildrenEnabled = enabledChildCount == totalChildCount && totalChildCount > 0;
    final someChildrenEnabled = enabledChildCount > 0;

    // 构建预览文本
    final previewTags = subGroup.children
        .take(5)
        .map((c) => _getDisplayName(c))
        .join(', ');
    final previewText = '${_getDisplayName(subGroup)}\n'
        '$enabledChildCount/$totalChildCount ${Localizations.localeOf(context).languageCode == 'zh' ? '已选择' : 'selected'}\n'
        '$previewTags${subGroup.children.length > 5 ? '...' : ''}';

    return Tooltip(
      richMessage: WidgetSpan(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(previewText),
        ),
      ),
      waitDuration: const Duration(milliseconds: 400),
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showSubGroupDialog(subGroup, category, enabledTitles),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: allChildrenEnabled
                  ? theme.colorScheme.primaryContainer
                  : someChildrenEnabled
                      ? theme.colorScheme.primaryContainer.withOpacity(0.5)
                      : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getSubGroupIcon(subGroup),
                  size: 16,
                  color: someChildrenEnabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_getDisplayName(subGroup)} ($enabledChildCount/$totalChildCount)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: someChildrenEnabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: someChildrenEnabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示子分组选择对话框（居中）
  void _showSubGroupDialog(
    TagGroupTreeNode subGroup,
    TagSubCategory category,
    Set<String> enabledTitles,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => _SubGroupDialog(
        subGroup: subGroup,
        category: category,
        enabledTitles: enabledTitles,
        onToggle: (child, isEnabled) => _toggleTagGroup(child, category, isEnabled),
        onSelectAll: () => _selectAllInSubGroup(subGroup, category),
        onDeselectAll: () => _deselectAllInSubGroup(subGroup, enabledTitles),
        getDisplayName: _getDisplayName,
      ),
    );
  }

  /// 获取子分组图标
  IconData _getSubGroupIcon(TagGroupTreeNode node) {
    final title = node.title.toLowerCase();
    final displayZh = node.displayNameZh;

    // 根据 title 或显示名称返回对应图标
    if (title.contains('animal') || displayZh.contains('动物')) return Icons.pets;
    if (title.contains('item') || displayZh.contains('物品')) return Icons.category;
    if (title.contains('activity') || displayZh.contains('活动')) return Icons.directions_run;
    if (title.contains('game') || displayZh.contains('游戏')) return Icons.sports_esports;
    if (title.contains('food') || displayZh.contains('食物')) return Icons.restaurant;
    if (title.contains('meta') || displayZh.contains('元数据')) return Icons.info_outline;
    if (title.contains('misc') || displayZh.contains('杂项')) return Icons.more_horiz;
    return Icons.folder_outlined;
  }

  /// 全选子分组下所有 tag_group
  Future<void> _selectAllInSubGroup(
    TagGroupTreeNode subGroup,
    TagSubCategory category,
  ) async {
    final notifier = ref.read(tagGroupMappingNotifierProvider.notifier);
    final leafNodes = _collectLeafNodes(subGroup);

    final allGroups = <String, ({String displayName, TagSubCategory category, bool includeChildren})>{};
    for (final leaf in leafNodes) {
      allGroups[leaf.title] = (
        displayName: _getDisplayName(leaf),
        category: category,
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

  /// 取消选择子分组下所有 tag_group
  Future<void> _deselectAllInSubGroup(
    TagGroupTreeNode subGroup,
    Set<String> currentEnabledTitles,
  ) async {
    final notifier = ref.read(tagGroupMappingNotifierProvider.notifier);
    final state = ref.read(tagGroupMappingNotifierProvider);
    final leafTitles = _collectLeafTitles(subGroup).toSet();

    for (final mapping in state.config.mappings.where((m) => m.enabled)) {
      if (leafTitles.contains(mapping.groupTitle)) {
        await notifier.removeMapping(mapping.id);
      }
    }
  }

  Widget _buildSyncProgress(ThemeData theme, TagGroupSyncProgress progress) {
    final statusText = progress.currentGroup != null
        ? context.l10n.tagGroup_syncFetching(
            progress.currentGroup!,
            progress.completedGroups.toString(),
            progress.totalGroups.toString(),
          )
        : progress.message;

    final isCompleted = progress.progress >= 1.0;
    final isFailed =
        progress.message.contains('失败') || progress.message.contains('failed');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (!isCompleted && !isFailed)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (isCompleted)
              Icon(
                Icons.check_circle,
                size: 16,
                color: theme.colorScheme.primary,
              )
            else
              Icon(
                Icons.error,
                size: 16,
                color: theme.colorScheme.error,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                statusText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (progress.totalGroups > 0 && !isCompleted) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress.progress),
        ],
      ],
    );
  }

  Widget _buildErrorBanner(ThemeData theme, String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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

/// 顶部工具栏 + 滑块
class _ToolbarWithSlider extends ConsumerStatefulWidget {
  final VoidCallback onResetToDefault;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;

  const _ToolbarWithSlider({
    required this.onResetToDefault,
    required this.onSelectAll,
    required this.onDeselectAll,
  });

  @override
  ConsumerState<_ToolbarWithSlider> createState() => _ToolbarWithSliderState();
}

class _ToolbarWithSliderState extends ConsumerState<_ToolbarWithSlider> {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 第一行：热度标签 + 当前值 + 预设按钮 + 工具按钮
        Row(
          children: [
            Text(
              context.l10n.tagGroup_minPostCount,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 8),
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
                          ref
                              .read(tagGroupMappingNotifierProvider.notifier)
                              .setMinPostCount(value);
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
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
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            // 工具按钮
            _buildTextButton(
              icon: Icons.restore,
              label: context.l10n.tagGroup_resetToDefault,
              onTap: widget.onResetToDefault,
              theme: theme,
            ),
            const SizedBox(width: 4),
            _buildTextButton(
              icon: Icons.check_box_outlined,
              label: context.l10n.common_selectAll,
              onTap: widget.onSelectAll,
              theme: theme,
            ),
            const SizedBox(width: 4),
            _buildTextButton(
              icon: Icons.check_box_outline_blank,
              label: context.l10n.common_deselectAll,
              onTap: widget.onDeselectAll,
              theme: theme,
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
                ref
                    .read(tagGroupMappingNotifierProvider.notifier)
                    .setMinPostCount(postCount);
                setState(() {
                  _draggingValue = null;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

/// 子分组选择对话框
class _SubGroupDialog extends ConsumerStatefulWidget {
  final TagGroupTreeNode subGroup;
  final TagSubCategory category;
  final Set<String> enabledTitles;
  final void Function(TagGroupTreeNode child, bool isEnabled) onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final String Function(TagGroupTreeNode node) getDisplayName;

  const _SubGroupDialog({
    required this.subGroup,
    required this.category,
    required this.enabledTitles,
    required this.onToggle,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.getDisplayName,
  });

  @override
  ConsumerState<_SubGroupDialog> createState() => _SubGroupDialogState();
}

class _SubGroupDialogState extends ConsumerState<_SubGroupDialog> {
  /// 本地预览缓存
  final Map<String, List<String>> _previewCache = {};
  final Map<String, int> _totalCountCache = {};
  final Set<String> _loadingGroups = {};

  /// 加载标签预览
  Future<void> _loadTagPreview(String groupTitle) async {
    if (_previewCache.containsKey(groupTitle) ||
        _loadingGroups.contains(groupTitle)) {
      return;
    }

    _loadingGroups.add(groupTitle);
    if (mounted) setState(() {});

    try {
      final service = ref.read(danbooruTagGroupServiceProvider);
      final group = await service.getTagGroup(groupTitle, fetchPostCounts: false);

      if (group != null && mounted) {
        final actualTags = group.tags
            .where((t) => !t.name.startsWith('tag_group'))
            .toList();
        _totalCountCache[groupTitle] = actualTags.length;
        _previewCache[groupTitle] =
            actualTags.take(20).map((t) => t.name).toList();
        setState(() {});
      }
    } catch (e) {
      // 静默失败
    } finally {
      _loadingGroups.remove(groupTitle);
      if (mounted) setState(() {});
    }
  }

  /// 获取预览文本
  InlineSpan _getPreviewSpan(TagGroupTreeNode node) {
    final displayName = widget.getDisplayName(node);
    final tags = _previewCache[node.title];
    final totalCount = _totalCountCache[node.title];
    final isLoading = _loadingGroups.contains(node.title);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';

    String text;
    if (isLoading) {
      text = '$displayName\n${isZh ? '加载中...' : 'Loading...'}';
    } else if (tags == null || tags.isEmpty) {
      text = displayName;
    } else {
      final tagText = tags.join(', ');
      final count = totalCount ?? tags.length;
      final countLabel = isZh ? 'Tag数量：$count' : 'Tag count: $count';
      text = '$displayName | $countLabel\n$tagText';
    }

    return WidgetSpan(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    // 监听最新状态
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
              widget.getDisplayName(widget.subGroup),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // 全选按钮
          IconButton(
            onPressed: () {
              widget.onSelectAll();
            },
            icon: const Icon(Icons.check_box_outlined, size: 20),
            tooltip: context.l10n.common_selectAll,
            color: theme.colorScheme.primary,
          ),
          // 全不选按钮
          IconButton(
            onPressed: () {
              widget.onDeselectAll();
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
          children: widget.subGroup.children.map((child) {
            final isEnabled = currentEnabledTitles.contains(child.title);
            return MouseRegion(
              onEnter: (_) => _loadTagPreview(child.title),
              child: Tooltip(
                richMessage: _getPreviewSpan(child),
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
                  onTap: () => widget.onToggle(child, isEnabled),
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
