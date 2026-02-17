import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/vibe/vibe_library_entry.dart';
import '../../providers/vibe_library_provider.dart';
import '../../providers/vibe_library_selection_provider.dart';
import '../../widgets/bulk_action_bar.dart';
import '../../widgets/gallery/gallery_state_views.dart';
import 'desktop_layout.dart';
import 'mobile_layout.dart';
import 'mixins/vibe_library_actions_mixin.dart';
import 'mixins/vibe_library_import_mixin.dart';
import 'widgets/vibe_detail_viewer.dart';
import 'widgets/vibe_library_content_view.dart';
import 'widgets/vibe_library_empty_view.dart';
import 'widgets/vibe_pagination_bar.dart';
import 'widgets/vibe_drop_overlay.dart';

/// Vibe库屏幕
/// Vibe Library Screen
class VibeLibraryScreen extends ConsumerStatefulWidget {
  const VibeLibraryScreen({super.key});

  @override
  ConsumerState<VibeLibraryScreen> createState() => _VibeLibraryScreenState();
}

class _VibeLibraryScreenState extends ConsumerState<VibeLibraryScreen>
    with VibeLibraryImportMixin<VibeLibraryScreen>,
         VibeLibraryActionsMixin<VibeLibraryScreen> {
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

    // 构建主体内容
    final content = _buildContent(state, columns, itemWidth, selectionState);

    // 构建分页条
    final paginationBar = state.totalPages > 0
        ? const VibePaginationBar()
        : const SizedBox.shrink();

    // 构建拖拽覆盖层
    final dropOverlay = const VibeDropOverlay();

    // 构建批量操作按钮
    final bulkActions = _buildBulkActions(theme);

    // 桌面端布局 (宽度 >= 800)
    if (screenWidth >= 800) {
      return Scaffold(
        body: DesktopVibeLibraryLayout(
          content: content,
          paginationBar: paginationBar,
          showCategoryPanel: _showCategoryPanel,
          onToggleCategoryPanel: () {
            setState(() => _showCategoryPanel = !_showCategoryPanel);
          },
          onRefresh: () {
            ref.read(vibeLibraryNotifierProvider.notifier).reload();
          },
          onImport: importVibes,
          onExport: () => exportVibes(),
          onEnterSelectionMode: () {
            ref.read(vibeLibrarySelectionNotifierProvider.notifier).enter();
          },
          searchController: _searchController,
          onSearchChanged: (value) {
            setState(() {});
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                ref
                    .read(vibeLibraryNotifierProvider.notifier)
                    .setSearchQuery(value);
              }
            });
          },
          onClearSearch: () {
            ref.read(vibeLibraryNotifierProvider.notifier).clearSearch();
            setState(() {});
          },
          onShowImportMenu: showImportMenu,
          bulkActions: bulkActions,
          isDragging: _isDragging,
          dropOverlay: dropOverlay,
          onDropChanged: (isDragging) => setState(() => _isDragging = isDragging),
          importOverlay: isImporting ? buildImportOverlay(theme) : null,
        ),
      );
    }

    // 移动端布局
    return Scaffold(
      body: MobileVibeLibraryLayout(
        content: content,
        paginationBar: paginationBar,
        onRefresh: () {
          ref.read(vibeLibraryNotifierProvider.notifier).reload();
        },
        onImport: importVibes,
        onExport: () => exportVibes(),
        onEnterSelectionMode: () {
          ref.read(vibeLibrarySelectionNotifierProvider.notifier).enter();
        },
        bulkActions: bulkActions,
        isDragging: _isDragging,
        dropOverlay: dropOverlay,
        importOverlay: isImporting ? buildImportOverlay(theme) : null,
      ),
    );
  }

  /// 构建主体内容
  Widget _buildContent(
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
      onSendToGeneration: sendEntryToGeneration,
      onExport: exportSingleEntry,
      onDelete: deleteSingleEntry,
    );
  }

  /// 构建批量操作按钮
  List<BulkActionItem> _buildBulkActions(ThemeData theme) {
    return [
      BulkActionItem(
        icon: Icons.send,
        label: '发送到生成',
        onPressed: batchSendToGeneration,
        color: theme.colorScheme.primary,
      ),
      BulkActionItem(
        icon: Icons.drive_file_move_outline,
        label: '移动',
        onPressed: showMoveToCategoryDialog,
        color: theme.colorScheme.secondary,
      ),
      BulkActionItem(
        icon: Icons.file_upload_outlined,
        label: '导出',
        onPressed: batchExport,
        color: theme.colorScheme.secondary,
      ),
      BulkActionItem(
        icon: Icons.favorite_border,
        label: '收藏',
        onPressed: batchToggleFavorite,
        color: theme.colorScheme.primary,
      ),
      BulkActionItem(
        icon: Icons.delete_outline,
        label: '删除',
        onPressed: batchDelete,
        color: theme.colorScheme.error,
        isDanger: true,
        showDividerBefore: true,
      ),
    ];
  }

  /// 显示 Vibe 详情
  void _showVibeDetail(BuildContext context, VibeLibraryEntry entry) {
    VibeDetailViewer.show(
      context,
      entry: entry,
      heroTag: 'vibe_${entry.id}',
      callbacks: VibeDetailCallbacks(
        onSendToGeneration: sendEntryToGenerationWithParams,
        onExport: exportSingleEntry,
        onDelete: deleteSingleEntry,
        onRename: renameSingleEntry,
        onParamsChanged: updateEntryParams,
      ),
    );
  }

  /// 显示上下文菜单
  void _showContextMenuForEntry(
    BuildContext context,
    VibeLibraryEntry entry,
    Offset position,
  ) {
    final theme = Theme.of(context);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.send, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              const Text('发送到生成'),
            ],
          ),
          onTap: () => sendEntryToGeneration(context, entry),
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.download, size: 20),
              SizedBox(width: 12),
              Text('导出'),
            ],
          ),
          onTap: () => exportSingleEntry(context, entry),
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.edit, size: 20),
              SizedBox(width: 12),
              Text('编辑'),
            ],
          ),
          onTap: () => _showVibeDetail(context, entry),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(
                entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: entry.isFavorite ? Colors.red : null,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(entry.isFavorite ? '取消收藏' : '收藏'),
            ],
          ),
          onTap: () {
            ref
                .read(vibeLibraryNotifierProvider.notifier)
                .toggleFavorite(entry.id);
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 20),
              const SizedBox(width: 12),
              Text('删除', style: TextStyle(color: theme.colorScheme.error)),
            ],
          ),
          onTap: () => deleteSingleEntry(context, entry),
        ),
      ],
    );
  }
}
