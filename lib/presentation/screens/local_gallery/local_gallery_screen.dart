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
import '../../../core/utils/file_explorer_utils.dart';
import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../../core/utils/nai_prompt_formatter.dart';
import '../../../core/utils/permission_utils.dart';
import '../../../core/utils/sd_to_nai_converter.dart';
import '../../../core/utils/zip_utils.dart';
import '../../../data/models/character/character_prompt.dart' as char;
import '../../../data/models/gallery/gallery_category.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../widgets/metadata/metadata_import_dialog.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../providers/bulk_operation_provider.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/collection_provider.dart';
import '../../providers/gallery_category_provider.dart';
import '../../providers/gallery_folder_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/gallery_scan_progress_provider.dart';
import '../../providers/reverse_prompt_provider.dart';
import '../../router/app_router.dart';
import '../../services/image_workflow_launcher.dart';
import '../../utils/asset_protection_guard.dart';
import '../../utils/krita_send_helper.dart';
import '../../utils/local_gallery_reference_factory.dart';
import '../../utils/metadata_import_applier.dart';
import '../../utils/metadata_import_coordinator.dart';
import '../../utils/prompt_preset_import_utils.dart';
import '../../providers/selection_mode_provider.dart';
import '../../widgets/bulk_metadata_edit_dialog.dart';
import '../../widgets/collection_select_dialog.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/pagination_bar.dart';
import '../../widgets/common/precise_reference_type_dialog.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/common/themed_input_dialog.dart';
import '../../widgets/gallery/gallery_category_tree_view.dart';
import '../../widgets/gallery/gallery_content_view.dart';
import '../../widgets/gallery/gallery_state_views.dart';
import '../../widgets/gallery/local_image_context_menu.dart';
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
              AppLogger.e(
                'Auto refresh on resume failed',
                e,
                stack,
                'LocalGalleryScreen',
              );
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
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildCategoryPanelHeader(theme),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          Expanded(
            child: FutureBuilder<int>(
              future: ref
                  .read(localGalleryNotifierProvider.notifier)
                  .getTotalFavoriteCount(),
              builder: (context, snapshot) {
                return GalleryCategoryTreeView(
                  categories: categoryState.categories,
                  totalImageCount: state.totalCount,
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
                  onImageDrop: _handleImageDrop,
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
              context.l10n.localGallery_categoryPanelTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: _createCategory,
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              context.l10n.common_new,
              style: const TextStyle(fontSize: 13),
            ),
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
      title: context.l10n.localGallery_createCategoryTitle,
      hintText: context.l10n.localGallery_createCategoryHint,
      confirmText: context.l10n.localGallery_createCategoryConfirm,
      cancelText: context.l10n.common_cancel,
    );
    if (name != null && name.isNotEmpty) {
      await ref
          .read(galleryCategoryNotifierProvider.notifier)
          .createCategory(name, parentId: null);
    }
  }

  void _handleCategorySelected(String? id) {
    // 更新分类选中状态
    ref.read(galleryCategoryNotifierProvider.notifier).selectCategory(id);

    // 获取分类信息以便应用过滤
    final categoryState = ref.read(galleryCategoryNotifierProvider);
    final category = id != null ? categoryState.categories.findById(id) : null;

    // 应用分类过滤
    if (id == 'favorites') {
      // 收藏特殊处理
      ref
          .read(localGalleryNotifierProvider.notifier)
          .setShowFavoritesOnly(true);
    } else if (id != null && category != null) {
      // 普通分类：按文件夹路径过滤
      ref
          .read(localGalleryNotifierProvider.notifier)
          .setShowFavoritesOnly(false);
      ref
          .read(localGalleryNotifierProvider.notifier)
          .setSelectedCategory(id, category.folderPath);
    } else {
      // 全部：清除分类过滤
      ref
          .read(localGalleryNotifierProvider.notifier)
          .setShowFavoritesOnly(false);
      ref
          .read(localGalleryNotifierProvider.notifier)
          .setSelectedCategory(null, null);
    }
  }

  Future<void> _handleCategoryDelete(String id) async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.common_confirmDelete,
      content: context.l10n.localGallery_categoryDeleteContent,
      confirmText: context.l10n.common_delete,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_outline,
    );
    if (confirmed) {
      if (!mounted) return;
      final protected = await AssetProtectionGuard.confirmDangerousAction(
        context: context,
        ref: ref,
        title: context.l10n.localGallery_protectedDeleteCategoryTitle,
        content: context.l10n.localGallery_protectedDeleteCategoryContent,
        confirmText: context.l10n.localGallery_confirmDelete,
        icon: Icons.delete_outline,
      );
      if (!protected || !mounted) return;
      await ref
          .read(galleryCategoryNotifierProvider.notifier)
          .deleteCategory(id, deleteFolder: false);
    }
  }

  Future<void> _handleAddSubCategory(String? parentId) async {
    final name = await ThemedInputDialog.show(
      context: context,
      title: parentId == null
          ? context.l10n.localGallery_createCategoryTitle
          : context.l10n.localGallery_createSubCategoryTitle,
      hintText: context.l10n.localGallery_createCategoryHint,
      confirmText: context.l10n.localGallery_createCategoryConfirm,
      cancelText: context.l10n.common_cancel,
    );
    if (name != null && name.isNotEmpty) {
      await ref
          .read(galleryCategoryNotifierProvider.notifier)
          .createCategory(name, parentId: parentId);
    }
  }

  Future<void> _handleImageDrop(String imagePath, String? categoryId) async {
    final protected = await AssetProtectionGuard.confirmDangerousAction(
      context: context,
      ref: ref,
      title: context.l10n.localGallery_confirmMoveImageTitle,
      content: context.l10n.localGallery_confirmMoveImageContent,
      confirmText: context.l10n.localGallery_confirmMove,
      icon: Icons.drive_file_move_outline,
    );
    if (!protected || !mounted) return;

    final newPath = await ref
        .read(galleryCategoryNotifierProvider.notifier)
        .moveImageToCategory(imagePath, categoryId);
    if (newPath != null) {
      await ref
          .read(localGalleryNotifierProvider.notifier)
          .refresh(scan: false);
      if (mounted) {
        AppToast.success(
          context,
          context.l10n.localGallery_imageMovedToCategory,
        );
      }
    }
  }

  Future<void> _handleSyncWithFileSystem() async {
    await ref
        .read(galleryCategoryNotifierProvider.notifier)
        .syncWithFileSystem();
    if (mounted) {
      AppToast.success(context, context.l10n.localGallery_categoriesSynced);
    }
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
        AppLogger.d(
          '[AutoRefresh] Skipped: not on local gallery page (current: $currentPath)',
          'LocalGalleryScreen',
        );
        return;
      }

      // 检查刷新频率限制
      final now = DateTime.now();
      if (_lastRefreshTime != null) {
        final elapsed = now.difference(_lastRefreshTime!).inMilliseconds;
        if (elapsed < _minRefreshIntervalMs) {
          AppLogger.d(
            '[AutoRefresh] Skipped: too frequent (${elapsed}ms < ${_minRefreshIntervalMs}ms)',
            'LocalGalleryScreen',
          );
          return;
        }
      }

      // 检查是否有扫描正在进行
      final scanState = ref.read(galleryScanProgressProvider);
      if (scanState.isScanning) {
        AppLogger.d(
          '[AutoRefresh] Skipped: scan in progress',
          'LocalGalleryScreen',
        );
        return;
      }

      AppLogger.i('[AutoRefresh] Executing auto refresh', 'LocalGalleryScreen');
      _lastRefreshTime = now;

      await ref
          .read(localGalleryNotifierProvider.notifier)
          .refresh(scan: false);
      await ref
          .read(galleryCategoryNotifierProvider.notifier)
          .syncWithFileSystem();
    });
  }

  // 元数据在扫描新文件时已自动提取，如需手动补全旧文件元数据，请使用设置页面的"补全元数据"功能

  Widget _buildToolbarOrSelectionBar(
    LocalGalleryState state,
    BulkOperationState bulkOpState,
  ) {
    return LocalGalleryToolbar(
      onRefresh: () =>
          ref.read(localGalleryNotifierProvider.notifier).refresh(),
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
        onRetry: () =>
            ref.read(localGalleryNotifierProvider.notifier).refresh(),
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
      onContextMenu: (record, position) =>
          _showImageContextMenu(record, position),
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
    } else if (event.logicalKey == LogicalKeyboardKey.keyY &&
        bulkOpState.canRedo) {
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
        if (mounted) {
          AppToast.info(context, context.l10n.localGallery_saveDirectoryNotSet);
        }
        return;
      }

      final dir = Directory(rootPath);
      if (!await dir.exists()) {
        if (mounted) {
          AppToast.info(context, context.l10n.localGallery_folderNotFound);
        }
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
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.localGallery_openFolderFailed('$e'),
        );
      }
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
    // 保存 context 相关数据（必须在任何 await 之前）
    final l10n = context.l10n;

    // 从数据库获取所有选中项的完整记录（支持跨页）
    final service = await ref
        .read(localGalleryNotifierProvider.notifier)
        .getService();
    final selectedImages = await service.getRecordsByPaths(
      selectionState.selectedIds.toList(),
    );

    if (selectedImages.isEmpty) return;

    final confirmed = await ThemedConfirmDialog.show(
      // ignore: use_build_context_synchronously
      context: context,
      title: l10n.localGallery_confirmBulkDelete,
      content: l10n.localGallery_confirmBulkDeleteContent(
        selectedImages.length,
      ),
      confirmText: l10n.common_delete,
      cancelText: l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );

    if (!confirmed || !mounted) return;

    final protected = await AssetProtectionGuard.confirmDangerousAction(
      context: context,
      ref: ref,
      title: l10n.localGallery_protectedDeleteTitle,
      content: l10n.localGallery_protectedDeleteImagesContent(
        selectedImages.length,
      ),
      confirmText: l10n.common_delete,
      icon: Icons.delete_forever_outlined,
    );
    if (!protected || !mounted) return;

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

    // 从数据库获取所有选中项的完整记录（支持跨页）
    final service = await ref
        .read(localGalleryNotifierProvider.notifier)
        .getService();
    final selectedImages = await service.getRecordsByPaths(
      selectionState.selectedIds.toList(),
    );

    if (selectedImages.isEmpty || !mounted) return;

    final defaultName = 'images_${DateTime.now().millisecondsSinceEpoch}';
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: context.l10n.localGallery_saveZipArchive,
      fileName: '$defaultName.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (outputPath == null || !mounted) return;

    final requestedPath = outputPath.endsWith('.zip')
        ? outputPath
        : '$outputPath.zip';
    final finalPath = AssetProtectionGuard.shouldPreventOverwrite(ref)
        ? await AssetProtectionGuard.resolveNonOverwritingPath(requestedPath)
        : requestedPath;

    if (!mounted) return;
    AppToast.info(
      context,
      context.l10n.localGallery_packingImages(selectedImages.length),
    );

    final imagePaths = selectedImages.map((img) => img.path).toList();
    final success = await ZipUtils.createZipFromImages(imagePaths, finalPath);

    if (mounted) {
      if (success) {
        AppToast.success(
          context,
          context.l10n.localGallery_packedImages(selectedImages.length),
        );
        ref.read(localGallerySelectionNotifierProvider.notifier).exit();
      } else {
        AppToast.error(context, context.l10n.localGallery_packFailed);
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
    final folderState = ref.read(galleryFolderNotifierProvider);
    // 保存 context 相关数据（必须在任何 await 之前）
    final l10n = context.l10n;

    // 从数据库获取所有选中项的完整记录（支持跨页）
    final service = await ref
        .read(localGalleryNotifierProvider.notifier)
        .getService();
    final selectedImages = await service.getRecordsByPaths(
      selectionState.selectedIds.toList(),
    );

    if (selectedImages.isEmpty) return;

    final folders = folderState.folders;

    if (folders.isEmpty) {
      // ignore: use_build_context_synchronously
      if (mounted) AppToast.info(context, l10n.localGallery_noFoldersAvailable);
      return;
    }

    final selectedFolder = await showDialog<String>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.localGallery_moveToFolder),
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
                subtitle: Text(l10n.localGallery_imageCount(folder.imageCount)),
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

    final protected = await AssetProtectionGuard.confirmDangerousAction(
      context: context,
      ref: ref,
      title: l10n.localGallery_protectedBulkMoveTitle,
      content: l10n.localGallery_protectedBulkMoveContent(
        selectedImages.length,
      ),
      confirmText: l10n.localGallery_confirmMove,
      icon: Icons.drive_file_move_outline,
    );
    if (!protected || !mounted) return;

    final imagePaths = selectedImages.map((img) => img.path).toList();
    final movedCount = await GalleryFolderRepository.instance
        .moveImagesToFolder(imagePaths, selectedFolder);

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

  Future<void> _addSelectedToCollection() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);

    // 从数据库获取所有选中项的完整记录（支持跨页）
    final service = await ref
        .read(localGalleryNotifierProvider.notifier)
        .getService();
    final selectedImages = await service.getRecordsByPaths(
      selectionState.selectedIds.toList(),
    );

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
    try {
      final metadata = record.metadata;
      if (metadata == null || !metadata.hasData) {
        AppToast.warning(context, context.l10n.localGallery_noMetadata);
        return;
      }

      final options = await MetadataImportDialog.show(
        context,
        metadata: metadata,
      );
      if (options == null || !mounted) return;

      final paramsNotifier = ref.read(
        generationParamsNotifierProvider.notifier,
      );

      // 安全获取角色提示词列表（防止 null）
      final characterPrompts = metadata.characterPrompts;
      final hasCharacters = characterPrompts.isNotEmpty;

      if (options.importCharacterPrompts && hasCharacters) {
        ref.read(characterPromptNotifierProvider.notifier).clearAllCharacters();
      }

      var appliedCount = 0;

      final currentModel = ref.read(generationParamsNotifierProvider).model;
      appliedCount += MetadataImportApplier.applyPromptAndGenerationParams(
        metadata: metadata,
        options: options,
        currentModel: currentModel,
        target: MetadataImportTarget(
          updatePrompt: (value) =>
              paramsNotifier.updatePrompt(_formatPrompt(value)),
          updateNegativePrompt: (value) =>
              paramsNotifier.updateNegativePrompt(_formatPrompt(value)),
          updateSeed: paramsNotifier.updateSeed,
          updateSteps: paramsNotifier.updateSteps,
          updateScale: paramsNotifier.updateScale,
          updateSize: paramsNotifier.updateSize,
          updateSampler: paramsNotifier.updateSampler,
          updateModel: paramsNotifier.updateModel,
          updateSmea: paramsNotifier.updateSmea,
          updateSmeaDyn: paramsNotifier.updateSmeaDyn,
          updateVarietyPlus: paramsNotifier.updateVarietyPlus,
          updateNoiseSchedule: paramsNotifier.updateNoiseSchedule,
          updateCfgRescale: paramsNotifier.updateCfgRescale,
          updateQualityToggle: (value) {
            paramsNotifier.updateQualityToggle(value);
            applyImportedQualityToggle(ref.read, value);
          },
          updateUcPreset: (value) {
            paramsNotifier.updateUcPreset(value);
            applyImportedUcPreset(ref.read, value);
          },
        ),
      );

      if (options.importCharacterPrompts && hasCharacters) {
        _applyCharacterPrompts(metadata);
        appliedCount++;
      }

      if (!mounted) return;

      if (appliedCount > 0) {
        AppToast.info(
          context,
          context.l10n.metadataImport_appliedToMain(appliedCount),
        );
      } else {
        AppToast.warning(context, context.l10n.metadataImport_noParamsSelected);
      }
    } catch (e, stack) {
      AppLogger.e('导入参数失败', e, stack, 'LocalGallery');
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.localGallery_importParamsFailed('$e'),
        );
      }
    }
  }

  String _formatPrompt(String prompt) {
    return NaiPromptFormatter.format(SdToNaiConverter.convert(prompt));
  }

  void _applyCharacterPrompts(NaiImageMetadata metadata) {
    final characterNotifier = ref.read(
      characterPromptNotifierProvider.notifier,
    );
    final characters = <char.CharacterPrompt>[];

    // 安全获取角色提示词列表
    final characterPrompts = metadata.characterPrompts;
    final characterNegativePrompts = metadata.characterNegativePrompts;

    for (var i = 0; i < characterPrompts.length; i++) {
      final prompt = _formatPrompt(characterPrompts[i]);
      var negPrompt = i < characterNegativePrompts.length
          ? characterNegativePrompts[i]
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
        if (mounted) {
          AppToast.info(context, context.l10n.localGallery_imageFileMissing);
        }
        return;
      }

      final imageBytes = await file.readAsBytes();
      ImageWorkflowLauncher.openImageToImage(ref, imageBytes);

      if (mounted) {
        context.go(AppRoutes.home);
        AppToast.success(context, context.l10n.localGallery_sentToImageToImage);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.localGallery_sendFailed('$e'));
      }
    }
  }

  Future<void> _sendToStyleTransfer(LocalImageRecord record) async {
    try {
      final file = File(record.path);
      if (!await file.exists()) {
        if (mounted) {
          AppToast.info(context, context.l10n.localGallery_imageFileMissing);
        }
        return;
      }

      if (!mounted || _warnIfStyleReferenceLimitReached()) return;

      final imageBytes = await file.readAsBytes();
      if (!mounted || _warnIfStyleReferenceLimitReached()) return;
      final currentCount = ref
          .read(generationParamsNotifierProvider)
          .vibeReferencesV4
          .length;
      final paramsNotifier = ref.read(
        generationParamsNotifierProvider.notifier,
      );
      paramsNotifier.addVibeReference(
        LocalGalleryReferenceFactory.createRawStyleReference(
          fileName: path.basename(record.path),
          imageBytes: imageBytes,
        ),
      );

      if (mounted) {
        context.go(AppRoutes.home);
        AppToast.success(
          context,
          currentCount == 0
              ? context.l10n.drop_addedToVibe
              : context.l10n.toast_appendedStyleReferences(1),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.localGallery_sendFailed('$e'));
      }
    }
  }

  bool _warnIfStyleReferenceLimitReached() {
    const maxCount = 16;
    if (ref.read(generationParamsNotifierProvider).vibeReferencesV4.length <
        maxCount) {
      return false;
    }

    AppToast.warning(context, context.l10n.toast_styleReferenceLimit(maxCount));
    return true;
  }

  Future<void> _sendToPreciseReference(LocalImageRecord record) async {
    try {
      final file = File(record.path);
      if (!await file.exists()) {
        if (mounted) {
          AppToast.info(context, context.l10n.localGallery_imageFileMissing);
        }
        return;
      }

      if (!mounted) return;
      final selectedType = await PreciseReferenceTypeDialog.show(context);
      if (selectedType == null || !mounted) return;

      final imageBytes = await file.readAsBytes();
      if (!mounted) return;
      unawaited(
        ref
            .read(generationParamsNotifierProvider.notifier)
            .addPreciseReferenceFromImage(
              imageBytes,
              type: selectedType,
              strength: 1.0,
              fidelity: 1.0,
            ),
      );

      if (mounted) {
        context.go(AppRoutes.home);
        AppToast.success(context, context.l10n.drop_addedToCharacterRef);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.localGallery_sendFailed('$e'));
      }
    }
  }

  Future<void> _importImageMetadata(LocalImageRecord record) async {
    try {
      final metadata = record.metadata;
      if (metadata == null || !metadata.hasData) {
        AppToast.warning(context, context.l10n.metadataImport_noDataFound);
        return;
      }

      final options = await MetadataImportDialog.show(
        context,
        metadata: metadata,
      );
      if (options == null || !mounted) return;

      final appliedCount = await MetadataImportCoordinator.apply(
        read: ref.read,
        metadata: metadata,
        options: options,
      );
      if (!mounted) return;

      if (appliedCount == 0) {
        AppToast.warning(context, context.l10n.metadataImport_noParamsSelected);
        return;
      }

      final l10n = context.l10n;
      final currentModel = ref.read(generationParamsNotifierProvider).model;
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      AppToast.success(context, l10n.metadataImport_appliedCount(appliedCount));
      context.go(AppRoutes.home);

      await WidgetsBinding.instance.endOfFrame;
      if (!rootNavigator.mounted) return;
      unawaited(
        MetadataImportCoordinator.showAppliedDialog(
          context: rootNavigator.context,
          metadata: metadata,
          options: options,
          l10n: l10n,
          currentModel: currentModel,
        ),
      );
    } catch (e, stack) {
      AppLogger.e('导入图片元数据失败', e, stack, 'LocalGallery');
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.localGallery_importParamsFailed('$e'),
        );
      }
    }
  }

  Future<void> _sendToReversePrompt(LocalImageRecord record) async {
    try {
      final file = File(record.path);
      if (!await file.exists()) {
        if (mounted) {
          AppToast.info(context, context.l10n.localGallery_imageFileMissing);
        }
        return;
      }

      await ref
          .read(reversePromptProvider.notifier)
          .addImage(await file.readAsBytes(), name: path.basename(record.path));

      if (mounted) {
        context.go(AppRoutes.home);
        AppToast.success(
          context,
          context.l10n.localGallery_sentToReversePrompt,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.localGallery_sendFailed('$e'));
      }
    }
  }

  Future<void> _sendToKrita(LocalImageRecord record) async {
    try {
      final file = File(record.path);
      if (!await file.exists()) {
        if (mounted) {
          AppToast.info(context, context.l10n.localGallery_imageFileMissing);
        }
        return;
      }

      final imageBytes = await file.readAsBytes();
      if (!mounted) return;
      KritaSendHelper.sendImageBytes(
        context,
        ref,
        imageBytes,
        name: path.basename(record.path),
      );
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.localGallery_sendToKritaFailed('$e'),
        );
      }
    }
  }

  Future<void> _showImageContextMenu(
    LocalImageRecord record,
    Offset position,
  ) async {
    final metadata = record.metadata;
    final action = await LocalImageContextMenu.show(
      context,
      position: position,
      hasImportableMetadata: metadata?.hasData == true,
      hasPrompt: metadata?.prompt.isNotEmpty == true,
      hasSeed: metadata?.seed != null,
      isKritaConnected:
          ref.read(kritaBridgeNotifierProvider).status ==
          KritaBridgeStatus.connected,
    );

    if (action == null || !context.mounted) return;

    switch (action) {
      case LocalImageContextAction.sendToImg2Img:
        await _sendToImg2Img(record);
      case LocalImageContextAction.sendToReversePrompt:
        await _sendToReversePrompt(record);
      case LocalImageContextAction.sendToStyleTransfer:
        await _sendToStyleTransfer(record);
      case LocalImageContextAction.sendToPreciseReference:
        await _sendToPreciseReference(record);
      case LocalImageContextAction.sendToKrita:
        await _sendToKrita(record);
      case LocalImageContextAction.importMetadata:
        await _importImageMetadata(record);
      case LocalImageContextAction.copyPrompt:
        if (metadata?.fullPrompt.isNotEmpty == true) {
          await Clipboard.setData(ClipboardData(text: metadata!.fullPrompt));
          if (mounted) {
            AppToast.success(context, context.l10n.localGallery_promptCopied);
          }
        }
      case LocalImageContextAction.copySeed:
        if (metadata?.seed != null) {
          await Clipboard.setData(
            ClipboardData(text: metadata!.seed.toString()),
          );
          if (mounted) {
            AppToast.success(context, context.l10n.localGallery_seedCopied);
          }
        }
      case LocalImageContextAction.showInFolder:
        await _openFileInFolder(record.path);
      case LocalImageContextAction.delete:
        await _confirmDeleteImage(record);
    }
  }

  Future<void> _openFileInFolder(String filePath) async {
    try {
      await FileExplorerUtils.revealFile(filePath);
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.localGallery_cannotOpenFolder('$e'),
        );
      }
    }
  }

  Future<void> _confirmDeleteImage(LocalImageRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.common_confirmDelete),
        content: Text(
          context.l10n.localGallery_confirmDeleteImageContent(
            path.basename(record.path),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final protected = await AssetProtectionGuard.confirmDangerousAction(
        context: context,
        ref: ref,
        title: context.l10n.localGallery_protectedDeleteTitle,
        content: context.l10n.localGallery_protectedDeleteImageContent(
          path.basename(record.path),
        ),
        confirmText: context.l10n.localGallery_confirmDelete,
        icon: Icons.delete_outline,
      );
      if (!protected || !mounted) return;
      try {
        final file = File(record.path);
        if (await file.exists()) {
          await file.delete();
          await ref.read(localGalleryNotifierProvider.notifier).refresh();
          if (mounted) {
            AppToast.success(context, context.l10n.localGallery_imageDeleted);
          }
        }
      } catch (e) {
        if (mounted) {
          AppToast.error(context, context.l10n.localGallery_deleteFailed('$e'));
        }
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
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
      final month = picked.month.toString().padLeft(2, '0');
      AppToast.info(
        context,
        context.l10n.localGallery_jumpedToMonth(picked.year, month),
      );
    }
  }
}
