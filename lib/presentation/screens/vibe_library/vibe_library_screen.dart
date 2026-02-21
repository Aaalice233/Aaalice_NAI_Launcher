import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/vibe_file_parser.dart';
import '../../../core/utils/vibe_image_embedder.dart';
import '../../../core/utils/vibe_library_path_helper.dart';
import '../../../data/models/vibe/vibe_library_category.dart';
import '../../../data/models/vibe/vibe_library_entry.dart';
import '../../../data/models/vibe/vibe_reference.dart';
import '../../../data/services/vibe_import_service.dart';
import '../../../data/services/vibe_library_storage_service.dart';
import '../../providers/generation/generation_params_notifier.dart';
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
import 'intents/vibe_intents.dart';
import 'models/vibe_import_progress.dart';
import 'services/vibe_library_import_repository.dart';
import 'widgets/category/vibe_category_tree_view.dart';
import 'widgets/menus/vibe_import_menu.dart';
import 'widgets/vibe_card.dart';
import 'widgets/vibe_library_content_view.dart';
import 'widgets/vibe_library_empty_view.dart';
import 'widgets/vibe_bundle_import_dialog.dart' as bundle_import_dialog;
import 'widgets/vibe_detail_viewer.dart';
import 'widgets/vibe_export_dialog.dart';
import 'widgets/vibe_export_dialog_advanced.dart';
import 'widgets/vibe_image_encode_dialog.dart' as encode_dialog;
import 'widgets/vibe_import_naming_dialog.dart' as naming_dialog;

/// Vibe库屏幕
/// Vibe Library Screen
class VibeLibraryScreen extends ConsumerStatefulWidget {
  const VibeLibraryScreen({super.key});

  @override
  ConsumerState<VibeLibraryScreen> createState() => _VibeLibraryScreenState();
}

class _VibeLibraryScreenState extends ConsumerState<VibeLibraryScreen> {
  /// 是否显示分类面板
  bool _showCategoryPanel = true;

  /// 搜索控制器
  final TextEditingController _searchController = TextEditingController();

  /// 是否正在拖拽文件
  bool _isDragging = false;

  /// 是否正在导入
  bool _isImporting = false;

  /// 是否正在打开文件选择器
  bool _isPickingFile = false;

  /// 导入进度信息
  ImportProgress _importProgress = const ImportProgress();

  @override
  void initState() {
    super.initState();
    // 初始化Vibe库
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vibeLibraryNotifierProvider.notifier).initialize();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 页面重新可见时刷新（同步文件系统）- 在后台执行
    _refreshIfNeededInBackground();
  }

  DateTime? _lastRefreshTime;
  bool _isRefreshingInBackground = false;

  /// 在后台刷新，不阻塞 UI
  void _refreshIfNeededInBackground() {
    final now = DateTime.now();
    // 如果超过5秒没有刷新，则执行刷新
    if (_lastRefreshTime == null ||
        now.difference(_lastRefreshTime!) > const Duration(seconds: 5)) {
      _lastRefreshTime = now;
      
      // 避免重复刷新
      if (_isRefreshingInBackground) return;
      _isRefreshingInBackground = true;
      
      // 使用延迟避免在初始化时重复刷新，并在后台执行
      Future.delayed(const Duration(milliseconds: 300), () async {
        if (mounted) {
          try {
            // 先执行轻量级的数据加载（从 Hive）
            await ref.read(vibeLibraryNotifierProvider.notifier).loadFromCache();
            
            // 然后在后台同步文件系统（扫描文件夹）
            await ref.read(vibeLibraryNotifierProvider.notifier).syncWithFileSystem();
          } finally {
            _isRefreshingInBackground = false;
          }
        } else {
          _isRefreshingInBackground = false;
        }
      });
    }
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
                if (!(_isImporting || _isPickingFile)) {
                  _importVibes();
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
              // 重要：不要等待 _handleDrop 完成，让拖放回调立即返回
              unawaited(_handleDrop(event));
              return;
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
                                totalEntryCount: state.entries.length,
                                favoriteCount: state.favoriteCount,
                                selectedCategoryId:
                                    categoryState.selectedCategoryId,
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
                                onCategoryRename: (id, newName) async {
                                  await ref
                                      .read(
                                        vibeLibraryCategoryNotifierProvider
                                            .notifier,
                                      )
                                      .renameCategory(id, newName);
                                },
                                onCategoryDelete: (id) async {
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
                                onCategoryMove:
                                    (categoryId, newParentId) async {
                                  await ref
                                      .read(
                                        vibeLibraryCategoryNotifierProvider
                                            .notifier,
                                      )
                                      .moveCategory(categoryId, newParentId);
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
                if (_isImporting) _buildImportOverlay(theme),
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
                  if (!(_isImporting || _isPickingFile)) {
                    _showImportMenu(details.globalPosition);
                  }
                },
                child: CompactIconButton(
                  icon: Icons.file_download_outlined,
                  label: '导入',
                  tooltip: '导入.naiv4vibe或.naiv4vibebundle文件（右键查看更多选项）',
                  isLoading: _isPickingFile,
                  onPressed: (_isImporting || _isPickingFile)
                      ? null
                      : () => _importVibes(),
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
              // 打开文件夹按钮
              CompactIconButton(
                icon: Icons.folder_open_outlined,
                label: '文件夹',
                tooltip: '打开 Vibe 库文件夹',
                onPressed: () => _openVibeLibraryFolder(),
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
        AppToast.warning(context, '没有可用的分类');
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
    AppToast.success(context, '已移动 $movedCount 个Vibe');
  }

  /// 批量切换收藏
  Future<void> _batchToggleFavorite() async {
    final selectionState = ref.read(vibeLibrarySelectionNotifierProvider);
    final ids = selectionState.selectedIds.toList();

    for (final id in ids) {
      await ref.read(vibeLibraryNotifierProvider.notifier).toggleFavorite(id);
    }

    if (mounted) {
      AppToast.success(context, '收藏状态已更新');
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
        AppToast.success(context, '已删除 ${ids.length} 个Vibe');
        ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
      }
    }
  }

  /// 显示导入右键菜单
  void _showImportMenu(Offset position) {
    Navigator.of(context).push(
      ImportMenu(
        position: position,
        items: [
          ProMenuItem(
            id: 'import_file',
            label: '从文件导入',
            icon: Icons.folder_outlined,
            onTap: () => _importVibes(),
          ),
          ProMenuItem(
            id: 'import_image',
            label: '从图片导入',
            icon: Icons.image_outlined,
            onTap: () => _importVibesFromImage(),
          ),
          ProMenuItem(
            id: 'import_clipboard',
            label: '从剪贴板导入编码',
            icon: Icons.content_paste,
            onTap: () => _importVibesFromClipboard(),
          ),
        ],
        onSelect: (_) {},
      ),
    );
  }

  /// 打开 Vibe 库文件夹（存放 .naiv4vibe 文件的地方）
  Future<void> _openVibeLibraryFolder() async {
    try {
      // 获取 vibe 文件存储路径
      final vibePath = await VibeLibraryPathHelper.instance.getPath();
      final dir = Directory(vibePath);

      // 确保目录存在
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      if (Platform.isWindows) {
        // 使用 Process.start 避免等待进程完成导致的延迟
        await Process.start('explorer', [vibePath]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [vibePath]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [vibePath]);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '打开文件夹失败: $e');
      }
    }
  }

  /// 导入 Vibe 文件
  Future<void> _importVibes() async {
    final files = await _pickImportFiles();
    if (files == null || files.isEmpty) {
      return;
    }

    setState(() => _isImporting = true);
    final (imageFiles, regularFiles) = await _categorizeFiles(files);
    final currentCategoryId =
        ref.read(vibeLibraryNotifierProvider).selectedCategoryId;
    final targetCategoryId =
        (currentCategoryId != null && currentCategoryId != 'favorites')
            ? currentCategoryId
            : null;
    final result = await _processImportSources(
      imageItems: imageFiles,
      vibeFiles: regularFiles,
      targetCategoryId: targetCategoryId,
      onProgress: (current, total, message) {
        AppLogger.d(message, 'VibeLibrary');
      },
    );
    setState(() => _isImporting = false);

    await _handleImportResult(result.success, result.fail);
  }

  Future<List<PlatformFile>?> _pickImportFiles() async {
    setState(() => _isPickingFile = true);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['naiv4vibe', 'naiv4vibebundle', 'png'],
      allowMultiple: true,
      dialogTitle: '选择要导入的 Vibe 文件',
    );

    setState(() => _isPickingFile = false);
    return result?.files;
  }

  Future<(List<VibeImageImportItem>, List<PlatformFile>)> _categorizeFiles(
    List<PlatformFile> files,
  ) async {
    final imageFiles = <VibeImageImportItem>[];
    final regularFiles = <PlatformFile>[];

    for (final file in files) {
      final ext = file.extension?.toLowerCase() ?? '';
      if (ext == 'png') {
        try {
          final bytes = await _readPlatformFileBytes(file);
          imageFiles.add(
            VibeImageImportItem(
              source: file.name,
              bytes: bytes,
            ),
          );
        } catch (e) {
          AppLogger.e('读取图片文件失败: ${file.name}', e, null, 'VibeLibrary');
        }
      } else if (ext == 'naiv4vibe' || ext == 'naiv4vibebundle') {
        regularFiles.add(file);
      }
    }

    return (imageFiles, regularFiles);
  }

  Future<({int success, int fail})> _processImportSources({
    required List<VibeImageImportItem> imageItems,
    required List<PlatformFile> vibeFiles,
    String? targetCategoryId,
    required ImportProgressCallback onProgress,
  }) async {
    final notifier = ref.read(vibeLibraryNotifierProvider.notifier);
    final repository = VibeLibraryNotifierImportRepository(
      onGetAllEntries: () async =>
          ref.read(vibeLibraryNotifierProvider).entries,
      onSaveEntry: notifier.saveEntry,
    );
    final importService = VibeImportService(repository: repository);

    var totalSuccess = 0;
    var totalFail = 0;
    final totalCount = imageItems.length + vibeFiles.length;

    // 单独处理每张图片，以便支持无 Vibe 数据图片的编码流程
    for (var i = 0; i < imageItems.length; i++) {
      final imageItem = imageItems[i];
      onProgress(i + 1, totalCount, '导入图片($i/${imageItems.length}): ${imageItem.source}');

      final result = await _processSingleImageImport(
        imageFile: imageItem,
        importService: importService,
        targetCategoryId: targetCategoryId,
      );

      if (result == true) {
        totalSuccess++;
      } else if (result == false) {
        totalFail++;
      }
      // result == null 表示用户取消，不计入成功或失败
    }

    if (vibeFiles.isNotEmpty) {
      try {
        var applyNamingToAll = false;
        String? batchNamingBase;
        final result = await importService.importFromFile(
          files: vibeFiles,
          categoryId: targetCategoryId,
          onProgress: (current, _, message) {
            onProgress(imageItems.length + current, totalCount, message);
          },
          onNaming: (
            suggestedName, {
            required bool isBatch,
            Uint8List? thumbnail,
          }) async {
            if (!mounted) {
              return null;
            }

            if (isBatch && applyNamingToAll && batchNamingBase != null) {
              return batchNamingBase;
            }

            final namingResult =
                await naming_dialog.VibeImportNamingDialog.show(
              context: context,
              suggestedName: suggestedName,
              thumbnail: thumbnail,
              isBatchImport: isBatch,
            );
            if (namingResult == null) {
              return null;
            }

            final customName = namingResult.name.trim();
            if (customName.isEmpty) {
              return null;
            }

            if (isBatch && namingResult.applyToAll) {
              applyNamingToAll = true;
              batchNamingBase = customName;
            }
            return customName;
          },
          onBundleOption: (bundleName, vibes) async {
            if (!mounted) {
              return null;
            }

            final bundleResult =
                await bundle_import_dialog.VibeBundleImportDialog.show(
              context: context,
              bundleName: bundleName,
              vibeNames: vibes.map((vibe) => vibe.displayName).toList(),
            );
            if (bundleResult == null) {
              return null;
            }

            switch (bundleResult.option) {
              case bundle_import_dialog.BundleImportOption.keepAsBundle:
                return const BundleImportOption.keepAsBundle();
              case bundle_import_dialog.BundleImportOption.split:
                return const BundleImportOption.split();
              case bundle_import_dialog.BundleImportOption.importSelected:
                return BundleImportOption.select(
                  bundleResult.selectedIndices ?? const <int>[],
                );
            }
          },
        );
        totalSuccess += result.successCount;
        totalFail += result.failCount;
      } catch (e, stackTrace) {
        AppLogger.e('导入 Vibe 文件失败', e, stackTrace, 'VibeLibrary');
        totalFail += vibeFiles.length;
      }
    }

    return (success: totalSuccess, fail: totalFail);
  }

  Future<void> _handleImportResult(int totalSuccess, int totalFail) async {
    // 用户全部取消，不显示任何提示
    if (totalSuccess == 0 && totalFail == 0) {
      return;
    }

    if (totalSuccess > 0) {
      await ref.read(vibeLibraryNotifierProvider.notifier).reload();
    }

    if (!mounted) {
      return;
    }

    if (totalFail == 0) {
      AppToast.success(context, '成功导入 $totalSuccess 个 Vibe');
    } else {
      AppToast.warning(
        context,
        '导入完成: $totalSuccess 成功, $totalFail 失败',
      );
    }
  }

  /// 读取 PlatformFile 的字节
  Future<Uint8List> _readPlatformFileBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes!;
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      throw ArgumentError('File path is empty: ${file.name}');
    }

    return File(path).readAsBytes();
  }

  /// 导出 Vibe (使用 V2 对话框)
  Future<void> _exportVibes({List<VibeLibraryEntry>? specificEntries}) async {
    final state = ref.read(vibeLibraryNotifierProvider);
    final entriesToExport = specificEntries ?? state.entries;

    if (entriesToExport.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (context) => VibeExportDialogAdvanced(
        entries: entriesToExport,
      ),
    );
  }

  /// 递归扫描文件夹内的 vibe 文件
  Future<List<String>> _scanVibeFilesInFolder(String folderPath) async {
    final vibeFiles = <String>[];
    final dir = Directory(folderPath);

    if (!await dir.exists()) {
      return vibeFiles;
    }

    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          final ext = p.extension(fileName).toLowerCase();
          if (ext == '.naiv4vibe' || ext == '.naiv4vibebundle') {
            vibeFiles.add(entity.path);
          }
        }
      }
    } catch (e, stackTrace) {
      AppLogger.e('扫描文件夹失败: $folderPath', e, stackTrace, 'VibeLibrary');
    }

    return vibeFiles;
  }

  /// 在 Isolate 中分类文件
  static Future<Map<String, List<String>>> _classifyPathsIsolate(
    List<String> paths,
  ) async {
    final folderPaths = <String>[];
    final imagePaths = <String>[];
    final vibeFilePaths = <String>[];

    for (final path in paths) {
      try {
        final entity = await FileSystemEntity.type(path, followLinks: false);

        if (entity == FileSystemEntityType.directory) {
          folderPaths.add(path);
        } else if (entity == FileSystemEntityType.file) {
          final fileName = p.basename(path);
          final ext = p.extension(fileName).toLowerCase();

          if (ext == '.png') {
            imagePaths.add(path);
          } else if (ext == '.naiv4vibe' || ext == '.naiv4vibebundle') {
            vibeFilePaths.add(path);
          }
        }
      } catch (e) {
        // 忽略无法访问的路径
      }
    }

    return {
      'folders': folderPaths,
      'images': imagePaths,
      'vibeFiles': vibeFilePaths,
    };
  }

  /// 处理拖拽文件
  /// 支持 .naiv4vibe, .naiv4vibebundle, .png 格式，以及文件夹
  Future<void> _handleDrop(PerformDropEvent event) async {
    // 收集所有文件/文件夹路径
    final allPaths = <String>[];

    for (final item in event.session.items) {
      final reader = item.dataReader;
      if (reader == null) continue;

      if (reader.canProvide(Formats.fileUri)) {
        final completer = Completer<Uri?>();
        final progress = reader.getValue<Uri>(
          Formats.fileUri,
          (uri) {
            if (!completer.isCompleted) {
              completer.complete(uri);
            }
          },
          onError: (e) {
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          },
        );

        // 关键检查：如果返回 null，说明格式不可用
        if (progress == null) continue;

        final uri = await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
        if (uri != null) {
          allPaths.add(uri.toFilePath());
        }
      }
    }

    if (allPaths.isEmpty) return;

    // 使用 Isolate 分类文件和文件夹，避免阻塞 UI
    final classified = await compute(_classifyPathsIsolate, allPaths);
    final folderPaths = classified['folders'] ?? <String>[];
    final imagePaths = classified['images'] ?? <String>[];
    final vibeFilePaths = classified['vibeFiles'] ?? <String>[];

    // 递归扫描文件夹
    if (folderPaths.isNotEmpty) {
      for (final folderPath in folderPaths) {
        final scannedFiles = await _scanVibeFilesInFolder(folderPath);
        vibeFilePaths.addAll(scannedFiles);
      }
    }

    if (imagePaths.isEmpty && vibeFilePaths.isEmpty) return;

    // 设置导入状态
    setState(() {
      _isImporting = true;
      _importProgress = ImportProgress(
        total: imagePaths.length + vibeFilePaths.length,
        message: '准备导入...',
      );
    });

    // 获取当前选中的分类
    final currentCategoryId =
        ref.read(vibeLibraryNotifierProvider).selectedCategoryId;
    final targetCategoryId =
        (currentCategoryId != null && currentCategoryId != 'favorites')
            ? currentCategoryId
            : null;

    // 并行读取图片文件，避免顺序阻塞
    final imageItems = <VibeImageImportItem>[];
    var preProcessFail = 0;

    await Future.wait(
      imagePaths.map((path) async {
        try {
          final bytes = await File(path).readAsBytes();
          imageItems.add(
            VibeImageImportItem(
              source: p.basename(path),
              bytes: bytes,
            ),
          );
        } catch (e, stackTrace) {
          AppLogger.e('读取拖拽图片失败: $path', e, stackTrace, 'VibeLibrary');
          preProcessFail++;
        }
      }),
    );

    final vibeFiles = vibeFilePaths
        .map(
          (path) => PlatformFile(
            name: p.basename(path),
            size: 0,
            path: path,
          ),
        )
        .toList();

    final result = await _processImportSources(
      imageItems: imageItems,
      vibeFiles: vibeFiles,
      targetCategoryId: targetCategoryId,
      onProgress: (current, total, message) {
        if (!mounted) {
          return;
        }
        setState(() {
          _importProgress = _importProgress.copyWith(
            current: current,
            total: total,
            message: message,
          );
        });
      },
    );

    final totalSuccess = result.success;
    final totalFail = result.fail + preProcessFail;

    setState(() {
      _isImporting = false;
      _importProgress = const ImportProgress();
    });

    // 用户全部取消，不显示任何提示
    if (totalSuccess == 0 && totalFail == 0) {
      return;
    }

    // 重新加载数据以确保UI显示导入的条目
    if (totalSuccess > 0) {
      await ref.read(vibeLibraryNotifierProvider.notifier).reload();
    }

    // 显示导入结果摘要
    if (mounted) {
      if (totalFail == 0) {
        AppToast.success(context, '成功导入 $totalSuccess 个 Vibe');
      } else {
        AppToast.warning(
          context,
          '导入完成: $totalSuccess 成功, $totalFail 失败',
        );
      }
    }
  }

  /// 构建拖拽覆盖层
  Widget _buildDropOverlay(ThemeData theme) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: theme.colorScheme.primary.withOpacity(0.1),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 24,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.file_upload_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '拖拽 .naiv4vibe/.naiv4vibebundle/.png 文件或文件夹到此处导入',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建导入进度覆盖层
  Widget _buildImportOverlay(ThemeData theme) {
    final hasProgress = _importProgress.isActive;
    final progressValue = _importProgress.progress;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 24,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    value: progressValue,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '正在导入...',
                  style: theme.textTheme.titleMedium,
                ),
                if (hasProgress) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_importProgress.current} / ${_importProgress.total}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (_importProgress.message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _importProgress.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 从图片导入 Vibe
  Future<void> _importVibesFromImage() async {
    setState(() => _isPickingFile = true);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png'],
      allowMultiple: true,
      dialogTitle: '选择包含 Vibe 的 PNG 图片',
    );

    setState(() => _isPickingFile = false);

    if (result == null || result.files.isEmpty) return;

    setState(() => _isImporting = true);

    // 获取当前选中的分类
    final currentCategoryId =
        ref.read(vibeLibraryNotifierProvider).selectedCategoryId;
    final targetCategoryId =
        (currentCategoryId != null && currentCategoryId != 'favorites')
            ? currentCategoryId
            : null;

    // 创建导入服务和仓库
    final notifier = ref.read(vibeLibraryNotifierProvider.notifier);
    final repository = VibeLibraryNotifierImportRepository(
      onGetAllEntries: () async =>
          ref.read(vibeLibraryNotifierProvider).entries,
      onSaveEntry: notifier.saveEntry,
    );
    final importService = VibeImportService(repository: repository);

    // 收集图片文件
    final imageFiles = <VibeImageImportItem>[];
    for (final file in result.files) {
      try {
        final bytes = await _readPlatformFileBytes(file);
        imageFiles.add(
          VibeImageImportItem(
            source: file.name,
            bytes: bytes,
          ),
        );
      } catch (e) {
        AppLogger.e('读取图片文件失败: ${file.name}', e, null, 'VibeLibrary');
      }
    }

    var totalSuccess = 0;
    var totalFail = 0;

    // 处理每张图片
    for (final imageFile in imageFiles) {
      final result = await _processSingleImageImport(
        imageFile: imageFile,
        importService: importService,
        targetCategoryId: targetCategoryId,
      );

      if (result == true) {
        totalSuccess++;
      } else if (result == false) {
        totalFail++;
      }
      // result == null 表示用户取消，不计入统计
    }

    setState(() => _isImporting = false);

    // 用户全部取消，不显示任何提示
    if (totalSuccess == 0 && totalFail == 0) {
      return;
    }

    // 重新加载数据
    if (totalSuccess > 0) {
      await ref.read(vibeLibraryNotifierProvider.notifier).reload();
    }

    if (mounted) {
      if (totalFail == 0) {
        AppToast.success(context, '成功导入 $totalSuccess 个 Vibe');
      } else {
        AppToast.warning(
          context,
          '导入完成: $totalSuccess 成功, $totalFail 失败',
        );
      }
    }
  }

  /// 处理单张图片导入
  ///
  /// 返回:
  /// - true: 成功导入
  /// - false: 导入失败
  /// - null: 用户取消
  Future<bool?> _processSingleImageImport({
    required VibeImageImportItem imageFile,
    required VibeImportService importService,
    String? targetCategoryId,
  }) async {
    // 首先尝试提取 Vibe 数据
    try {
      final result = await VibeImageEmbedder.extractVibeFromImage(imageFile.bytes);

      // 如果是 bundle（多个 vibes），让用户选择处理方式
      if (result.isBundle && result.vibes.length > 1) {
        return await _handleBundleImport(
          imageFile: imageFile,
          vibes: result.vibes,
          targetCategoryId: targetCategoryId,
        );
      }

      // 单个 vibe，直接保存
      return await _saveVibeReference(
        reference: result.vibes.first,
        categoryId: targetCategoryId,
      );
    } on NoVibeDataException {
      return await _handleImageEncoding(
        imageFile: imageFile,
        targetCategoryId: targetCategoryId,
      );
    } catch (e) {
      if (_isNoVibeDataError(e)) {
        return await _handleImageEncoding(
          imageFile: imageFile,
          targetCategoryId: targetCategoryId,
        );
      }
      AppLogger.e('处理图片失败: ${imageFile.source}', e, null, 'VibeLibrary');
      return false;
    }
  }

  /// 保存 VibeReference 到库
  Future<bool> _saveVibeReference({
    required VibeReference reference,
    String? categoryId,
  }) async {
    try {
      final notifier = ref.read(vibeLibraryNotifierProvider.notifier);

      // 生成唯一名称（处理重名）
      final baseName = reference.displayName.trim().isEmpty
          ? 'vibe_${DateTime.now().millisecondsSinceEpoch}'
          : reference.displayName.trim();
      final uniqueName = _generateUniqueName(baseName);

      // 创建条目
      final entry = VibeLibraryEntry.fromVibeReference(
        name: uniqueName,
        vibeData: reference,
        categoryId: categoryId,
      );

      await notifier.saveEntry(entry);
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('保存 Vibe 到库失败', e, stackTrace, 'VibeLibrary');
      return false;
    }
  }

  /// 生成唯一名称（避免重名）
  String _generateUniqueName(String baseName) {
    // 通过 provider 读取当前所有条目
    final existingEntries = ref.read(vibeLibraryNotifierProvider).entries;
    final existingNames = existingEntries.map((e) => e.name.toLowerCase()).toSet();

    if (!existingNames.contains(baseName.toLowerCase())) {
      return baseName;
    }

    // 名称冲突，添加序号
    var index = 2;
    var candidateName = '$baseName ($index)';
    while (existingNames.contains(candidateName.toLowerCase())) {
      index++;
      candidateName = '$baseName ($index)';
    }
    return candidateName;
  }

  /// 处理 Bundle 导入
  Future<bool?> _handleBundleImport({
    required VibeImageImportItem imageFile,
    required List<VibeReference> vibes,
    String? targetCategoryId,
  }) async {
    if (!mounted) return null;

    // 显示 Bundle 导入选项对话框
    final result = await showDialog<bundle_import_dialog.BundleImportResult>(
      context: context,
      builder: (context) => bundle_import_dialog.VibeBundleImportDialog(
        bundleName: imageFile.source,
        vibeNames: vibes.map((v) => v.displayName).toList(),
      ),
    );

    if (result == null) return null; // 用户取消

    final selectedVibes = _getSelectedVibesForBundle(result, vibes);
    if (selectedVibes == null) return null;

    // 保持为 Bundle - 保存整个 bundle 为一个条目
    if (result.option == bundle_import_dialog.BundleImportOption.keepAsBundle) {
      return await _saveAsBundle(
        vibes: selectedVibes,
        bundleName: imageFile.source,
        categoryId: targetCategoryId,
      );
    }

    // 拆分导入或选择性导入 - 保存所有选中的 vibes
    return await _saveMultipleVibes(selectedVibes, targetCategoryId);
  }

  List<VibeReference>? _getSelectedVibesForBundle(
    bundle_import_dialog.BundleImportResult result,
    List<VibeReference> vibes,
  ) {
    switch (result.option) {
      case bundle_import_dialog.BundleImportOption.keepAsBundle:
      case bundle_import_dialog.BundleImportOption.split:
        return vibes;
      case bundle_import_dialog.BundleImportOption.importSelected:
        final indices = result.selectedIndices;
        if (indices == null || indices.isEmpty) return null;
        return indices
            .where((index) => index >= 0 && index < vibes.length)
            .map((index) => vibes[index])
            .toList();
    }
  }

  Future<bool> _saveMultipleVibes(
    List<VibeReference> vibes,
    String? categoryId,
  ) async {
    var successCount = 0;
    for (final vibe in vibes) {
      final saved = await _saveVibeReference(
        reference: vibe,
        categoryId: categoryId,
      );
      if (saved) successCount++;
    }
    return successCount > 0;
  }

  /// 保存为 Bundle 条目
  Future<bool> _saveAsBundle({
    required List<VibeReference> vibes,
    required String bundleName,
    String? categoryId,
  }) async {
    try {
      final notifier = ref.read(vibeLibraryNotifierProvider.notifier);

      // 生成唯一名称（处理重名）
      final baseName = bundleName.trim().isEmpty
          ? 'vibe-bundle_${DateTime.now().millisecondsSinceEpoch}'
          : bundleName.trim();
      final uniqueName = _generateUniqueName(baseName);

      // 使用 saveBundleEntry 保存整个 bundle
      final saved = await notifier.saveBundleEntry(
        vibes,
        name: uniqueName,
        categoryId: categoryId,
      );

      return saved != null;
    } catch (e, stackTrace) {
      AppLogger.e('保存 Bundle 到库失败', e, stackTrace, 'VibeLibrary');
      return false;
    }
  }

  /// 处理图片编码流程
  bool _isNoVibeDataError(Object e) {
    return e is NoVibeDataException ||
        e.toString().contains('No naiv4vibe metadata');
  }

  Future<bool?> _handleImageEncoding({
    required VibeImageImportItem imageFile,
    String? targetCategoryId,
  }) async {
    if (!mounted) return null;

    // 显示编码配置对话框
    final config = await encode_dialog.VibeImageEncodeDialog.show(
      context: context,
      imageBytes: imageFile.bytes,
      fileName: imageFile.source,
    );

    if (config == null) return null; // 用户取消

    // 编码重试循环
    while (mounted) {
      // 显示编码中对话框
      if (!mounted) break;
      encode_dialog.VibeImageEncodingDialog.show(context);

      String? encoding;
      String? errorMessage;

      try {
        final notifier = ref.read(generationParamsNotifierProvider.notifier);
        final params = ref.read(generationParamsNotifierProvider);
        final model = params.model;

        encoding = await notifier
            .encodeVibeWithCache(
          imageFile.bytes,
          model: model,
          informationExtracted: config.infoExtracted,
          vibeName: config.name,
        )
            .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            errorMessage = '编码超时，请检查网络连接';
            return null;
          },
        );
      } catch (e) {
        errorMessage = e.toString();
        AppLogger.e('Vibe 编码失败: ${imageFile.source}', e, null, 'VibeLibrary');
      } finally {
        // 关闭编码中对话框
        if (mounted) {
          encode_dialog.VibeImageEncodingDialog.hide(context);
        }
      }

      if (encoding != null && mounted) {
        // 编码成功，保存到 Vibe 库
        return await _saveEncodedVibe(
          name: config.name,
          encoding: encoding,
          imageBytes: imageFile.bytes,
          strength: config.strength,
          infoExtracted: config.infoExtracted,
          categoryId: targetCategoryId,
        );
      }

      // 编码失败，显示错误对话框
      if (!mounted) return null;

      final action = await encode_dialog.VibeImageEncodeErrorDialog.show(
        context: context,
        fileName: imageFile.source,
        errorMessage: errorMessage ?? '未知错误',
      );

      if (action == encode_dialog.VibeEncodeErrorAction.skip) {
        return false; // 标记为失败，继续下一张
      } else if (action == null) {
        return null; // 用户关闭对话框，视为取消
      }
      // 否则重试
    }

    return null;
  }

  /// 保存编码后的 Vibe 到库
  Future<bool> _saveEncodedVibe({
    required String name,
    required String encoding,
    required Uint8List imageBytes,
    required double strength,
    required double infoExtracted,
    String? categoryId,
  }) async {
    try {
      final notifier = ref.read(vibeLibraryNotifierProvider.notifier);

      // 创建 VibeReference
      final reference = VibeReference(
        displayName: name,
        vibeEncoding: encoding,
        strength: strength,
        infoExtracted: infoExtracted,
        sourceType: VibeSourceType.naiv4vibe,
        thumbnail: imageBytes,
        rawImageData: imageBytes,
      );

      // 创建并保存条目
      final entry = VibeLibraryEntry.fromVibeReference(
        name: name,
        vibeData: reference,
        categoryId: categoryId,
      );

      await notifier.saveEntry(entry);
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('保存编码 Vibe 失败', e, stackTrace, 'VibeLibrary');
      return false;
    }
  }

  /// 从剪贴板导入 Vibe 编码
  Future<void> _importVibesFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text?.trim();

    if (text == null || text.isEmpty) {
      if (mounted) {
        AppToast.error(context, '剪贴板为空');
      }
      return;
    }

    setState(() => _isImporting = true);

    // 获取当前选中的分类
    final currentCategoryId =
        ref.read(vibeLibraryNotifierProvider).selectedCategoryId;
    final targetCategoryId =
        (currentCategoryId != null && currentCategoryId != 'favorites')
            ? currentCategoryId
            : null;

    // 创建导入服务和仓库
    final notifier = ref.read(vibeLibraryNotifierProvider.notifier);
    final repository = VibeLibraryNotifierImportRepository(
      onGetAllEntries: () async =>
          ref.read(vibeLibraryNotifierProvider).entries,
      onSaveEntry: notifier.saveEntry,
    );
    final importService = VibeImportService(repository: repository);

    var totalSuccess = 0;
    var totalFail = 0;

    try {
      final result = await importService.importFromEncoding(
        items: [
          VibeEncodingImportItem(
            source: '剪贴板',
            encoding: text,
          ),
        ],
        categoryId: targetCategoryId,
        onProgress: (current, total, message) {
          AppLogger.d(message, 'VibeLibrary');
        },
      );
      totalSuccess += result.successCount;
      totalFail += result.failCount;
    } catch (e, stackTrace) {
      AppLogger.e('从剪贴板导入 Vibe 失败', e, stackTrace, 'VibeLibrary');
      totalFail++;
    }

    setState(() => _isImporting = false);

    // 用户全部取消，不显示任何提示
    if (totalSuccess == 0 && totalFail == 0) {
      return;
    }

    // 重新加载数据
    if (totalSuccess > 0) {
      await ref.read(vibeLibraryNotifierProvider.notifier).reload();
    }

    if (mounted) {
      if (totalFail == 0) {
        AppToast.success(context, '成功导入 $totalSuccess 个 Vibe');
      } else {
        AppToast.warning(
          context,
          '导入完成: $totalSuccess 成功, $totalFail 失败',
        );
      }
    }
  }
}
