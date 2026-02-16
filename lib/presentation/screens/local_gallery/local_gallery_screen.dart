import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../core/utils/nai_prompt_formatter.dart';
import '../../../core/utils/permission_utils.dart';
import '../../../core/utils/sd_to_nai_converter.dart';
import '../../../core/utils/zip_utils.dart';
import '../../../data/models/character/character_prompt.dart' as char;
import '../../../data/models/gallery/local_image_record.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/metadata/metadata_import_options.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../providers/bulk_operation_provider.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/collection_provider.dart';
import '../../providers/gallery_folder_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../widgets/bulk_metadata_edit_dialog.dart';
import '../../widgets/collection_select_dialog.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/pagination_bar.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/common/themed_input_dialog.dart';
import '../../widgets/gallery/folder_tabs.dart';
import '../../widgets/gallery/folder_tree_view.dart';
import '../../widgets/gallery/gallery_content_view.dart';
import '../../widgets/gallery/gallery_state_views.dart';
import '../../widgets/gallery/image_send_destination_dialog.dart';
import '../../widgets/gallery/local_gallery_toolbar.dart';
import '../../widgets/gallery_filter_panel.dart';
import '../../widgets/grouped_grid_view.dart'
    show GroupedGridViewState, ImageDateGroup;
import '../../widgets/shortcuts/shortcut_aware_widget.dart';

/// 本地画廊屏幕
/// Local gallery screen
class LocalGalleryScreen extends ConsumerStatefulWidget {
  const LocalGalleryScreen({super.key});

  @override
  ConsumerState<LocalGalleryScreen> createState() => _LocalGalleryScreenState();
}

class _LocalGalleryScreenState extends ConsumerState<LocalGalleryScreen> {
  /// Key for accessing GroupedGridView's scrollToGroup method
  /// 用于访问 GroupedGridView 的 scrollToGroup 方法的键
  final GlobalKey<GroupedGridViewState> _groupedGridViewKey =
      GlobalKey<GroupedGridViewState>();

  /// Focus node for keyboard shortcuts
  /// 用于键盘快捷键的焦点节点
  final FocusNode _shortcutsFocusNode = FocusNode();

  /// 是否使用3D卡片视图
  /// Whether to use 3D card view mode
  final bool _use3DCardView = true;

  /// 是否显示分类面板
  /// Whether to show category panel
  bool _showCategoryPanel = true;

  /// 缓存的快捷方式映射
  late final Map<String, VoidCallback> _shortcuts = {
    ShortcutIds.previousPage: _goToPreviousPage,
    ShortcutIds.nextPage: _goToNextPage,
    ShortcutIds.refreshGallery: _refreshGallery,
    ShortcutIds.focusSearch: _focusSearch,
    ShortcutIds.enterSelectionMode: _enterSelectionMode,
    ShortcutIds.openFilterPanel: () => showGalleryFilterPanel(context),
    ShortcutIds.clearFilter: _clearFilters,
    ShortcutIds.toggleCategoryPanel: _toggleCategoryPanel,
    ShortcutIds.jumpToDate: _jumpToDate,
    ShortcutIds.openFolder: _openGalleryFolder,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPermissionsAndScan();
      await _showFirstTimeTip();
    });
  }

  void _goToPreviousPage() {
    final state = ref.read(localGalleryNotifierProvider);
    if (state.currentPage > 0) {
      ref
          .read(localGalleryNotifierProvider.notifier)
          .loadPage(state.currentPage - 1);
    }
  }

  void _goToNextPage() {
    final state = ref.read(localGalleryNotifierProvider);
    if (state.currentPage < state.totalPages - 1) {
      ref
          .read(localGalleryNotifierProvider.notifier)
          .loadPage(state.currentPage + 1);
    }
  }

  void _refreshGallery() {
    ref.read(localGalleryNotifierProvider.notifier).refresh();
  }

  void _focusSearch() {
    final focusNode = FocusManager.instance.primaryFocus;
    focusNode?.unfocus();
    Future.delayed(const Duration(milliseconds: 50), () {
      FocusManager.instance.primaryFocus?.requestFocus();
    });
  }

  void _enterSelectionMode() {
    ref.read(localGallerySelectionNotifierProvider.notifier).enter();
  }

  void _clearFilters() {
    ref.read(localGalleryNotifierProvider.notifier).clearAllFilters();
  }

  @override
  void dispose() {
    _shortcutsFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localGalleryNotifierProvider);
    final bulkOpState = ref.watch(bulkOperationNotifierProvider);
    final folderState = ref.watch(galleryFolderNotifierProvider);
    final folderViewMode = ref.watch(folderViewModeProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);

    final contentWidth = _showCategoryPanel && screenWidth > 800
        ? screenWidth - 250
        : screenWidth;
    final columns = (contentWidth / 200).floor().clamp(2, 8);
    final itemWidth = contentWidth / columns;

    return PageShortcuts(
      contextType: ShortcutContext.gallery,
      shortcuts: _shortcuts,
      child: KeyboardListener(
        focusNode: _shortcutsFocusNode,
        autofocus: true,
        onKeyEvent: (event) => _handleKeyEvent(event, bulkOpState),
        child: Scaffold(
          body: Row(
            children: [
              if (_showCategoryPanel && screenWidth > 800)
                _buildCategoryPanel(theme, state, folderState),
              Expanded(
                child: Column(
                  children: [
                    _buildToolbarOrSelectionBar(state, bulkOpState),
                    Expanded(
                      child: _buildBody(state, columns, itemWidth),
                    ),
                    if (!state.isIndexing &&
                        state.filteredFiles.isNotEmpty &&
                        state.totalPages > 0)
                      PaginationBar(
                        currentPage: state.currentPage,
                        totalPages: state.totalPages,
                        totalItems: state.filteredCount,
                        itemsPerPage: state.pageSize,
                        onPageChanged: (p) => ref
                            .read(localGalleryNotifierProvider.notifier)
                            .loadPage(p),
                        onItemsPerPageChanged: (size) => ref
                            .read(localGalleryNotifierProvider.notifier)
                            .setPageSize(size),
                        showItemsPerPage: true,
                        showTotalInfo: true,
                        compact: contentWidth < 600,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPanel(
    ThemeData theme,
    LocalGalleryState state,
    GalleryFolderState folderState,
  ) {
    final folderViewMode = ref.watch(folderViewModeProvider);

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
          _buildCategoryPanelHeader(theme),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
          // Folder tabs (horizontal tabs view)
          if (folderViewMode == FolderViewMode.tabs)
            FolderTabs(
              onFolderSelected: (folderId) {
                _handleFolderSelected(folderId);
              },
            ),
          // Folder tree (hierarchical view)
          if (folderViewMode == FolderViewMode.tree)
            Expanded(
              child: FolderTreeView(
                folders: folderState.folders,
                totalImageCount: state.allFiles.length,
                favoriteCount: ref
                    .read(localGalleryNotifierProvider.notifier)
                    .getTotalFavoriteCount(),
                selectedFolderId: folderState.selectedFolderId,
                onFolderSelected: _handleFolderSelected,
                onFolderRename: (id, newName) => ref
                    .read(galleryFolderNotifierProvider.notifier)
                    .renameFolder(id, newName),
                onFolderDelete: _handleFolderDelete,
                onAddSubFolder: _handleAddSubFolder,
                onFolderMove: (folderId, newParentId) => ref
                    .read(galleryFolderNotifierProvider.notifier)
                    .moveFolder(folderId, newParentId),
                onFolderReorder: (parentId, oldIndex, newIndex) => ref
                    .read(galleryFolderNotifierProvider.notifier)
                    .reorderFolders(parentId, oldIndex, newIndex),
                onImageDrop: (imagePath, folderId) =>
                    _handleImageDrop(imagePath, folderId),
                onAutoCategorizeAll: _handleAutoCategorizeAll,
                onAutoCategorizeToFolder: _handleAutoCategorizeToFolder,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryPanelHeader(ThemeData theme) {
    return Container(
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
              '文件夹',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: _createFolder,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新建', style: TextStyle(fontSize: 13)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createFolder() async {
    final name = await ThemedInputDialog.show(
      context: context,
      title: '新建文件夹',
      hintText: '请输入文件夹名称',
      confirmText: '创建',
      cancelText: '取消',
    );
    if (name != null && name.isNotEmpty) {
      await ref
          .read(galleryFolderNotifierProvider.notifier)
          .createFolder(name, parentId: null);
    }
  }

  void _handleFolderSelected(String? id) {
    ref.read(galleryFolderNotifierProvider.notifier).selectFolder(id);
    ref
        .read(localGalleryNotifierProvider.notifier)
        .setShowFavoritesOnly(id == 'favorites');
  }

  Future<void> _handleFolderDelete(String id) async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: '确认删除',
      content: '确定要删除此文件夹吗？文件夹及其内容将被保留。',
      confirmText: '删除',
      cancelText: '取消',
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_outline,
    );
    if (confirmed) {
      await ref
          .read(galleryFolderNotifierProvider.notifier)
          .deleteFolder(id, deleteFolder: false);
    }
  }

  Future<void> _handleAddSubFolder(String? parentId) async {
    final name = await ThemedInputDialog.show(
      context: context,
      title: parentId == null ? '新建文件夹' : '新建子文件夹',
      hintText: '请输入文件夹名称',
      confirmText: '创建',
      cancelText: '取消',
    );
    if (name != null && name.isNotEmpty) {
      await ref
          .read(galleryFolderNotifierProvider.notifier)
          .createFolder(name, parentId: parentId);
    }
  }

  Future<void> _handleImageDrop(String imagePath, String? folderId) async {
    final newPath = await ref
        .read(galleryFolderNotifierProvider.notifier)
        .moveImageToFolder(imagePath, folderId);
    if (newPath != null) {
      ref.read(localGalleryNotifierProvider.notifier).refresh();
      if (mounted) {
        AppToast.success(context, '图片已移动到文件夹');
      }
    }
  }

  Future<void> _handleAutoCategorizeAll() async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: '智能分类',
      content: '是否对所有未分类图片进行智能分类？\n\n'
          '系统将根据图片标签自动移动到最合适的文件夹。',
      confirmText: '开始分类',
      cancelText: '取消',
      type: ThemedConfirmDialogType.info,
      icon: Icons.auto_awesome,
    );
    if (confirmed) {
      // TODO: Implement auto-categorization logic
      if (mounted) {
        AppToast.info(context, '智能分类功能开发中');
      }
    }
  }

  Future<void> _handleAutoCategorizeToFolder(
    String folderId,
    List<String> imagePaths,
  ) async {
    // TODO: Implement auto-categorization to specific folder
    if (mounted) {
      AppToast.info(context, '智能分类功能开发中');
    }
  }

  /// 处理重建索引
  Future<void> _handleRebuildIndex() async {
    final notifier = ref.read(localGalleryNotifierProvider.notifier);
    final state = ref.read(localGalleryNotifierProvider);

    // 如果已经在更新中，则取消
    if (state.isRebuildingIndex) {
      await notifier.performFullScan(); // 这会触发取消
      if (mounted) {
        AppToast.info(context, '已取消索引更新');
      }
      return;
    }

    // 开始更新
    final result = await notifier.performFullScan();

    if (!mounted) return;

    if (result == null) {
      // 可能是取消或失败
      final currentState = ref.read(localGalleryNotifierProvider);
      if (!currentState.isRebuildingIndex) {
        // 确实已经停止了，可能是取消
        AppToast.info(context, '索引更新已停止');
      }
      return;
    }

    if (result.filesAdded == 0 &&
        result.filesUpdated == 0 &&
        result.filesDeleted == 0) {
      // 没有变化
      AppToast.info(context, '索引已是最新，无需更新');
    } else {
      // 有更新
      final parts = <String>[];
      if (result.filesAdded > 0) parts.add('新增 ${result.filesAdded} 张');
      if (result.filesUpdated > 0) parts.add('更新 ${result.filesUpdated} 张');
      if (result.filesDeleted > 0) parts.add('删除 ${result.filesDeleted} 张');

      AppToast.success(context, '索引更新完成：${parts.join('，')}');
    }
  }

  /// 构建工具栏或选择栏
  Widget _buildToolbarOrSelectionBar(
    LocalGalleryState state,
    BulkOperationState bulkOpState,
  ) {
    final folderViewMode = ref.watch(folderViewModeProvider);

    // 使用独立的美化工具栏组件
    return LocalGalleryToolbar(
      use3DCardView: _use3DCardView,
      onRefresh: () =>
          ref.read(localGalleryNotifierProvider.notifier).refresh(),
      onRebuildIndex: () => _handleRebuildIndex(),
      onEnterSelectionMode: () =>
          ref.read(localGallerySelectionNotifierProvider.notifier).enter(),
      canUndo: bulkOpState.canUndo,
      canRedo: bulkOpState.canRedo,
      onUndo: bulkOpState.canUndo
          ? () => ref.read(bulkOperationNotifierProvider.notifier).undo()
          : null,
      onRedo: bulkOpState.canRedo
          ? () => ref.read(bulkOperationNotifierProvider.notifier).redo()
          : null,
      groupedGridViewKey: _groupedGridViewKey,
      onAddToCollection: _addSelectedToCollection,
      onDeleteSelected: _deleteSelectedImages,
      onPackSelected: _packSelectedImages,
      onEditMetadata: _editSelectedMetadata,
      onMoveToFolder: _moveSelectedToFolder,
      showCategoryPanel: _showCategoryPanel,
      onToggleCategoryPanel: _toggleCategoryPanel,
      onOpenFolder: () => _openGalleryFolder(),
      folderViewMode: folderViewMode,
      onToggleFolderViewMode: _toggleFolderViewMode,
    );
  }

  /// Build main body content
  /// 构建主体内容
  Widget _buildBody(LocalGalleryState state, int columns, double itemWidth) {
    if (state.error != null) {
      return GalleryErrorView(
        error: state.error,
        onRetry: () =>
            ref.read(localGalleryNotifierProvider.notifier).refresh(),
      );
    }

    // 只有在真正加载中且没有文件时才显示加载视图
    // 后台索引时不应阻止用户浏览已加载的文件
    if (state.isLoading && state.allFiles.isEmpty) {
      return const GalleryLoadingView();
    }

    if (state.allFiles.isEmpty) {
      return const GalleryEmptyView();
    }

    return GalleryContentView(
      use3DCardView: _use3DCardView,
      columns: columns,
      itemWidth: itemWidth,
      groupedGridViewKey: _groupedGridViewKey,
      onReuseMetadata: _reuseMetadata,
      onSendToImg2Img: _sendToImg2Img,
      onContextMenu: (record, position) {
        _showImageContextMenu(record, position);
      },
    );
  }

  /// Handle keyboard events for undo/redo
  /// 处理撤销/重做的键盘事件
  void _handleKeyEvent(KeyEvent event, BulkOperationState bulkOpState) {
    if (event is KeyDownEvent) {
      final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;

      if (isCtrlPressed) {
        if (event.logicalKey == LogicalKeyboardKey.keyZ) {
          if (HardwareKeyboard.instance.isShiftPressed) {
            // Ctrl+Shift+Z for redo
            if (bulkOpState.canRedo) _redo();
          } else {
            // Ctrl+Z for undo
            if (bulkOpState.canUndo) _undo();
          }
        } else if (event.logicalKey == LogicalKeyboardKey.keyY) {
          // Ctrl+Y for redo
          if (bulkOpState.canRedo) _redo();
        }
      }
    }
  }

  // ============================================================
  // Permission and initialization methods
  // 权限和初始化方法
  // ============================================================

  /// 检查权限并扫描图片
  Future<void> _checkPermissionsAndScan() async {
    final hasPermission = await PermissionUtils.checkGalleryPermission();

    if (!hasPermission) {
      final granted = await PermissionUtils.requestGalleryPermission();
      if (!granted && mounted) {
        _showPermissionDeniedDialog();
        return;
      }
    }

    if (mounted) {
      ref.read(localGalleryNotifierProvider.notifier).initialize();
    }
  }

  /// 显示权限被拒绝对话框
  void _showPermissionDeniedDialog() async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.localGallery_permissionRequiredTitle,
      content: context.l10n.localGallery_permissionRequiredContent,
      confirmText: context.l10n.localGallery_openSettings,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.warning,
      icon: Icons.folder_off_outlined,
    );

    if (confirmed) {
      PermissionUtils.openAppSettings();
    }
  }

  /// 显示首次使用提示
  Future<void> _showFirstTimeTip() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTip =
        prefs.getBool(StorageKeys.hasSeenLocalGalleryTip) ?? false;

    if (hasSeenTip || !mounted) return;

    await prefs.setBool(StorageKeys.hasSeenLocalGalleryTip, true);
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    await ThemedConfirmDialog.showInfo(
      context: context,
      title: context.l10n.localGallery_firstTimeTipTitle,
      content: context.l10n.localGallery_firstTimeTipContent,
      confirmText: context.l10n.localGallery_gotIt,
      icon: Icons.lightbulb_outline,
    );
  }

  // ============================================================
  // Folder operations
  // 文件夹操作
  // ============================================================

  /// 打开画廊文件夹
  Future<void> _openGalleryFolder() async {
    try {
      final rootPath = await GalleryFolderRepository.instance.getRootPath();
      if (rootPath == null || rootPath.isEmpty) {
        if (mounted) {
          AppToast.info(context, '未设置保存目录');
        }
        return;
      }

      final dir = Directory(rootPath);
      if (!await dir.exists()) {
        if (mounted) {
          AppToast.info(context, '文件夹不存在');
        }
        return;
      }

      if (Platform.isWindows) {
        // 使用 Process.start 避免等待进程完成导致的延迟
        await Process.start('explorer', [rootPath]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [rootPath]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [rootPath]);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '打开文件夹失败: $e');
      }
    }
  }

  // ============================================================
  // Undo/Redo operations
  // 撤销/重做操作
  // ============================================================

  /// 撤销上一步操作
  Future<void> _undo() async {
    await ref.read(bulkOperationNotifierProvider.notifier).undo();
    await ref.read(localGalleryNotifierProvider.notifier).refresh();

    if (mounted) {
      AppToast.info(context, context.l10n.localGallery_undone);
    }
  }

  /// 重做上一步撤销的操作
  Future<void> _redo() async {
    await ref.read(bulkOperationNotifierProvider.notifier).redo();
    await ref.read(localGalleryNotifierProvider.notifier).refresh();

    if (mounted) {
      AppToast.info(context, context.l10n.localGallery_redone);
    }
  }

  // ============================================================
  // Bulk operations
  // 批量操作
  // ============================================================

  /// 批量删除选中的图片
  Future<void> _deleteSelectedImages() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final galleryState = ref.read(localGalleryNotifierProvider);

    final selectedImages = galleryState.currentImages
        .where((img) => selectionState.selectedIds.contains(img.path))
        .toList();

    if (selectedImages.isEmpty) return;

    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.localGallery_confirmBulkDelete,
      content: context.l10n
          .localGallery_confirmBulkDeleteContent(selectedImages.length),
      confirmText: context.l10n.common_delete,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );

    if (!confirmed || !mounted) return;

    final deletedImages = <LocalImageRecord>[];
    for (final image in selectedImages) {
      try {
        final file = File(image.path);
        if (await file.exists()) {
          await file.delete();
          deletedImages.add(image);
        }
      } catch (e) {
        // Skip failed deletions
      }
    }

    ref.read(localGallerySelectionNotifierProvider.notifier).exit();
    await ref.read(localGalleryNotifierProvider.notifier).refresh();

    if (mounted && deletedImages.isNotEmpty) {
      AppToast.success(
        context,
        context.l10n.localGallery_deletedImages(deletedImages.length),
      );
    }
  }

  /// 批量打包选中的图片成压缩包
  Future<void> _packSelectedImages() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final galleryState = ref.read(localGalleryNotifierProvider);

    final selectedImages = galleryState.currentImages
        .where((img) => selectionState.selectedIds.contains(img.path))
        .toList();

    if (selectedImages.isEmpty || !mounted) return;

    // 直接使用保存文件对话框，用户可以选择路径并输入文件名
    final defaultName = 'images_${DateTime.now().millisecondsSinceEpoch}';
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: '保存压缩包',
      fileName: '$defaultName.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (outputPath == null || !mounted) return;

    // 确保文件名以 .zip 结尾
    final finalPath =
        outputPath.endsWith('.zip') ? outputPath : '$outputPath.zip';

    // 显示打包进度
    AppToast.info(context, '正在打包 ${selectedImages.length} 张图片...');

    // 执行打包
    final imagePaths = selectedImages.map((img) => img.path).toList();
    final success = await ZipUtils.createZipFromImages(
      imagePaths,
      finalPath,
    );

    if (mounted) {
      if (success) {
        AppToast.success(context, '已打包 ${selectedImages.length} 张图片');
        ref.read(localGallerySelectionNotifierProvider.notifier).exit();
      } else {
        AppToast.error(context, '打包失败');
      }
    }
  }

  /// 批量编辑选中的图片元数据
  Future<void> _editSelectedMetadata() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    if (selectionState.selectedIds.isEmpty || !mounted) return;
    showBulkMetadataEditDialog(context);
  }

  /// 批量移动选中的图片到文件夹
  Future<void> _moveSelectedToFolder() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final galleryState = ref.read(localGalleryNotifierProvider);
    final folderState = ref.read(galleryFolderNotifierProvider);

    final selectedImages = galleryState.currentImages
        .where((img) => selectionState.selectedIds.contains(img.path))
        .toList();

    if (selectedImages.isEmpty) return;

    final folders = folderState.folders;
    if (folders.isEmpty) {
      if (mounted) {
        AppToast.info(context, context.l10n.localGallery_noFoldersAvailable);
      }
      return;
    }

    final selectedFolder = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.localGallery_moveToFolder),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(folder.name),
                subtitle: Text(
                  context.l10n.localGallery_imageCount(folder.imageCount),
                ),
                onTap: () => Navigator.of(context).pop(folder.path),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.common_cancel),
          ),
        ],
      ),
    );

    if (selectedFolder == null || !mounted) return;

    final imagePaths = selectedImages.map((img) => img.path).toList();
    final movedCount =
        await GalleryFolderRepository.instance.moveImagesToFolder(
      imagePaths,
      selectedFolder,
    );

    if (mounted) {
      if (movedCount > 0) {
        AppToast.info(
          context,
          context.l10n.localGallery_movedImages(movedCount),
        );
        ref.read(localGallerySelectionNotifierProvider.notifier).exit();
        ref.read(localGalleryNotifierProvider.notifier).refresh();
        ref.read(galleryFolderNotifierProvider.notifier).refresh();
      } else {
        AppToast.info(context, context.l10n.localGallery_moveImagesFailed);
      }
    }
  }

  /// 批量添加选中的图片到集合
  Future<void> _addSelectedToCollection() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final galleryState = ref.read(localGalleryNotifierProvider);

    final selectedImages = galleryState.currentImages
        .where((img) => selectionState.selectedIds.contains(img.path))
        .toList();

    if (selectedImages.isEmpty || !mounted) return;

    final result = await CollectionSelectDialog.show(
      context,
      theme: Theme.of(context),
    );

    if (result == null) return;

    final imagePaths = selectedImages.map((img) => img.path).toList();
    final addedCount = await ref
        .read(collectionNotifierProvider.notifier)
        .addImagesToCollection(result.collectionId, imagePaths);

    if (mounted) {
      if (addedCount > 0) {
        AppToast.success(
          context,
          context.l10n.localGallery_addedToCollection(
            addedCount,
            result.collectionName,
          ),
        );
        ref.read(localGallerySelectionNotifierProvider.notifier).exit();
      } else {
        AppToast.info(context, context.l10n.localGallery_addToCollectionFailed);
      }
    }
  }

  // ============================================================
  // Image operations (reuse metadata, send to img2img)
  // 图片操作（复用元数据、发送到图生图）
  // ============================================================

  /// 复用图片的元数据参数到主界面
  Future<void> _reuseMetadata(LocalImageRecord record) async {
    final metadata = record.metadata;
    if (metadata == null || !metadata.hasData) return;

    // 显示参数选择对话框
    final options = await showDialog<MetadataImportOptions>(
      context: context,
      builder: (context) => _buildImportOptionsDialog(metadata),
    );

    if (options == null || !mounted) return; // 用户取消

    final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);

    // 只有在勾选导入多角色提示词时才清空
    if (options.importCharacterPrompts &&
        metadata.characterPrompts.isNotEmpty) {
      final characterNotifier =
          ref.read(characterPromptNotifierProvider.notifier);
      characterNotifier.clearAllCharacters();
    }

    // 根据选项应用参数
    var appliedCount = 0;

    if (options.importPrompt && metadata.prompt.isNotEmpty) {
      paramsNotifier.updatePrompt(_formatPrompt(metadata.prompt));
      appliedCount++;
    }

    if (options.importNegativePrompt && metadata.negativePrompt.isNotEmpty) {
      paramsNotifier
          .updateNegativePrompt(_formatPrompt(metadata.negativePrompt));
      appliedCount++;
    }

    if (options.importCharacterPrompts &&
        metadata.characterPrompts.isNotEmpty) {
      _applyCharacterPrompts(metadata);
      appliedCount++;
    }

    // 应用单个参数
    _applyParam(options.importSeed, metadata.seed, paramsNotifier.updateSeed);
    _applyParam(
        options.importSteps, metadata.steps, paramsNotifier.updateSteps,);
    _applyParam(
        options.importScale, metadata.scale, paramsNotifier.updateScale,);
    _applyParam(
        options.importSampler, metadata.sampler, paramsNotifier.updateSampler,);
    _applyParam(
        options.importModel, metadata.model, paramsNotifier.updateModel,);
    _applyParam(options.importSmea, metadata.smea, paramsNotifier.updateSmea);
    _applyParam(
        options.importSmeaDyn, metadata.smeaDyn, paramsNotifier.updateSmeaDyn,);
    _applyParam(options.importNoiseSchedule, metadata.noiseSchedule,
        paramsNotifier.updateNoiseSchedule,);
    _applyParam(options.importCfgRescale, metadata.cfgRescale,
        paramsNotifier.updateCfgRescale,);
    _applyParam(options.importQualityToggle, metadata.qualityToggle,
        paramsNotifier.updateQualityToggle,);
    _applyParam(options.importUcPreset, metadata.ucPreset,
        paramsNotifier.updateUcPreset,);

    if (options.importSize &&
        metadata.width != null &&
        metadata.height != null) {
      paramsNotifier.updateSize(metadata.width!, metadata.height!);
      appliedCount++;
    }

    if (!mounted) return;

    if (appliedCount > 0) {
      AppToast.info(
          context, context.l10n.metadataImport_appliedToMain(appliedCount),);
    } else {
      AppToast.warning(context, context.l10n.metadataImport_noParamsSelected);
    }
  }

  /// 构建导入选项对话框（简化版，用于画廊）
  Widget _buildImportOptionsDialog(dynamic metadata) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.metadataImport_title),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 快速预设按钮
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: Text(l10n.metadataImport_selectAll),
                    avatar: const Icon(Icons.select_all, size: 18),
                    onPressed: () => Navigator.of(context).pop(
                      MetadataImportOptions.all(),
                    ),
                    backgroundColor: theme.colorScheme.primaryContainer,
                    side: BorderSide.none,
                  ),
                  ActionChip(
                    label: Text(l10n.metadataImport_promptsOnly),
                    avatar: const Icon(Icons.text_fields, size: 18),
                    onPressed: () => Navigator.of(context).pop(
                      MetadataImportOptions.promptsOnly(),
                    ),
                  ),
                  ActionChip(
                    label: Text(l10n.metadataImport_generationOnly),
                    avatar: const Icon(Icons.tune, size: 18),
                    onPressed: () => Navigator.of(context).pop(
                      MetadataImportOptions.generationOnly(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.metadataImport_quickSelectHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            MetadataImportOptions.all(),
          ),
          child: Text(l10n.common_confirm),
        ),
      ],
    );
  }

  /// 格式化提示词（SD→NAI + 格式化）
  String _formatPrompt(String prompt) {
    return NaiPromptFormatter.format(SdToNaiConverter.convert(prompt));
  }

  /// 应用单个参数（如果条件满足）
  void _applyParam<T>(bool shouldApply, T? value, void Function(T) updater) {
    if (shouldApply && value != null) {
      updater(value);
    }
  }

  /// 应用多角色提示词
  void _applyCharacterPrompts(dynamic metadata) {
    final characterNotifier =
        ref.read(characterPromptNotifierProvider.notifier);
    final characters = <char.CharacterPrompt>[];

    for (var i = 0; i < metadata.characterPrompts.length; i++) {
      final prompt = _formatPrompt(metadata.characterPrompts[i]);
      var negPrompt = i < metadata.characterNegativePrompts.length
          ? metadata.characterNegativePrompts[i]
          : '';
      if (negPrompt.isNotEmpty) {
        negPrompt = _formatPrompt(negPrompt);
      }

      characters.add(
        char.CharacterPrompt.create(
          name: 'Character ${i + 1}',
          gender: _inferGenderFromPrompt(prompt),
          prompt: prompt,
          negativePrompt: negPrompt,
        ),
      );
    }
    characterNotifier.replaceAll(characters);
  }

  /// 从提示词推断角色性别
  char.CharacterGender _inferGenderFromPrompt(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    if (lowerPrompt.contains('1girl') ||
        lowerPrompt.contains('girl,') ||
        lowerPrompt.startsWith('girl')) {
      return char.CharacterGender.female;
    } else if (lowerPrompt.contains('1boy') ||
        lowerPrompt.contains('boy,') ||
        lowerPrompt.startsWith('boy')) {
      return char.CharacterGender.male;
    }
    return char.CharacterGender.other;
  }

  /// 发送图片到图生图
  Future<void> _sendToImg2Img(LocalImageRecord record) async {
    try {
      final file = File(record.path);
      if (!await file.exists()) {
        if (mounted) {
          AppToast.info(context, '图片文件不存在');
        }
        return;
      }

      final imageBytes = await file.readAsBytes();
      final paramsNotifier =
          ref.read(generationParamsNotifierProvider.notifier);

      paramsNotifier.setSourceImage(imageBytes);
      paramsNotifier.updateAction(ImageGenerationAction.img2img);

      if (mounted) {
        AppToast.success(context, '图片已发送到图生图，请切换到生成页面');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '发送失败: $e');
      }
    }
  }

  /// 发送图片到 Vibe Transfer
  /// 提取图片中的 vibe 数据并添加到生成参数
  Future<void> _sendToVibeTransfer(LocalImageRecord record) async {
    try {
      // 检查是否有 vibe 数据
      final vibeData = record.vibeData;
      if (vibeData == null) {
        if (mounted) {
          AppToast.warning(context, '此图片不包含 Vibe 数据');
        }
        return;
      }

      final paramsNotifier =
          ref.read(generationParamsNotifierProvider.notifier);

      // 添加 vibe 到生成参数
      paramsNotifier.addVibeReferences([vibeData]);

      if (mounted) {
        AppToast.success(
          context,
          'Vibe "${vibeData.displayName}" 已添加到生成参数',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '添加 Vibe 失败: $e');
      }
    }
  }

  /// 显示发送目标选择对话框
  Future<void> _showSendDestinationDialog(LocalImageRecord record) async {
    final destination = await ImageSendDestinationDialog.show(context, record);

    if (destination == null || !mounted) return;

    switch (destination) {
      case SendDestination.img2img:
        await _sendToImg2Img(record);
      case SendDestination.vibeTransfer:
        await _sendToVibeTransfer(record);
    }
  }

  /// 显示图片右键上下文菜单
  Future<void> _showImageContextMenu(
    LocalImageRecord record,
    Offset position,
  ) async {
    final metadata = record.metadata;

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        // 发送到选项
        const PopupMenuItem(
          value: 'send_to',
          child: Row(
            children: [
              Icon(Icons.send, size: 18),
              SizedBox(width: 8),
              Text('发送到...'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (metadata?.prompt.isNotEmpty == true)
          const PopupMenuItem(
            value: 'copy_prompt',
            child: Row(
              children: [
                Icon(Icons.content_copy, size: 18),
                SizedBox(width: 8),
                Text('复制 Prompt'),
              ],
            ),
          ),
        if (metadata?.seed != null)
          const PopupMenuItem(
            value: 'copy_seed',
            child: Row(
              children: [
                Icon(Icons.tag, size: 18),
                SizedBox(width: 8),
                Text('复制 Seed'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'open_folder',
          child: Row(
            children: [
              Icon(Icons.folder_open, size: 18),
              SizedBox(width: 8),
              Text('在文件夹中显示'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('删除', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );

    if (value == null || !context.mounted) return;

    switch (value) {
      case 'send_to':
        await _showSendDestinationDialog(record);
      case 'copy_prompt':
        if (metadata?.fullPrompt.isNotEmpty == true) {
          await Clipboard.setData(ClipboardData(text: metadata!.fullPrompt));
          if (mounted) {
            AppToast.success(context, 'Prompt 已复制');
          }
        }
      case 'copy_seed':
        if (metadata?.seed != null) {
          await Clipboard.setData(
            ClipboardData(text: metadata!.seed.toString()),
          );
          if (mounted) {
            AppToast.success(context, 'Seed 已复制');
          }
        }
      case 'open_folder':
        await _openFileInFolder(record.path);
      case 'delete':
        await _confirmDeleteImage(record);
    }
  }

  /// 在文件夹中打开文件
  Future<void> _openFileInFolder(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.start('explorer', ['/select,', filePath]);
      } else if (Platform.isMacOS) {
        await Process.start('open', ['-R', filePath]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [path.dirname(filePath)]);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '无法打开文件夹: $e');
      }
    }
  }

  /// 确认删除图片
  Future<void> _confirmDeleteImage(LocalImageRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          '确定要删除图片「${path.basename(record.path)}」吗？\n\n此操作无法撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final file = File(record.path);
        if (await file.exists()) {
          await file.delete();
          await ref.read(localGalleryNotifierProvider.notifier).refresh();
          if (mounted) {
            AppToast.success(context, '图片已删除');
          }
        }
      } catch (e) {
        if (mounted) {
          AppToast.error(context, '删除失败: $e');
        }
      }
    }
  }

  /// 切换分类面板显示状态
  void _toggleCategoryPanel() {
    setState(() {
      _showCategoryPanel = !_showCategoryPanel;
    });
  }

  /// 切换文件夹视图模式
  void _toggleFolderViewMode() {
    final currentMode = ref.read(folderViewModeProvider);
    final newMode = currentMode == FolderViewMode.tabs
        ? FolderViewMode.tree
        : FolderViewMode.tabs;
    ref.read(galleryFolderNotifierProvider.notifier).setFolderViewMode(newMode);
  }

  /// 跳转到日期
  Future<void> _jumpToDate() async {
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
      // 确保分组视图已激活
      final currentState = ref.read(localGalleryNotifierProvider);
      final notifier = ref.read(localGalleryNotifierProvider.notifier);
      if (!currentState.isGroupedView) {
        await notifier.setGroupedView(true);
      }

      // 等待分组数据加载
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // 计算所选日期属于哪个分组
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
      final selectedDate = DateTime(picked.year, picked.month, picked.day);

      // ignore: undefined_enum_constant
      dynamic targetGroup;

      // ignore: undefined_enum_constant
      if (selectedDate == today) {
        targetGroup = ImageDateGroup.today;
        // ignore: undefined_enum_constant
      } else if (selectedDate == yesterday) {
        targetGroup = ImageDateGroup.yesterday;
        // ignore: undefined_enum_constant
      } else if (selectedDate.isAfter(thisWeekStart) &&
          selectedDate.isBefore(today)) {
        targetGroup = ImageDateGroup.thisWeek;
        // ignore: undefined_enum_constant
      } else {
        targetGroup = ImageDateGroup.earlier;
      }

      // 使用 key 跳转到对应分组
      if (_groupedGridViewKey.currentState != null) {
        (_groupedGridViewKey.currentState as dynamic)
            .scrollToGroup(targetGroup);
      }

      // 显示提示
      if (context.mounted) {
        AppToast.info(
          context,
          '已跳转到 ${picked.year}-${picked.month.toString().padLeft(2, '0')}',
        );
      }
    }
  }
}
