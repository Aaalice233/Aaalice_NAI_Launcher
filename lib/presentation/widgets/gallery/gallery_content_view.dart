import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/gallery_aspect_ratio_cache.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../../data/services/image_metadata_service.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../providers/local_gallery_provider.dart';
import '../../services/local_gallery_deletion.dart';
import '../../providers/selection_mode_provider.dart';
import '../../widgets/grouped_grid_view.dart';
import '../../utils/image_detail_opener.dart';
import 'local_image_card_3d.dart';
import '../common/image_detail/image_detail_viewer.dart';
import '../common/image_detail/image_detail_data.dart';
import '../common/shimmer_skeleton.dart';
import 'gallery_grid.dart';
import 'gallery_state_views.dart';
import 'grouped_gallery_card.dart';
import '../common/image_card_action.dart';
import 'local_image_context_menu.dart';

/// 通用画廊状态接口
abstract class GalleryState<T> {
  List<T> get currentImages;
  List<LocalImageRecord> get groupedImages;
  bool get isGroupedView;
  bool get isPageLoading;
  bool get isGroupedLoading;
  bool get hasFilters;
  List<T> get filteredFiles;
}

/// 通用选择状态接口
abstract class SelectionState {
  bool get isActive;
  Set<String> get selectedIds;
}

/// 画廊内容视图（含分组/3D/瀑布流切换）- 泛型版本
class GenericGalleryContentView<T> extends ConsumerStatefulWidget {
  final int columns;
  final double itemWidth;
  final GalleryState<T> state;
  final SelectionState selectionState;
  final String Function(T item) idExtractor;
  final void Function(T item, int index)? onTap;
  final void Function(T item, int index)? onDoubleTap;
  final void Function(T item, int index)? onLongPress;
  final void Function(T item, Offset position)? onContextMenu;
  final void Function(T item)? onFavoriteToggle;
  final void Function(T item)? onSelectionToggle;
  final void Function(T item)? onEnterSelection;
  final VoidCallback? onClearFilters;
  final GlobalKey<GroupedGridViewState>? groupedGridViewKey;
  final Gallery3DViewConfig<T>? view3DConfig;
  final Future<void> Function(
    LocalImageRecord record,
    LocalImageContextAction action,
  )?
  onSendAction;
  final bool isKritaConnected;
  final String? emptyTitle;
  final String? emptySubtitle;
  final IconData? emptyIcon;

  /// 当前是否在某个普通相簿里浏览；传给卡片决定右键菜单是否显示「移出相簿」
  final bool inAlbum;

  const GenericGalleryContentView({
    super.key,
    required this.columns,
    required this.itemWidth,
    required this.state,
    required this.selectionState,
    required this.idExtractor,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onContextMenu,
    this.onFavoriteToggle,
    this.onSelectionToggle,
    this.onEnterSelection,
    this.onClearFilters,
    this.groupedGridViewKey,
    this.view3DConfig,
    this.onSendAction,
    this.isKritaConnected = false,
    this.emptyTitle,
    this.emptySubtitle,
    this.emptyIcon,
    this.inAlbum = false,
  });

  @override
  ConsumerState<GenericGalleryContentView<T>> createState() =>
      _GenericGalleryContentViewState<T>();
}

/// 3D视图配置
class Gallery3DViewConfig<T> {
  final List<T> images;
  final void Function(List<T> images, int initialIndex) showDetailViewer;

  const Gallery3DViewConfig({
    required this.images,
    required this.showDetailViewer,
  });
}

class _GenericGalleryContentViewState<T>
    extends ConsumerState<GenericGalleryContentView<T>>
    with TickerProviderStateMixin {
  final GalleryAspectRatioCache _aspectRatios = GalleryAspectRatioCache();
  bool _showSkeleton = false;
  late final AnimationController _emptyStateController;
  late final Animation<double> _emptyStateAnimation;
  bool _motionPreferenceInitialized = false;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _initSkeletonDelay();
    _initEmptyStateAnimation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_motionPreferenceInitialized &&
        _disableAnimations == disableAnimations) {
      return;
    }
    final isFirstUpdate = !_motionPreferenceInitialized;
    _motionPreferenceInitialized = true;
    _disableAnimations = disableAnimations;
    if (disableAnimations) {
      _emptyStateController.stop();
      _emptyStateController.value = 1;
    } else if (isFirstUpdate) {
      _emptyStateController.forward();
    }
  }

  @override
  void didUpdateWidget(GenericGalleryContentView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.isPageLoading && !widget.state.isPageLoading) {
      _showSkeleton = false;
    }
    if (!oldWidget.state.isPageLoading && widget.state.isPageLoading) {
      _initSkeletonDelay();
    }
  }

  @override
  void dispose() {
    _emptyStateController.dispose();
    super.dispose();
  }

  void _initEmptyStateAnimation() {
    _emptyStateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _emptyStateAnimation = CurvedAnimation(
      parent: _emptyStateController,
      curve: Curves.easeOut,
    );
  }

  void _initSkeletonDelay() {
    _showSkeleton = false;
    if (widget.state.isPageLoading) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && widget.state.isPageLoading) {
          setState(() => _showSkeleton = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.state.isGroupedView) {
      return _buildGroupedView(widget.state, widget.selectionState, theme);
    }

    if (widget.state.filteredFiles.isEmpty && widget.state.hasFilters) {
      return _buildAnimatedEmptyState(
        GalleryNoResultsView(
          onClearFilters: widget.onClearFilters,
          title: widget.emptyTitle,
          subtitle: widget.emptySubtitle,
          icon: widget.emptyIcon,
        ),
      );
    }

    if (widget.state.isPageLoading && _showSkeleton) {
      return _buildLoadingSkeleton();
    }

    return _buildGalleryGrid(widget.state, widget.selectionState);
  }

  Widget _buildAnimatedEmptyState(Widget child) {
    if (_disableAnimations) return child;
    return FadeTransition(
      opacity: _emptyStateAnimation,
      child: AnimatedBuilder(
        animation: _emptyStateAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 20 * (1 - _emptyStateAnimation.value)),
            child: child,
          );
        },
        child: child,
      ),
    );
  }

  Widget _buildGroupedView(
    GalleryState<T> state,
    SelectionState selectionState,
    ThemeData theme,
  ) {
    if (state.isGroupedLoading) {
      return _buildGroupedLoadingSkeleton();
    }

    if (state.groupedImages.isEmpty) {
      return _buildAnimatedEmptyState(
        GalleryNoResultsView(onClearFilters: widget.onClearFilters),
      );
    }

    return GroupedGridView(
      key: widget.groupedGridViewKey,
      images: state.groupedImages,
      columns: widget.columns,
      itemWidth: widget.itemWidth,
      buildCard: (record) => GroupedGalleryCard(
        key: ValueKey(record.path),
        record: record,
        aspectRatios: _aspectRatios,
        builder: (context, aspectRatio) => LocalImageCard3D(
          record: record,
          width: widget.itemWidth,
          height: widget.itemWidth / aspectRatio,
          isSelected: selectionState.selectedIds.contains(record.path),
          onTap: () {
            if (selectionState.isActive) {
              widget.onSelectionToggle?.call(record as T);
            }
          },
          onLongPress: () {
            if (!selectionState.isActive) {
              widget.onEnterSelection?.call(record as T);
            }
          },
          onSecondaryTapUp: widget.onContextMenu != null
              ? (details) =>
                    widget.onContextMenu!(record as T, details.globalPosition)
              : null,
          onFavoriteToggle: () {
            widget.onFavoriteToggle?.call(record as T);
          },
          onSendAction: widget.onSendAction != null
              ? (action) => widget.onSendAction!(record, action)
              : null,
          enableAddToAgent: !selectionState.isActive,
          isKritaConnected: widget.isKritaConnected,
          inAlbum: widget.inAlbum,
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return AnimatedOpacity(
      opacity: _showSkeleton ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: GridView.builder(
        key: const PageStorageKey<String>('gallery_grid_loading'),
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: widget.state.currentImages.isNotEmpty
            ? widget.state.currentImages.length
            : 20,
        itemBuilder: (_, __) => const Card(
          clipBehavior: Clip.antiAlias,
          child: ShimmerSkeleton(height: 250),
        ),
      ),
    );
  }

  Widget _buildGroupedLoadingSkeleton() {
    return const GalleryGroupedLoadingView();
  }

  Widget _buildGalleryGrid(
    GalleryState<T> state,
    SelectionState selectionState,
  ) {
    final selectedIndices = <int>{};
    for (int i = 0; i < state.currentImages.length; i++) {
      if (selectionState.selectedIds.contains(
        widget.idExtractor(state.currentImages[i]),
      )) {
        selectedIndices.add(i);
      }
    }

    return GalleryGrid(
      key: const PageStorageKey<String>('gallery_grid'),
      images: _convertToLocalImageRecords(state.currentImages),
      columns: widget.columns,
      spacing: 12,
      padding: const EdgeInsets.all(12),
      selectedIndices: selectionState.isActive ? selectedIndices : null,
      enableDrag: !selectionState.isActive,
      onTap: (record, index) {
        if (selectionState.isActive) {
          widget.onSelectionToggle?.call(state.currentImages[index]);
          return;
        }
        if (widget.onTap != null) {
          widget.onTap!(state.currentImages[index], index);
        } else if (widget.view3DConfig != null) {
          widget.view3DConfig!.showDetailViewer(
            widget.view3DConfig!.images,
            index,
          );
        }
      },
      onDoubleTap: widget.onDoubleTap == null
          ? null
          : (record, index) {
              widget.onDoubleTap!(state.currentImages[index], index);
            },
      onLongPress: (record, index) {
        if (!selectionState.isActive) {
          widget.onEnterSelection?.call(state.currentImages[index]);
        } else {
          widget.onLongPress?.call(state.currentImages[index], index);
        }
      },
      onSecondaryTapUp: (record, index, details) {
        widget.onContextMenu?.call(
          state.currentImages[index],
          details.globalPosition,
        );
      },
      onFavoriteToggle: (record, index) {
        widget.onFavoriteToggle?.call(state.currentImages[index]);
      },
      onSendAction: widget.onSendAction != null
          ? (record, index, action) => widget.onSendAction!(record, action)
          : null,
      isKritaConnected: widget.isKritaConnected,
      inAlbum: widget.inAlbum,
    );
  }

  List<LocalImageRecord> _convertToLocalImageRecords(List<T> items) {
    // ignore: avoid_as
    return items as List<LocalImageRecord>;
  }
}

/// 本地画廊状态适配器
class _LocalGalleryStateAdapter implements GalleryState<LocalImageRecord> {
  final LocalGalleryState _state;

  _LocalGalleryStateAdapter(this._state);

  @override
  List<LocalImageRecord> get currentImages => _state.currentImages;

  @override
  List<LocalImageRecord> get groupedImages => _state.groupedImages;

  @override
  bool get isGroupedView => _state.isGroupedView;

  @override
  bool get isPageLoading => _state.isPageLoading;

  @override
  bool get isGroupedLoading => _state.isGroupedLoading;

  @override
  bool get hasFilters => _state.filterCriteria.hasClearableFilters;

  @override
  List<LocalImageRecord> get filteredFiles =>
      _state.hasFilters ? _state.currentImages : const [];
}

/// 本地选择状态适配器
class _LocalSelectionStateAdapter implements SelectionState {
  final SelectionModeState _state;

  _LocalSelectionStateAdapter(this._state);

  @override
  bool get isActive => _state.isActive;

  @override
  Set<String> get selectedIds => _state.selectedIds;
}

// 大图查看器里的右键菜单：这些操作会离开画廊页
const _leavesGallery = {
  LocalImageContextAction.sendToTextToImage,
  LocalImageContextAction.importMetadata,
  LocalImageContextAction.sendToImg2Img,
  LocalImageContextAction.sendToReversePrompt,
  LocalImageContextAction.sendToStyleTransfer,
  LocalImageContextAction.sendToPreciseReference,
  LocalImageContextAction.upscale,
};

// 这些操作会移动或删除文件，查看器里的图片列表不会跟着更新，所以右键菜单不提供
const _hiddenInViewer = {ImageCardActionId.classify, ImageCardActionId.delete};

/// 本地画廊内容视图
class LocalGalleryContentView extends ConsumerWidget {
  final int columns;
  final double itemWidth;
  final void Function(LocalImageRecord record)? onReuseMetadata;
  final Future<GalleryImageDeleteResult> Function(LocalImageRecord record)?
  onDelete;
  final void Function(LocalImageRecord record, Offset position)? onContextMenu;
  final Future<void> Function(
    LocalImageRecord record,
    LocalImageContextAction action, {
    VoidCallback? onSent,
  })?
  onSendAction;
  final GlobalKey<GroupedGridViewState>? groupedGridViewKey;
  final bool inAlbum;

  const LocalGalleryContentView({
    super.key,
    required this.columns,
    required this.itemWidth,
    this.onReuseMetadata,
    this.onDelete,
    this.onContextMenu,
    this.onSendAction,
    this.groupedGridViewKey,
    this.inAlbum = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localGalleryNotifierProvider);
    final selectionState = ref.watch(localGallerySelectionNotifierProvider);
    final isKritaConnected =
        PlatformCapabilities.current.supportsKritaBridge &&
        ref.watch(
          kritaBridgeNotifierProvider.select(
            (state) => state.status == KritaBridgeStatus.connected,
          ),
        );

    void showImageDetailViewer(
      List<LocalImageRecord> images,
      int initialIndex,
    ) {
      final container = ProviderScope.containerOf(context, listen: false);
      final gallery = container.read(localGalleryNotifierProvider.notifier);
      final l10n = context.l10n;
      var pageNumber = state.currentPage;
      bool getFavoriteStatus(String path) {
        final providerState = container.read(localGalleryNotifierProvider);
        final image = providerState.currentImages
            .cast<LocalImageRecord?>()
            .firstWhere((img) => img?.path == path, orElse: () => null);
        return image?.isFavorite ?? false;
      }

      final metadataService = ref.read(imageMetadataServiceProvider);
      LocalImageDetailData detailFor(LocalImageRecord record) =>
          LocalImageDetailData(
            record,
            getFavoriteStatus: getFavoriteStatus,
            metadataService: metadataService,
          );
      Future<ImageDetailDeleteResult> pageAfterDelete() async {
        final page = await gallery.settledPage();
        if (page.pageNeedsRetry) {
          return ImageDetailDeletePageError(
            l10n.localGallery_loadFailed(
              page.error?.localized(l10n) ?? l10n.localGallery_unknownError,
            ),
            retry: () async {
              await gallery.loadPage(page.currentPage);
              return pageAfterDelete();
            },
          );
        }
        final previousPage = page.currentPage < pageNumber;
        pageNumber = page.currentPage;
        return ImageDetailDeletePage(
          page.currentImages.map(detailFor).toList(),
          previousPage: previousPage,
        );
      }

      // 查看器翻到头尾时换成相邻一页；画廊列表同步翻页，关掉查看器后停在同一页
      Future<List<ImageDetailData>?> loadAdjacentPage(bool forward) async {
        final notifier = container.read(localGalleryNotifierProvider.notifier);
        final before = container.read(localGalleryNotifierProvider).currentPage;
        await (forward ? notifier.loadNextPage() : notifier.loadPreviousPage());
        final after = container.read(localGalleryNotifierProvider);
        return after.currentPage == before
            ? null
            : after.currentImages.map(detailFor).toList();
      }

      bool hasAdjacentPage(bool forward) {
        final galleryState = container.read(localGalleryNotifierProvider);
        return !galleryState.isGroupedView &&
            !(forward ? galleryState.isLastPage : galleryState.isFirstPage);
      }

      final send = onSendAction;
      ImageDetailOpener.showMultipleImmediate(
        context,
        images: images.map(detailFor).toList(),
        initialIndex: initialIndex,
        showMetadataPanel: true,
        showThumbnails: images.length > 1,
        pageNavigator: ImageDetailPageNavigator(
          hasMore: hasAdjacentPage,
          load: loadAdjacentPage,
        ),
        callbacks: ImageDetailCallbacks(
          onDelete: onDelete == null
              ? null
              : (data) async {
                  final result = await onDelete!(
                    (data as LocalImageDetailData).record,
                  );
                  if (!result.fileIsGone) return null;
                  return pageAfterDelete();
                },
          onAddToAlbum: send == null
              ? null
              : (data) => send(
                  (data as LocalImageDetailData).record,
                  LocalImageContextAction.addToAlbum,
                ),
          contextMenuActions: send == null
              ? null
              : (menuContext, data) {
                  final record = (data as LocalImageDetailData).record;
                  final metadata = record.metadata;
                  return LocalImageContextMenu.buildActions(
                        menuContext,
                        onAction: (action) async {
                          // 这些操作会离开画廊（跳到生成页），先关掉查看器
                          if (_leavesGallery.contains(action) &&
                              menuContext.mounted) {
                            Navigator.of(menuContext).pop();
                          }
                          await send(record, action);
                        },
                        hasImportableMetadata: metadata?.hasData == true,
                        hasPrompt: metadata?.prompt.isNotEmpty == true,
                        hasSeed: metadata?.seed != null,
                        isKritaConnected: isKritaConnected,
                      )
                      .where((action) => !_hiddenInViewer.contains(action.id))
                      .toList();
                },
          onReuseMetadata: onReuseMetadata != null
              ? (data) async =>
                    onReuseMetadata?.call((data as LocalImageDetailData).record)
              : null,
          onFavoriteToggle: (data) => container
              .read(localGalleryNotifierProvider.notifier)
              .toggleFavorite((data as LocalImageDetailData).record.path),
          onSendToImg2Img: send == null
              ? null
              : (data, closeViewer) => send(
                  (data as LocalImageDetailData).record,
                  LocalImageContextAction.sendToImg2Img,
                  onSent: closeViewer,
                ),
          onSendToReversePrompt: send == null
              ? null
              : (data, closeViewer) => send(
                  (data as LocalImageDetailData).record,
                  LocalImageContextAction.sendToReversePrompt,
                  onSent: closeViewer,
                ),
        ),
      );
    }

    return GenericGalleryContentView<LocalImageRecord>(
      columns: columns,
      itemWidth: itemWidth,
      state: _LocalGalleryStateAdapter(state),
      selectionState: _LocalSelectionStateAdapter(selectionState),
      idExtractor: (record) => record.path,
      onSelectionToggle: (record) => ref
          .read(localGallerySelectionNotifierProvider.notifier)
          .toggle(record.path),
      onEnterSelection: (record) => ref
          .read(localGallerySelectionNotifierProvider.notifier)
          .enterAndSelect(record.path),
      onFavoriteToggle: (record) => ref
          .read(localGalleryNotifierProvider.notifier)
          .toggleFavorite(record.path),
      onContextMenu: onContextMenu,
      onClearFilters: () => ref
          .read(localGalleryNotifierProvider.notifier)
          .clearFiltersWithinScope(),
      groupedGridViewKey: groupedGridViewKey,
      view3DConfig: Gallery3DViewConfig<LocalImageRecord>(
        images: state.currentImages,
        showDetailViewer: showImageDetailViewer,
      ),
      onSendAction: onSendAction,
      isKritaConnected: isKritaConnected,
      inAlbum: inAlbum,
    );
  }
}
