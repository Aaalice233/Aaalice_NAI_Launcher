import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/vibe_library_category_provider.dart';
import '../../providers/vibe_library_provider.dart';
import '../../providers/vibe_library_selection_provider.dart';
import '../../widgets/bulk_action_bar.dart';
import '../../widgets/common/compact_icon_button.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/common/themed_input_dialog.dart';
import '../mixins/vibe_library_import_mixin.dart';
import 'widgets/vibe_category_tree_view.dart';

/// Vibe库桌面端布局
class DesktopVibeLibraryLayout extends ConsumerStatefulWidget {
  final Widget content;
  final Widget paginationBar;
  final bool showCategoryPanel;
  final VoidCallback onToggleCategoryPanel;
  final VoidCallback onRefresh;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onEnterSelectionMode;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onShowImportMenu;
  final List<BulkActionItem> bulkActions;
  final bool isDragging;
  final Widget dropOverlay;
  final ValueChanged<bool> onDropChanged;
  final Widget? importOverlay;

  const DesktopVibeLibraryLayout({
    super.key,
    required this.content,
    required this.paginationBar,
    required this.showCategoryPanel,
    required this.onToggleCategoryPanel,
    required this.onRefresh,
    required this.onImport,
    required this.onExport,
    required this.onEnterSelectionMode,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onShowImportMenu,
    required this.bulkActions,
    required this.isDragging,
    required this.dropOverlay,
    required this.onDropChanged,
    this.importOverlay,
  });

  @override
  ConsumerState<DesktopVibeLibraryLayout> createState() =>
      _DesktopVibeLibraryLayoutState();
}

class _DesktopVibeLibraryLayoutState
    extends ConsumerState<DesktopVibeLibraryLayout>
    with VibeLibraryImportMixin<DesktopVibeLibraryLayout> {

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vibeLibraryNotifierProvider);
    final categoryState = ref.watch(vibeLibraryCategoryNotifierProvider);
    final selectionState = ref.watch(vibeLibrarySelectionNotifierProvider);
    final theme = Theme.of(context);

    return Stack(
      children: [
        Row(
          children: [
            // 左侧分类面板
            if (widget.showCategoryPanel)
              _buildCategoryPanel(theme, categoryState, state),
            // 右侧主内容
            Expanded(
              child: Column(
                children: [
                  // 工具栏
                  _buildToolbar(state, selectionState, theme),
                  // 主体内容
                  Expanded(child: widget.content),
                  // 底部分页条
                  if (!state.isLoading &&
                      state.filteredEntries.isNotEmpty &&
                      state.totalPages > 0)
                    widget.paginationBar,
                ],
              ),
            ),
          ],
        ),
        // 拖拽覆盖层
        if (widget.isDragging) widget.dropOverlay,
        // 导入进度覆盖层
        if (isImporting) buildImportOverlay(theme),
      ],
    );
  }

  Widget _buildCategoryPanel(
    ThemeData theme,
    VibeLibraryCategoryState categoryState,
    VibeLibraryState state,
  ) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // 顶部标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: const BoxConstraints(minHeight: 62),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '分类',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showCreateCategoryDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新建', style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
          // 分类树
          Expanded(
            child: VibeCategoryTreeView(
              categories: categoryState.categories,
              selectedCategoryId: categoryState.selectedCategoryId,
              categoryEntryCounts: {
                for (final category in categoryState.categories)
                  category.id: state.entries
                      .where((e) => e.categoryIds.contains(category.id))
                      .length,
              },
              allEntriesCount: state.entries.length,
              onCategorySelected: (id) {
                ref
                    .read(vibeLibraryCategoryNotifierProvider.notifier)
                    .selectCategory(id);
                if (id == 'favorites') {
                  ref
                      .read(vibeLibraryNotifierProvider.notifier)
                      .setFavoritesOnly(true);
                } else {
                  ref
                      .read(vibeLibraryNotifierProvider.notifier)
                      .setFavoritesOnly(false);
                  ref
                      .read(vibeLibraryNotifierProvider.notifier)
                      .setCategoryFilter(id);
                }
              },
              onRename: (id, newName) async {
                await ref
                    .read(vibeLibraryCategoryNotifierProvider.notifier)
                    .renameCategory(id, newName);
              },
              onDelete: (id) async {
                final confirmed = await ThemedConfirmDialog.show(
                  context: context,
                  title: '确认删除',
                  content: '确定要删除此分类吗？分类下的Vibe将被移动到未分类。',
                  confirmText: '删除',
                  cancelText: '取消',
                  type: ThemedConfirmDialogType.danger,
                  icon: Icons.delete_outline,
                );
                if (confirmed) {
                  await ref
                      .read(vibeLibraryCategoryNotifierProvider.notifier)
                      .deleteCategory(id, moveEntriesToParent: true);
                }
              },
              onAddSubCategory: (parentId) async {
                final name = await ThemedInputDialog.show(
                  context: context,
                  title: parentId == null ? '新建分类' : '新建子分类',
                  hintText: '请输入分类名称',
                  confirmText: '创建',
                  cancelText: '取消',
                );
                if (name != null && name.isNotEmpty) {
                  await ref
                      .read(vibeLibraryCategoryNotifierProvider.notifier)
                      .createCategory(name, parentId: parentId);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(
    VibeLibraryState state,
    SelectionModeState selectionState,
    ThemeData theme,
  ) {
    if (selectionState.isActive) {
      return _buildBulkActionBar(state, selectionState, theme);
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: const BoxConstraints(minHeight: 62),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.surfaceContainerHigh.withOpacity(0.9)
                : theme.colorScheme.surface.withOpacity(0.8),
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withOpacity(
                  theme.brightness == Brightness.dark ? 0.2 : 0.3,
                ),
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Vibe库',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              if (!state.isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? theme.colorScheme.primaryContainer.withOpacity(0.4)
                        : theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    state.hasFilters
                        ? '${state.filteredCount}/${state.totalCount}'
                        : '${state.totalCount}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(child: _buildSearchField(theme)),
              const SizedBox(width: 8),
              _buildSortButton(theme, state),
              const SizedBox(width: 6),
              CompactIconButton(
                icon: widget.showCategoryPanel
                    ? Icons.view_sidebar
                    : Icons.view_sidebar_outlined,
                label: '分类',
                tooltip: widget.showCategoryPanel ? '隐藏分类面板' : '显示分类面板',
                onPressed: widget.onToggleCategoryPanel,
              ),
              const SizedBox(width: 6),
              CompactIconButton(
                icon: Icons.checklist,
                label: '多选',
                tooltip: '进入选择模式',
                onPressed: widget.onEnterSelectionMode,
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onSecondaryTapDown: (details) {
                  if (!(isImporting || isPickingFile)) {
                    widget.onShowImportMenu();
                  }
                },
                child: CompactIconButton(
                  icon: Icons.file_download_outlined,
                  label: '导入',
                  tooltip: '导入.naiv4vibe或.naiv4vibebundle文件（右键查看更多选项）',
                  isLoading: isPickingFile,
                  onPressed: (isImporting || isPickingFile)
                      ? null
                      : widget.onImport,
                ),
              ),
              const SizedBox(width: 6),
              CompactIconButton(
                icon: Icons.file_upload_outlined,
                label: '导出',
                tooltip: '导出Vibe到文件',
                onPressed: state.entries.isEmpty ? null : widget.onExport,
              ),
              const SizedBox(width: 6),
              _buildRefreshButton(state, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return Container(
      height: 36,
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: widget.searchController,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: '搜索Vibe名称或标签...',
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
          suffixIcon: widget.searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  onPressed: () {
                    widget.searchController.clear();
                    widget.onClearSearch();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
        onChanged: widget.onSearchChanged,
        onSubmitted: widget.onSearchChanged,
      ),
    );
  }

  Widget _buildSortButton(ThemeData theme, VibeLibraryState state) {
    IconData sortIcon;
    String sortLabel;

    switch (state.sortOrder) {
      case VibeLibrarySortOrder.createdAt:
        sortIcon = Icons.access_time;
        sortLabel = '创建时间';
      case VibeLibrarySortOrder.lastUsed:
        sortIcon = Icons.history;
        sortLabel = '最近使用';
      case VibeLibrarySortOrder.usedCount:
        sortIcon = Icons.trending_up;
        sortLabel = '使用次数';
      case VibeLibrarySortOrder.name:
        sortIcon = Icons.sort_by_alpha;
        sortLabel = '名称';
    }

    return PopupMenuButton<VibeLibrarySortOrder>(
      tooltip: '排序方式',
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(sortIcon, size: 16),
            const SizedBox(width: 4),
            Text(sortLabel, style: const TextStyle(fontSize: 12)),
            Icon(
              state.sortDescending
                  ? Icons.arrow_drop_down
                  : Icons.arrow_drop_up,
              size: 16,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        _buildSortMenuItem(
          VibeLibrarySortOrder.createdAt,
          '创建时间',
          Icons.access_time,
          state,
        ),
        _buildSortMenuItem(
          VibeLibrarySortOrder.lastUsed,
          '最近使用',
          Icons.history,
          state,
        ),
        _buildSortMenuItem(
          VibeLibrarySortOrder.usedCount,
          '使用次数',
          Icons.trending_up,
          state,
        ),
        _buildSortMenuItem(
          VibeLibrarySortOrder.name,
          '名称',
          Icons.sort_by_alpha,
          state,
        ),
      ],
      onSelected: (order) {
        ref.read(vibeLibraryNotifierProvider.notifier).setSortOrder(order);
      },
    );
  }

  PopupMenuItem<VibeLibrarySortOrder> _buildSortMenuItem(
    VibeLibrarySortOrder order,
    String label,
    IconData icon,
    VibeLibraryState state,
  ) {
    final isSelected = state.sortOrder == order;
    return PopupMenuItem(
      value: order,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.blue : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blue : null,
              fontWeight: isSelected ? FontWeight.w600 : null,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(
              state.sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
              size: 16,
              color: Colors.blue,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRefreshButton(VibeLibraryState state, ThemeData theme) {
    if (state.isLoading) {
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
              '加载中...',
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
      tooltip: '刷新Vibe库',
      onPressed: widget.onRefresh,
    );
  }

  Widget _buildBulkActionBar(
    VibeLibraryState state,
    SelectionModeState selectionState,
    ThemeData theme,
  ) {
    final currentIds = state.currentEntries.map((e) => e.id).toList();
    final isAllSelected = currentIds.isNotEmpty &&
        currentIds.every((id) => selectionState.selectedIds.contains(id));

    return BulkActionBar(
      selectedCount: selectionState.selectedIds.length,
      isAllSelected: isAllSelected,
      onExit: () {
        ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
      },
      onSelectAll: () {
        if (isAllSelected) {
          ref
              .read(vibeLibrarySelectionNotifierProvider.notifier)
              .clearSelection();
        } else {
          ref
              .read(vibeLibrarySelectionNotifierProvider.notifier)
              .selectAll(currentIds);
        }
      },
      actions: widget.bulkActions,
    );
  }

  Future<void> _showCreateCategoryDialog(BuildContext context) async {
    final name = await ThemedInputDialog.show(
      context: context,
      title: '新建分类',
      hintText: '请输入分类名称',
      confirmText: '创建',
      cancelText: '取消',
    );
    if (name != null && name.isNotEmpty) {
      await ref
          .read(vibeLibraryCategoryNotifierProvider.notifier)
          .createCategory(name);
    }
  }
}
