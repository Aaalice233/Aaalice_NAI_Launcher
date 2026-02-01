import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/tag_library_page_provider.dart';
import '../../../providers/tag_library_selection_provider.dart';
import '../../../widgets/bulk_action_bar.dart';

/// 词库工具栏（搜索、视图切换、批量操作）
class TagLibraryToolbar extends ConsumerStatefulWidget {
  /// 进入选择模式按钮回调
  final VoidCallback? onEnterSelectionMode;

  /// 批量删除回调
  final VoidCallback? onBulkDelete;

  /// 批量转移分类回调
  final VoidCallback? onBulkMoveCategory;

  /// 批量切换收藏回调
  final VoidCallback? onBulkToggleFavorite;

  /// 批量复制内容回调
  final VoidCallback? onBulkCopy;

  const TagLibraryToolbar({
    super.key,
    this.onEnterSelectionMode,
    this.onBulkDelete,
    this.onBulkMoveCategory,
    this.onBulkToggleFavorite,
    this.onBulkCopy,
  });

  @override
  ConsumerState<TagLibraryToolbar> createState() => _TagLibraryToolbarState();
}

class _TagLibraryToolbarState extends ConsumerState<TagLibraryToolbar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tagLibraryPageNotifierProvider);
    final selectionState = ref.watch(tagLibrarySelectionNotifierProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 获取当前筛选后的所有条目 ID
    final allEntryIds = state.filteredEntries.map((e) => e.id).toList();
    final isAllSelected = allEntryIds.isNotEmpty &&
        allEntryIds.every((id) => selectionState.selectedIds.contains(id));

    // 选择模式时显示批量操作栏
    if (selectionState.isActive) {
      return BulkActionBar(
        selectedCount: selectionState.selectedIds.length,
        isAllSelected: isAllSelected,
        onExit: () =>
            ref.read(tagLibrarySelectionNotifierProvider.notifier).exit(),
        onSelectAll: () {
          if (isAllSelected) {
            ref
                .read(tagLibrarySelectionNotifierProvider.notifier)
                .clearSelection();
          } else {
            ref
                .read(tagLibrarySelectionNotifierProvider.notifier)
                .selectAll(allEntryIds);
          }
        },
        actions: [
          BulkActionItem(
            icon: Icons.drive_file_move_outline,
            label: '转移分类',
            onPressed: widget.onBulkMoveCategory,
            color: theme.colorScheme.secondary,
          ),
          BulkActionItem(
            icon: Icons.copy,
            label: '复制内容',
            onPressed: widget.onBulkCopy,
            color: theme.colorScheme.tertiary,
          ),
          BulkActionItem(
            icon: Icons.favorite_outline,
            label: '收藏',
            onPressed: widget.onBulkToggleFavorite,
            color: Colors.pink,
          ),
          BulkActionItem(
            icon: Icons.delete_outline,
            label: '删除',
            onPressed: widget.onBulkDelete,
            color: theme.colorScheme.error,
            isDanger: true,
            showDividerBefore: true,
          ),
        ],
      );
    }

    // 普通工具栏
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: const BoxConstraints(minHeight: 62),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHigh.withOpacity(0.9)
                : theme.colorScheme.surface.withOpacity(0.8),
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withOpacity(isDark ? 0.2 : 0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              // 添加条目按钮
              FilledButton.icon(
                onPressed: () {
                  // 触发添加条目对话框
                  _showAddEntryDialog();
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.l10n.tagLibrary_addEntry),
              ),
              const SizedBox(width: 12),

              // 搜索框
              Expanded(
                child: _buildSearchField(theme, state),
              ),

              const SizedBox(width: 12),

              // 视图切换
              _buildViewModeToggle(theme, state),

              const SizedBox(width: 8),

              // 分隔线
              Container(
                width: 1,
                height: 24,
                color: theme.dividerColor.withOpacity(0.3),
              ),
              const SizedBox(width: 8),

              // 多选按钮
              _CompactIconButton(
                icon: Icons.checklist,
                label: '多选',
                onPressed: widget.onEnterSelectionMode,
              ),
              const SizedBox(width: 6),

              // 导入按钮
              _CompactIconButton(
                icon: Icons.file_download_outlined,
                label: '导入',
                onPressed: () => _showImportDialog(),
              ),
              const SizedBox(width: 6),

              // 导出按钮
              _CompactIconButton(
                icon: Icons.file_upload_outlined,
                label: '导出',
                onPressed:
                    state.entries.isEmpty ? null : () => _showExportDialog(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建搜索框
  Widget _buildSearchField(ThemeData theme, TagLibraryPageState state) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: context.l10n.tagLibrary_searchHint,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
          suffixIcon: state.searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    ref
                        .read(tagLibraryPageNotifierProvider.notifier)
                        .setSearchQuery('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
        onChanged: (value) {
          ref
              .read(tagLibraryPageNotifierProvider.notifier)
              .setSearchQuery(value);
        },
      ),
    );
  }

  /// 构建视图切换按钮
  Widget _buildViewModeToggle(ThemeData theme, TagLibraryPageState state) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewModeButton(
            icon: Icons.view_list_rounded,
            isSelected: state.viewMode == TagLibraryViewMode.list,
            onTap: () => ref
                .read(tagLibraryPageNotifierProvider.notifier)
                .setViewMode(TagLibraryViewMode.list),
          ),
          _ViewModeButton(
            icon: Icons.grid_view_rounded,
            isSelected: state.viewMode == TagLibraryViewMode.card,
            onTap: () => ref
                .read(tagLibraryPageNotifierProvider.notifier)
                .setViewMode(TagLibraryViewMode.card),
          ),
        ],
      ),
    );
  }

  void _showAddEntryDialog() {
    // 通过 provider 通知显示添加对话框
    // 实际实现由父组件处理
  }

  void _showImportDialog() {
    // 通过 provider 通知显示导入对话框
  }

  void _showExportDialog() {
    // 通过 provider 通知显示导出对话框
  }
}

/// 视图模式切换按钮
class _ViewModeButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewModeButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withOpacity(0.5)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}

/// 紧凑图标按钮
class _CompactIconButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onPressed;

  const _CompactIconButton({
    required this.icon,
    this.label,
    this.onPressed,
  });

  @override
  State<_CompactIconButton> createState() => _CompactIconButtonState();
}

class _CompactIconButtonState extends State<_CompactIconButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null;
    final hasLabel = widget.label != null && widget.label!.isNotEmpty;

    Color iconColor;
    Color labelColor;
    Color bgColor;
    Color borderColor;
    List<BoxShadow>? shadows;

    iconColor = isEnabled
        ? (_isHovered
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant
                .withOpacity(isDark ? 0.85 : 0.75))
        : theme.colorScheme.onSurfaceVariant.withOpacity(0.35);
    labelColor = isEnabled
        ? (_isHovered
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withOpacity(isDark ? 0.85 : 0.75))
        : theme.colorScheme.onSurface.withOpacity(0.35);
    bgColor = _isPressed
        ? theme.colorScheme.primary.withOpacity(isDark ? 0.2 : 0.14)
        : (_isHovered
            ? theme.colorScheme.primary.withOpacity(isDark ? 0.14 : 0.08)
            : (isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.white.withOpacity(0.6)));
    borderColor = _isHovered
        ? theme.colorScheme.primary.withOpacity(isDark ? 0.5 : 0.35)
        : theme.colorScheme.outline.withOpacity(isDark ? 0.2 : 0.15);
    if (_isHovered && isEnabled) {
      shadows = [
        BoxShadow(
          color: theme.colorScheme.shadow.withOpacity(isDark ? 0.15 : 0.08),
          blurRadius: 6,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ];
    }

    return MouseRegion(
      onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: isEnabled ? (_) => setState(() => _isHovered = false) : null,
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Tooltip(
        message: widget.label ?? '',
        waitDuration: const Duration(milliseconds: 500),
        child: GestureDetector(
          onTapDown: isEnabled
              ? (_) {
                  setState(() => _isPressed = true);
                  _scaleController.forward();
                }
              : null,
          onTapUp: isEnabled
              ? (_) {
                  setState(() => _isPressed = false);
                  _scaleController.reverse();
                }
              : null,
          onTapCancel: isEnabled
              ? () {
                  setState(() => _isPressed = false);
                  _scaleController.reverse();
                }
              : null,
          onTap: widget.onPressed,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: hasLabel ? 12 : 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: borderColor,
                      width: _isHovered ? 1.4 : 1.0,
                    ),
                    boxShadow: shadows,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.icon,
                        size: 17,
                        color: iconColor,
                      ),
                      if (hasLabel) ...[
                        const SizedBox(width: 6),
                        Text(
                          widget.label!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: labelColor,
                            fontSize: 12.5,
                            fontWeight:
                                _isHovered ? FontWeight.w600 : FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
