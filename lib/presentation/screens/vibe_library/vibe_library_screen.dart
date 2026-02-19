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
import 'widgets/vibe_card_3d.dart';
import 'widgets/vibe_bundle_import_dialog.dart' as bundle_import_dialog;
import 'widgets/vibe_detail_viewer.dart';
import 'widgets/vibe_export_dialog.dart';
import 'widgets/vibe_export_dialog_advanced.dart';
import 'widgets/vibe_image_encode_dialog.dart' as encode_dialog;
import 'widgets/vibe_import_naming_dialog.dart' as naming_dialog;

class ImportProgress {
  final int current;
  final int total;
  final String message;

  const ImportProgress({
    this.current = 0,
    this.total = 0,
    this.message = '',
  });

  double? get progress => total > 0 ? current / total : null;

  bool get isActive => total > 0;

  bool get isComplete => total > 0 && current >= total;

  ImportProgress copyWith({
    int? current,
    int? total,
    String? message,
  }) {
    return ImportProgress(
      current: current ?? this.current,
      total: total ?? this.total,
      message: message ?? this.message,
    );
  }
}

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
    // 页面重新可见时刷新（同步文件系统）
    _refreshIfNeeded();
  }

  DateTime? _lastRefreshTime;

  void _refreshIfNeeded() {
    final now = DateTime.now();
    // 如果超过5秒没有刷新，则执行刷新
    if (_lastRefreshTime == null ||
        now.difference(_lastRefreshTime!) > const Duration(seconds: 5)) {
      _lastRefreshTime = now;
      // 使用延迟避免在初始化时重复刷新
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          ref.read(vibeLibraryNotifierProvider.notifier).reload();
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
                              child: _VibeCategoryTreeView(
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
      return const _VibeLibraryEmptyView();
    }

    return _VibeLibraryContentView(
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

  /// 显示导入右键菜单
  void _showImportMenu(Offset position) {
    Navigator.of(context).push(
      _ImportMenuRoute(
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
    final repository = _VibeLibraryNotifierImportRepository(
      onGetAllEntries: () async =>
          ref.read(vibeLibraryNotifierProvider).entries,
      onSaveEntry: notifier.saveEntry,
    );
    final importService = VibeImportService(repository: repository);

    var totalSuccess = 0;
    var totalFail = 0;
    final totalCount = imageItems.length + vibeFiles.length;

    if (imageItems.isNotEmpty) {
      try {
        final result = await importService.importFromImage(
          images: imageItems,
          categoryId: targetCategoryId,
          onProgress: (current, _, message) {
            onProgress(current, totalCount, message);
          },
        );
        totalSuccess += result.successCount;
        totalFail += result.failCount;
      } catch (e, stackTrace) {
        AppLogger.e('导入图片 Vibe 失败', e, stackTrace, 'VibeLibrary');
        totalFail += imageItems.length;
      }
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
    final repository = _VibeLibraryNotifierImportRepository(
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
      final reference =
          await VibeImageEmbedder.extractVibeFromImage(imageFile.bytes);
      // 提取成功，正常导入
      final importResult = await importService.importFromImage(
        images: [imageFile],
        categoryId: targetCategoryId,
      );
      return importResult.successCount > 0;
    } on NoVibeDataException {
      // 无 Vibe 数据，询问用户是否编码
      return await _handleImageEncoding(
        imageFile: imageFile,
        targetCategoryId: targetCategoryId,
      );
    } catch (e) {
      // 其他错误，记录为失败
      AppLogger.e('处理图片失败: ${imageFile.source}', e, null, 'VibeLibrary');
      return false;
    }
  }

  /// 处理图片编码流程
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
    final repository = _VibeLibraryNotifierImportRepository(
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

/// 导入菜单路由
class _ImportMenuRoute extends PopupRoute {
  final Offset position;
  final List<ProMenuItem> items;
  final void Function(ProMenuItem) onSelect;

  _ImportMenuRoute({
    required this.position,
    required this.items,
    required this.onSelect,
  });

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeLeft: true,
      removeRight: true,
      removeBottom: true,
      child: Builder(
        builder: (context) {
          // 计算菜单位置，确保不超出屏幕
          final screenSize = MediaQuery.of(context).size;
          const menuWidth = 180.0;
          final menuHeight = items.where((i) => !i.isDivider).length * 36.0 +
              items.where((i) => i.isDivider).length * 1.0;

          double left = position.dx;
          double top = position.dy;

          // 调整水平位置
          if (left + menuWidth > screenSize.width) {
            left = screenSize.width - menuWidth - 16;
          }

          // 调整垂直位置
          if (top + menuHeight > screenSize.height) {
            top = screenSize.height - menuHeight - 16;
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.of(context).pop(),
            child: Stack(
              children: [
                ProContextMenu(
                  position: Offset(left, top),
                  items: items,
                  onSelect: (item) {
                    onSelect(item);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ),
        child: child,
      ),
    );
  }
}

/// Vibe库空视图
class _VibeLibraryEmptyView extends StatelessWidget {
  const _VibeLibraryEmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 64,
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Vibe库为空',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '从生成页面保存Vibe到库中',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vibe库分类树视图
class _VibeCategoryTreeView extends StatefulWidget {
  final List<VibeLibraryCategory> categories;
  final int totalEntryCount;
  final int favoriteCount;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;
  final void Function(String id, String newName)? onCategoryRename;
  final ValueChanged<String>? onCategoryDelete;
  final ValueChanged<String?>? onAddSubCategory;
  final void Function(String categoryId, String? newParentId)? onCategoryMove;

  const _VibeCategoryTreeView({
    required this.categories,
    required this.totalEntryCount,
    required this.favoriteCount,
    this.selectedCategoryId,
    required this.onCategorySelected,
    this.onCategoryRename,
    this.onCategoryDelete,
    this.onAddSubCategory,
    this.onCategoryMove,
  });

  @override
  State<_VibeCategoryTreeView> createState() => _VibeCategoryTreeViewState();
}

class _VibeCategoryTreeViewState extends State<_VibeCategoryTreeView> {
  final Set<String> _expandedIds = <String>{};
  String? _hoveredCategoryId;
  Timer? _autoExpandTimer;

  @override
  void dispose() {
    _autoExpandTimer?.cancel();
    super.dispose();
  }

  void _startAutoExpandTimer(String categoryId) {
    _autoExpandTimer?.cancel();
    _autoExpandTimer = Timer(const Duration(milliseconds: 800), () {
      if (_hoveredCategoryId == categoryId && mounted) {
        setState(() {
          _expandedIds.add(categoryId);
        });
      }
    });
  }

  void _cancelAutoExpandTimer() {
    _autoExpandTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // 全部Vibe
        _CategoryItem(
          icon: Icons.auto_awesome_outlined,
          label: '全部Vibe',
          count: widget.totalEntryCount,
          isSelected: widget.selectedCategoryId == null,
          onTap: () => widget.onCategorySelected(null),
        ),
        // 收藏
        _CategoryItem(
          icon: widget.selectedCategoryId == 'favorites'
              ? Icons.favorite
              : Icons.favorite_border,
          iconColor: Colors.red.shade400,
          label: '收藏',
          count: widget.favoriteCount,
          isSelected: widget.selectedCategoryId == 'favorites',
          onTap: () => widget.onCategorySelected('favorites'),
        ),
        if (widget.categories.isNotEmpty)
          const Divider(height: 16, indent: 12, endIndent: 12),
        // 分类树
        ...widget.categories.rootCategories.sortedByOrder().map(
              (category) => _buildCategoryNode(theme, category, 0),
            ),
      ],
    );
  }

  Widget _buildCategoryNode(
    ThemeData theme,
    VibeLibraryCategory category,
    int depth,
  ) {
    final children = widget.categories.getChildren(category.id).sortedByOrder();
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedIds.contains(category.id);

    // 构建基础分类项
    Widget categoryItem = _CategoryItem(
      icon: hasChildren
          ? (isExpanded ? Icons.folder_open : Icons.folder)
          : Icons.folder_outlined,
      label: category.displayName,
      count: widget.categories.getChildren(category.id).length,
      isSelected: widget.selectedCategoryId == category.id,
      depth: depth,
      hasChildren: hasChildren,
      isExpanded: isExpanded,
      onTap: () => widget.onCategorySelected(category.id),
      onExpand: hasChildren
          ? () {
              setState(() {
                if (isExpanded) {
                  _expandedIds.remove(category.id);
                } else {
                  _expandedIds.add(category.id);
                }
              });
            }
          : null,
      onRename: widget.onCategoryRename != null
          ? (newName) => widget.onCategoryRename!(category.id, newName)
          : null,
      onDelete: widget.onCategoryDelete != null
          ? () => widget.onCategoryDelete!(category.id)
          : null,
      onAddSubCategory: widget.onAddSubCategory != null
          ? () => widget.onAddSubCategory!(category.id)
          : null,
    );

    // 包装为可拖拽组件
    categoryItem = _wrapWithDraggable(theme, category, categoryItem);

    // 包装为拖放目标
    categoryItem = _wrapWithDragTarget(theme, category, categoryItem);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        categoryItem,
        if (hasChildren && isExpanded)
          ...children
              .map((child) => _buildCategoryNode(theme, child, depth + 1)),
      ],
    );
  }

  /// 包装为可拖拽组件
  Widget _wrapWithDraggable(
    ThemeData theme,
    VibeLibraryCategory category,
    Widget child,
  ) {
    return Draggable<VibeLibraryCategory>(
      data: category,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerHigh,
        child: Container(
          width: 180,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: child),
      onDragStarted: () => HapticFeedback.mediumImpact(),
      onDragEnd: (_) {
        _cancelAutoExpandTimer();
        setState(() => _hoveredCategoryId = null);
      },
      child: child,
    );
  }

  /// 包装为拖放目标
  Widget _wrapWithDragTarget(
    ThemeData theme,
    VibeLibraryCategory targetCategory,
    Widget child,
  ) {
    return DragTarget<VibeLibraryCategory>(
      onWillAcceptWithDetails: (details) {
        final draggedCategory = details.data;
        // 不能拖到自己
        if (draggedCategory.id == targetCategory.id) return false;
        // 检查循环引用
        if (widget.categories.wouldCreateCycle(
          draggedCategory.id,
          targetCategory.id,
        )) {
          return false;
        }
        // 已经是子分类则不接受
        if (draggedCategory.parentId == targetCategory.id) return false;
        return true;
      },
      onAcceptWithDetails: (details) {
        HapticFeedback.heavyImpact();
        widget.onCategoryMove?.call(details.data.id, targetCategory.id);
        setState(() {
          _expandedIds.add(targetCategory.id);
          _hoveredCategoryId = null;
        });
        _cancelAutoExpandTimer();
      },
      onMove: (details) {
        if (_hoveredCategoryId != targetCategory.id) {
          setState(() => _hoveredCategoryId = targetCategory.id);
          final hasChildren =
              widget.categories.getChildren(targetCategory.id).isNotEmpty;
          if (hasChildren && !_expandedIds.contains(targetCategory.id)) {
            _startAutoExpandTimer(targetCategory.id);
          }
        }
      },
      onLeave: (_) {
        if (_hoveredCategoryId == targetCategory.id) {
          setState(() => _hoveredCategoryId = null);
          _cancelAutoExpandTimer();
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isAccepting = candidateData.isNotEmpty;
        final isRejected = rejectedData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isAccepting
                ? Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  )
                : isRejected
                    ? Border.all(
                        color: theme.colorScheme.error,
                        width: 2,
                      )
                    : null,
          ),
          child: child,
        );
      },
    );
  }
}

/// 分类项组件
class _CategoryItem extends StatefulWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final int count;
  final bool isSelected;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onExpand;
  final void Function(String)? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onAddSubCategory;

  const _CategoryItem({
    required this.icon,
    this.iconColor,
    required this.label,
    required this.count,
    required this.isSelected,
    this.depth = 0,
    this.hasChildren = false,
    this.isExpanded = false,
    required this.onTap,
    this.onExpand,
    this.onRename,
    this.onDelete,
    this.onAddSubCategory,
  });

  @override
  State<_CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<_CategoryItem> {
  bool _isHovering = false;
  bool _isEditing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.label);
  }

  @override
  void didUpdateWidget(covariant _CategoryItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label && !_isEditing) {
      _editController.text = widget.label;
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indent = 12.0 + widget.depth * 16.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onSecondaryTapUp: widget.onRename != null
            ? (details) => _showContextMenu(context, details.globalPosition)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? theme.colorScheme.primaryContainer
                : (_isHovering
                    ? theme.colorScheme.surfaceContainerHighest
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.only(
                left: indent,
                right: 8,
                top: 8,
                bottom: 8,
              ),
              child: Row(
                children: [
                  if (widget.hasChildren)
                    GestureDetector(
                      onTap: widget.onExpand,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          widget.isExpanded
                              ? Icons.expand_more
                              : Icons.chevron_right,
                          size: 16,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 20),
                  Icon(
                    widget.icon,
                    size: 18,
                    color: widget.iconColor ??
                        (widget.isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _isEditing
                        ? TextField(
                            controller: _editController,
                            autofocus: true,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (value) {
                              if (value.trim().isNotEmpty) {
                                widget.onRename?.call(value.trim());
                              }
                              setState(() => _isEditing = false);
                            },
                            onTapOutside: (_) {
                              setState(() => _isEditing = false);
                            },
                          )
                        : Text(
                            widget.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: widget.isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: widget.isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  Text(
                    widget.count.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.outline,
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

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        if (widget.onRename != null)
          PopupMenuItem(
            onTap: () {
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  setState(() => _isEditing = true);
                }
              });
            },
            child: const Row(
              children: [
                Icon(Icons.edit, size: 18),
                SizedBox(width: 8),
                Text('重命名'),
              ],
            ),
          ),
        if (widget.onAddSubCategory != null)
          PopupMenuItem(
            onTap: widget.onAddSubCategory,
            child: const Row(
              children: [
                Icon(Icons.create_new_folder, size: 18),
                SizedBox(width: 8),
                Text('新建子分类'),
              ],
            ),
          ),
        if (widget.onDelete != null)
          PopupMenuItem(
            onTap: widget.onDelete,
            child: Row(
              children: [
                Icon(
                  Icons.delete,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  '删除',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Vibe库内容视图
class _VibeLibraryContentView extends ConsumerStatefulWidget {
  final int columns;
  final double itemWidth;

  const _VibeLibraryContentView({
    required this.columns,
    required this.itemWidth,
  });

  @override
  ConsumerState<_VibeLibraryContentView> createState() {
    return _VibeLibraryContentViewState();
  }
}

class _VibeLibraryContentViewState
    extends ConsumerState<_VibeLibraryContentView> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vibeLibraryNotifierProvider);
    final selectionState = ref.watch(vibeLibrarySelectionNotifierProvider);

    // 使用 3D 卡片视图模式
    return _build3DCardView(state, selectionState);
  }

  /// 构建 3D 卡片视图
  Widget _build3DCardView(
    VibeLibraryState state,
    SelectionModeState selectionState,
  ) {
    final entries = state.currentEntries;

    // 空状态处理
    if (entries.isEmpty) {
      final emptyInfo = _getEmptyStateInfo(state);
      return GalleryErrorView(
        error: emptyInfo.subtitle ?? emptyInfo.title,
        onRetry: () {
          ref.read(vibeLibraryNotifierProvider.notifier).reload();
        },
      );
    }

    // 加载中状态
    if (state.isLoading) {
      return const GalleryLoadingView();
    }

    return GridView.builder(
      key: const PageStorageKey<String>('vibe_library_3d_grid'),
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.columns,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isSelected = selectionState.selectedIds.contains(entry.id);

        return VibeCard3D(
          entry: entry,
          width: widget.itemWidth,
          height: widget.itemWidth,
          isSelected: isSelected,
          showFavoriteIndicator: true,
          onTap: () {
            if (selectionState.isActive) {
              ref
                  .read(vibeLibrarySelectionNotifierProvider.notifier)
                  .toggle(entry.id);
            } else {
              _showVibeDetail(context, entry);
            }
          },
          onLongPress: () {
            if (!selectionState.isActive) {
              ref
                  .read(vibeLibrarySelectionNotifierProvider.notifier)
                  .enterAndSelect(entry.id);
            }
          },
          onSecondaryTapDown: (details) {
            _showContextMenu(context, entry, details.globalPosition);
          },
          onFavoriteToggle: () {
            ref
                .read(vibeLibraryNotifierProvider.notifier)
                .toggleFavorite(entry.id);
          },
          onSendToGeneration: () => _sendEntryToGeneration(context, entry),
          onExport: () => _exportSingleEntry(context, entry),
          onEdit: () => _showVibeDetail(context, entry),
          onDelete: () => _deleteSingleEntry(context, entry),
        );
      },
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
  void _showContextMenu(
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
      _ContextMenuRoute(
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
      AppToast.warning(context, '已达到最大数量 (16张)');
      return;
    }

    paramsNotifier.addVibeReferences([entry.toVibeReference()]);
    ref.read(vibeLibraryNotifierProvider.notifier).recordUsage(entry.id);
    AppToast.success(context, '已发送到生成页面: ${entry.displayName}');
    context.go(AppRoutes.home);
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
      AppToast.warning(context, '已达到最大数量 (16张)');
      return;
    }

    final vibeRef = entry.toVibeReference().copyWith(
          strength: strength,
          infoExtracted: infoExtracted,
        );

    paramsNotifier.addVibeReferences([vibeRef]);
    ref.read(vibeLibraryNotifierProvider.notifier).recordUsage(entry.id);
    AppToast.success(context, '已发送到生成页面: ${entry.displayName}');
    context.go(AppRoutes.home);
  }

  /// 导出单个条目
  void _exportSingleEntry(BuildContext context, VibeLibraryEntry entry) {
    final categories = ref.read(vibeLibraryCategoryNotifierProvider).categories;

    showDialog<void>(
      context: context,
      builder: (context) => VibeExportDialog(
        entries: [entry],
        categories: categories,
      ),
    );
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
    return null;
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

  /// 获取空状态提示信息
  _EmptyStateInfo _getEmptyStateInfo(VibeLibraryState state) {
    // 搜索无结果
    if (state.searchQuery.isNotEmpty) {
      return const _EmptyStateInfo(
        title: '未找到匹配的 Vibe',
        subtitle: '尝试其他关键词',
        icon: Icons.search_off,
      );
    }

    // 收藏无结果
    if (state.favoritesOnly) {
      return const _EmptyStateInfo(
        title: '暂无收藏的 Vibe',
        subtitle: '点击心形图标收藏 Vibe',
        icon: Icons.favorite_border,
      );
    }

    // 分类无结果
    if (state.selectedCategoryId != null) {
      return const _EmptyStateInfo(
        title: '该分类下暂无 Vibe',
        subtitle: '尝试切换到"全部 Vibe"查看所有内容',
        icon: Icons.folder_outlined,
      );
    }

    // 默认无结果
    return const _EmptyStateInfo(
      title: '无匹配结果',
      subtitle: null,
      icon: Icons.search_off,
    );
  }
}

/// 空状态信息
class _EmptyStateInfo {
  final String title;
  final String? subtitle;
  final IconData icon;

  const _EmptyStateInfo({
    required this.title,
    this.subtitle,
    required this.icon,
  });
}

/// 自定义上下文菜单路由
class _ContextMenuRoute extends PopupRoute {
  final Offset position;
  final List<ProMenuItem> items;
  final void Function(ProMenuItem) onSelect;

  _ContextMenuRoute({
    required this.position,
    required this.items,
    required this.onSelect,
  });

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeLeft: true,
      removeRight: true,
      removeBottom: true,
      child: Builder(
        builder: (context) {
          // 计算调整后的位置以保持菜单在屏幕边界内
          final screenSize = MediaQuery.of(context).size;
          const menuWidth = 180.0;
          final menuHeight = items.where((i) => !i.isDivider).length * 36.0 +
              items.where((i) => i.isDivider).length * 1.0;

          double left = position.dx;
          double top = position.dy;

          // 调整水平位置，如果菜单超出屏幕
          if (left + menuWidth > screenSize.width) {
            left = screenSize.width - menuWidth - 16;
          }

          // 调整垂直位置，如果菜单超出屏幕
          if (top + menuHeight > screenSize.height) {
            top = screenSize.height - menuHeight - 16;
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.of(context).pop(),
            child: Stack(
              children: [
                ProContextMenu(
                  position: Offset(left, top),
                  items: items,
                  onSelect: (item) {
                    onSelect(item);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ),
        child: child,
      ),
    );
  }
}

/// VibeLibraryNotifier 的导入仓库适配器
/// 实现 VibeLibraryImportRepository 接口以适配 VibeImportService
class _VibeLibraryNotifierImportRepository
    implements VibeLibraryImportRepository {
  _VibeLibraryNotifierImportRepository({
    required this.onGetAllEntries,
    required this.onSaveEntry,
  });

  final Future<List<VibeLibraryEntry>> Function() onGetAllEntries;
  final Future<VibeLibraryEntry?> Function(VibeLibraryEntry) onSaveEntry;

  @override
  Future<List<VibeLibraryEntry>> getAllEntries() async {
    return onGetAllEntries();
  }

  @override
  Future<VibeLibraryEntry> saveEntry(VibeLibraryEntry entry) async {
    final saved = await onSaveEntry(entry);
    if (saved == null) {
      throw StateError('Failed to save entry: ${entry.name}');
    }
    return saved;
  }
}

/// Vibe导入Intent
class VibeImportIntent extends Intent {
  const VibeImportIntent();
}

/// Vibe导出Intent
class VibeExportIntent extends Intent {
  const VibeExportIntent();
}
