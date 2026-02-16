import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/models/vibe/vibe_library_entry.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../providers/vibe_library_category_provider.dart';
import '../../providers/vibe_library_provider.dart';
import '../../providers/vibe_library_selection_provider.dart';
import '../../router/app_router.dart';
import '../../widgets/bulk_action_bar.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/compact_icon_button.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/common/themed_input_dialog.dart';
import '../../widgets/common/pro_context_menu.dart';
import '../../widgets/gallery/gallery_state_views.dart';
import 'widgets/vibe_card_3d.dart';
import 'widgets/vibe_detail_viewer.dart';
import 'widgets/vibe_export_dialog.dart';
import 'widgets/category_item.dart';
import 'widgets/context_menu_route.dart';
import 'widgets/import_menu_route.dart';
import 'widgets/vibe_category_tree_view.dart';
import 'widgets/vibe_library_empty_view.dart';
import 'widgets/vibe_library_content_view.dart';
import 'vibe_intents.dart';
import 'mixins/vibe_library_import_mixin.dart';

/// Vibe库屏幕
/// Vibe Library Screen
class VibeLibraryScreen extends ConsumerStatefulWidget {
  const VibeLibraryScreen({super.key});

  @override
  ConsumerState<VibeLibraryScreen> createState() => _VibeLibraryScreenState();
}

class _VibeLibraryScreenState extends ConsumerState<VibeLibraryScreen>
    with VibeLibraryImportMixin<VibeLibraryScreen> {
  /// 是否显示分类面板
  bool _showCategoryPanel = true;

  /// 搜索控制器
  final TextEditingController _searchController = TextEditingController();

  /// 是否正在拖拽文件
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // 初始化Vibe库
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vibeLibraryNotifierProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vibeLibraryNotifierProvider);
    final categoryState = ref.watch(vibeLibraryCategoryNotifierProvider);
    final selectionState = ref.watch(vibeLibrarySelectionNotifierProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);

    // 计算内容区域宽度
    final contentWidth = _showCategoryPanel && screenWidth > 800
        ? screenWidth - 250
        : screenWidth;

    // 计算列数（200px/列，最少2列，最多8列）
    final columns = (contentWidth / 200).floor().clamp(2, 8);
    // 考虑 GridView padding (16 * 2 = 32) 后计算每个 item 的宽度
    final itemWidth = (contentWidth - 32) / columns;

    return Scaffold(
      body: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyI):
              const VibeImportIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyE):
              const VibeExportIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            VibeImportIntent: CallbackAction<VibeImportIntent>(
              onInvoke: (intent) {
                if (!(isImporting || isPickingFile)) {
                  importVibes();
                }
                return null;
              },
            ),
            VibeExportIntent: CallbackAction<VibeExportIntent>(
              onInvoke: (intent) {
                final state = ref.read(vibeLibraryNotifierProvider);
                if (state.entries.isNotEmpty) {
                  _exportVibes();
                }
                return null;
              },
            ),
          },
          child: DropRegion(
            formats: Formats.standardFormats,
            hitTestBehavior: HitTestBehavior.opaque,
            onDropOver: (event) {
              // 检查是否包含文件
              if (event.session.allowedOperations
                  .contains(DropOperation.copy)) {
                if (!_isDragging) {
                  setState(() => _isDragging = true);
                }
                return DropOperation.copy;
              }
              return DropOperation.none;
            },
            onDropLeave: (event) {
              if (_isDragging) {
                setState(() => _isDragging = false);
              }
            },
            onPerformDrop: (event) async {
              setState(() => _isDragging = false);
              await handleDrop(event);
            },
            child: Stack(
              children: [
                Row(
                  children: [
                    // 左侧分类面板
                    if (_showCategoryPanel && screenWidth > 800)
                      Container(
                        width: 250,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          border: Border(
                            right: BorderSide(
                              color: theme.colorScheme.outlineVariant
                                  .withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            // 顶部标题栏
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
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
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: () =>
                                        _showCreateCategoryDialog(context),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text(
                                      '新建',
                                      style: TextStyle(fontSize: 13),
                                    ),
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
                              color: theme.colorScheme.outlineVariant
                                  .withOpacity(0.3),
                            ),
                            // 分类树
                            Expanded(
                              child: VibeCategoryTreeView(
                                categories: categoryState.categories,
                                selectedCategoryId:
                                    categoryState.selectedCategoryId,
                                categoryEntryCounts: {
                                  for (final category
                                      in categoryState.categories)
                                    category.id: state.entries
                                        .where(
                                          (e) => e.categoryIds.contains(
                                            category.id,
                                          ),
                                        )
                                        .length,
                                },
                                allEntriesCount: state.entries.length,
                                onCategorySelected: (id) {
                                  ref
                                      .read(
                                        vibeLibraryCategoryNotifierProvider
                                            .notifier,
                                      )
                                      .selectCategory(id);
                                  if (id == 'favorites') {
                                    ref
                                        .read(
                                          vibeLibraryNotifierProvider.notifier,
                                        )
                                        .setFavoritesOnly(true);
                                  } else {
                                    // 切换到其他分类时，清除收藏过滤状态
                                    ref
                                        .read(
                                          vibeLibraryNotifierProvider.notifier,
                                        )
                                        .setFavoritesOnly(false);
                                    ref
                                        .read(
                                          vibeLibraryNotifierProvider.notifier,
                                        )
                                        .setCategoryFilter(id);
                                  }
                                },
                                onRename: (id, newName) async {
                                  await ref
                                      .read(
                                        vibeLibraryCategoryNotifierProvider
                                            .notifier,
                                      )
                                      .renameCategory(id, newName);
                                },
                                onDelete: (id) async {
                                  final confirmed =
                                      await ThemedConfirmDialog.show(
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
                                        .read(
                                          vibeLibraryCategoryNotifierProvider
                                              .notifier,
                                        )
                                        .deleteCategory(
                                          id,
                                          moveEntriesToParent: true,
                                        );
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
                                        .read(
                                          vibeLibraryCategoryNotifierProvider
                                              .notifier,
                                        )
                                        .createCategory(
                                          name,
                                          parentId: parentId,
                                        );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    // 右侧主内容
                    Expanded(
                      child: Column(
                        children: [
                          // 工具栏
                          _buildToolbar(state, selectionState, theme),
                          // 主体内容
                          Expanded(
                            child: _buildBody(
                              state,
                              columns,
                              itemWidth,
                              selectionState,
                            ),
                          ),
                          // 底部分页条
                          if (!state.isLoading &&
                              state.filteredEntries.isNotEmpty &&
                              state.totalPages > 0)
                            _buildPaginationBar(state, contentWidth),
                        ],
                      ),
                    ),
                  ],
                ),
                // 拖拽覆盖层
                if (_isDragging) _buildDropOverlay(theme),
                // 导入进度覆盖层
                if (isImporting) buildImportOverlay(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建工具栏
  Widget _buildToolbar(
    VibeLibraryState state,
    SelectionModeState selectionState,
    ThemeData theme,
  ) {
    // 选择模式时显示批量操作栏
    if (selectionState.isActive) {
      return _buildBulkActionBar(state, selectionState, theme);
    }

    // 普通工具栏
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
              // 标题
              Text(
                'Vibe库',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              // 数量
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
              // 搜索框
              Expanded(
                child: _buildSearchField(theme, state),
              ),
              const SizedBox(width: 8),
              // 排序按钮
              _buildSortButton(theme, state),
              const SizedBox(width: 6),
              // 分类面板切换
              CompactIconButton(
                icon: _showCategoryPanel
                    ? Icons.view_sidebar
                    : Icons.view_sidebar_outlined,
                label: '分类',
                tooltip: _showCategoryPanel ? '隐藏分类面板' : '显示分类面板',
                onPressed: () {
                  setState(() {
                    _showCategoryPanel = !_showCategoryPanel;
                  });
                },
              ),
              const SizedBox(width: 6),
              // 选择模式
              CompactIconButton(
                icon: Icons.checklist,
                label: '多选',
                tooltip: '进入选择模式',
                onPressed: () {
                  ref
                      .read(vibeLibrarySelectionNotifierProvider.notifier)
                      .enter();
                },
              ),
              const SizedBox(width: 6),
              // 导入按钮（支持右键菜单）
              GestureDetector(
                onSecondaryTapDown: (details) {
                  if (!(isImporting || isPickingFile)) {
                    _showImportMenu(details.globalPosition);
                  }
                },
                child: CompactIconButton(
                  icon: Icons.file_download_outlined,
                  label: '导入',
                  tooltip: '导入.naiv4vibe或.naiv4vibebundle文件（右键查看更多选项）',
                  isLoading: isPickingFile,
                  onPressed: (isImporting || isPickingFile)
                      ? null
                      : () => importVibes(),
                ),
              ),
              const SizedBox(width: 6),
              // 导出按钮
              CompactIconButton(
                icon: Icons.file_upload_outlined,
                label: '导出',
                tooltip: '导出Vibe到文件',
                onPressed: state.entries.isEmpty ? null : () => _exportVibes(),
              ),
              const SizedBox(width: 6),
              // 刷新按钮
              _buildRefreshButton(state, theme),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建搜索框
  Widget _buildSearchField(ThemeData theme, VibeLibraryState state) {
    return Container(
      height: 36,
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: _searchController,
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
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    ref
                        .read(vibeLibraryNotifierProvider.notifier)
                        .clearSearch();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
        onChanged: (value) {
          setState(() {});
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              ref
                  .read(vibeLibraryNotifierProvider.notifier)
                  .setSearchQuery(value);
            }
          });
        },
        onSubmitted: (value) {
          ref.read(vibeLibraryNotifierProvider.notifier).setSearchQuery(value);
        },
      ),
    );
  }

  /// 构建排序按钮
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

  /// 构建刷新按钮
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
      onPressed: () {
        ref.read(vibeLibraryNotifierProvider.notifier).reload();
      },
    );
  }

  /// 构建批量操作栏
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
      actions: [
        BulkActionItem(
          icon: Icons.send,
          label: '发送到生成',
          onPressed: () => _batchSendToGeneration(),
          color: theme.colorScheme.primary,
        ),
        BulkActionItem(
          icon: Icons.drive_file_move_outline,
          label: '移动',
          onPressed: () => _showMoveToCategoryDialog(context),
          color: theme.colorScheme.secondary,
        ),
        BulkActionItem(
          icon: Icons.file_upload_outlined,
          label: '导出',
          onPressed: () => _batchExport(),
          color: theme.colorScheme.secondary,
        ),
        BulkActionItem(
          icon: Icons.favorite_border,
          label: '收藏',
          onPressed: () => _batchToggleFavorite(),
          color: theme.colorScheme.primary,
        ),
        BulkActionItem(
          icon: Icons.delete_outline,
          label: '删除',
          onPressed: () => _batchDelete(),
          color: theme.colorScheme.error,
          isDanger: true,
          showDividerBefore: true,
        ),
      ],
    );
  }

  /// 构建主体内容
  Widget _buildBody(
    VibeLibraryState state,
    int columns,
    double itemWidth,
    SelectionModeState selectionState,
  ) {
    if (state.error != null) {
      return GalleryErrorView(
        error: state.error,
        onRetry: () {
          ref.read(vibeLibraryNotifierProvider.notifier).reload();
        },
      );
    }

    if (state.isInitializing && state.entries.isEmpty) {
      return const GalleryLoadingView();
    }

    if (state.entries.isEmpty) {
      return const VibeLibraryEmptyView();
    }

    return VibeLibraryContentView(
      columns: columns,
      itemWidth: itemWidth,
      onShowDetail: _showVibeDetail,
      onShowContextMenu: _showContextMenuForEntry,
      onSendToGeneration: _sendEntryToGeneration,
      onExport: _exportSingleEntry,
      onDelete: _deleteSingleEntry,
    );
  }

  /// 构建分页条
  Widget _buildPaginationBar(VibeLibraryState state, double contentWidth) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: state.currentPage > 0
                ? () {
                    ref
                        .read(vibeLibraryNotifierProvider.notifier)
                        .loadPreviousPage();
                  }
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${state.currentPage + 1} / ${state.totalPages} 页',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: state.currentPage < state.totalPages - 1
                ? () {
                    ref
                        .read(vibeLibraryNotifierProvider.notifier)
                        .loadNextPage();
                  }
                : null,
          ),
          const SizedBox(width: 16),
          Text('每页:', style: theme.textTheme.bodySmall),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: state.pageSize,
            underline: const SizedBox(),
            items: [20, 50, 100].map((size) {
              return DropdownMenuItem(
                value: size,
                child: Text('$size'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                ref
                    .read(vibeLibraryNotifierProvider.notifier)
                    .setPageSize(value);
              }
            },
          ),
          const Spacer(),
          Text(
            '共 ${state.filteredCount} 个Vibe',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// 构建拖拽覆盖层
  Widget _buildDropOverlay(ThemeData theme) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.file_download_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '释放以导入 Vibe',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '支持 .naiv4vibe、.naiv4vibebundle 和 .png 文件',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示 Vibe 详情
  void _showVibeDetail(BuildContext context, VibeLibraryEntry entry) {
    VibeDetailViewer.show(
      context,
      entry: entry,
      heroTag: 'vibe_${entry.id}',
      callbacks: VibeDetailCallbacks(
        onSendToGeneration: (entry, strength, infoExtracted) {
          _sendEntryToGenerationWithParams(
            context,
            entry,
            strength,
            infoExtracted,
          );
        },
        onExport: (entry) {
          _exportSingleEntry(context, entry);
        },
        onDelete: (entry) {
          _deleteSingleEntry(context, entry);
        },
        onRename: (entry, newName) {
          return _renameSingleEntry(context, entry, newName);
        },
        onParamsChanged: (entry, strength, infoExtracted) {
          _updateEntryParams(context, entry, strength, infoExtracted);
        },
      ),
    );
  }

  /// 显示上下文菜单
  void _showContextMenuForEntry(
    BuildContext context,
    VibeLibraryEntry entry,
    Offset position,
  ) {
    final items = <ProMenuItem>[
      ProMenuItem(
        id: 'send_to_generation',
        label: '发送到生成',
        icon: Icons.send,
        onTap: () => _sendEntryToGeneration(context, entry),
      ),
      ProMenuItem(
        id: 'export',
        label: '导出',
        icon: Icons.download,
        onTap: () => _exportSingleEntry(context, entry),
      ),
      ProMenuItem(
        id: 'edit',
        label: '编辑',
        icon: Icons.edit,
        onTap: () => _showVibeDetail(context, entry),
      ),
      const ProMenuItem.divider(),
      ProMenuItem(
        id: 'toggle_favorite',
        label: entry.isFavorite ? '取消收藏' : '收藏',
        icon: entry.isFavorite ? Icons.favorite : Icons.favorite_border,
        onTap: () {
          ref
              .read(vibeLibraryNotifierProvider.notifier)
              .toggleFavorite(entry.id);
        },
      ),
      ProMenuItem(
        id: 'delete',
        label: '删除',
        icon: Icons.delete_outline,
        isDanger: true,
        onTap: () => _deleteSingleEntry(context, entry),
      ),
    ];

    Navigator.of(context).push(
      ContextMenuRoute(
        position: position,
        items: items,
        onSelect: (item) {
          // Item onTap is already called
        },
      ),
    );
  }

  /// 发送单个条目到生成页面
  void _sendEntryToGeneration(BuildContext context, VibeLibraryEntry entry) {
    final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);
    final currentParams = ref.read(generationParamsNotifierProvider);

    // 检查是否超过16个限制
    if (currentParams.vibeReferencesV4.length >= 16) {
      AppToast.warning(context, 'Vibe 数量已达到上限 (16个)');
      return;
    }

    // 检查是否已存在
    final exists = currentParams.vibeReferencesV4.any(
      (v) => v.vibeImagePath == entry.imagePath,
    );
    if (exists) {
      AppToast.info(context, '该 Vibe 已存在于生成参数中');
      return;
    }

    paramsNotifier.addVibeReference(entry.toVibeReference());
    AppToast.success(context, '已发送到生成页面: ${entry.displayName}');
  }

  /// 发送单个条目到生成页面（带参数）
  void _sendEntryToGenerationWithParams(
    BuildContext context,
    VibeLibraryEntry entry,
    double strength,
    double infoExtracted,
  ) {
    final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);
    final currentParams = ref.read(generationParamsNotifierProvider);

    // 检查是否超过16个限制
    if (currentParams.vibeReferencesV4.length >= 16) {
      AppToast.warning(context, 'Vibe 数量已达到上限 (16个)');
      return;
    }

    // 检查是否已存在
    final exists = currentParams.vibeReferencesV4.any(
      (v) => v.vibeImagePath == entry.imagePath,
    );
    if (exists) {
      AppToast.info(context, '该 Vibe 已存在于生成参数中');
      return;
    }

    final updatedEntry =
        entry.updateStrength(strength).updateInfoExtracted(infoExtracted);
    paramsNotifier.addVibeReference(updatedEntry.toVibeReference());
    AppToast.success(context, '已发送到生成页面: ${entry.displayName}');
  }

  /// 导出单个条目
  Future<void> _exportSingleEntry(
    BuildContext context,
    VibeLibraryEntry entry,
  ) async {
    final result = await VibeExportDialog.show(
      context: context,
      entries: [entry],
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      AppToast.success(context, '导出成功: ${entry.displayName}');
    }
  }

  /// 删除单个条目
  Future<void> _deleteSingleEntry(
    BuildContext context,
    VibeLibraryEntry entry,
  ) async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: '确认删除',
      content: '确定要删除 "${entry.displayName}" 吗？此操作无法撤销。',
      confirmText: '删除',
      cancelText: '取消',
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );

    if (confirmed) {
      await ref
          .read(vibeLibraryNotifierProvider.notifier)
          .deleteEntries([entry.id]);
      if (context.mounted) {
        AppToast.success(context, '已删除: ${entry.displayName}');
      }
    }
  }

  /// 重命名单个条目
  Future<String?> _renameSingleEntry(
    BuildContext context,
    VibeLibraryEntry entry,
    String newName,
  ) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      return '名称不能为空';
    }

    final result = await ref
        .read(vibeLibraryNotifierProvider.notifier)
        .renameEntry(entry.id, trimmedName);
    if (result.isSuccess) {
      return null;
    }

    switch (result.error) {
      case VibeEntryRenameError.invalidName:
        return '名称不能为空';
      case VibeEntryRenameError.nameConflict:
        return '名称已存在，请使用其他名称';
      case VibeEntryRenameError.entryNotFound:
        return '条目不存在，可能已被删除';
      case VibeEntryRenameError.filePathMissing:
        return '该条目缺少文件路径，无法重命名';
      case VibeEntryRenameError.fileRenameFailed:
        return '重命名文件失败，请稍后重试';
      case null:
        return '重命名失败，请稍后重试';
    }
  }

  /// 更新条目参数
  void _updateEntryParams(
    BuildContext context,
    VibeLibraryEntry entry,
    double strength,
    double infoExtracted,
  ) {
    final updatedEntry =
        entry.updateStrength(strength).updateInfoExtracted(infoExtracted);

    ref.read(vibeLibraryNotifierProvider.notifier).saveEntry(updatedEntry);
  }

  /// 显示创建分类对话框
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

  /// 显示移动到分类对话框
  Future<void> _showMoveToCategoryDialog(BuildContext context) async {
    final selectionState = ref.read(vibeLibrarySelectionNotifierProvider);
    final categories = ref.read(vibeLibraryCategoryNotifierProvider).categories;

    if (categories.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可用的分类')),
        );
      }
      return;
    }

    final selectedCategory = await showDialog<VibeLibraryCategory>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移动到分类'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: categories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('未分类'),
                  onTap: () => Navigator.of(context).pop(null),
                );
              }
              final category = categories[index - 1];
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(category.name),
                onTap: () => Navigator.of(context).pop(category),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (selectedCategory == null || !mounted) return;

    final categoryId = selectedCategory.id;
    final ids = selectionState.selectedIds.toList();

    var movedCount = 0;
    for (final id in ids) {
      final result = await ref
          .read(vibeLibraryNotifierProvider.notifier)
          .updateEntryCategory(id, categoryId);
      if (result != null) movedCount++;
    }

    ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已移动 $movedCount 个Vibe')),
    );
  }

  /// 批量切换收藏
  Future<void> _batchToggleFavorite() async {
    final selectionState = ref.read(vibeLibrarySelectionNotifierProvider);
    final ids = selectionState.selectedIds.toList();

    for (final id in ids) {
      await ref.read(vibeLibraryNotifierProvider.notifier).toggleFavorite(id);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('收藏状态已更新')),
      );
      ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
    }
  }

  /// 批量发送到生成页面
  Future<void> _batchSendToGeneration() async {
    final selectionState = ref.read(vibeLibrarySelectionNotifierProvider);
    final selectedIds = selectionState.selectedIds.toList();

    if (selectedIds.isEmpty) return;

    // 检查是否超过16个限制
    if (selectedIds.length > 16) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Vibe数量过多'),
            content: Text(
              '选中了 ${selectedIds.length} 个Vibe，但最多只能同时使用16个。\n\n'
              '请减少选择数量后再试。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 获取选中的条目
    final state = ref.read(vibeLibraryNotifierProvider);
    final selectedEntries =
        state.entries.where((e) => selectedIds.contains(e.id)).toList();

    // 获取当前的生成参数
    final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);
    final currentParams = ref.read(generationParamsNotifierProvider);

    // 检查添加后是否会超过16个
    final currentVibeCount = currentParams.vibeReferencesV4.length;
    final willExceedLimit = currentVibeCount + selectedEntries.length > 16;

    if (willExceedLimit) {
      final remainingSlots = 16 - currentVibeCount;
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Vibe数量过多'),
            content: Text(
              '当前生成页面已有 $currentVibeCount 个Vibe，'
              '还可以添加 $remainingSlots 个。\n\n'
              '请减少选择数量后再试。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 添加选中的Vibe到生成参数
    final vibes = selectedEntries.map((e) => e.toVibeReference()).toList();
    paramsNotifier.addVibeReferences(vibes);

    // 显示成功提示
    if (mounted) {
      AppToast.success(context, '已发送 ${selectedEntries.length} 个Vibe到生成页面');
    }

    // 退出选择模式
    ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();

    // 跳转到生成页面
    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  /// 批量导出
  Future<void> _batchExport() async {
    final selectionState = ref.read(vibeLibrarySelectionNotifierProvider);
    final ids = selectionState.selectedIds.toList();

    if (ids.isEmpty) return;

    final state = ref.read(vibeLibraryNotifierProvider);
    final selectedEntries =
        state.entries.where((e) => ids.contains(e.id)).toList();

    if (selectedEntries.isEmpty) return;

    // 打开导出对话框
    await _exportVibes(specificEntries: selectedEntries);

    // 退出选择模式
    ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
  }

  /// 批量删除
  Future<void> _batchDelete() async {
    final selectionState = ref.read(vibeLibrarySelectionNotifierProvider);
    final ids = selectionState.selectedIds.toList();

    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: '确认删除',
      content: '确定要删除选中的 ${ids.length} 个Vibe吗？此操作无法撤销。',
      confirmText: '删除',
      cancelText: '取消',
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );

    if (confirmed) {
      await ref.read(vibeLibraryNotifierProvider.notifier).deleteEntries(ids);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 ${ids.length} 个Vibe')),
        );
        ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
      }
    }
  }

  /// 导出Vibes
  Future<void> _exportVibes({List<VibeLibraryEntry>? specificEntries}) async {
    final state = ref.read(vibeLibraryNotifierProvider);
    final entries = specificEntries ?? state.entries;

    if (entries.isEmpty) return;

    await VibeExportDialog.show(
      context: context,
      entries: entries,
    );
  }

  /// 显示导入右键菜单
  void _showImportMenu(Offset position) {
    Navigator.of(context).push(
      ImportMenuRoute(
        position: position,
        items: [
          ProMenuItem(
            id: 'import_file',
            label: '从文件导入',
            icon: Icons.folder_outlined,
            onTap: () => importVibes(),
          ),
          ProMenuItem(
            id: 'import_image',
            label: '从图片导入',
            icon: Icons.image_outlined,
            onTap: () => importVibesFromImage(),
          ),
          ProMenuItem(
            id: 'import_clipboard',
            label: '从剪贴板导入编码',
            icon: Icons.content_paste,
            onTap: () => importVibesFromClipboard(),
          ),
        ],
        onSelect: (_) {},
      ),
    );
  }
}
