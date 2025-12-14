import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/danbooru_tag_group_tree.dart';
import '../../../data/models/prompt/tag_category.dart';
import '../../providers/tag_group_mapping_provider.dart';
import '../../widgets/common/app_toast.dart';

/// Tag Group 树状浏览选择对话框
/// 按 NAI 提示词类别分组，使用预定义树结构
class TagGroupBrowseDialog extends ConsumerStatefulWidget {
  /// 目标类别（从类别条目进入时传入）
  final TagSubCategory targetCategory;

  const TagGroupBrowseDialog({
    super.key,
    required this.targetCategory,
  });

  @override
  ConsumerState<TagGroupBrowseDialog> createState() =>
      _TagGroupBrowseDialogState();
}

class _TagGroupBrowseDialogState extends ConsumerState<TagGroupBrowseDialog> {
  final _searchController = TextEditingController();

  /// 展开的节点 title 集合
  final Set<String> _expandedNodes = {};

  /// 选中的 tag_group 标题
  String? _selectedGroupTitle;

  /// 选中的 tag_group 显示名称
  String? _selectedGroupDisplayName;

  /// 是否包含子分组
  bool _includeChildren = true;

  /// 搜索模式
  bool _isSearchMode = false;

  /// 搜索结果
  List<TagGroupTreeNode> _searchResults = [];

  @override
  void initState() {
    super.initState();
    // 默认展开目标类别对应的节点
    _expandedNodes.add(widget.targetCategory.name);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 获取当前语言的显示名称
  String _getDisplayName(TagGroupTreeNode node) {
    final locale = Localizations.localeOf(context).languageCode;
    return locale == 'zh' ? node.displayNameZh : node.displayNameEn;
  }

  /// 切换节点展开状态
  void _toggleExpand(String title) {
    setState(() {
      if (_expandedNodes.contains(title)) {
        _expandedNodes.remove(title);
      } else {
        _expandedNodes.add(title);
      }
    });
  }

  /// 展开全部
  void _expandAll() {
    setState(() {
      for (final node in DanbooruTagGroupTree.tree) {
        _expandedNodes.add(node.title);
        for (final child in node.children) {
          if (child.hasChildren) {
            _expandedNodes.add(child.title);
          }
        }
      }
    });
  }

  /// 收起全部
  void _collapseAll() {
    setState(() {
      _expandedNodes.clear();
    });
  }

  /// 选择 tag_group
  void _selectGroup(TagGroupTreeNode node) {
    if (!node.isTagGroup) return;

    final state = ref.read(tagGroupMappingNotifierProvider);
    if (state.config.hasGroup(node.title)) return;

    setState(() {
      _selectedGroupTitle = node.title;
      _selectedGroupDisplayName = _getDisplayName(node);
    });
  }

  /// 添加映射
  void _onAddPressed() async {
    if (_selectedGroupTitle == null) return;

    final state = ref.read(tagGroupMappingNotifierProvider);
    if (state.config.hasGroup(_selectedGroupTitle!)) {
      AppToast.warning(context, context.l10n.tagGroup_groupExists);
      return;
    }

    try {
      await ref.read(tagGroupMappingNotifierProvider.notifier).addMapping(
            groupTitle: _selectedGroupTitle!,
            displayName: _selectedGroupDisplayName!,
            targetCategory: widget.targetCategory,
            includeChildren: _includeChildren,
          );
      if (mounted) {
        AppToast.success(context, context.l10n.tagGroup_addSuccess);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, e.toString());
      }
    }
  }

  /// 搜索
  void _search(String query) {
    if (query.isEmpty) {
      setState(() {
        _isSearchMode = false;
        _searchResults = [];
      });
      return;
    }

    final results = <TagGroupTreeNode>[];
    final lowerQuery = query.toLowerCase();

    void searchNode(TagGroupTreeNode node) {
      if (node.isTagGroup) {
        if (node.title.toLowerCase().contains(lowerQuery) ||
            node.displayNameZh.contains(query) ||
            node.displayNameEn.toLowerCase().contains(lowerQuery)) {
          results.add(node);
        }
      }
      for (final child in node.children) {
        searchNode(child);
      }
    }

    for (final node in DanbooruTagGroupTree.tree) {
      searchNode(node);
    }

    setState(() {
      _isSearchMode = true;
      _searchResults = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryName = TagSubCategoryHelper.getDisplayName(
      widget.targetCategory,
    );

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.tagGroup_addMapping),
                Text(
                  context.l10n.tagGroup_addTo(categoryName),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          // 展开/收起按钮
          if (!_isSearchMode) ...[
            TextButton.icon(
              onPressed: _expandAll,
              icon: const Icon(Icons.unfold_more, size: 16),
              label: Text(context.l10n.common_expandAll),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
            TextButton.icon(
              onPressed: _collapseAll,
              icon: const Icon(Icons.unfold_less, size: 16),
              label: Text(context.l10n.common_collapseAll),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: 550,
        height: 450,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 搜索栏
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.l10n.tagGroup_searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 12),

            // 树状列表或搜索结果
            Expanded(
              child: _isSearchMode
                  ? _buildSearchResults(theme)
                  : _buildTreeView(theme),
            ),

            // 选中信息和选项
            if (_selectedGroupTitle != null) ...[
              const Divider(height: 16),
              _buildSelectedInfo(theme),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_cancel),
        ),
        FilledButton(
          onPressed: _selectedGroupTitle == null ? null : _onAddPressed,
          child: Text(context.l10n.common_add),
        ),
      ],
    );
  }

  /// 构建树状视图
  Widget _buildTreeView(ThemeData theme) {
    return ListView.builder(
      itemCount: DanbooruTagGroupTree.tree.length,
      itemBuilder: (context, index) {
        return _buildCategoryNode(DanbooruTagGroupTree.tree[index], theme);
      },
    );
  }

  /// 构建类别节点（顶级）
  Widget _buildCategoryNode(TagGroupTreeNode node, ThemeData theme) {
    final isExpanded = _expandedNodes.contains(node.title);
    final isTargetCategory = node.category == widget.targetCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 类别标题
        InkWell(
          onTap: () => _toggleExpand(node.title),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isTargetCategory
                  ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                  : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Icon(
                  _getCategoryIcon(node.category),
                  size: 18,
                  color: isTargetCategory
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getDisplayName(node),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isTargetCategory ? theme.colorScheme.primary : null,
                    ),
                  ),
                ),
                // 数量提示
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_countTagGroups(node)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 子节点
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: node.children.map((child) {
                if (child.isTagGroup) {
                  return _buildTagGroupNode(child, theme, 1);
                } else {
                  return _buildSubCategoryNode(child, theme, 1);
                }
              }).toList(),
            ),
          ),
      ],
    );
  }

  /// 构建子分类节点
  Widget _buildSubCategoryNode(
    TagGroupTreeNode node,
    ThemeData theme,
    int depth,
  ) {
    final isExpanded = _expandedNodes.contains(node.title);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _toggleExpand(node.title),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _getDisplayName(node),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_countTagGroups(node)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: node.children.map((child) {
                if (child.isTagGroup) {
                  return _buildTagGroupNode(child, theme, depth + 1);
                } else {
                  return _buildSubCategoryNode(child, theme, depth + 1);
                }
              }).toList(),
            ),
          ),
      ],
    );
  }

  /// 构建 tag_group 节点（叶子节点）
  Widget _buildTagGroupNode(TagGroupTreeNode node, ThemeData theme, int depth) {
    final state = ref.watch(tagGroupMappingNotifierProvider);
    final alreadyAdded = state.config.hasGroup(node.title);
    final isSelected = _selectedGroupTitle == node.title;

    return Opacity(
      opacity: alreadyAdded ? 0.5 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 2, left: 4),
        elevation: 0,
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.5)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: isSelected
              ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: alreadyAdded ? null : () => _selectGroup(node),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.label_outline,
                  size: 14,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _getDisplayName(node),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                ),
                if (alreadyAdded)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      context.l10n.tagGroup_alreadyAdded,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建搜索结果
  Widget _buildSearchResults(ThemeData theme) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          context.l10n.tagGroup_noResults,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final node = _searchResults[index];
        return _buildTagGroupNode(node, theme, 0);
      },
    );
  }

  /// 构建选中信息
  Widget _buildSelectedInfo(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.check_circle,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${context.l10n.tagGroup_selected}: $_selectedGroupDisplayName',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // 包含子分组开关
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.tagGroup_includeChildren,
              style: theme.textTheme.bodySmall,
            ),
            Switch(
              value: _includeChildren,
              onChanged: (v) => setState(() => _includeChildren = v),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ],
    );
  }

  /// 统计节点下的 tag_group 数量
  int _countTagGroups(TagGroupTreeNode node) {
    var count = 0;
    if (node.isTagGroup) count++;
    for (final child in node.children) {
      count += _countTagGroups(child);
    }
    return count;
  }

  /// 获取类别图标
  IconData _getCategoryIcon(TagSubCategory? category) {
    return switch (category) {
      TagSubCategory.hairColor => Icons.palette,
      TagSubCategory.eyeColor => Icons.visibility,
      TagSubCategory.hairStyle => Icons.content_cut,
      TagSubCategory.clothing => Icons.checkroom,
      TagSubCategory.expression => Icons.mood,
      TagSubCategory.pose => Icons.accessibility_new,
      TagSubCategory.background => Icons.wallpaper,
      TagSubCategory.scene => Icons.landscape,
      TagSubCategory.style => Icons.brush,
      TagSubCategory.bodyFeature => Icons.person,
      TagSubCategory.accessory => Icons.diamond,
      TagSubCategory.characterCount => Icons.groups,
      TagSubCategory.other => Icons.category,
      null => Icons.folder,
    };
  }
}
