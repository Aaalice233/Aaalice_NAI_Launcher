import '../../widgets/common/image_card_action.dart';
import '../../widgets/common/image_card_batch_scope.dart';
import '../../selection/card_selection_scope.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/storage_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/local_gallery_thumbnail_provider.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../core/utils/localization_extension.dart';
import '../../providers/bulk_operation_provider.dart';
import '../../providers/gallery_album_provider.dart';
import '../../providers/gallery_category_provider.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../widgets/app_branch_visibility.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/pagination_bar.dart';
import '../../widgets/gallery/gallery_content_view.dart';
import '../../widgets/gallery/gallery_sidebar.dart';
import '../../widgets/gallery/gallery_state_views.dart';
import '../../widgets/gallery/local_gallery_toolbar.dart';
import '../../widgets/grouped_grid_view.dart' show GroupedGridViewState;
import '../../widgets/shortcuts/shortcut_aware_widget.dart';
import 'local_gallery_action_coordinator.dart';
import 'local_gallery_screen_controller.dart';
import 'local_gallery_view_model.dart';

/// Stable shell for the local gallery route.
class LocalGalleryScreen extends ConsumerStatefulWidget {
  const LocalGalleryScreen({super.key});

  @override
  ConsumerState<LocalGalleryScreen> createState() => _LocalGalleryScreenState();
}

class _LocalGalleryScreenState extends ConsumerState<LocalGalleryScreen> {
  final GlobalKey<GroupedGridViewState> _groupedGridViewKey =
      GlobalKey<GroupedGridViewState>();
  late final LocalGalleryActionCoordinator _actions;
  late final LocalGalleryScreenController _controller;
  bool? _branchVisible;

  @override
  void initState() {
    super.initState();
    _actions = LocalGalleryActionCoordinator(
      ref: ref,
      context: () => context,
      mounted: () => mounted,
    );
    _controller = LocalGalleryScreenController(
      ref: ref,
      context: () => context,
      mounted: () => mounted,
      groupedGridViewKey: _groupedGridViewKey,
      actions: _actions,
    )..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = AppBranchVisibility.of(context);
    if (_branchVisible == visible) return;
    _branchVisible = visible;
    LocalGalleryThumbnailProvider.setGalleryVisible(visible);
  }

  @override
  void dispose() {
    LocalGalleryThumbnailProvider.setGalleryVisible(false);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final galleryState = ref.watch(localGalleryNotifierProvider);
    ref.listen(localGalleryNotifierProvider.select((s) => s.filterCriteria), (
      _,
      _,
    ) {
      ref.read(localGallerySelectionNotifierProvider.notifier).exit();
    });
    final bulkOperation = ref.watch(bulkOperationNotifierProvider);
    final categoryState = ref.watch(galleryCategoryNotifierProvider);
    final isSelectionMode = ref.watch(
      localGallerySelectionNotifierProvider.select((value) => value.isActive),
    );
    ref.listen(galleryCategoryNotifierProvider.select((value) => value.error), (
      previous,
      error,
    ) {
      if (error == null) return;
      AppToast.error(context, error.localized(context.l10n));
      ref.read(galleryCategoryNotifierProvider.notifier).clearError();
    });

    final selection = ref.watch(localGallerySelectionNotifierProvider);
    final albumId = ref.watch(
      galleryAlbumNotifierProvider.select((s) => s.selectedAlbumId),
    );
    return ImageCardBatchScope(
      targetIds: selection.selectedIds,
      actions: _buildBatchActions(selection.selectedIds, albumId),
      child: CardSelectionScope(
        selection: ref.watch(localGallerySelectionNotifierProvider),
        commands: ref.read(localGallerySelectionNotifierProvider.notifier),
        orderedIds:
            (galleryState.isGroupedView
                    ? galleryState.groupedImages
                    : galleryState.currentImages)
                .map((e) => e.path)
                .toList(),
        child: CardSelectionShortcuts(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => PopScope<void>(
              canPop: !isSelectionMode,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && isSelectionMode) {
                  ref
                      .read(localGallerySelectionNotifierProvider.notifier)
                      .exit();
                }
              },
              child: PageShortcuts(
                contextType: ShortcutContext.gallery,
                shortcuts: _controller.shortcuts,
                child: KeyboardListener(
                  focusNode: _controller.shortcutsFocusNode,
                  autofocus: true,
                  onKeyEvent: _controller.handleKeyEvent,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final viewModel = LocalGalleryViewModel.fromStates(
                        gallery: galleryState,
                        bulkOperation: bulkOperation,
                        categories: categoryState,
                        isSelectionMode: isSelectionMode,
                        categoryPanelRequested: _controller.showCategoryPanel,
                        isPackingImages: _controller.isPackingImages,
                        maxWidth: constraints.maxWidth,
                      );
                      return _LocalGalleryShell(
                        viewModel: viewModel,
                        controller: _controller,
                        actions: _actions,
                        groupedGridViewKey: _groupedGridViewKey,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<ImageCardAction> _buildBatchActions(Set<String> ids, String? albumId) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return [
      ImageCardAction(
        id: ImageCardActionId.classify,
        supportsBatch: true,
        icon: Icons.drive_file_move_outline,
        label: l10n.localGallery_moveSelected,
        invoke: () => _actions.moveSelectedToCategory(ids),
        iconColor: theme.colorScheme.secondary,
      ),
      ImageCardAction(
        id: ImageCardActionId.export,
        isLoading: _controller.isPackingImages,
        supportsBatch: true,
        icon: Icons.archive_outlined,
        label: l10n.localGallery_packSelected,
        invoke: () =>
            _controller.runPacking(() => _actions.packSelectedImages(ids)),
        iconColor: theme.colorScheme.tertiary,
      ),
      ImageCardAction(
        id: ImageCardActionId.edit,
        supportsBatch: true,
        icon: Icons.edit_outlined,
        label: l10n.localGallery_editMetadata,
        invoke: () => _actions.editSelectedMetadata(ids),
        iconColor: theme.colorScheme.primary,
      ),
      ImageCardAction(
        id: ImageCardActionId.addToAlbum,
        supportsBatch: true,
        icon: Icons.playlist_add,
        label: l10n.localGallery_addToAlbum,
        invoke: () => _actions.addSelectedToAlbum(ids),
        iconColor: theme.colorScheme.secondary,
      ),
      if (albumId != null && albumId != 'favorites')
        ImageCardAction(
          id: ImageCardActionId.removeFromAlbum,
          supportsBatch: true,
          icon: Icons.playlist_remove,
          label: l10n.localGallery_removeFromAlbum,
          invoke: () => _actions.removeSelectedFromAlbum(ids, albumId),
          iconColor: theme.colorScheme.secondary,
        ),
      ImageCardAction(
        id: ImageCardActionId.delete,
        supportsBatch: true,
        icon: Icons.delete_outline,
        label: l10n.common_delete,
        invoke: () => _actions.deleteSelectedImages(ids),
        iconColor: theme.colorScheme.error,
        isDanger: true,
      ),
    ];
  }
}

class _LocalGalleryShell extends ConsumerWidget {
  const _LocalGalleryShell({
    required this.viewModel,
    required this.controller,
    required this.actions,
    required this.groupedGridViewKey,
  });

  final LocalGalleryViewModel viewModel;
  final LocalGalleryScreenController controller;
  final LocalGalleryActionCoordinator actions;
  final GlobalKey<GroupedGridViewState> groupedGridViewKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gallery = viewModel.gallery;
    return Scaffold(
      key: controller.categoryDrawerScaffoldKey,
      // 【偏离上游】上游窄屏把分类树塞进 AdaptivePresenter 的底部弹面板，
      // 这里改成左侧 Drawer 承载同一个 buildCategoryPanel（用户点名的
      // 「左边侧边栏」）。宽屏有常驻侧栏时不挂 drawer，避免多一个入口。
      drawer: viewModel.usePersistentCategories ? null : _buildCategoryDrawer(),
      // 画廊卡片本身有横向滑动手势，边缘拖拽会和它抢触点，所以只允许按钮打开
      drawerEnableOpenDragGesture: false,
      body: GalleryCollectionWorkspace(
        sidebarWidthKey: StorageKeys.localGallerySidebarWidth,
        toolbar: _buildToolbar(context, ref),
        sidebar: viewModel.showPersistentCategories
            ? controller.buildCategoryPanel(
                galleryState: gallery,
                categoryState: viewModel.categories,
                albumState: ref.watch(galleryAlbumNotifierProvider),
              )
            : null,
        body: _buildBody(context, ref),
        footer:
            !gallery.isIndexing &&
                gallery.currentImages.isNotEmpty &&
                gallery.totalPages > 0
            ? PaginationBar(
                currentPage: gallery.currentPage,
                totalPages: gallery.totalPages,
                totalItems: gallery.filteredCount,
                itemsPerPage: gallery.pageSize,
                onPageChanged: (page) => ref
                    .read(localGalleryNotifierProvider.notifier)
                    .loadPage(page),
                onItemsPerPageChanged: (size) => ref
                    .read(localGalleryNotifierProvider.notifier)
                    .setPageSize(size),
                showItemsPerPage: true,
                showTotalInfo: true,
                compact: viewModel.contentWidth < 680,
                tonalCard: true,
              )
            : null,
      ),
    );
  }

  /// 窄屏分类抽屉：内容与常驻侧栏、上游底部面板完全同源
  Widget _buildCategoryDrawer() {
    return Drawer(
      key: const Key('local-gallery-category-drawer'),
      width: 290,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 上游的底部弹面板自带标题（showPanel 的 title 参数），换成抽屉后
            // 不补一个标题头就是退化——抽屉滑出来只有一棵光秃秃的分类树。
            // 沿用上游同一条 localGallery_categoryPanelTitle。
            Builder(
              builder: (headerContext) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        headerContext.l10n.localGallery_categoryPanelTitle,
                        style: Theme.of(headerContext).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: headerContext.l10n.common_close,
                      onPressed: controller.closeCategoryDrawer,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Consumer(
                builder: (context, drawerRef, _) =>
                    controller.buildCategoryPanel(
                      galleryState: drawerRef.watch(
                        localGalleryNotifierProvider,
                      ),
                      categoryState: drawerRef.watch(
                        galleryCategoryNotifierProvider,
                      ),
                      albumState: drawerRef.watch(galleryAlbumNotifierProvider),
                      modal: true,
                      afterSelection: controller.closeCategoryDrawer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, WidgetRef ref) {
    final bulk = viewModel.bulkOperation;
    return LocalGalleryToolbar(
      showPageTitle: true,
      onRefresh: () =>
          ref.read(localGalleryNotifierProvider.notifier).refresh(),
      onEnterSelectionMode: () =>
          ref.read(localGallerySelectionNotifierProvider.notifier).enter(),
      canUndo: bulk.canUndo,
      canRedo: bulk.canRedo,
      onUndo: bulk.canUndo ? actions.undo : null,
      onRedo: bulk.canRedo ? actions.redo : null,
      groupedGridViewKey: groupedGridViewKey,
      showCategoryPanel: viewModel.showPersistentCategories,
      onToggleCategoryPanel: viewModel.usePersistentCategories
          ? controller.toggleCategoryPanel
          : controller.openCategoryDrawer,
      onOpenFolder: PlatformCapabilities.current.supportsOpenFolder
          ? controller.openGalleryFolder
          : null,
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    final gallery = viewModel.gallery;
    if (gallery.error != null) {
      return GalleryErrorView(
        error: gallery.error!.localized(context.l10n),
        onRetry: () =>
            ref.read(localGalleryNotifierProvider.notifier).refresh(),
      );
    }
    if (gallery.isLoading && gallery.currentImages.isEmpty) {
      return const GalleryLoadingView();
    }
    if (gallery.currentImages.isEmpty) {
      return gallery.hasFilters
          ? const GalleryNoResultsView()
          : const GalleryEmptyView();
    }

    return LocalGalleryContentView(
      use3DCardView: true,
      columns: viewModel.columns,
      itemWidth: viewModel.itemWidth,
      groupedGridViewKey: groupedGridViewKey,
      // 【偏离上游】这条回调只喂全屏查看器（LocalGalleryContentView 内部
      // 只把它挂到 ImageDetailCallbacks.onReuseMetadata），所以走
      // 「只弹 toast、不跳生成页」的查看器专用入口；列表卡片右键菜单的
      // 「复用参数」走下面的 onSendAction → routeImageAction，仍是上游默认跳转。
      onReuseMetadata: actions.importImageMetadataFromViewer,
      onSendAction: (record, action) => actions.routeImageAction(
        LocalGalleryImageAction(record: record, action: action),
      ),
      onContextMenu: actions.showImageContextMenu,
    );
  }
}
