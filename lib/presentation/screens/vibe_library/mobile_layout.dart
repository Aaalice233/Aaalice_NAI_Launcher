import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/vibe_library_category_provider.dart';
import '../../providers/vibe_library_provider.dart';
import '../../providers/vibe_library_selection_provider.dart';
import '../../widgets/bulk_action_bar.dart';
import '../mixins/vibe_library_import_mixin.dart';
import 'widgets/vibe_category_tree_view.dart';

/// Vibe库移动端布局
class MobileVibeLibraryLayout extends ConsumerStatefulWidget {
  final Widget content;
  final Widget paginationBar;
  final VoidCallback onRefresh;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onEnterSelectionMode;
  final List<BulkActionItem> bulkActions;
  final bool isDragging;
  final Widget dropOverlay;
  final Widget? importOverlay;

  const MobileVibeLibraryLayout({
    super.key,
    required this.content,
    required this.paginationBar,
    required this.onRefresh,
    required this.onImport,
    required this.onExport,
    required this.onEnterSelectionMode,
    required this.bulkActions,
    required this.isDragging,
    required this.dropOverlay,
    this.importOverlay,
  });

  @override
  ConsumerState<MobileVibeLibraryLayout> createState() =>
      _MobileVibeLibraryLayoutState();
}

class _MobileVibeLibraryLayoutState
    extends ConsumerState<MobileVibeLibraryLayout>
    with VibeLibraryImportMixin<MobileVibeLibraryLayout> {

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vibeLibraryNotifierProvider);
    final selectionState = ref.watch(vibeLibrarySelectionNotifierProvider);
    final theme = Theme.of(context);

    return Stack(
      children: [
        Column(
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
        // 拖拽覆盖层
        if (widget.isDragging) widget.dropOverlay,
        // 导入进度覆盖层
        if (isImporting) buildImportOverlay(theme),
      ],
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(minHeight: 56),
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
          child: SafeArea(
            bottom: false,
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
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: '多选',
                  onPressed: widget.onEnterSelectionMode,
                ),
                IconButton(
                  icon: const Icon(Icons.file_download_outlined),
                  tooltip: '导入',
                  onPressed:
                      (isImporting || isPickingFile) ? null : widget.onImport,
                ),
                IconButton(
                  icon: const Icon(Icons.folder_outlined),
                  tooltip: '分类',
                  onPressed: () => _showCategoryBottomSheet(context),
                ),
              ],
            ),
          ),
        ),
      ),
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
      actions: widget.bulkActions.where((a) => !a.showDividerBefore).toList(),
    );
  }

  void _showCategoryBottomSheet(BuildContext context) {
    final categoryState = ref.read(vibeLibraryCategoryNotifierProvider);
    final state = ref.read(vibeLibraryNotifierProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        '分类',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
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
                      Navigator.of(context).pop();
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
                    onRename: (_, __) async {},
                    onDelete: (_) async {},
                    onAddSubCategory: (_) async {},
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
