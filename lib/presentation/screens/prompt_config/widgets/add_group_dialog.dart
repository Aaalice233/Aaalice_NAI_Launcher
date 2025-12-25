import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/danbooru_tag_group_tree.dart';
import '../../../../data/models/prompt/tag_category.dart';
import '../../../utils/category_icon_utils.dart';

/// 添加分组类型
enum AddGroupType {
  /// 内置词库
  builtin,

  /// 远程 Tag Group
  tagGroup,
}

/// 添加分组结果
class AddGroupResult {
  final AddGroupType type;
  final String? groupTitle;
  final String? displayName;
  final bool includeChildren;
  final TagSubCategory? targetCategory;

  const AddGroupResult({
    required this.type,
    this.groupTitle,
    this.displayName,
    this.includeChildren = true,
    this.targetCategory,
  });

  /// 创建内置词库结果
  factory AddGroupResult.builtin() =>
      const AddGroupResult(type: AddGroupType.builtin);

  /// 创建 Tag Group 结果
  factory AddGroupResult.tagGroup({
    required String groupTitle,
    required String displayName,
    bool includeChildren = true,
    TagSubCategory? targetCategory,
  }) =>
      AddGroupResult(
        type: AddGroupType.tagGroup,
        groupTitle: groupTitle,
        displayName: displayName,
        includeChildren: includeChildren,
        targetCategory: targetCategory,
      );
}

/// 添加分组对话框（支持内置词库和 Tag Group）
class AddGroupDialog extends StatefulWidget {
  final ThemeData theme;
  final TagSubCategory category;
  final bool isBuiltinEnabled;
  final Set<String> existingGroupTitles;
  final String locale;

  const AddGroupDialog({
    super.key,
    required this.theme,
    required this.category,
    required this.isBuiltinEnabled,
    required this.existingGroupTitles,
    required this.locale,
  });

  /// 显示添加分组对话框
  static Future<AddGroupResult?> show(
    BuildContext context, {
    required ThemeData theme,
    required TagSubCategory category,
    required bool isBuiltinEnabled,
    required Set<String> existingGroupTitles,
    required String locale,
  }) {
    return showDialog<AddGroupResult>(
      context: context,
      builder: (context) => AddGroupDialog(
        theme: theme,
        category: category,
        isBuiltinEnabled: isBuiltinEnabled,
        existingGroupTitles: existingGroupTitles,
        locale: locale,
      ),
    );
  }

  @override
  State<AddGroupDialog> createState() => _AddGroupDialogState();
}

class _AddGroupDialogState extends State<AddGroupDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 自定义模式状态
  bool _isCustomMode = false;
  final _groupTitleController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _includeChildren = true;
  String? _errorMessage;

  // 树状导航状态
  final List<TagGroupTreeNode> _navigationStack = [];
  TagSubCategory? _selectedTargetCategory;

  @override
  void initState() {
    super.initState();
    // 如果内置已启用，默认显示 TagGroup 标签页
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.isBuiltinEnabled ? 1 : 0,
    );
    // 初始化目标分类
    _selectedTargetCategory = widget.category;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _groupTitleController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _selectBuiltin() {
    Navigator.of(context).pop(AddGroupResult.builtin());
  }

  void _selectTagGroup(TagGroupTreeNode node) {
    final displayName =
        widget.locale == 'zh' ? node.displayNameZh : node.displayNameEn;
    Navigator.of(context).pop(
      AddGroupResult.tagGroup(
        groupTitle: node.title,
        displayName: displayName.isNotEmpty ? displayName : node.title,
        includeChildren: true,
        targetCategory: _selectedTargetCategory,
      ),
    );
  }

  void _navigateInto(TagGroupTreeNode node) {
    setState(() {
      _navigationStack.add(node);
    });
  }

  void _navigateBack() {
    if (_navigationStack.isNotEmpty) {
      setState(() {
        _navigationStack.removeLast();
      });
    }
  }

  void _submitCustom() {
    final groupTitle = _groupTitleController.text.trim();
    final displayName = _displayNameController.text.trim();

    if (groupTitle.isEmpty) {
      setState(() => _errorMessage = context.l10n.addGroup_errorEmptyTitle);
      return;
    }

    // 自动添加 tag_group: 前缀（如果没有）
    final finalGroupTitle = groupTitle.startsWith('tag_group:')
        ? groupTitle
        : 'tag_group:$groupTitle';

    if (widget.existingGroupTitles.contains(finalGroupTitle)) {
      setState(() => _errorMessage = context.l10n.addGroup_errorGroupExists);
      return;
    }

    Navigator.of(context).pop(
      AddGroupResult.tagGroup(
        groupTitle: finalGroupTitle,
        displayName: displayName.isNotEmpty ? displayName : groupTitle,
        includeChildren: _includeChildren,
        targetCategory: _selectedTargetCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final categoryName = TagSubCategoryHelper.getDisplayName(widget.category);
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.addGroup_dialogTitle(categoryName)),
      content: SizedBox(
        width: 500,
        height: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tab 切换
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: Icon(
                    Icons.home_outlined,
                    color: widget.isBuiltinEnabled
                        ? theme.colorScheme.outline
                        : theme.colorScheme.primary,
                  ),
                  text: l10n.addGroup_builtinTab,
                ),
                Tab(
                  icon: const Icon(Icons.cloud_outlined),
                  text: l10n.addGroup_tagGroupTab,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Tab 内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBuiltinTab(theme),
                  _buildTagGroupTab(theme),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.addGroup_cancel),
        ),
        if (_isCustomMode && _tabController.index == 1)
          FilledButton(
            onPressed: _submitCustom,
            child: Text(l10n.addGroup_submit),
          ),
      ],
    );
  }

  Widget _buildBuiltinTab(ThemeData theme) {
    final l10n = context.l10n;
    if (widget.isBuiltinEnabled) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              l10n.addGroup_builtinEnabled,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.addGroup_builtinEnabledDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.home_outlined, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            l10n.addGroup_enableBuiltin,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.addGroup_enableBuiltinDesc,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _selectBuiltin,
            icon: const Icon(Icons.add),
            label: Text(l10n.addGroup_enable),
          ),
        ],
      ),
    );
  }

  Widget _buildTagGroupTab(ThemeData theme) {
    final l10n = context.l10n;
    return Column(
      children: [
        // 顶部操作栏
        Row(
          children: [
            // 返回按钮
            if (_navigationStack.isNotEmpty && !_isCustomMode)
              IconButton(
                onPressed: _navigateBack,
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.addGroup_backToParent,
              ),
            // 面包屑
            if (!_isCustomMode)
              Expanded(
                child: _buildBreadcrumb(theme),
              ),
            if (_isCustomMode) const Spacer(),
            // 切换按钮
            TextButton.icon(
              onPressed: () => setState(() {
                _isCustomMode = !_isCustomMode;
                _errorMessage = null;
                if (!_isCustomMode) {
                  _navigationStack.clear();
                }
              }),
              icon: Icon(_isCustomMode ? Icons.list : Icons.edit, size: 16),
              label: Text(
                _isCustomMode
                    ? l10n.addGroup_browseMode
                    : l10n.addGroup_customMode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 内容区
        Expanded(
          child: _isCustomMode
              ? _buildCustomInput(theme)
              : _buildTreeNavigation(theme),
        ),
      ],
    );
  }

  /// 面包屑导航
  Widget _buildBreadcrumb(ThemeData theme) {
    final l10n = context.l10n;
    final parts = <Widget>[
      InkWell(
        onTap: _navigationStack.isNotEmpty
            ? () => setState(() => _navigationStack.clear())
            : null,
        child: Text(
          l10n.addGroup_allCategories,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _navigationStack.isEmpty
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
            fontWeight: _navigationStack.isEmpty ? FontWeight.bold : null,
          ),
        ),
      ),
    ];

    for (var i = 0; i < _navigationStack.length; i++) {
      final node = _navigationStack[i];
      final isLast = i == _navigationStack.length - 1;
      final displayName =
          widget.locale == 'zh' ? node.displayNameZh : node.displayNameEn;

      parts.add(
        Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.outline),
      );
      parts.add(
        InkWell(
          onTap: isLast
              ? null
              : () => setState(() {
                    _navigationStack.removeRange(i + 1, _navigationStack.length);
                  }),
          child: Text(
            displayName.isNotEmpty ? displayName : node.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isLast
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              fontWeight: isLast ? FontWeight.bold : null,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: parts),
    );
  }

  /// 树状导航列表
  Widget _buildTreeNavigation(ThemeData theme) {
    final l10n = context.l10n;
    final currentNodes = _navigationStack.isEmpty
        ? DanbooruTagGroupTree.tree
        : _navigationStack.last.children;

    if (currentNodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              l10n.addGroup_noMoreSubcategories,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: currentNodes.length,
      itemBuilder: (context, index) {
        final node = currentNodes[index];
        final displayName =
            widget.locale == 'zh' ? node.displayNameZh : node.displayNameEn;
        final isExisting = widget.existingGroupTitles.contains(node.title);

        if (node.isTagGroup) {
          // 叶子节点：可选择的 Tag Group
          return ListTile(
            leading: Icon(
              Icons.cloud_outlined,
              color: isExisting
                  ? theme.colorScheme.outline
                  : theme.colorScheme.primary,
            ),
            title: Text(
              displayName.isNotEmpty ? displayName : node.title,
              style: TextStyle(
                color: isExisting ? theme.colorScheme.outline : null,
              ),
            ),
            subtitle: Text(
              node.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            trailing: isExisting
                ? Text(
                    l10n.tagGroup_alreadyAdded,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  )
                : Icon(Icons.add, color: theme.colorScheme.primary),
            enabled: !isExisting,
            onTap: isExisting ? null : () => _selectTagGroup(node),
          );
        } else {
          // 分支节点：可进入的分类
          final childCount = _countLeafNodes(node);
          return ListTile(
            leading: Icon(
              node.category != null
                  ? CategoryIconUtils.getCategoryIcon(node.category!)
                  : Icons.folder_outlined,
              color: theme.colorScheme.primary,
            ),
            title: Text(displayName.isNotEmpty ? displayName : node.title),
            subtitle: Text(
              l10n.addGroup_tagGroupCount(childCount),
              style: theme.textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateInto(node),
          );
        }
      },
    );
  }

  /// 计算节点下的叶子节点数量
  int _countLeafNodes(TagGroupTreeNode node) {
    if (node.isTagGroup) return 1;
    int count = 0;
    for (final child in node.children) {
      count += _countLeafNodes(child);
    }
    return count;
  }

  Widget _buildCustomInput(ThemeData theme) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 说明文字
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.addGroup_customInputHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tag Group 标题输入
          TextField(
            controller: _groupTitleController,
            decoration: InputDecoration(
              labelText: l10n.addGroup_groupTitleLabel,
              hintText: l10n.addGroup_groupTitleHint,
              prefixIcon: const Icon(Icons.tag),
              border: const OutlineInputBorder(),
              errorText: _errorMessage,
            ),
            onChanged: (_) {
              if (_errorMessage != null) {
                setState(() => _errorMessage = null);
              }
            },
          ),
          const SizedBox(height: 16),
          // 显示名称输入
          TextField(
            controller: _displayNameController,
            decoration: InputDecoration(
              labelText: l10n.addGroup_displayNameLabel,
              hintText: l10n.addGroup_displayNameHint,
              prefixIcon: const Icon(Icons.label_outline),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          // 目标分类选择
          DropdownButtonFormField<TagSubCategory>(
            value: _selectedTargetCategory,
            decoration: InputDecoration(
              labelText: l10n.addGroup_targetCategoryLabel,
              prefixIcon: const Icon(Icons.category_outlined),
              border: const OutlineInputBorder(),
            ),
            items: TagSubCategory.values
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(TagSubCategoryHelper.getDisplayName(c)),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedTargetCategory = v),
          ),
          const SizedBox(height: 16),
          // 包含子组选项
          CheckboxListTile(
            value: _includeChildren,
            onChanged: (v) => setState(() => _includeChildren = v ?? true),
            title: Text(l10n.addGroup_includeChildren),
            subtitle: Text(l10n.addGroup_includeChildrenDesc),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }
}
