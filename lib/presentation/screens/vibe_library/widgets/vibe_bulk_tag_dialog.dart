import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';

/// Vibe 批量编辑标签对话框
///
/// 用于为多个选中的 Vibe 条目批量添加或移除标签
class VibeBulkTagDialog extends ConsumerStatefulWidget {
  /// 选中的 Vibe 条目列表
  final List<VibeLibraryEntry> selectedEntries;

  const VibeBulkTagDialog({
    super.key,
    required this.selectedEntries,
  });

  @override
  ConsumerState<VibeBulkTagDialog> createState() => _VibeBulkTagDialogState();
}

class _VibeBulkTagDialogState extends ConsumerState<VibeBulkTagDialog> {
  /// 当前所有标签（来自选中的条目）
  final Set<String> _allTags = {};

  /// 新增的标签
  final Set<String> _tagsToAdd = {};

  /// 要移除的标签
  final Set<String> _tagsToRemove = {};

  /// 新标签输入控制器
  final TextEditingController _tagInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 收集所有选中条目的标签
    for (final entry in widget.selectedEntries) {
      _allTags.addAll(entry.tags);
    }
  }

  @override
  void dispose() {
    _tagInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // 计算最终标签状态
    final currentTags = _allTags.difference(_tagsToRemove).union(_tagsToAdd);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.label_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '批量编辑标签',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 统计信息
              Text(
                '已选中 ${widget.selectedEntries.length} 个 Vibe',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),

              const SizedBox(height: 16),

              // 新标签输入
              _buildTagInput(theme),

              const SizedBox(height: 16),

              // 标签列表
              Expanded(
                child: _buildTagList(theme, currentTags),
              ),

              const Divider(height: 24),

              // 操作说明
              _buildActionSummary(theme, currentTags),

              const SizedBox(height: 16),

              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.common_cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _hasChanges ? _applyChanges : null,
                    child: const Text('应用'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建标签输入区域
  Widget _buildTagInput(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _tagInputController,
            decoration: InputDecoration(
              hintText: '输入新标签...',
              prefixIcon: const Icon(Icons.add),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            onSubmitted: _addNewTag,
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: () => _addNewTag(_tagInputController.text),
          child: const Text('添加'),
        ),
      ],
    );
  }

  /// 构建标签列表
  Widget _buildTagList(ThemeData theme, Set<String> currentTags) {
    if (currentTags.isEmpty && _allTags.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.label_off_outlined,
              size: 48,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              '暂无标签',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '添加标签以方便筛选和管理',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '当前标签 (${currentTags.length})',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: currentTags.length,
              itemBuilder: (context, index) {
                final tag = currentTags.elementAt(index);
                final isNew = _tagsToAdd.contains(tag);

                return _buildTagItem(theme, tag, isNew: isNew);
              },
            ),
          ),
        ),

        // 显示已移除的标签（如果有）
        if (_tagsToRemove.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '待移除标签 (${_tagsToRemove.length})',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _tagsToRemove.map((tag) {
                return _buildRemovedTagItem(theme, tag);
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  /// 构建单个标签项
  Widget _buildTagItem(
    ThemeData theme,
    String tag, {
    required bool isNew,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(
        Icons.label,
        size: 18,
        color: isNew ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
      title: Text(
        tag,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isNew ? theme.colorScheme.primary : null,
          fontWeight: isNew ? FontWeight.w500 : null,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isNew)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '新增',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontSize: 10,
                ),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            color: theme.colorScheme.error,
            onPressed: () => _removeTag(tag),
            tooltip: '移除标签',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建已移除标签项
  Widget _buildRemovedTagItem(ThemeData theme, String tag) {
    return ListTile(
      dense: true,
      leading: Icon(
        Icons.label_off,
        size: 18,
        color: theme.colorScheme.error,
      ),
      title: Text(
        tag,
        style: theme.textTheme.bodyMedium?.copyWith(
          decoration: TextDecoration.lineThrough,
          color: theme.colorScheme.error,
        ),
      ),
      trailing: TextButton.icon(
        onPressed: () => _restoreTag(tag),
        icon: const Icon(Icons.undo, size: 16),
        label: const Text('恢复'),
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }

  /// 构建操作摘要
  Widget _buildActionSummary(ThemeData theme, Set<String> currentTags) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Text(
                '操作预览',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_tagsToAdd.isNotEmpty)
            _buildActionItem(
              theme,
              icon: Icons.add_circle_outline,
              color: theme.colorScheme.primary,
              text: '添加标签: ${_tagsToAdd.join(', ')}',
            ),
          if (_tagsToRemove.isNotEmpty)
            _buildActionItem(
              theme,
              icon: Icons.remove_circle_outline,
              color: theme.colorScheme.error,
              text: '移除标签: ${_tagsToRemove.join(', ')}',
            ),
          if (!_hasChanges)
            Text(
              '没有要应用的更改',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
        ],
      ),
    );
  }

  /// 构建操作项
  Widget _buildActionItem(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 是否有更改
  bool get _hasChanges => _tagsToAdd.isNotEmpty || _tagsToRemove.isNotEmpty;

  /// 添加新标签
  void _addNewTag(String value) {
    final tag = value.trim();
    if (tag.isEmpty) return;

    setState(() {
      // 如果要移除的标签列表中有这个标签，则恢复它
      if (_tagsToRemove.contains(tag)) {
        _tagsToRemove.remove(tag);
      }
      // 如果原标签中没有，则添加到新增列表
      else if (!_allTags.contains(tag)) {
        _tagsToAdd.add(tag);
      }
    });

    _tagInputController.clear();
  }

  /// 移除标签
  void _removeTag(String tag) {
    setState(() {
      // 如果是新增的标签，直接从新增列表移除
      if (_tagsToAdd.contains(tag)) {
        _tagsToAdd.remove(tag);
      }
      // 否则添加到移除列表
      else {
        _tagsToRemove.add(tag);
      }
    });
  }

  /// 恢复已移除的标签
  void _restoreTag(String tag) {
    setState(() {
      _tagsToRemove.remove(tag);
    });
  }

  /// 应用更改
  void _applyChanges() {
    if (!_hasChanges) return;

    final result = VibeBulkTagResult(
      tagsToAdd: _tagsToAdd.toList(),
      tagsToRemove: _tagsToRemove.toList(),
    );

    Navigator.of(context).pop(result);
  }
}

/// 批量编辑标签结果
class VibeBulkTagResult {
  /// 要添加的标签列表
  final List<String> tagsToAdd;

  /// 要移除的标签列表
  final List<String> tagsToRemove;

  const VibeBulkTagResult({
    required this.tagsToAdd,
    required this.tagsToRemove,
  });

  /// 是否有更改
  bool get hasChanges => tagsToAdd.isNotEmpty || tagsToRemove.isNotEmpty;

  @override
  String toString() {
    return 'VibeBulkTagResult(add: $tagsToAdd, remove: $tagsToRemove)';
  }
}

/// 显示批量编辑标签对话框
///
/// 返回 [VibeBulkTagResult] 或 null（如果用户取消）
Future<VibeBulkTagResult?> showVibeBulkTagDialog({
  required BuildContext context,
  required List<VibeLibraryEntry> selectedEntries,
}) async {
  return showDialog<VibeBulkTagResult>(
    context: context,
    builder: (context) => VibeBulkTagDialog(
      selectedEntries: selectedEntries,
    ),
  );
}
