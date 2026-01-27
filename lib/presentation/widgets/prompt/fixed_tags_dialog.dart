import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../router/app_router.dart';
import '../common/themed_switch.dart';
import 'fixed_tag_edit_dialog.dart';

/// 固定词管理对话框
class FixedTagsDialog extends ConsumerStatefulWidget {
  const FixedTagsDialog({super.key});

  @override
  ConsumerState<FixedTagsDialog> createState() => _FixedTagsDialogState();
}

class _FixedTagsDialogState extends ConsumerState<FixedTagsDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fixedTagsState = ref.watch(fixedTagsNotifierProvider);
    final entries = fixedTagsState.entries;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
          minWidth: 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(theme),

            // 列表区域
            Flexible(
              child: entries.isEmpty
                  ? _buildEmptyState(theme)
                  : _buildEntryList(theme, entries),
            ),

            // 底部操作栏
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final enabledCount = ref.watch(enabledFixedTagsCountProvider);
    final totalCount = ref.watch(fixedTagsCountProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.push_pin,
            color: theme.colorScheme.secondary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.fixedTags_manage,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (totalCount > 0)
                  Text(
                    context.l10n.fixedTags_enabledCount(
                      enabledCount.toString(),
                      totalCount.toString(),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.push_pin_outlined,
              size: 48,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.fixedTags_empty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.fixedTags_emptyHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryList(ThemeData theme, List<FixedTagEntry> entries) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      buildDefaultDragHandles: false,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _FixedTagEntryTile(
          key: ValueKey(entry.id),
          entry: entry,
          index: index,
          onToggleEnabled: () {
            ref
                .read(fixedTagsNotifierProvider.notifier)
                .toggleEnabled(entry.id);
          },
          onEdit: () => _showEditDialog(entry),
          onDelete: () => _showDeleteConfirmation(entry),
        );
      },
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        ref
            .read(fixedTagsNotifierProvider.notifier)
            .reorder(oldIndex, newIndex);
      },
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          // 打开词库按钮
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop(); // 关闭当前对话框
              context.go(AppRoutes.tagLibraryPage); // 导航到词库页面
            },
            icon: const Icon(Icons.library_books, size: 18),
            label: Text(context.l10n.fixedTags_openLibrary),
          ),
          const Spacer(),
          // 添加按钮
          FilledButton.icon(
            onPressed: () => _showEditDialog(null),
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.fixedTags_add),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(FixedTagEntry? entry) async {
    final result = await showDialog<FixedTagEntry>(
      context: context,
      builder: (context) => FixedTagEditDialog(entry: entry),
    );

    if (result != null) {
      if (entry == null) {
        // 新建
        await ref.read(fixedTagsNotifierProvider.notifier).addEntry(
              name: result.name,
              content: result.content,
              weight: result.weight,
              position: result.position,
              enabled: result.enabled,
            );
      } else {
        // 更新
        await ref.read(fixedTagsNotifierProvider.notifier).updateEntry(result);
      }
    }
  }

  void _showDeleteConfirmation(FixedTagEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.fixedTags_deleteTitle),
        content: Text(context.l10n.fixedTags_deleteConfirm(entry.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref
                  .read(fixedTagsNotifierProvider.notifier)
                  .deleteEntry(entry.id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );
  }
}

/// 固定词条目卡片
class _FixedTagEntryTile extends StatefulWidget {
  final FixedTagEntry entry;
  final int index;
  final VoidCallback onToggleEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FixedTagEntryTile({
    super.key,
    required this.entry,
    required this.index,
    required this.onToggleEnabled,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_FixedTagEntryTile> createState() => _FixedTagEntryTileState();
}

class _FixedTagEntryTileState extends State<_FixedTagEntryTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _isHovering
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: entry.enabled
                ? theme.colorScheme.secondary
                    .withOpacity(_isHovering ? 0.5 : 0.3)
                : theme.colorScheme.outlineVariant.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: _isHovering
              ? [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              // 拖拽手柄
              ReorderableDragStartListener(
                index: widget.index,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 18,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ),

              // 启用开关
              ThemedSwitch(
                value: entry.enabled,
                onChanged: (_) => widget.onToggleEnabled(),
                scale: 0.85,
              ),

              const SizedBox(width: 8),

              // 内容区域
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 名称行
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.displayName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: entry.enabled
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                              decoration: entry.enabled
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 位置标签
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: entry.isPrefix
                                ? theme.colorScheme.primary.withOpacity(0.1)
                                : theme.colorScheme.tertiary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                entry.isPrefix
                                    ? Icons.arrow_forward
                                    : Icons.arrow_back,
                                size: 10,
                                color: entry.isPrefix
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.tertiary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                entry.isPrefix
                                    ? context.l10n.fixedTags_prefix
                                    : context.l10n.fixedTags_suffix,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: entry.isPrefix
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 权重标签
                        if (entry.weight != 1.0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  theme.colorScheme.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${entry.weight.toStringAsFixed(2)}x',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // 内容预览
                    if (entry.content.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.content.length > 50
                            ? '${entry.content.substring(0, 50)}...'
                            : entry.content,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // 操作按钮
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: widget.onEdit,
                    tooltip: context.l10n.common_edit,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: widget.onDelete,
                    tooltip: context.l10n.common_delete,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
