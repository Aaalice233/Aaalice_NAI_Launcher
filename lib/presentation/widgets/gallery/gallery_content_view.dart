import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../data/models/gallery/local_image_record.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../widgets/grouped_grid_view.dart';
import 'local_image_card_3d.dart';
import '../common/image_detail/image_detail_viewer.dart';
import '../common/image_detail/image_detail_data.dart';
import '../common/shimmer_skeleton.dart';
import '../../utils/image_detail_opener.dart';
import 'virtual_gallery_grid.dart';
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
  final VoidCallback? onTap;
  final VoidCallback? onSelectionToggle;
  final VoidCallback? onLongPress;

  const GalleryItemConfig({
    required this.selectionMode,
    required this.isSelected,
    required this.itemWidth,
    required this.aspectRatio,
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
  final Future<double> Function(T item)? aspectRatioExtractor;
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
    this.aspectRatioExtractor,
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
    extends ConsumerState<GenericGalleryContentView<T>> {
  /// Aspect ratio cache
  /// 宽高比缓存
  final Map<String, double> _aspectRatioCache = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Grouped view
    if (widget.state.isGroupedView) {
      return _buildGroupedView(widget.state, widget.selectionState, theme);
    }

    // Check for filtered empty state
    if (widget.state.filteredFiles.isEmpty && widget.state.hasFilters) {
      return GalleryNoResultsView(
        onClearFilters: widget.onClearFilters,
        title: widget.emptyTitle,
        subtitle: widget.emptySubtitle,
        icon: widget.emptyIcon,
      );
    }

    // Loading skeleton
    if (widget.state.isPageLoading) {
      return _buildLoadingSkeleton();
    }

    // 3D card view mode
    if (widget.use3DCardView) {
      return _build3DCardView(widget.state, widget.selectionState);
    }

    // Classic masonry view
    return _buildMasonryView(widget.state, widget.selectionState);
  }

  /// Build grouped view
  /// 构建分组视图
  Widget _buildGroupedView(
    GalleryState<T> state,
    SelectionState selectionState,
    ThemeData theme,
  ) {
    // Loading skeleton in grouped view
    if (state.isGroupedLoading) {
      return const GalleryGroupedLoadingView();
    }

    // No results in grouped view
    if (state.groupedImages.isEmpty) {
      return GalleryNoResultsView(
        onClearFilters: widget.onClearFilters,
      );
    }

    // Show grouped view - 注意：分组视图仍然使用 LocalImageRecord
    // 因为 GroupedGridView 目前只支持 LocalImageRecord
    return GroupedGridView(
      key: widget.groupedGridViewKey,
      images: state.groupedImages,
      columns: widget.columns,
      itemWidth: widget.itemWidth,
      selectionMode: selectionState.isActive,
      buildSelected: (path) => selectionState.selectedIds.contains(path),
      buildCard: (record) {
        final isSelected = selectionState.selectedIds.contains(record.path);

        // Get or calculate aspect ratio for grouped view
        final double aspectRatio = _aspectRatioCache[record.path] ?? 1.0;

        // Calculate and cache aspect ratio asynchronously if not cached
        if (!_aspectRatioCache.containsKey(record.path)) {
          _calculateAspectRatioForRecord(record).then((value) {
            if (mounted && value != aspectRatio) {
              setState(() {
                _aspectRatioCache[record.path] = value;
              });
            }
          });
        }

        // 使用 LocalImageCard3D 构建分组视图的卡片
        return LocalImageCard3D(
          record: record,
          width: widget.itemWidth,
          height: widget.itemWidth / aspectRatio,
          isSelected: isSelected,
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
          onFavoriteToggle: () {
            widget.onFavoriteToggle?.call(record as T);
          },
          onSendToHome: widget.onSendToHome != null
              ? () => widget.onSendToHome!(record)
              : null,
        );
      },
    );
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
    } catch (_) {}

    return 1.0;
  }

  Future<double> _calculateAspectRatio(T item) async {
    return await widget.aspectRatioExtractor?.call(item) ?? 1.0;
  }

  Widget _buildLoadingSkeleton() {
    return GridView.builder(
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
    );
  }

  Widget _build3DCardView(GalleryState<T> state, SelectionState selectionState) {
    final selectedIndices = <int>{};
    for (int i = 0; i < state.currentImages.length; i++) {
      if (selectionState.selectedIds.contains(
        widget.idExtractor(state.currentImages[i]),
      )) {
        selectedIndices.add(i);
      }
    }

    return VirtualGalleryGrid(
      key: PageStorageKey<String>(
        'gallery_3d_grid_${state.currentPage}_${selectionState.isActive}',
      ),
      images: _convertToLocalImageRecords(state.currentImages),
      columns: widget.columns,
      spacing: 12,
      padding: const EdgeInsets.all(16),
      selectedIndices: selectionState.isActive ? selectedIndices : null,
      onTap: (record, index) {
        if (selectionState.isActive) {
          // Selection mode: toggle selection
          widget.onSelectionToggle?.call(state.currentImages[index]);
        } else {
          // Normal mode: custom tap or default behavior
          if (widget.onTap != null) {
            widget.onTap!(state.currentImages[index], index);
          } else if (widget.view3DConfig != null) {
            widget.view3DConfig!.showDetailViewer(
              widget.view3DConfig!.images,
              index,
            );
          }
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
          ? (record, index) {
              widget.onSendToHome!(record);
            }
          : null,
    );
  }

  List<LocalImageRecord> _convertToLocalImageRecords(List<T> items) {
    // 如果 T 已经是 LocalImageRecord，直接返回
    if (T == LocalImageRecord || items is List<LocalImageRecord>) {
      return items as List<LocalImageRecord>;
    }
    return <LocalImageRecord>[];
  }

  Widget _buildMasonryView(GalleryState<T> state, SelectionState selectionState) {
    return MasonryGridView.count(
      key: const PageStorageKey<String>('gallery_grid'),
      crossAxisCount: widget.columns,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      padding: const EdgeInsets.all(16),
      cacheExtent: 1000,
      itemCount: state.currentImages.length,
      itemBuilder: (_, i) {
        final item = state.currentImages[i];
        final itemId = widget.idExtractor(item);
        final isSelected = selectionState.selectedIds.contains(itemId);
        final aspectRatio = _aspectRatioCache[itemId] ?? 1.0;

        if (!_aspectRatioCache.containsKey(itemId)) {
          _calculateAspectRatio(item).then((value) {
            if (mounted && value != aspectRatio) {
              setState(() => _aspectRatioCache[itemId] = value);
            }
          });
        }

        return widget.itemBuilder(
          context,
          item,
          i,
          GalleryItemConfig(
            selectionMode: selectionState.isActive,
            isSelected: isSelected,
            itemWidth: widget.itemWidth,
            aspectRatio: aspectRatio,
            onTap: () {
              if (widget.view3DConfig != null) {
                widget.view3DConfig!.showDetailViewer(
                  widget.view3DConfig!.images,
                  i,
                );
              } else {
                widget.onTap?.call(item, i);
              }
            },
            onSelectionToggle: () => widget.onSelectionToggle?.call(item),
            onLongPress: !selectionState.isActive
                ? () => widget.onEnterSelection?.call(item)
                : null,
          ),
        );
      },
    );
  }
}

/// ============================================
/// 向后兼容的 LocalImageRecord 专用版本
/// Backward-compatible LocalImageRecord version
/// ============================================

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
      _state.filteredFiles.cast<LocalImageRecord>();
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

    void showImageDetailViewer(List<LocalImageRecord> images, int initialIndex) {
      bool getFavoriteStatus(String path) {
        final providerState = ref.read(localGalleryNotifierProvider);
        final image = providerState.currentImages
            .cast<LocalImageRecord?>()
            .firstWhere((img) => img?.path == path, orElse: () => null);
        return image?.isFavorite ?? false;
      }

      ImageDetailOpener.showMultipleImmediate(
        context,
        images: images.map((r) => LocalImageDetailData(r, getFavoriteStatus: getFavoriteStatus)).toList(),
        initialIndex: initialIndex,
        showMetadataPanel: true,
        showThumbnails: images.length > 1,
        callbacks: ImageDetailCallbacks(
          onReuseMetadata: onReuseMetadata != null
              ? (data, _) => onReuseMetadata?.call((data as LocalImageDetailData).record)
              : null,
          onFavoriteToggle: (data) => ref
              .read(localGalleryNotifierProvider.notifier)
              .toggleFavorite((data as LocalImageDetailData).record.path),
        ),
      );
    }

    Future<double> getAspectRatio(LocalImageRecord record) async {
      final metadata = record.metadata;
      if (metadata?.width != null && metadata?.height != null) {
        if (metadata!.width! > 0 && metadata.height! > 0) {
          return metadata.width! / metadata.height!;
        }
      }
      try {
        final buffer = await ui.ImmutableBuffer.fromFilePath(record.path);
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (descriptor.width > 0 && descriptor.height > 0) {
          return descriptor.width / descriptor.height;
        }
      } catch (_) {}
      return 1.0;
    }

    return GenericGalleryContentView<LocalImageRecord>(
      use3DCardView: use3DCardView,
      columns: columns,
      itemWidth: itemWidth,
      state: _LocalGalleryStateAdapter(state),
      selectionState: _LocalSelectionStateAdapter(selectionState),
      idExtractor: (record) => record.path,
      aspectRatioExtractor: getAspectRatio,
      itemBuilder: (context, record, index, config) => LocalImageCard3D(
        record: record,
        width: config.itemWidth,
        height: config.itemWidth / config.aspectRatio,
        isSelected: config.isSelected,
        onTap: config.selectionMode ? config.onSelectionToggle : config.onTap,
        onLongPress: config.onLongPress,
        onFavoriteToggle: () => ref
            .read(localGalleryNotifierProvider.notifier)
            .toggleFavorite(record.path),
        onSendToHome: onReuseMetadata != null ? () => onReuseMetadata!(record) : null,
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
      onClearFilters: () => ref.read(localGalleryNotifierProvider.notifier).clearAllFilters(),
      onRefresh: () => ref.read(localGalleryNotifierProvider.notifier).refresh(),
      onLoadPage: (page) => ref.read(localGalleryNotifierProvider.notifier).loadPage(page),
      groupedGridViewKey: groupedGridViewKey,
      view3DConfig: Gallery3DViewConfig<LocalImageRecord>(
        images: state.currentImages,
        showDetailViewer: showImageDetailViewer,
      ),
      onSendToHome: onReuseMetadata,
    );
  }
}

/// 向后兼容的类型别名
typedef GalleryContentView = LocalGalleryContentView;
