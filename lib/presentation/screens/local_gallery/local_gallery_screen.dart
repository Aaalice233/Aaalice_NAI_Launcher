import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/nai_prompt_formatter.dart';
import '../../../core/utils/permission_utils.dart';
import '../../../core/utils/sd_to_nai_converter.dart';
import '../../../core/utils/zip_utils.dart';
import '../../../data/models/character/character_prompt.dart' as char;
import '../../../data/models/gallery/local_image_record.dart';
import '../../../data/models/image/image_params.dart';
import '../../widgets/metadata/metadata_import_dialog.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../providers/bulk_operation_provider.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/collection_provider.dart';
import '../../providers/gallery_category_provider.dart';
import '../../providers/gallery_folder_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/gallery_scan_progress_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../widgets/bulk_metadata_edit_dialog.dart';
import '../../widgets/collection_select_dialog.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/pagination_bar.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/common/themed_input_dialog.dart';
import '../../widgets/gallery/gallery_category_tree_view.dart';
import '../../widgets/gallery/gallery_content_view.dart';
import '../../widgets/gallery/gallery_state_views.dart';
import '../../widgets/gallery/image_send_destination_dialog.dart';
import '../../widgets/gallery/local_gallery_toolbar.dart';
import '../../widgets/gallery_filter_panel.dart';
import '../../widgets/grouped_grid_view.dart'
    show GroupedGridViewState, ImageDateGroup;
import '../../widgets/shortcuts/shortcut_aware_widget.dart';

/// 本地画廊屏幕
class LocalGalleryScreen extends ConsumerStatefulWidget {
  const LocalGalleryScreen({super.key});

  @override
  ConsumerState<LocalGalleryScreen> createState() => _LocalGalleryScreenState();
}

class _LocalGalleryScreenState extends ConsumerState<LocalGalleryScreen> {
  final GlobalKey<GroupedGridViewState> _groupedGridViewKey =
      GlobalKey<GroupedGridViewState>();
  final FocusNode _shortcutsFocusNode = FocusNode();

  final bool _use3DCardView = true;
  bool _showCategoryPanel = true;
  AppLifecycleListener? _lifecycleListener;
  
  // 防抖计时器，防止频繁触发刷新
  Timer? _refreshDebounceTimer;
  
  // 上次刷新时间，用于限制刷新频率
  DateTime? _lastRefreshTime;
  
  // 最小刷新间隔（毫秒）
  static const int _minRefreshIntervalMs = 5000; // 5秒

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
      await _autoRefresh();
    });

    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _autoRefresh().catchError((e, stack) {
              AppLogger.e('Auto refresh on resume failed', e, stack, 'LocalGalleryScreen');
            });
          }
        });
      },
    );
  }


  @override
  void dispose() {
    _refreshDebounceTimer?.cancel();
    _lifecycleListener?.dispose();
    _shortcutsFocusNode.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
    final state = ref.watch(localGalleryNotifierProvider);
    final bulkOpState = ref.watch(bulkOperationNotifierProvider);
    final categoryState = ref.watch(galleryCategoryNotifierProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);

    final contentWidth =
        _showCategoryPanel && screenWidth > 800 ? screenWidth - 250 : screenWidth;
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
                _buildCategoryPanel(theme, state, categoryState),
              Expanded(
                child: Column(
                  children: [
                    _buildToolbarOrSelectionBar(state, bulkOpState),
                    Expanded(child: _buildBody(state, columns, itemWidth)),
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
    GalleryCategoryState categoryState,
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
          _buildCategoryPanelHeader(theme),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
          Expanded(
            child: FutureBuilder<int>(
              future: ref
                  .read(localGalleryNotifierProvider.notifier)
                  .getTotalFavoriteCount(),
              builder: (context, snapshot) {
                return GalleryCategoryTreeView(
                  categories: categoryState.categories,
                  totalImageCount: state.allFiles.length,
                  favoriteCount: snapshot.data ?? 0,
                  selectedCategoryId: categoryState.selectedCategoryId,
                  onCategorySelected: _handleCategorySelected,
                  onCategoryRename: (id, newName) => ref
                      .read(galleryCategoryNotifierProvider.notifier)
                      .renameCategory(id, newName),
                  onCategoryDelete: _handleCategoryDelete,
                  onAddSubCategory: _handleAddSubCategory,
                  onCategoryMove: (categoryId, newParentId) => ref
                      .read(galleryCategoryNotifierProvider.notifier)
                      .moveCategory(categoryId, newParentId),
                  onCategoryReorder: (parentId, oldIndex, newIndex) => ref
                      .read(galleryCategoryNotifierProvider.notifier)
                      .reorderCategories(parentId, oldIndex, newIndex),
                  onImageDrop: (imagePath, categoryId) =>
                      _handleImageDrop(imagePath, categoryId!),
                  onSyncWithFileSystem: _handleSyncWithFileSystem,
                );
              },
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
              '分类',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: _createCategory,
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

  Future<void> _createCategory() async {
    final name = await ThemedInputDialog.show(
      context: context,
      title: '新建分类',
      hintText: '请输入分类名称',
      confirmText: '创建',
      cancelText: '取消',
    );
    if (name != null && name.isNotEmpty) {
      await ref
          .read(galleryCategoryNotifierProvider.notifier)
          .createCategory(name, parentId: null);
    }
  }

  void _handleCategorySelected(String? id) {
    ref.read(galleryCategoryNotifierProvider.notifier).selectCategory(id);
    ref
        .read(localGalleryNotifierProvider.notifier)
        .setShowFavoritesOnly(id == 'favorites');
  }

  Future<void> _handleCategoryDelete(String id) async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: '确认删除',
      content: '确定要删除此分类吗？文件夹及其内容将被保留。',
      confirmText: '删除',
      cancelText: '取消',
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_outline,
    );
    if (confirmed) {
      await ref
          .read(galleryCategoryNotifierProvider.notifier)
          .deleteCategory(id, deleteFolder: false);
    }
  }

  Future<void> _handleAddSubCategory(String? parentId) async {
    final name = await ThemedInputDialog.show(
      context: context,
      title: parentId == null ? '新建分类' : '新建子分类',
      hintText: '请输入分类名称',
      confirmText: '创建',
      cancelText: '取消',
    );
    if (name != null && name.isNotEmpty) {
      await ref
          .read(galleryCategoryNotifierProvider.notifier)
          .createCategory(name, parentId: parentId);
    }
  }

  Future<void> _handleImageDrop(String imagePath, String categoryId) async {
    final newPath = await ref
        .read(galleryCategoryNotifierProvider.notifier)
        .moveImageToCategory(imagePath, categoryId);
    if (newPath != null) {
      ref.read(localGalleryNotifierProvider.notifier).refresh();
      if (mounted) AppToast.success(context, '图片已移动到分类');
    }
  }

  Future<void> _handleSyncWithFileSystem() async {
    await ref
        .read(galleryCategoryNotifierProvider.notifier)
        .syncWithFileSystem();
    if (mounted) AppToast.success(context, '分类已与文件夹同步');
  }

  Future<void> _autoRefresh() async {
    // 取消之前的防抖计时器
    _refreshDebounceTimer?.cancel();
    
    // 设置防抖延迟，避免频繁触发
    _refreshDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      
      // 检查当前是否仍在本地画廊页面
      final router = GoRouter.of(context);
      final currentPath = router.routeInformationProvider.value.uri.path;
      if (currentPath != '/local-gallery') {
        AppLogger.d('[AutoRefresh] Skipped: not on local gallery page (current: $currentPath)', 'LocalGalleryScreen');
        return;
      }
      
      // 检查刷新频率限制
      final now = DateTime.now();
      if (_lastRefreshTime != null) {
        final elapsed = now.difference(_lastRefreshTime!).inMilliseconds;
        if (elapsed < _minRefreshIntervalMs) {
          AppLogger.d('[AutoRefresh] Skipped: too frequent (${elapsed}ms < ${_minRefreshIntervalMs}ms)', 'LocalGalleryScreen');
          return;
        }
      }
      
      // 检查是否有扫描正在进行
      final scanState = ref.read(galleryScanProgressProvider);
      if (scanState.isScanning) {
        AppLogger.d('[AutoRefresh] Skipped: scan in progress', 'LocalGalleryScreen');
        return;
      }
      
      AppLogger.i('[AutoRefresh] Executing auto refresh', 'LocalGalleryScreen');
      _lastRefreshTime = now;

      await ref.read(localGalleryNotifierProvider.notifier).refresh();
      await ref.read(galleryCategoryNotifierProvider.notifier).syncWithFileSystem();
    });
  }

  // 元数据在扫描新文件时已自动提取，如需手动补全旧文件元数据，请使用设置页面的"补全元数据"功能

  Widget _buildToolbarOrSelectionBar(
    LocalGalleryState state,
    BulkOperationState bulkOpState,
  ) {
    return LocalGalleryToolbar(
      onRefresh: () => ref.read(localGalleryNotifierProvider.notifier).refresh(),
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
      onOpenFolder: () => _openGalleryFolder(),
    );
  }

  Widget _buildBody(LocalGalleryState state, int columns, double itemWidth) {
    if (state.error != null) {
      return GalleryErrorView(
        error: state.error,
        onRetry: () => ref.read(localGalleryNotifierProvider.notifier).refresh(),
      );
    }

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
      onContextMenu: (record, position) => _showImageContextMenu(record, position),
    );
  }

  void _handleKeyEvent(KeyEvent event, BulkOperationState bulkOpState) {
    if (event is! KeyDownEvent) return;

    final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
    if (!isCtrlPressed) return;

    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        if (bulkOpState.canRedo) _redo();
      } else {
        if (bulkOpState.canUndo) _undo();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyY && bulkOpState.canRedo) {
      _redo();
    }
  }

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
      await ref.read(localGalleryNotifierProvider.notifier).initialize();
      await ref.read(collectionNotifierProvider.notifier).initialize();
      _showFirstTimeIndexTipIfNeeded();
    }
  }

  void _showFirstTimeIndexTipIfNeeded() {
    final state = ref.read(localGalleryNotifierProvider);
    if (state.firstTimeIndexMessage != null && mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) AppToast.info(context, state.firstTimeIndexMessage!);
      });
    }
  }

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

    if (confirmed) PermissionUtils.openAppSettings();
  }

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

  Future<void> _openGalleryFolder() async {
    try {
      final rootPath = await GalleryFolderRepository.instance.getRootPath();
      if (rootPath == null || rootPath.isEmpty) {
        if (mounted) AppToast.info(context, '未设置保存目录');
        return;
      }

      final dir = Directory(rootPath);
      if (!await dir.exists()) {
        if (mounted) AppToast.info(context, '文件夹不存在');
        return;
      }

      if (Platform.isWindows) {
        await Process.start('explorer', [rootPath]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [rootPath]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [rootPath]);
      }
    } catch (e) {
      if (mounted) AppToast.error(context, '打开文件夹失败: $e');
    }
  }

  Future<void> _undo() async {
    await ref.read(bulkOperationNotifierProvider.notifier).undo();
    await ref.read(localGalleryNotifierProvider.notifier).refresh();
    if (mounted) AppToast.info(context, context.l10n.localGallery_undone);
  }

  Future<void> _redo() async {
    await ref.read(bulkOperationNotifierProvider.notifier).redo();
    await ref.read(localGalleryNotifierProvider.notifier).refresh();
    if (mounted) AppToast.info(context, context.l10n.localGallery_redone);
  }

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

  Future<void> _packSelectedImages() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final galleryState = ref.read(localGalleryNotifierProvider);

    final selectedImages = galleryState.currentImages
        .where((img) => selectionState.selectedIds.contains(img.path))
        .toList();

    if (selectedImages.isEmpty || !mounted) return;

    final defaultName = 'images_${DateTime.now().millisecondsSinceEpoch}';
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: '保存压缩包',
      fileName: '$defaultName.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (outputPath == null || !mounted) return;

    final finalPath =
        outputPath.endsWith('.zip') ? outputPath : '$outputPath.zip';

    AppToast.info(context, '正在打包 ${selectedImages.length} 张图片...');

    final imagePaths = selectedImages.map((img) => img.path).toList();
    final success = await ZipUtils.createZipFromImages(imagePaths, finalPath);

    if (mounted) {
      if (success) {
        AppToast.success(context, '已打包 ${selectedImages.length} 张图片');
        ref.read(localGallerySelectionNotifierProvider.notifier).exit();
      } else {
        AppToast.error(context, '打包失败');
      }
    }
  }

  Future<void> _editSelectedMetadata() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    if (selectionState.selectedIds.isEmpty || !mounted) return;
    showBulkMetadataEditDialog(context);
  }

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
      if (mounted) AppToast.info(context, context.l10n.localGallery_noFoldersAvailable);
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
    final movedCount = await GalleryFolderRepository.instance.moveImagesToFolder(
      imagePaths,
      selectedFolder,
    );

    if (mounted) {
      if (movedCount > 0) {
        AppToast.info(context, context.l10n.localGallery_movedImages(movedCount));
        ref.read(localGallerySelectionNotifierProvider.notifier).exit();
        ref.read(localGalleryNotifierProvider.notifier).refresh();
        ref.read(galleryFolderNotifierProvider.notifier).refresh();
      } else {
        AppToast.info(context, context.l10n.localGallery_moveImagesFailed);
      }
    }
  }

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

  Future<void> _reuseMetadata(LocalImageRecord record) async {
    final metadata = record.metadata;
    if (metadata == null || !metadata.hasData) return;

    final options = await MetadataImportDialog.show(context, metadata: metadata);
    if (options == null || !mounted) return;

    final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);

    if (options.importCharacterPrompts && metadata.characterPrompts.isNotEmpty) {
      ref.read(characterPromptNotifierProvider.notifier).clearAllCharacters();
    }

    var appliedCount = 0;

    if (options.importPrompt && metadata.prompt.isNotEmpty) {
      paramsNotifier.updatePrompt(_formatPrompt(metadata.prompt));
      appliedCount++;
    }

    if (options.importNegativePrompt && metadata.negativePrompt.isNotEmpty) {
      paramsNotifier.updateNegativePrompt(_formatPrompt(metadata.negativePrompt));
      appliedCount++;
    }

    if (options.importCharacterPrompts && metadata.characterPrompts.isNotEmpty) {
      _applyCharacterPrompts(metadata);
      appliedCount++;
    }

    _applyParam(options.importSeed, metadata.seed, paramsNotifier.updateSeed);
    _applyParam(options.importSteps, metadata.steps, paramsNotifier.updateSteps);
    _applyParam(options.importScale, metadata.scale, paramsNotifier.updateScale);
    _applyParam(options.importSampler, metadata.sampler, paramsNotifier.updateSampler);
    _applyParam(options.importModel, metadata.model, paramsNotifier.updateModel);
    _applyParam(options.importSmea, metadata.smea, paramsNotifier.updateSmea);
    _applyParam(options.importSmeaDyn, metadata.smeaDyn, paramsNotifier.updateSmeaDyn);
    _applyParam(options.importNoiseSchedule, metadata.noiseSchedule, paramsNotifier.updateNoiseSchedule);
    _applyParam(options.importCfgRescale, metadata.cfgRescale, paramsNotifier.updateCfgRescale);
    _applyParam(options.importQualityToggle, metadata.qualityToggle, paramsNotifier.updateQualityToggle);
    _applyParam(options.importUcPreset, metadata.ucPreset, paramsNotifier.updateUcPreset);

    if (options.importSize && metadata.width != null && metadata.height != null) {
      paramsNotifier.updateSize(metadata.width!, metadata.height!);
      appliedCount++;
    }

    if (!mounted) return;

    if (appliedCount > 0) {
      AppToast.info(context, context.l10n.metadataImport_appliedToMain(appliedCount));
    } else {
      AppToast.warning(context, context.l10n.metadataImport_noParamsSelected);
    }
  }

  String _formatPrompt(String prompt) {
    return NaiPromptFormatter.format(SdToNaiConverter.convert(prompt));
  }

  void _applyParam<T>(bool shouldApply, T? value, void Function(T) updater) {
    if (shouldApply && value != null) updater(value);
  }

  void _applyCharacterPrompts(dynamic metadata) {
    final characterNotifier = ref.read(characterPromptNotifierProvider.notifier);
    final characters = <char.CharacterPrompt>[];

    for (var i = 0; i < metadata.characterPrompts.length; i++) {
      final prompt = _formatPrompt(metadata.characterPrompts[i]);
      var negPrompt = i < metadata.characterNegativePrompts.length
          ? metadata.characterNegativePrompts[i]
          : '';
      if (negPrompt.isNotEmpty) negPrompt = _formatPrompt(negPrompt);

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

  Future<void> _sendToImg2Img(LocalImageRecord record) async {
    try {
      final file = File(record.path);
      if (!await file.exists()) {
        if (mounted) AppToast.info(context, '图片文件不存在');
        return;
      }

      final imageBytes = await file.readAsBytes();
      final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);

      paramsNotifier.setSourceImage(imageBytes);
      paramsNotifier.updateAction(ImageGenerationAction.img2img);

      if (mounted) AppToast.success(context, '图片已发送到图生图，请切换到生成页面');
    } catch (e) {
      if (mounted) AppToast.error(context, '发送失败: $e');
    }
  }

  Future<void> _sendToVibeTransfer(LocalImageRecord record) async {
    try {
      final vibeData = record.vibeData;
      if (vibeData == null) {
        if (mounted) AppToast.warning(context, '此图片不包含 Vibe 数据');
        return;
      }

      final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);
      paramsNotifier.addVibeReferences([vibeData]);

      if (mounted) {
        AppToast.success(context, 'Vibe "${vibeData.displayName}" 已添加到生成参数');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, '添加 Vibe 失败: $e');
    }
  }

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
          if (mounted) AppToast.success(context, 'Prompt 已复制');
        }
      case 'copy_seed':
        if (metadata?.seed != null) {
          await Clipboard.setData(ClipboardData(text: metadata!.seed.toString()));
          if (mounted) AppToast.success(context, 'Seed 已复制');
        }
      case 'open_folder':
        await _openFileInFolder(record.path);
      case 'delete':
        await _confirmDeleteImage(record);
    }
  }

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
      if (mounted) AppToast.error(context, '无法打开文件夹: $e');
    }
  }

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
          if (mounted) AppToast.success(context, '图片已删除');
        }
      } catch (e) {
        if (mounted) AppToast.error(context, '删除失败: $e');
      }
    }
  }

  void _toggleCategoryPanel() {
    setState(() => _showCategoryPanel = !_showCategoryPanel);
  }

  Future<void> _jumpToDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (pickerContext, child) => Theme(
        data: Theme.of(pickerContext).copyWith(
          dialogTheme: DialogTheme(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;

    final notifier = ref.read(localGalleryNotifierProvider.notifier);
    final currentState = ref.read(localGalleryNotifierProvider);
    if (!currentState.isGroupedView) await notifier.setGroupedView(true);

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // Calculate date differences for grouping
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(picked.year, picked.month, picked.day);
    final daysDiff = today.difference(selectedDate).inDays;

    late final ImageDateGroup targetGroup;
    if (daysDiff == 0) {
      targetGroup = ImageDateGroup.today;
    } else if (daysDiff == 1) {
      targetGroup = ImageDateGroup.yesterday;
    } else if (daysDiff < today.weekday) {
      targetGroup = ImageDateGroup.thisWeek;
    } else {
      targetGroup = ImageDateGroup.earlier;
    }

    _groupedGridViewKey.currentState?.scrollToGroup(targetGroup);

    if (context.mounted) {
      AppToast.info(context, '已跳转到 ${picked.year}-${picked.month.toString().padLeft(2, '0')}');
    }
  }
}
