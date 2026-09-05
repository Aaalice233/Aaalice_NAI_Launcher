import 'dart:async';

import 'package:flutter/material.dart';
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => PopScope<void>(
        canPop: !isSelectionMode,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && isSelectionMode) {
            ref.read(localGallerySelectionNotifierProvider.notifier).exit();
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
    );
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
      body: GalleryCollectionWorkspace(
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

  Widget _buildToolbar(BuildContext context, WidgetRef ref) {
    final bulk = viewModel.bulkOperation;
    // 浏览具体相簿（非全部/收藏）时才提供“移出相簿”入口
    final selectedAlbumId = ref.watch(
      galleryAlbumNotifierProvider.select((value) => value.selectedAlbumId),
    );
    final browsingAlbum =
        selectedAlbumId != null && selectedAlbumId != 'favorites';
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
      onAddToAlbum: actions.addSelectedToAlbum,
      onRemoveFromAlbum: browsingAlbum ? actions.removeSelectedFromAlbum : null,
      onDeleteSelected: actions.deleteSelectedImages,
      onPackSelected: viewModel.isPackingImages
          ? null
          : () => unawaited(controller.runPacking(actions.packSelectedImages)),
      onEditMetadata: actions.editSelectedMetadata,
      onMoveToCategory: actions.moveSelectedToCategory,
      showCategoryPanel: viewModel.showPersistentCategories,
      onToggleCategoryPanel: viewModel.usePersistentCategories
          ? controller.toggleCategoryPanel
          : () => unawaited(controller.showCategoryPanelSheet()),
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
      onReuseMetadata: actions.importImageMetadata,
      onSendAction: (record, action) => actions.routeImageAction(
        LocalGalleryImageAction(record: record, action: action),
      ),
      onContextMenu: actions.showImageContextMenu,
    );
  }
}
