import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/prompt/default_tag_group_mappings.dart';
import '../../../data/models/prompt/random_category.dart';
import '../../../data/models/prompt/random_tag_group.dart';

/// 分组来源类型
enum _AddGroupSource {
  custom,
  tagGroup,
  pool,
}

/// 添加分组对话框
///
/// 用于向类别中添加新的标签分组
class AddGroupDialog extends ConsumerStatefulWidget {
  final RandomCategory category;

  const AddGroupDialog({
    super.key,
    required this.category,
  });

  /// 显示对话框并返回新创建的分组（如果有）
  static Future<RandomTagGroup?> show(
    BuildContext context, {
    required RandomCategory category,
  }) {
    return showDialog<RandomTagGroup>(
      context: context,
      builder: (context) => AddGroupDialog(category: category),
    );
  }

  @override
  ConsumerState<AddGroupDialog> createState() => _AddGroupDialogState();
}

class _AddGroupDialogState extends ConsumerState<AddGroupDialog> {
  _AddGroupSource _selectedSource = _AddGroupSource.custom;
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_box, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '添加分组到「${widget.category.name}」',
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 来源选择
                    _buildSourceSelector(theme),

                    const SizedBox(height: 16),

                    // 根据选择显示不同内容
                    if (_selectedSource == _AddGroupSource.custom)
                      _buildCustomGroupForm(theme)
                    else
                      _buildExternalGroupSelector(theme),
                  ],
                ),
              ),
            ),

            // 底部按钮
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  if (_selectedSource == _AddGroupSource.custom)
                    FilledButton(
                      onPressed: _isLoading ? null : _createCustomGroup,
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('创建'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择分组来源',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<_AddGroupSource>(
          segments: const [
            ButtonSegment(
              value: _AddGroupSource.custom,
              icon: Icon(Icons.edit),
              label: Text('自定义'),
            ),
            ButtonSegment(
              value: _AddGroupSource.tagGroup,
              icon: Icon(Icons.category),
              label: Text('Tag Group'),
            ),
            ButtonSegment(
              value: _AddGroupSource.pool,
              icon: Icon(Icons.collections),
              label: Text('Pool'),
            ),
          ],
          selected: {_selectedSource},
          onSelectionChanged: (values) {
            setState(() {
              _selectedSource = values.first;
              _searchQuery = '';
              _searchController.clear();
            });
          },
        ),
      ],
    );
  }

  Widget _buildCustomGroupForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '分组名称',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: '输入分组名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (_) => _createCustomGroup(),
        ),
        const SizedBox(height: 8),
        Text(
          '创建后可以在分组设置中添加标签',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildExternalGroupSelector(ThemeData theme) {
    final isTagGroup = _selectedSource == _AddGroupSource.tagGroup;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 搜索框
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: isTagGroup ? '搜索 Tag Group...' : '搜索 Pool...',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),

        const SizedBox(height: 16),

        // 推荐列表
        Text(
          isTagGroup ? '推荐的 Tag Groups' : '推荐的 Pools',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        if (isTagGroup)
          _buildTagGroupList(theme)
        else
          _buildPoolList(theme),
      ],
    );
  }

  Widget _buildTagGroupList(ThemeData theme) {
    // 使用默认映射作为推荐列表
    final allMappings = DefaultTagGroupMappings.mappings;

    // 根据类别 key 过滤相关映射
    final categoryKey = widget.category.key;
    final categoryMappings = allMappings.where((m) {
      // 简单匹配类别名称
      final targetName = m.targetCategory.name.toLowerCase();
      return targetName.contains(categoryKey.toLowerCase()) ||
          categoryKey.toLowerCase().contains(targetName);
    }).toList();

    // 如果没有精确匹配，显示所有映射
    final displayMappings =
        categoryMappings.isEmpty ? allMappings : categoryMappings;

    // 过滤搜索结果
    final filteredMappings = _searchQuery.isEmpty
        ? displayMappings
        : displayMappings
            .where(
              (m) =>
                  m.displayName
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ||
                  m.groupTitle
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()),
            )
            .toList();

    if (filteredMappings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _searchQuery.isEmpty
                ? '暂无推荐的 Tag Group'
                : '未找到匹配的 Tag Group',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filteredMappings.map((mapping) {
        // 检查是否已添加
        final alreadyAdded = widget.category.groups.any(
          (g) =>
              g.sourceType == TagGroupSourceType.tagGroup &&
              g.sourceId == mapping.groupTitle,
        );

        return ActionChip(
          label: Text(mapping.displayName),
          avatar: alreadyAdded
              ? const Icon(Icons.check, size: 18)
              : const Icon(Icons.add, size: 18),
          onPressed: alreadyAdded
              ? null
              : () => _addTagGroup(mapping.groupTitle, mapping.displayName),
        );
      }).toList(),
    );
  }

  Widget _buildPoolList(ThemeData theme) {
    // Pool 功能暂未实现，显示占位提示
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.construction,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'Pool 功能开发中',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createCustomGroup() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入分组名称')),
      );
      return;
    }

    // 检查名称是否重复
    if (widget.category.groups.any((g) => g.name == name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分组名称已存在: $name')),
      );
      return;
    }

    final newGroup = RandomTagGroup.custom(name: name);
    Navigator.of(context).pop(newGroup);
  }

  Future<void> _addTagGroup(String tagGroupName, String displayName) async {
    setState(() => _isLoading = true);

    try {
      // TODO: 从 Danbooru API 获取标签列表
      // 暂时创建空分组，用户可以之后同步
      final newGroup = RandomTagGroup.fromTagGroup(
        name: displayName,
        tagGroupName: tagGroupName,
        tags: [], // 空标签列表，用户可以之后同步
      );

      if (mounted) {
        Navigator.of(context).pop(newGroup);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
