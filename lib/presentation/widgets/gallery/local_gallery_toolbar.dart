import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/shortcuts/default_shortcuts.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../bulk_action_bar.dart';
import '../common/compact_icon_button.dart';
import '../gallery_filter_panel.dart';
import '../grouped_grid_view.dart' show ImageDateGroup;

import '../common/app_toast.dart';
import '../autocomplete/autocomplete_wrapper.dart';
import '../autocomplete/autocomplete_controller.dart';
import '../autocomplete/strategies/local_tag_strategy.dart';

/// Local gallery toolbar with search, filter and actions
/// 本地画廊工具栏（搜索、过滤、操作按钮）
class LocalGalleryToolbar extends ConsumerStatefulWidget {
  /// Whether 3D card view mode is active
  /// 是否启用3D卡片视图模式
  final bool use3DCardView;

  /// Callback when view mode is toggled
  /// 视图模式切换回调
  final VoidCallback? onToggleViewMode;

  /// Callback when open folder button is pressed
  /// 打开文件夹按钮回调
  final VoidCallback? onOpenFolder;

  /// Callback when refresh button is pressed
  /// 刷新按钮回调
  final VoidCallback? onRefresh;

  /// Callback when enter selection mode button is pressed
  /// 进入选择模式按钮回调
  final VoidCallback? onEnterSelectionMode;

  /// Callback when undo button is pressed
  /// 撤销按钮回调
  final VoidCallback? onUndo;

  /// Callback when redo button is pressed
  /// 重做按钮回调
  final VoidCallback? onRedo;

  /// Whether undo is available
  /// 是否可撤销
  final bool canUndo;

  /// Whether redo is available
  /// 是否可重做
  final bool canRedo;

  /// Key for GroupedGridView to scroll to group
  /// 用于滚动到分组的 GroupedGridView key
  final GlobalKey? groupedGridViewKey;

  /// Callbacks for bulk actions
  /// 批量操作回调
  final VoidCallback? onAddToCollection;
  final VoidCallback? onDeleteSelected;
  final VoidCallback? onPackSelected;
  final VoidCallback? onEditMetadata;
  final VoidCallback? onMoveToFolder;

  /// Whether category panel is visible
  /// 是否显示分类面板
  final bool showCategoryPanel;

  /// Callback when category panel toggle is pressed
  /// 分类面板切换按钮回调
  final VoidCallback? onToggleCategoryPanel;

  const LocalGalleryToolbar({
    super.key,
    this.use3DCardView = true,
    this.onToggleViewMode,
    this.onOpenFolder,
    this.onRefresh,
    this.onEnterSelectionMode,
    this.onUndo,
    this.onRedo,
    this.canUndo = false,
    this.canRedo = false,
    this.groupedGridViewKey,
    this.onAddToCollection,
    this.onDeleteSelected,
    this.onPackSelected,
    this.onEditMetadata,
    this.onMoveToFolder,
    this.showCategoryPanel = true,
    this.onToggleCategoryPanel,
  });

  @override
  ConsumerState<LocalGalleryToolbar> createState() =>
      _LocalGalleryToolbarState();
}

class _LocalGalleryToolbarState extends ConsumerState<LocalGalleryToolbar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  Future<LocalTagStrategy>? _searchStrategyFuture;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    // Future 不需要 dispose
    super.dispose();
  }

  /// Search with debounce
  /// 搜索防抖
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(localGalleryNotifierProvider.notifier).setSearchQuery(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localGalleryNotifierProvider);
    final selectionState = ref.watch(localGallerySelectionNotifierProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Show bulk action bar when in selection mode
    // 选择模式时显示批量操作栏
    if (selectionState.isActive) {
      final allImagePaths = state.currentImages.map((r) => r.path).toList();
      final isAllSelected = allImagePaths.isNotEmpty &&
          allImagePaths.every((p) => selectionState.selectedIds.contains(p));

      return BulkActionBar(
        selectedCount: selectionState.selectedIds.length,
        isAllSelected: isAllSelected,
        onExit: () =>
            ref.read(localGallerySelectionNotifierProvider.notifier).exit(),
        onSelectAll: () {
          if (isAllSelected) {
            ref
                .read(localGallerySelectionNotifierProvider.notifier)
                .clearSelection();
          } else {
            ref
                .read(localGallerySelectionNotifierProvider.notifier)
                .selectAll(allImagePaths);
          }
        },
        actions: [
          BulkActionItem(
            icon: Icons.drive_file_move_outline,
            label: '移动',
            onPressed: widget.onMoveToFolder,
            color: theme.colorScheme.secondary,
          ),
          BulkActionItem(
            icon: Icons.archive_outlined,
            label: '打包',
            onPressed: widget.onPackSelected,
            color: theme.colorScheme.tertiary,
          ),
          BulkActionItem(
            icon: Icons.edit_outlined,
            label: '编辑',
            onPressed: widget.onEditMetadata,
            color: theme.colorScheme.primary,
          ),
          BulkActionItem(
            icon: Icons.playlist_add,
            label: '收藏',
            onPressed: widget.onAddToCollection,
            color: theme.colorScheme.secondary,
          ),
          BulkActionItem(
            icon: Icons.delete_outline,
            label: '删除',
            onPressed: widget.onDeleteSelected,
            color: theme.colorScheme.error,
            isDanger: true,
            showDividerBefore: true,
          ),
        ],
      );
    }

    // Normal toolbar
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Single row: title + count + search + filter/action buttons
              Row(
                children: [
                  // Title
                  Text(
                    '本地画廊',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Image count
                  if (!state.isIndexing)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? theme.colorScheme.primaryContainer
                                .withOpacity(0.4)
                            : theme.colorScheme.primaryContainer
                                .withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        state.hasFilters
                            ? '${state.filteredCount}/${state.totalCount}'
                            : '${state.totalCount}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  // Search field (expanded)
                  Expanded(
                    child: _buildSearchField(theme, state),
                  ),
                  const SizedBox(width: 8),
                  // Filter button group
                  _buildDateRangeButton(theme, state),
                  const SizedBox(width: 6),
                  CompactIconButton(
                    icon: Icons.calendar_today,
                    label: '日期',
                    tooltip: '跳转到日期',
                    shortcutId: ShortcutIds.jumpToDate,
                    onPressed: () => _pickDateAndJump(context),
                  ),
                  const SizedBox(width: 6),
                  CompactIconButton(
                    icon: Icons.tune,
                    label: '筛选',
                    tooltip: '打开筛选面板',
                    shortcutId: ShortcutIds.openFilterPanel,
                    onPressed: () => showGalleryFilterPanel(context),
                  ),
                  // Note: View mode toggle removed - only 3D card view is supported now
                  if (state.hasFilters) ...[
                    const SizedBox(width: 6),
                    CompactIconButton(
                      icon: Icons.filter_alt_off,
                      label: '清除',
                      tooltip: '清除筛选',
                      shortcutId: ShortcutIds.clearFilter,
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(localGalleryNotifierProvider.notifier)
                            .clearAllFilters();
                      },
                      isDanger: true,
                    ),
                  ],
                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      width: 1,
                      height: 24,
                      color: theme.dividerColor.withOpacity(0.3),
                    ),
                  ),
                  // Category panel toggle
                  if (widget.onToggleCategoryPanel != null) ...[
                    CompactIconButton(
                      icon: widget.showCategoryPanel
                          ? Icons.view_sidebar
                          : Icons.view_sidebar_outlined,
                      label: '分类',
                      tooltip: widget.showCategoryPanel ? '隐藏分类面板' : '显示分类面板',
                      shortcutId: ShortcutIds.toggleCategoryPanel,
                      onPressed: widget.onToggleCategoryPanel,
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Undo/Redo
                  if (widget.canUndo || widget.canRedo) ...[
                    CompactIconButton(
                      icon: Icons.undo,
                      tooltip: '撤销',
                      onPressed: widget.canUndo ? widget.onUndo : null,
                    ),
                    const SizedBox(width: 4),
                    CompactIconButton(
                      icon: Icons.redo,
                      tooltip: '重做',
                      onPressed: widget.canRedo ? widget.onRedo : null,
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Multi-select
                  CompactIconButton(
                    icon: Icons.checklist,
                    label: '多选',
                    tooltip: '进入选择模式',
                    shortcutId: ShortcutIds.enterSelectionMode,
                    onPressed: widget.onEnterSelectionMode,
                  ),
                  const SizedBox(width: 6),
                  // Open folder
                  CompactIconButton(
                    icon: Icons.folder_open,
                    label: '文件夹',
                    tooltip: '打开文件夹',
                    shortcutId: ShortcutIds.openFolder,
                    onPressed: widget.onOpenFolder,
                  ),
                  const SizedBox(width: 6),
                  // Refresh button (shows loading state when refreshing)
                  _RefreshButton(
                    isRefreshing: state.isLoading,
                    onRefresh: widget.onRefresh,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build search field
  /// 构建搜索框 - 类似在线画廊的简洁圆角样式
  Widget _buildSearchField(ThemeData theme, LocalGalleryState state) {
    // 缓存策略 Future，避免每次build都创建新的
    _searchStrategyFuture ??= LocalTagStrategy.create(
      ref,
      const AutocompleteConfig(
        minQueryLength: 2,
        maxSuggestions: 8,
        showTranslation: true,
        showCategory: true,
        showCount: true,
      ),
    );

    return AutocompleteWrapper(
      controller: _searchController,
      focusNode: _searchFocusNode,
      asyncStrategy: _searchStrategyFuture!,
      onSuggestionSelected: (value) {
        // 选择补全建议后立即触发搜索
        _debounceTimer?.cancel();
        ref.read(localGalleryNotifierProvider.notifier).setSearchQuery(value);
      },
      child: Container(
        height: 36,
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(18),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: '搜索文件名或 Prompt...',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color:
                          theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      ref
                          .read(localGalleryNotifierProvider.notifier)
                          .setSearchQuery('');
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            isDense: true,
          ),
          onChanged: (value) {
            setState(() {}); // 更新清除按钮可见性
            _onSearchChanged(value);
          },
          onSubmitted: (value) {
            _debounceTimer?.cancel();
            ref
                .read(localGalleryNotifierProvider.notifier)
                .setSearchQuery(value);
          },
        ),
      ),
    );
  }

  /// Build date range button
  /// 构建日期范围按钮
  Widget _buildDateRangeButton(ThemeData theme, LocalGalleryState state) {
    final hasDateRange = state.dateStart != null || state.dateEnd != null;

    return OutlinedButton.icon(
      onPressed: () => _selectDateRange(context, state),
      icon: Icon(
        Icons.date_range,
        size: 16,
        color: hasDateRange ? theme.colorScheme.primary : null,
      ),
      label: Text(
        hasDateRange
            ? _formatDateRange(state.dateStart, state.dateEnd)
            : '日期过滤',
        style: TextStyle(
          fontSize: 12,
          color: hasDateRange ? theme.colorScheme.primary : null,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        visualDensity: VisualDensity.compact,
        side:
            hasDateRange ? BorderSide(color: theme.colorScheme.primary) : null,
      ),
    );
  }

  /// Format date range display
  /// 格式化日期范围显示
  String _formatDateRange(DateTime? start, DateTime? end) {
    final format = DateFormat('MM-dd');
    if (start != null && end != null) {
      return '${format.format(start)}~${format.format(end)}';
    } else if (start != null) {
      return '${format.format(start)}~';
    } else if (end != null) {
      return '~${format.format(end)}';
    }
    return '';
  }

  /// Select date range
  /// 选择日期范围
  Future<void> _selectDateRange(
    BuildContext context,
    LocalGalleryState state,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: state.dateStart != null && state.dateEnd != null
          ? DateTimeRange(start: state.dateStart!, end: state.dateEnd!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)),
              end: now,
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(localGalleryNotifierProvider.notifier).setDateRange(
            picked.start,
            picked.end,
          );
    }
  }

  /// Pick date and jump to corresponding group
  /// 选择日期并跳转到对应分组
  Future<void> _pickDateAndJump(BuildContext context) async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (pickerContext, child) {
        return Theme(
          data: Theme.of(pickerContext).copyWith(
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      // Ensure grouped view is activated
      final currentState = ref.read(localGalleryNotifierProvider);
      final notifier = ref.read(localGalleryNotifierProvider.notifier);
      if (!currentState.isGroupedView) {
        notifier.setGroupedView(true);
      }

      // Wait for grouped data to load
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // Calculate which group the selected date belongs to
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
      final selectedDate = DateTime(picked.year, picked.month, picked.day);

      ImageDateGroup? targetGroup;

      if (selectedDate == today) {
        targetGroup = ImageDateGroup.today;
      } else if (selectedDate == yesterday) {
        targetGroup = ImageDateGroup.yesterday;
      } else if (selectedDate.isAfter(thisWeekStart) &&
          selectedDate.isBefore(today)) {
        targetGroup = ImageDateGroup.thisWeek;
      } else {
        targetGroup = ImageDateGroup.earlier;
      }

      // Jump to corresponding group using the key
      if (widget.groupedGridViewKey?.currentState != null) {
        (widget.groupedGridViewKey!.currentState as dynamic)
            .scrollToGroup(targetGroup);
      }

      // Show hint message
      if (context.mounted) {
        AppToast.info(
          context,
          '已跳转到 ${picked.year}-${picked.month.toString().padLeft(2, '0')}',
        );
      }
    }
  }
}

/// 刷新按钮（带加载状态）
class _RefreshButton extends StatelessWidget {
  final bool isRefreshing;
  final VoidCallback? onRefresh;

  const _RefreshButton({
    required this.isRefreshing,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isRefreshing) {
      return Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '刷新中...',
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return CompactIconButton(
      icon: Icons.refresh,
      label: '刷新',
      tooltip: '刷新画廊\n\n自动检测新增/修改的图片并更新索引',
      shortcutId: ShortcutIds.refreshGallery,
      onPressed: onRefresh,
    );
  }
}

