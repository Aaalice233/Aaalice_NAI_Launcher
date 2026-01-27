import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/selection_mode_provider.dart';

/// Bulk action bar for selected images
/// 显示批量操作按钮的工具栏
class BulkActionBar extends ConsumerWidget {
  /// Callback when delete button is pressed
  /// 删除按钮回调
  final VoidCallback? onDelete;

  /// Callback when export button is pressed
  /// 导出按钮回调
  final VoidCallback? onExport;

  /// Callback when edit metadata button is pressed
  /// 编辑元数据按钮回调
  final VoidCallback? onEditMetadata;

  /// Callback when add to collection button is pressed
  /// 添加到集合按钮回调
  final VoidCallback? onAddToCollection;

  /// Callback when exit button is pressed
  /// 退出按钮回调
  final VoidCallback? onExit;

  /// Callback when select all button is pressed
  /// 全选按钮回调
  final VoidCallback? onSelectAll;

  /// Callback when move to folder button is pressed
  /// 移动到文件夹按钮回调
  final VoidCallback? onMoveToFolder;

  /// Whether all items are selected
  /// 是否已全选
  final bool isAllSelected;

  /// Total number of items that can be selected
  /// 可选择的总数
  final int totalCount;

  const BulkActionBar({
    super.key,
    this.onDelete,
    this.onExport,
    this.onEditMetadata,
    this.onAddToCollection,
    this.onExit,
    this.onSelectAll,
    this.onMoveToFolder,
    this.isAllSelected = false,
    this.totalCount = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectionState = ref.watch(localGallerySelectionNotifierProvider);
    final isDark = theme.brightness == Brightness.dark;
    final hasSelection = selectionState.selectedIds.isNotEmpty;
    final selectedCount = selectionState.selectedIds.length;

    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surface.withOpacity(0.9)
                : theme.colorScheme.surface.withOpacity(0.95),
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withOpacity(isDark ? 0.15 : 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              // Exit button
              _ActionButton(
                icon: Icons.close,
                label: '退出',
                onPressed: onExit,
                compact: true,
              ),
              const SizedBox(width: 12),

              // Selection count badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '已选择 $selectedCount 项',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Select all / Deselect all button
              _ActionButton(
                icon: isAllSelected ? Icons.deselect : Icons.select_all,
                label: isAllSelected ? '取消全选' : '全选',
                onPressed: onSelectAll,
                compact: true,
              ),

              const Spacer(),

              // Action buttons group
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Move to folder button
                  _ActionButton(
                    icon: Icons.drive_file_move_outline,
                    label: '移动',
                    onPressed: hasSelection ? onMoveToFolder : null,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),

                  // Export button
                  _ActionButton(
                    icon: Icons.download_outlined,
                    label: '导出',
                    onPressed: hasSelection ? onExport : null,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),

                  // Edit metadata button
                  _ActionButton(
                    icon: Icons.edit_outlined,
                    label: '编辑',
                    onPressed: hasSelection ? onEditMetadata : null,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),

                  // Add to collection button
                  _ActionButton(
                    icon: Icons.playlist_add,
                    label: '收藏',
                    onPressed: hasSelection ? onAddToCollection : null,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 16),

                  // Divider
                  Container(
                    width: 1,
                    height: 28,
                    color: theme.dividerColor.withOpacity(0.3),
                  ),
                  const SizedBox(width: 16),

                  // Delete button (danger)
                  _ActionButton(
                    icon: Icons.delete_outline,
                    label: '删除',
                    onPressed: hasSelection ? onDelete : null,
                    color: theme.colorScheme.error,
                    isDanger: true,
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

/// Action button with icon and optional label
/// 带图标和可选标签的操作按钮
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isDanger;
  final bool compact;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.color,
    this.isDanger = false,
    this.compact = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null;
    final effectiveColor = widget.color ?? theme.colorScheme.onSurface;
    final displayColor =
        isEnabled ? effectiveColor : effectiveColor.withOpacity(0.4);

    return MouseRegion(
      onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: isEnabled ? (_) => setState(() => _isHovered = false) : null,
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 10 : 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: _isHovered
                  ? (widget.isDanger
                      ? effectiveColor.withOpacity(isDark ? 0.2 : 0.12)
                      : effectiveColor.withOpacity(isDark ? 0.15 : 0.08))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: _isHovered
                  ? Border.all(
                      color: effectiveColor.withOpacity(0.3),
                      width: 1,
                    )
                  : Border.all(
                      color: Colors.transparent,
                      width: 1,
                    ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 18,
                  color: displayColor,
                ),
                if (!widget.compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: displayColor,
                      fontWeight:
                          _isHovered ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
