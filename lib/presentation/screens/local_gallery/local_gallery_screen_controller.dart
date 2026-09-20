import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/file_explorer_utils.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/permission_utils.dart';
import '../../../data/models/gallery/gallery_category.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../providers/bulk_operation_provider.dart';
import '../../providers/collection_provider.dart';
import '../../providers/gallery_album_provider.dart';
import '../../providers/gallery_category_provider.dart';
import '../../providers/gallery_scan_progress_provider.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../services/library_sidebar_move_service.dart';
import '../../utils/asset_protection_guard.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/image_card_action.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/common/themed_input_dialog.dart';
import '../../widgets/gallery_filter_panel.dart';
import '../../widgets/grouped_grid_view.dart'
    show GroupedGridViewState, ImageDateGroup;
import 'local_gallery_action_coordinator.dart';
import 'local_gallery_category_panel.dart';

class LocalGalleryScreenController extends ChangeNotifier {
  LocalGalleryScreenController({
    required WidgetRef ref,
    required BuildContext Function() context,
    required bool Function() mounted,
    required this.groupedGridViewKey,
    required LocalGalleryActionCoordinator actions,
  }) : _ref = ref,
       _context = context,
       _mounted = mounted,
       _actions = actions {
    shortcuts = {
      ShortcutIds.previousPage: goToPreviousPage,
      ShortcutIds.nextPage: goToNextPage,
      ShortcutIds.refreshGallery: refreshGallery,
      ShortcutIds.focusSearch: focusSearch,
      ShortcutIds.enterSelectionMode: enterSelectionMode,
      ShortcutIds.openFilterPanel: () => showGalleryFilterPanel(_context()),
      ShortcutIds.clearFilter: clearFilters,
      ShortcutIds.toggleCategoryPanel: toggleCategoryPanel,
      ShortcutIds.jumpToDate: jumpToDate,
      if (PlatformCapabilities.current.supportsOpenFolder)
        ShortcutIds.openFolder: openGalleryFolder,
    };
  }

  static const Duration _refreshDebounce = Duration(milliseconds: 500);
  static const Duration _minimumRefreshInterval = Duration(seconds: 30);

  final WidgetRef _ref;
  final BuildContext Function() _context;
  final bool Function() _mounted;
  final LocalGalleryActionCoordinator _actions;
  final GlobalKey<GroupedGridViewState> groupedGridViewKey;

  /// 窄屏分类抽屉所在 Scaffold 的 key
  ///
  /// 【偏离上游】上游窄屏用 AdaptivePresenter.showPanel 弹底部面板，不需要
  /// Scaffold 句柄；我们保留左侧 Drawer 呈现（用户点名的「左边侧边栏」），
  /// 而触发按钮在工具栏里、context 位于 Scaffold 之上，只能靠 key 打开。
  final GlobalKey<ScaffoldState> categoryDrawerScaffoldKey =
      GlobalKey<ScaffoldState>();

  late final Map<String, VoidCallback> shortcuts;
  final FocusNode shortcutsFocusNode = FocusNode();

  AppLifecycleListener? _lifecycleListener;
  Timer? _refreshDebounceTimer;
  Completer<void>? _refreshCompleter;
  DateTime? _lastRefreshTime;
  bool _showCategoryPanel = true;
  bool _isPackingImages = false;

  bool get showCategoryPanel => _showCategoryPanel;
  bool get isPackingImages => _isPackingImages;

  void start() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPermissionsAndScan();
      await _showFirstTimeTip();
      await autoRefresh();
    });
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        Future<void>.delayed(const Duration(milliseconds: 500), () async {
          if (!_mounted()) return;
          try {
            await autoRefresh();
          } catch (error, stackTrace) {
            AppLogger.e(
              'Auto refresh on resume failed',
              error,
              stackTrace,
              'LocalGalleryScreen',
            );
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _refreshDebounceTimer?.cancel();
    if (_refreshCompleter case final completer? when !completer.isCompleted) {
      completer.complete();
    }
    _lifecycleListener?.dispose();
    shortcutsFocusNode.dispose();
    super.dispose();
  }

  void goToPreviousPage() {
    final state = _ref.read(localGalleryNotifierProvider);
    if (state.currentPage > 0) {
      _ref
          .read(localGalleryNotifierProvider.notifier)
          .loadPage(state.currentPage - 1);
    }
  }

  void goToNextPage() {
    final state = _ref.read(localGalleryNotifierProvider);
    if (state.currentPage < state.totalPages - 1) {
      _ref
          .read(localGalleryNotifierProvider.notifier)
          .loadPage(state.currentPage + 1);
    }
  }

  void refreshGallery() {
    _ref.read(localGalleryNotifierProvider.notifier).refresh();
  }

  void focusSearch() {
    FocusManager.instance.primaryFocus?.unfocus();
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      FocusManager.instance.primaryFocus?.requestFocus();
    });
  }

  void enterSelectionMode() {
    _ref.read(localGallerySelectionNotifierProvider.notifier).enter();
  }

  void clearFilters() {
    _ref.read(localGalleryNotifierProvider.notifier).clearAllFilters();
  }

  void handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || !HardwareKeyboard.instance.isControlPressed) {
      return;
    }
    final bulkState = _ref.read(bulkOperationNotifierProvider);
    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        if (bulkState.canRedo) unawaited(_actions.redo());
      } else if (bulkState.canUndo) {
        unawaited(_actions.undo());
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyY &&
        bulkState.canRedo) {
      unawaited(_actions.redo());
    }
  }

  Future<void> runPacking(Future<void> Function() action) async {
    if (_isPackingImages) {
      AppToast.info(
        _context(),
        _context().l10n.localGallery_packAlreadyInProgress,
      );
      return;
    }
    _isPackingImages = true;
    notifyListeners();
    try {
      await action();
    } finally {
      if (_isPackingImages) {
        _isPackingImages = false;
        notifyListeners();
      }
    }
  }

  Future<void> autoRefresh() {
    _refreshDebounceTimer?.cancel();
    final completer = _refreshCompleter ??= Completer<void>();
    _refreshDebounceTimer = Timer(_refreshDebounce, () async {
      _refreshDebounceTimer = null;
      if (identical(_refreshCompleter, completer)) {
        _refreshCompleter = null;
      }
      try {
        if (!_mounted()) return;
        final router = GoRouter.of(_context());
        final currentPath = router.routeInformationProvider.value.uri.path;
        if (currentPath != '/local-gallery') {
          AppLogger.d(
            '[AutoRefresh] Skipped: not on local gallery page (current: $currentPath)',
            'LocalGalleryScreen',
          );
          return;
        }

        final now = DateTime.now();
        final lastRefreshTime =
            _lastRefreshTime ??
            _ref.read(localGalleryNotifierProvider.notifier).lastSynchronizedAt;
        if (lastRefreshTime != null &&
            now.difference(lastRefreshTime) < _minimumRefreshInterval) {
          AppLogger.d(
            '[AutoRefresh] Skipped: too frequent',
            'LocalGalleryScreen',
          );
          return;
        }
        if (_ref.read(galleryScanProgressProvider).isScanning) {
          AppLogger.d(
            '[AutoRefresh] Skipped: scan in progress',
            'LocalGalleryScreen',
          );
          return;
        }

        _lastRefreshTime = now;
        await _ref
            .read(localGalleryNotifierProvider.notifier)
            .refresh(scan: false);
        await _ref
            .read(galleryCategoryNotifierProvider.notifier)
            .syncWithFileSystem();
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    });
    return completer.future;
  }

  /// 打开窄屏分类面板（相簿 + 分类树）
  ///
  /// 【偏离上游】上游 v4.2.1 这里是 `AdaptivePresenter.showPanel` 弹底部面板
  /// （local_gallery_screen_controller.dart:251-269）。用户点名要保留左侧边栏，
  /// 所以只换承载容器：抽屉里装的仍然是同一个 [buildCategoryPanel]，分类树本身
  /// 没有重建，上游后续对面板内容的改动可以直接吃下。
  void openCategoryDrawer() {
    categoryDrawerScaffoldKey.currentState?.openDrawer();
  }

  /// 关闭窄屏分类抽屉（选中分类/相簿后调用，等价于上游面板里的 maybePop）
  void closeCategoryDrawer() {
    categoryDrawerScaffoldKey.currentState?.closeDrawer();
  }

  Widget buildCategoryPanel({
    required LocalGalleryState galleryState,
    required GalleryCategoryState categoryState,
    required GalleryAlbumState albumState,
    bool modal = false,
    ScrollController? scrollController,
    VoidCallback? afterSelection,
  }) {
    return LocalGalleryCategoryPanel(
      galleryState: galleryState,
      categoryState: categoryState,
      albumState: albumState,
      favoriteCount: _ref
          .read(localGalleryNotifierProvider.notifier)
          .getTotalFavoriteCount(),
      modal: modal,
      scrollController: scrollController,
      afterSelection: afterSelection,
      onCreateCategory: () => unawaited(createCategory()),
      onCategorySelected: (id) => unawaited(handleCategorySelected(id)),
      onCategoryRename: (id, name) => _ref
          .read(galleryCategoryNotifierProvider.notifier)
          .renameCategory(id, name),
      onCategoryDelete: handleCategoryDelete,
      onAddSubCategory: handleAddSubCategory,
      onCategoryMove: (id, parentId) => _ref
          .read(galleryCategoryNotifierProvider.notifier)
          .moveCategory(id, parentId),
      onCategoryMoveToSlot: (id, targetId, slot) => _ref
          .read(librarySidebarMoveServiceProvider)
          .moveFolder(id, targetId, slot),
      onImagesDrop: handleImagesDrop,
      onSyncWithFileSystem: handleSyncWithFileSystem,
      onCreateAlbum: (parentId) => createAlbum(parentId),
      onAlbumSelected: (id) => unawaited(handleAlbumSelected(id)),
      onAlbumRename: (id, newName) => _ref
          .read(galleryAlbumNotifierProvider.notifier)
          .renameAlbum(id, newName),
      onAlbumDeleteRequest: handleAlbumDelete,
      onAddAlbumRequest: (parentId) => createAlbum(parentId),
      onAlbumMove: (id, parentId) => _ref
          .read(galleryAlbumNotifierProvider.notifier)
          .moveAlbum(id, parentId),
      onAlbumMoveToSlot: (id, targetId, slot) => _ref
          .read(librarySidebarMoveServiceProvider)
          .moveAlbum(id, targetId, slot),
      onImagesDropToAlbum: handleImagesDropToAlbum,
      onImagesFavoriteDrop: handleImagesFavoriteDrop,
    );
  }

  Future<void> createAlbum(String? parentId) async {
    final context = _context();
    final name = await ThemedInputDialog.show(
      context: context,
      title: parentId == null
          ? context.l10n.localGallery_createAlbumTitle
          : context.l10n.localGallery_createSubAlbumTitle,
      hintText: context.l10n.localGallery_createAlbumHint,
      confirmText: context.l10n.common_create,
      cancelText: context.l10n.common_cancel,
    );
    if (name == null || name.trim().isEmpty || !_mounted()) return;
    await _ref
        .read(galleryAlbumNotifierProvider.notifier)
        .createAlbum(name, parentId: parentId);
  }

  Future<void> handleAlbumSelected(String? id) async {
    await _ref.read(galleryAlbumNotifierProvider.notifier).selectAlbum(id);
  }

  Future<void> handleAlbumDelete(String albumId) async {
    final context = _context();
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.localGallery_deleteAlbumTitle,
      content: context.l10n.localGallery_deleteAlbumContent,
      confirmText: context.l10n.common_delete,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_outline,
    );
    if (!confirmed || !_mounted()) return;
    await _ref.read(galleryAlbumNotifierProvider.notifier).deleteAlbum(albumId);
  }

  Future<void> handleImagesDropToAlbum(
    List<String> imagePaths,
    String albumId,
  ) async {
    final albums = _ref.read(galleryAlbumNotifierProvider.notifier);
    final owner = _ref.read(localGalleryNotifierProvider.notifier);
    final service = await owner.getService();
    final images = await service.getRecordsByPaths(imagePaths);
    if (images.length != imagePaths.toSet().length) {
      throw StateError('Some dropped gallery images are unavailable');
    }
    final added = await albums.addImagesByPaths(albumId, imagePaths);
    if (!_mounted()) return;
    AppToast.info(
      _context(),
      added > 0
          ? _context().l10n.localGallery_addedToAlbum
          : _context().l10n.localGallery_albumAddFailed,
    );
  }

  void toggleCategoryPanel() {
    final context = _context();
    final availableWidth =
        context.size?.width ?? MediaQuery.sizeOf(context).width;
    if (availableWidth < 1000) {
      openCategoryDrawer();
      return;
    }
    _showCategoryPanel = !_showCategoryPanel;
    notifyListeners();
  }

  Future<void> createCategory() async {
    final context = _context();
    final name = await ThemedInputDialog.show(
      context: context,
      title: context.l10n.localGallery_createCategoryTitle,
      hintText: context.l10n.localGallery_createCategoryHint,
      confirmText: context.l10n.localGallery_createCategoryConfirm,
      cancelText: context.l10n.common_cancel,
    );
    if (name != null && name.isNotEmpty) {
      await _ref
          .read(galleryCategoryNotifierProvider.notifier)
          .createCategory(name, parentId: null);
    }
  }

  Future<void> handleCategorySelected(String? id) async {
    final gallery = _ref.read(localGalleryNotifierProvider.notifier);

    // 分类、收藏与相簿必须同时清理状态和真实过滤条件，避免空相簿
    // 留下不可见的 albumId，导致“全部图片”仍显示空结果。
    await _ref.read(galleryAlbumNotifierProvider.notifier).selectAlbum(null);
    if (!_mounted()) return;

    _ref.read(galleryCategoryNotifierProvider.notifier).selectCategory(id);
    final categoryState = _ref.read(galleryCategoryNotifierProvider);
    final category = id != null ? categoryState.categories.findById(id) : null;
    if (id == 'favorites') {
      await gallery.setShowFavoritesOnly(true);
    } else if (id != null && category != null) {
      await gallery.setShowFavoritesOnly(false);
      await gallery.setSelectedCategory(id, category.folderPath);
    } else {
      await gallery.setShowFavoritesOnly(false);
      await gallery.setSelectedCategory(null, null);
    }
  }

  Future<void> handleCategoryDelete(String id) async {
    final context = _context();
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.common_confirmDelete,
      content: context.l10n.localGallery_categoryDeleteContent,
      confirmText: context.l10n.common_delete,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_outline,
    );
    if (!confirmed || !_mounted()) return;
    final protected = await AssetProtectionGuard.confirmDangerousAction(
      context: _context(),
      ref: _ref,
      title: _context().l10n.localGallery_protectedDeleteCategoryTitle,
      content: _context().l10n.localGallery_protectedDeleteCategoryContent,
      confirmText: _context().l10n.localGallery_confirmDelete,
      icon: Icons.delete_outline,
    );
    if (!protected || !_mounted()) return;
    await _ref
        .read(galleryCategoryNotifierProvider.notifier)
        .deleteCategory(id, deleteFolder: false);
  }

  Future<void> handleAddSubCategory(String? parentId) async {
    final context = _context();
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
      await _ref
          .read(galleryCategoryNotifierProvider.notifier)
          .createCategory(name, parentId: parentId);
    }
  }

  Future<void> handleImagesDrop(List<String> imagePaths, String? categoryId) =>
      _actions.moveImagesToCategory(imagePaths, categoryId);

  Future<void> handleImagesFavoriteDrop(List<String> imagePaths) async {
    final owner = _ref.read(localGalleryNotifierProvider.notifier);
    final service = await owner.getService();
    final images = await service.getRecordsByPaths(imagePaths);
    if (images.length != imagePaths.toSet().length) {
      throw StateError('Some dropped gallery images are unavailable');
    }
    final result = await ImageCardBatchResult.execute(images, (image) async {
      if (image.isFavorite) return;
      if (!await owner.toggleFavorite(image.path)) {
        throw StateError('Unable to favorite image: ${image.path}');
      }
    });
    result.requireComplete();
  }

  Future<void> handleSyncWithFileSystem() async {
    await _ref
        .read(galleryCategoryNotifierProvider.notifier)
        .syncWithFileSystem();
    if (_mounted()) {
      AppToast.success(
        _context(),
        _context().l10n.localGallery_categoriesSynced,
      );
    }
  }

  Future<void> openGalleryFolder() async {
    if (!PlatformCapabilities.current.supportsOpenFolder) return;
    try {
      final rootPath = await GalleryFolderRepository.instance.getRootPath();
      if (rootPath == null || rootPath.isEmpty) {
        if (_mounted()) {
          AppToast.info(
            _context(),
            _context().l10n.localGallery_saveDirectoryNotSet,
          );
        }
        return;
      }
      if (!await Directory(rootPath).exists()) {
        if (_mounted()) {
          AppToast.info(
            _context(),
            _context().l10n.localGallery_folderNotFound,
          );
        }
        return;
      }
      await FileExplorerUtils.openDirectory(rootPath);
    } catch (error) {
      if (_mounted()) {
        AppToast.error(
          _context(),
          _context().l10n.localGallery_openFolderFailed('$error'),
        );
      }
    }
  }

  Future<void> jumpToDate() async {
    final context = _context();
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
    if (picked == null || !_mounted()) return;
    final notifier = _ref.read(localGalleryNotifierProvider.notifier);
    if (!_ref.read(localGalleryNotifierProvider).isGroupedView) {
      await notifier.setGroupedView(true);
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!_mounted()) return;

    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(picked.year, picked.month, picked.day);
    final daysDiff = today.difference(selectedDate).inDays;
    final targetGroup = daysDiff == 0
        ? ImageDateGroup.today
        : daysDiff == 1
        ? ImageDateGroup.yesterday
        : daysDiff < today.weekday
        ? ImageDateGroup.thisWeek
        : ImageDateGroup.earlier;
    groupedGridViewKey.currentState?.scrollToGroup(targetGroup);
    if (_mounted()) {
      final month = picked.month.toString().padLeft(2, '0');
      AppToast.info(
        _context(),
        _context().l10n.localGallery_jumpedToMonth(picked.year, month),
      );
    }
  }

  Future<void> _checkPermissionsAndScan() async {
    final hasPermission = await PermissionUtils.checkGalleryPermission();
    if (!hasPermission) {
      final granted = await PermissionUtils.requestGalleryPermission();
      if (!granted && _mounted()) {
        unawaited(_showPermissionDeniedDialog());
        return;
      }
    }
    if (!_mounted()) return;
    await _ref.read(localGalleryNotifierProvider.notifier).initialize();
    await _ref.read(collectionNotifierProvider.notifier).initialize();
    _showFirstTimeIndexTipIfNeeded();
  }

  void _showFirstTimeIndexTipIfNeeded() {
    final imageCount = _ref
        .read(localGalleryNotifierProvider)
        .firstTimeIndexCount;
    if (imageCount == null || !_mounted()) return;
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (_mounted()) {
        AppToast.info(
          _context(),
          _context().l10n.localGallery_firstIndexHint(imageCount),
        );
      }
    });
  }

  Future<void> _showPermissionDeniedDialog() async {
    final context = _context();
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
    if (hasSeenTip || !_mounted()) return;
    await prefs.setBool(StorageKeys.hasSeenLocalGalleryTip, true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!_mounted()) return;
    await ThemedConfirmDialog.showInfo(
      context: _context(),
      title: _context().l10n.localGallery_firstTimeTipTitle,
      content: _context().l10n.localGallery_firstTimeTipContent,
      confirmText: _context().l10n.localGallery_gotIt,
      icon: Icons.lightbulb_outline,
    );
  }
}
