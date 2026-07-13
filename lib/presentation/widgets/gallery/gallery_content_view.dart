import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/reverse_prompt_provider.dart';
import '../../router/app_router.dart';
import '../../services/image_workflow_launcher.dart';
import '../../providers/selection_mode_provider.dart';
import '../common/app_toast.dart';
import '../../widgets/grouped_grid_view.dart';
import '../../utils/image_detail_opener.dart';
import 'local_image_card_3d.dart';
import '../common/image_detail/image_detail_viewer.dart';
import '../common/image_detail/image_detail_data.dart';
import '../common/shimmer_skeleton.dart';
import 'gallery_grid.dart';
import 'gallery_state_views.dart';

/// 画廊项目构建函数类型
typedef GalleryItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  int index,
  GalleryItemConfig config,
);

/// 画廊项目配置
class GalleryItemConfig {
  final bool selectionMode;
  final bool isSelected;
  final double itemWidth;
  final double aspectRatio;
  final bool isVisible;
  final VoidCallback? onTap;
  final VoidCallback? onSelectionToggle;
  final VoidCallback? onLongPress;

  const GalleryItemConfig({
    required this.selectionMode,
    required this.isSelected,
    required this.itemWidth,
    required this.aspectRatio,
    this.isVisible = false,
    this.onTap,
    this.onSelectionToggle,
    this.onLongPress,
  });
}

/// 通用画廊状态接口
abstract class GalleryState<T> {
  List<T> get currentImages;
  List<LocalImageRecord> get groupedImages;
  bool get isGroupedView;
  bool get isPageLoading;
  bool get isGroupedLoading;
  int get currentPage;
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
  final bool use3DCardView;
  final int columns;
  final double itemWidth;
  final GalleryState<T> state;
  final SelectionState selectionState;
  final GalleryItemBuilder<T> itemBuilder;
  final String Function(T item) idExtractor;
  final void Function(T item, int index)? onTap;
  final void Function(T item, int index)? onDoubleTap;
  final void Function(T item, int index)? onLongPress;
  final void Function(T item, Offset position)? onContextMenu;
  final void Function(T item)? onFavoriteToggle;
  final void Function(T item)? onSelectionToggle;
  final void Function(T item)? onEnterSelection;
  final VoidCallback? onDeleted;
  final VoidCallback? onClearFilters;
  final VoidCallback? onRefresh;
  final void Function(int page)? onLoadPage;
  final GlobalKey<GroupedGridViewState>? groupedGridViewKey;
  final Gallery3DViewConfig<T>? view3DConfig;
  final void Function(LocalImageRecord record)? onSendToHome;
  final void Function(LocalImageRecord record)? onSendToImg2Img;
  final String? emptyTitle;
  final String? emptySubtitle;
  final IconData? emptyIcon;

  const GenericGalleryContentView({
    super.key,
    this.use3DCardView = true,
    required this.columns,
    required this.itemWidth,
    required this.state,
    required this.selectionState,
    required this.itemBuilder,
    required this.idExtractor,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onContextMenu,
    this.onFavoriteToggle,
    this.onSelectionToggle,
    this.onEnterSelection,
    this.onDeleted,
    this.onClearFilters,
    this.onRefresh,
    this.onLoadPage,
    this.groupedGridViewKey,
    this.view3DConfig,
    this.onSendToHome,
    this.onSendToImg2Img,
    this.emptyTitle,
    this.emptySubtitle,
    this.emptyIcon,
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
  final Map<String, double> _aspectRatioCache = {};
  bool _showSkeleton = false;
  final Set<int> _visibleIndices = {};
  late final AnimationController _emptyStateController;
  late final Animation<double> _emptyStateAnimation;

  @override
  void initState() {
    super.initState();
    _initSkeletonDelay();
    _initEmptyStateAnimation();
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
    _emptyStateController.forward();
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
      buildCard: (record) {
        final isSelected = selectionState.selectedIds.contains(record.path);
        final aspectRatio = _getCachedAspectRatio(record);
        final index = state.groupedImages.indexOf(record);
        final isVisible = _visibleIndices.contains(index);

        return VisibilityDetector(
          key: ValueKey('grouped_visibility_${record.path}_$index'),
          onVisibilityChanged: (visibilityInfo) {
            final isNowVisible = visibilityInfo.visibleFraction > 0.05;
            final wasVisible = _visibleIndices.contains(index);

            if (isNowVisible != wasVisible && mounted) {
              setState(() {
                if (isNowVisible) {
                  _visibleIndices.add(index);
                } else {
                  _visibleIndices.remove(index);
                }
              });
            }
          },
          child: LocalImageCard3D(
            record: record,
            width: widget.itemWidth,
            height: widget.itemWidth / aspectRatio,
            isSelected: isSelected,
            isVisible: isVisible,
            priority: isVisible ? 1 : 5,
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
            onSecondaryTapDown: widget.onContextMenu != null
                ? (details) =>
                      widget.onContextMenu!(record as T, details.globalPosition)
                : null,
            onFavoriteToggle: () {
              widget.onFavoriteToggle?.call(record as T);
            },
            onSendToHome: widget.onSendToHome != null
                ? () => widget.onSendToHome!(record)
                : null,
            onSendToImg2Img: widget.onSendToImg2Img != null
                ? () => widget.onSendToImg2Img!(record)
                : null,
          ),
        );
      },
    );
  }

  double _getCachedAspectRatio(LocalImageRecord record) {
    if (_aspectRatioCache.containsKey(record.path)) {
      return _aspectRatioCache[record.path]!;
    }

    _calculateAspectRatioForRecord(record).then((value) {
      if (mounted && value != _aspectRatioCache[record.path]) {
        setState(() => _aspectRatioCache[record.path] = value);
      }
    });

    return 1.0;
  }

  Future<double> _calculateAspectRatioForRecord(LocalImageRecord record) async {
    final metadata = record.metadata;
    if (metadata?.width != null && metadata?.height != null) {
      final width = metadata!.width!;
      final height = metadata.height!;
      if (width > 0 && height > 0) return width / height;
    }

    try {
      final buffer = await ui.ImmutableBuffer.fromFilePath(record.path);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width > 0 && descriptor.height > 0) {
        return descriptor.width / descriptor.height;
      }
    } catch (e) {
      AppLogger.d(
        'Failed to read gallery image aspect ratio: $e',
        'GalleryContent',
      );
    }

    return 1.0;
  }

  Widget _buildLoadingSkeleton() {
    return AnimatedOpacity(
      opacity: _showSkeleton ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: GridView.builder(
        key: const PageStorageKey<String>('gallery_grid_loading'),
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
      padding: const EdgeInsets.all(16),
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
      onDoubleTap: (record, index) {
        if (widget.onDoubleTap != null) {
          widget.onDoubleTap!(state.currentImages[index], index);
        } else if (widget.view3DConfig != null) {
          widget.view3DConfig!.showDetailViewer(
            widget.view3DConfig!.images,
            index,
          );
        }
      },
      onLongPress: (record, index) {
        if (!selectionState.isActive) {
          widget.onEnterSelection?.call(state.currentImages[index]);
        } else {
          widget.onLongPress?.call(state.currentImages[index], index);
        }
      },
      onSecondaryTapDown: (record, index, details) {
        widget.onContextMenu?.call(
          state.currentImages[index],
          details.globalPosition,
        );
      },
      onFavoriteToggle: (record, index) {
        widget.onFavoriteToggle?.call(state.currentImages[index]);
      },
      onSendToHome: widget.onSendToHome != null
          ? (record, index) => widget.onSendToHome!(record)
          : null,
      onSendToImg2Img: widget.onSendToImg2Img != null
          ? (record, index) => widget.onSendToImg2Img!(record)
          : null,
    );
  }

  List<LocalImageRecord> _convertToLocalImageRecords(List<T> items) {
    // ignore: avoid_as
    return items as List<LocalImageRecord>;
  }
}

// ============================================
// 向后兼容的 LocalImageRecord 专用版本
// ============================================

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
  int get currentPage => _state.currentPage;

  @override
  bool get hasFilters => _state.hasFilters;

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

/// 向后兼容的画廊内容视图
class LocalGalleryContentView extends ConsumerWidget {
  final bool use3DCardView;
  final int columns;
  final double itemWidth;
  final void Function(LocalImageRecord record)? onReuseMetadata;
  final void Function(LocalImageRecord record)? onSendToImg2Img;
  final void Function(LocalImageRecord record, Offset position)? onContextMenu;
  final void Function(LocalImageRecord record)? onSendToHome;
  final VoidCallback? onDeleted;
  final GlobalKey<GroupedGridViewState>? groupedGridViewKey;

  const LocalGalleryContentView({
    super.key,
    this.use3DCardView = true,
    required this.columns,
    required this.itemWidth,
    this.onReuseMetadata,
    this.onSendToImg2Img,
    this.onContextMenu,
    this.onSendToHome,
    this.onDeleted,
    this.groupedGridViewKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localGalleryNotifierProvider);
    final selectionState = ref.watch(localGallerySelectionNotifierProvider);

    void showImageDetailViewer(
      List<LocalImageRecord> images,
      int initialIndex,
    ) {
      bool getFavoriteStatus(String path) {
        final providerState = ref.read(localGalleryNotifierProvider);
        final image = providerState.currentImages
            .cast<LocalImageRecord?>()
            .firstWhere((img) => img?.path == path, orElse: () => null);
        return image?.isFavorite ?? false;
      }

      ImageDetailOpener.showMultipleImmediate(
        context,
        images: images
            .map(
              (r) =>
                  LocalImageDetailData(r, getFavoriteStatus: getFavoriteStatus),
            )
            .toList(),
        initialIndex: initialIndex,
        showMetadataPanel: true,
        showThumbnails: images.length > 1,
        callbacks: ImageDetailCallbacks(
          onReuseMetadata: onReuseMetadata != null
              ? (data, _) =>
                  onReuseMetadata?.call((data as LocalImageDetailData).record)
              : null,
          onFavoriteToggle: (data) => ref
              .read(localGalleryNotifierProvider.notifier)
              .toggleFavorite((data as LocalImageDetailData).record.path),
          onSendToImg2Img: (data) async {
            try {
              final bytes = await data.getImageBytes();
              ImageWorkflowLauncher.openImageToImage(ref, bytes);
              if (!context.mounted) return;
              Navigator.of(context).pop();
              context.go(AppRoutes.home);
              AppToast.success(context, context.l10n.gallery_sentToImg2Img);
            } catch (e) {
              if (context.mounted) {
                AppToast.error(context, context.l10n.gallery_sendFailed('$e'));
              }
            }
          },
          onSendToReversePrompt: (data) async {
            try {
              await ref.read(reversePromptProvider.notifier).addImage(
                    await data.getImageBytes(),
                    name: data.fileInfo?.fileName ?? 'gallery-image',
                  );
              if (!context.mounted) return;
              Navigator.of(context).pop();
              context.go(AppRoutes.home);
              AppToast.success(
                context,
                context.l10n.gallery_sentToReversePrompt,
              );
            } catch (e) {
              if (context.mounted) {
                AppToast.error(context, context.l10n.gallery_sendFailed('$e'));
              }
            }
          },
        ),
      );
    }

    return GenericGalleryContentView<LocalImageRecord>(
      use3DCardView: use3DCardView,
      columns: columns,
      itemWidth: itemWidth,
      state: _LocalGalleryStateAdapter(state),
      selectionState: _LocalSelectionStateAdapter(selectionState),
      idExtractor: (record) => record.path,
      itemBuilder: (context, record, index, config) => LocalImageCard3D(
        record: record,
        width: config.itemWidth,
        height: config.itemWidth / config.aspectRatio,
        isSelected: config.isSelected,
        isVisible: config.isVisible,
        priority: config.isVisible ? 1 : 5,
        onTap: config.selectionMode ? config.onSelectionToggle : config.onTap,
        onLongPress: config.onLongPress,
        onFavoriteToggle: () => ref
            .read(localGalleryNotifierProvider.notifier)
            .toggleFavorite(record.path),
        onSendToHome:
            onReuseMetadata != null ? () => onReuseMetadata!(record) : null,
        onSendToImg2Img:
            onSendToImg2Img != null ? () => onSendToImg2Img!(record) : null,
      ),
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
      onDeleted: onDeleted,
      onClearFilters: () =>
          ref.read(localGalleryNotifierProvider.notifier).clearAllFilters(),
      onRefresh: () =>
          ref.read(localGalleryNotifierProvider.notifier).refresh(),
      onLoadPage: (page) =>
          ref.read(localGalleryNotifierProvider.notifier).loadPage(page),
      groupedGridViewKey: groupedGridViewKey,
      view3DConfig: Gallery3DViewConfig<LocalImageRecord>(
        images: state.currentImages,
        showDetailViewer: showImageDetailViewer,
      ),
      onSendToHome: onReuseMetadata,
      onSendToImg2Img: onSendToImg2Img,
    );
  }
}

// 向后兼容的类型别名
typedef GalleryContentView = LocalGalleryContentView;
