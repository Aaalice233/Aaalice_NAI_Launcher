import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../data/models/gallery/local_image_record.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../widgets/grouped_grid_view.dart';
import '../../widgets/local_image_card.dart';
import '../common/image_detail/image_detail_data.dart';
import '../common/image_detail/image_detail_viewer.dart';
import '../common/shimmer_skeleton.dart';
import 'virtual_gallery_grid.dart';
import 'gallery_state_views.dart';

/// 画廊项目构建函数类型
/// Gallery item builder function type
typedef GalleryItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  int index,
  GalleryItemConfig config,
);

/// 画廊项目配置
/// Configuration for building gallery items
class GalleryItemConfig {
  /// 是否处于选择模式
  final bool selectionMode;

  /// 是否被选中
  final bool isSelected;

  /// 项目宽度
  final double itemWidth;

  /// 宽高比
  final double aspectRatio;

  /// 选择切换回调
  final VoidCallback? onSelectionToggle;

  /// 长按回调
  final VoidCallback? onLongPress;

  const GalleryItemConfig({
    required this.selectionMode,
    required this.isSelected,
    required this.itemWidth,
    required this.aspectRatio,
    this.onSelectionToggle,
    this.onLongPress,
  });
}

/// 通用画廊状态接口
/// Generic gallery state interface
abstract class GalleryState<T> {
  /// 当前页的图片列表
  List<T> get currentImages;

  /// 分组后的图片（用于分组视图）
  List<LocalImageRecord> get groupedImages;

  /// 是否处于分组视图
  bool get isGroupedView;

  /// 是否正在加载页面
  bool get isPageLoading;

  /// 是否正在加载分组
  bool get isGroupedLoading;

  /// 当前页码
  int get currentPage;

  /// 是否有筛选条件
  bool get hasFilters;

  /// 筛选后的文件列表（用于判断是否为空）
  List<T> get filteredFiles;
}

/// 通用选择状态接口
/// Generic selection state interface
abstract class SelectionState {
  /// 是否处于选择模式
  bool get isActive;

  /// 已选中的ID集合
  Set<String> get selectedIds;
}

/// Gallery content view with grouped/3D/masonry view modes (Generic version)
/// 画廊内容视图（含分组/3D/瀑布流切换）- 泛型版本
///
/// [T] 项目类型，如 LocalImageRecord 或 VibeLibraryEntry
class GenericGalleryContentView<T> extends ConsumerStatefulWidget {
  /// Whether 3D card view mode is active
  /// 是否启用3D卡片视图模式
  final bool use3DCardView;

  /// Number of columns in the grid
  /// 网格列数
  final int columns;

  /// Width of each item
  /// 每个项目的宽度
  final double itemWidth;

  /// 画廊状态
  final GalleryState<T> state;

  /// 选择状态
  final SelectionState selectionState;

  /// 项目构建器
  final GalleryItemBuilder<T> itemBuilder;

  /// ID提取器（用于选择状态匹配）
  final String Function(T item) idExtractor;

  /// 宽高比提取器（可选，用于瀑布流视图）
  final Future<double> Function(T item)? aspectRatioExtractor;

  /// 点击回调
  final void Function(T item, int index)? onTap;

  /// 双击回调
  final void Function(T item, int index)? onDoubleTap;

  /// 长按回调
  final void Function(T item, int index)? onLongPress;

  /// 右键菜单回调
  final void Function(T item, Offset position)? onContextMenu;

  /// 收藏切换回调
  final void Function(T item)? onFavoriteToggle;

  /// 选择切换回调
  final void Function(T item)? onSelectionToggle;

  /// 进入选择模式并选中回调
  final void Function(T item)? onEnterSelection;

  /// 删除回调
  final VoidCallback? onDeleted;

  /// 清除筛选回调
  final VoidCallback? onClearFilters;

  /// 刷新回调
  final VoidCallback? onRefresh;

  /// 加载指定页回调
  final void Function(int page)? onLoadPage;

  /// Key for GroupedGridView to scroll to group
  /// 用于滚动到分组的 GroupedGridView key
  final GlobalKey<GroupedGridViewState>? groupedGridViewKey;

  /// 3D视图模式下的额外配置
  final Gallery3DViewConfig<T>? view3DConfig;

  /// 空状态标题
  final String? emptyTitle;

  /// 空状态副标题
  final String? emptySubtitle;

  /// 空状态图标
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
  /// 图片列表（用于详情查看器）
  final List<T> images;

  /// 显示图片详情查看器
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

        // 使用 LocalImageCard 构建分组视图的卡片
        return LocalImageCard(
          record: record,
          itemWidth: widget.itemWidth,
          aspectRatio: aspectRatio,
          selectionMode: selectionState.isActive,
          isSelected: isSelected,
          onSelectionToggle: () {
            widget.onSelectionToggle?.call(record as T);
          },
          onLongPress: () {
            if (!selectionState.isActive) {
              widget.onEnterSelection?.call(record as T);
            }
          },
          onDeleted: () {
            widget.onRefresh?.call();
            widget.onDeleted?.call();
          },
          onFavoriteToggle: (record) {
            widget.onFavoriteToggle?.call(record as T);
          },
        );
      },
    );
  }

  /// Calculate aspect ratio for LocalImageRecord
  Future<double> _calculateAspectRatioForRecord(LocalImageRecord record) async {
    // Try to get dimensions from metadata first
    final metadata = record.metadata;
    if (metadata != null && metadata.width != null && metadata.height != null) {
      final width = metadata.width!;
      final height = metadata.height!;
      if (width > 0 && height > 0) {
        return width / height;
      }
    }

    // If metadata doesn't have dimensions, read from image file
    try {
      final buffer = await ui.ImmutableBuffer.fromFilePath(record.path);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width;
      final height = descriptor.height;
      if (width > 0 && height > 0) {
        return width / height;
      }
    } catch (e) {
      // If reading fails, return default aspect ratio
    }

    // Default aspect ratio
    return 1.0;
  }

  /// Calculate aspect ratio for generic type
  Future<double> _calculateAspectRatio(T item) async {
    if (widget.aspectRatioExtractor != null) {
      return await widget.aspectRatioExtractor!(item);
    }

    // Default aspect ratio
    return 1.0;
  }

  /// Build loading skeleton
  /// 构建加载骨架屏
  Widget _buildLoadingSkeleton() {
    return GridView.builder(
      key: const PageStorageKey<String>('gallery_grid_loading'),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount:
          widget.state.currentImages.isNotEmpty
              ? widget.state.currentImages.length
              : 20,
      itemBuilder: (c, i) {
        return const Card(
          clipBehavior: Clip.antiAlias,
          child: ShimmerSkeleton(height: 250),
        );
      },
    );
  }

  /// Build 3D card view
  /// 构建3D卡片视图
  Widget _build3DCardView(
    GalleryState<T> state,
    SelectionState selectionState,
  ) {
    final selectedIndices = <int>{};

    // Convert ids to indices
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
    );
  }

  /// Convert generic items to LocalImageRecords for 3D view compatibility
  /// 将泛型项目转换为 LocalImageRecord（用于3D视图的兼容性）
  List<LocalImageRecord> _convertToLocalImageRecords(List<T> items) {
    // 如果 T 已经是 LocalImageRecord，直接返回
    if (T == LocalImageRecord || items is List<LocalImageRecord>) {
      return items as List<LocalImageRecord>;
    }

    // 否则返回空列表（3D视图需要适配）
    // 实际使用时应该通过 view3DConfig 提供自定义3D视图
    return [];
  }

  /// Build masonry view
  /// 构建瀑布流视图
  Widget _buildMasonryView(
    GalleryState<T> state,
    SelectionState selectionState,
  ) {
    return MasonryGridView.count(
      key: const PageStorageKey<String>('gallery_grid'),
      crossAxisCount: widget.columns,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      padding: const EdgeInsets.all(16),
      cacheExtent: 1000,
      itemCount: state.currentImages.length,
      itemBuilder: (c, i) {
        final item = state.currentImages[i];
        final itemId = widget.idExtractor(item);
        final isSelected = selectionState.selectedIds.contains(itemId);

        // Get or calculate aspect ratio
        final double aspectRatio = _aspectRatioCache[itemId] ?? 1.0;

        // Calculate and cache aspect ratio asynchronously
        if (!_aspectRatioCache.containsKey(itemId)) {
          _calculateAspectRatio(item).then((value) {
            if (mounted && value != aspectRatio) {
              setState(() {
                _aspectRatioCache[itemId] = value;
              });
            }
          });
        }

        final config = GalleryItemConfig(
          selectionMode: selectionState.isActive,
          isSelected: isSelected,
          itemWidth: widget.itemWidth,
          aspectRatio: aspectRatio,
          onSelectionToggle: () => widget.onSelectionToggle?.call(item),
          onLongPress:
              !selectionState.isActive
                  ? () => widget.onEnterSelection?.call(item)
                  : null,
        );

        return widget.itemBuilder(context, item, i, config);
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
/// 使用 ConsumerWidget 自动读取本地画廊状态
class LocalGalleryContentView extends ConsumerWidget {
  /// Whether 3D card view mode is active
  final bool use3DCardView;

  /// Number of columns in the grid
  final int columns;

  /// Width of each item
  final double itemWidth;

  /// Callback when reuse metadata is triggered
  final void Function(LocalImageRecord record)? onReuseMetadata;

  /// Callback when send to img2img is triggered
  final void Function(LocalImageRecord record)? onSendToImg2Img;

  /// Callback when context menu is triggered
  final void Function(LocalImageRecord record, Offset position)? onContextMenu;

  /// Callback when image is deleted
  final VoidCallback? onDeleted;

  /// Key for GroupedGridView to scroll to group
  final GlobalKey<GroupedGridViewState>? groupedGridViewKey;

  const LocalGalleryContentView({
    super.key,
    this.use3DCardView = true,
    required this.columns,
    required this.itemWidth,
    this.onReuseMetadata,
    this.onSendToImg2Img,
    this.onContextMenu,
    this.onDeleted,
    this.groupedGridViewKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localGalleryNotifierProvider);
    final selectionState = ref.watch(localGallerySelectionNotifierProvider);

    // 显示图片详情查看器
    void showImageDetailViewer(List<LocalImageRecord> images, int initialIndex) {
      // 获取最新的收藏状态的函数
      bool getFavoriteStatus(String path) {
        final providerState = ref.read(localGalleryNotifierProvider);
        final image = providerState.currentImages
            .cast<LocalImageRecord?>()
            .firstWhere((img) => img?.path == path, orElse: () => null);
        return image?.isFavorite ?? false;
      }

      // 将 LocalImageRecord 转换为 ImageDetailData
      final imageDataList = images.map((record) {
        return LocalImageDetailData(
          record,
          getFavoriteStatus: getFavoriteStatus,
        );
      }).toList();

      ImageDetailViewer.show(
        context,
        images: imageDataList,
        initialIndex: initialIndex,
        showMetadataPanel: true,
        showThumbnails: images.length > 1,
        callbacks: ImageDetailCallbacks(
          onReuseMetadata: onReuseMetadata != null
              ? (data, options) {
                  if (data is LocalImageDetailData) {
                    onReuseMetadata!(data.record);
                  }
                }
              : null,
          onFavoriteToggle: (data) {
            if (data is LocalImageDetailData) {
              ref
                  .read(localGalleryNotifierProvider.notifier)
                  .toggleFavorite(data.record.path);
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
      aspectRatioExtractor: (record) async {
        // Try to get dimensions from metadata first
        final metadata = record.metadata;
        if (metadata != null &&
            metadata.width != null &&
            metadata.height != null) {
          final width = metadata.width!;
          final height = metadata.height!;
          if (width > 0 && height > 0) {
            return width / height;
          }
        }

        // If metadata doesn't have dimensions, read from image file
        try {
          final buffer = await ui.ImmutableBuffer.fromFilePath(record.path);
          final descriptor = await ui.ImageDescriptor.encoded(buffer);
          final width = descriptor.width;
          final height = descriptor.height;
          if (width > 0 && height > 0) {
            return width / height;
          }
        } catch (e) {
          // If reading fails, return default aspect ratio
        }

        return 1.0;
      },
      itemBuilder: (context, record, index, config) {
        return LocalImageCard(
          record: record,
          itemWidth: config.itemWidth,
          aspectRatio: config.aspectRatio,
          selectionMode: config.selectionMode,
          isSelected: config.isSelected,
          onSelectionToggle: config.onSelectionToggle,
          onLongPress: config.onLongPress,
          onDeleted: () {
            ref
                .read(localGalleryNotifierProvider.notifier)
                .loadPage(state.currentPage);
            onDeleted?.call();
          },
          onReuseMetadata: onReuseMetadata,
          onSendToImg2Img: onSendToImg2Img,
          onFavoriteToggle: (record) {
            ref
                .read(localGalleryNotifierProvider.notifier)
                .toggleFavorite(record.path);
          },
        );
      },
      onSelectionToggle: (record) {
        ref
            .read(localGallerySelectionNotifierProvider.notifier)
            .toggle(record.path);
      },
      onEnterSelection: (record) {
        ref
            .read(localGallerySelectionNotifierProvider.notifier)
            .enterAndSelect(record.path);
      },
      onContextMenu: onContextMenu,
      onDeleted: onDeleted,
      onClearFilters: () {
        ref.read(localGalleryNotifierProvider.notifier).clearAllFilters();
      },
      onRefresh: () {
        ref.read(localGalleryNotifierProvider.notifier).refresh();
      },
      onLoadPage: (page) {
        ref.read(localGalleryNotifierProvider.notifier).loadPage(page);
      },
      groupedGridViewKey: groupedGridViewKey,
      view3DConfig: Gallery3DViewConfig<LocalImageRecord>(
        images: state.currentImages,
        showDetailViewer: showImageDetailViewer,
      ),
    );
  }
}

/// Gallery content view with grouped/3D/masonry view modes
/// 画廊内容视图（含分组/3D/瀑布流切换）
///
/// 此类型别名指向 LocalGalleryContentView，保持完全向后兼容
/// 现有的 LocalGalleryScreen 可以继续使用 GalleryContentView(...) 而不需要修改
typedef GalleryContentView = LocalGalleryContentView;
