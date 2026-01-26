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

  const BulkActionBar({
    super.key,
    this.onDelete,
    this.onExport,
    this.onEditMetadata,
    this.onAddToCollection,
    this.onExit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectionState = ref.watch(localGallerySelectionNotifierProvider);
    final isDark = theme.brightness == Brightness.dark;
    final hasSelection = selectionState.selectedIds.isNotEmpty;

    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.primaryContainer.withOpacity(0.85)
                : theme.colorScheme.primaryContainer.withOpacity(0.7),
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withOpacity(isDark ? 0.2 : 0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              // Exit button
              _RoundedIconButton(
                icon: Icons.close,
                tooltip: '退出多选',
                onPressed: onExit,
              ),
              const SizedBox(width: 12),
              // Selection count
              Text(
                '已选择 ${selectionState.selectedIds.length} 项',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Delete button
              _RoundedIconButton(
                icon: Icons.delete,
                tooltip: '删除',
                onPressed: hasSelection ? onDelete : null,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              // Export button
              _RoundedIconButton(
                icon: Icons.download,
                tooltip: '导出',
                onPressed: hasSelection ? onExport : null,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              // Edit metadata button
              _RoundedIconButton(
                icon: Icons.edit,
                tooltip: '编辑元数据',
                onPressed: hasSelection ? onEditMetadata : null,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              // Add to collection button
              _RoundedIconButton(
                icon: Icons.playlist_add,
                tooltip: '添加到集合',
                onPressed: hasSelection ? onAddToCollection : null,
                color: theme.colorScheme.tertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded icon button with hover animation
/// 圆角图标按钮（带悬停动画）
class _RoundedIconButton extends StatefulWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  const _RoundedIconButton({
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.color,
  });

  @override
  State<_RoundedIconButton> createState() => _RoundedIconButtonState();
}

class _RoundedIconButtonState extends State<_RoundedIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveColor =
        widget.color ?? theme.colorScheme.onSurfaceVariant;
    final isEnabled = widget.onPressed != null;

    return MouseRegion(
      onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: isEnabled ? (_) => setState(() => _isHovered = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isEnabled && _isHovered
              ? effectiveColor.withOpacity(isDark ? 0.2 : 0.15)
              : effectiveColor.withOpacity(isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: effectiveColor.withOpacity(isDark ? 0.15 : 0.2),
            width: 1,
          ),
        ),
        child: IconButton(
          icon: Icon(widget.icon),
          tooltip: widget.tooltip,
          onPressed: widget.onPressed,
          color: effectiveColor,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
