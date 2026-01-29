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

/// Gallery content view with grouped/3D/masonry view modes
/// 画廊内容视图（含分组/3D/瀑布流切换）
class GalleryContentView extends ConsumerStatefulWidget {
  /// Whether 3D card view mode is active
  /// 是否启用3D卡片视图模式
  final bool use3DCardView;

  /// Number of columns in the grid
  /// 网格列数
  final int columns;

  /// Width of each item
  /// 每个项目的宽度
  final double itemWidth;

  /// Callback when reuse metadata is triggered
  /// 复用元数据回调
  final void Function(LocalImageRecord record)? onReuseMetadata;

  /// Callback when send to img2img is triggered
  /// 发送到图生图回调
  final void Function(LocalImageRecord record)? onSendToImg2Img;

  /// Callback when context menu is triggered
  /// 上下文菜单回调
  final void Function(LocalImageRecord record, Offset position)? onContextMenu;

  /// Callback when image is deleted
  /// 图片删除回调
  final VoidCallback? onDeleted;

  /// Key for GroupedGridView to scroll to group
  /// 用于滚动到分组的 GroupedGridView key
  final GlobalKey<GroupedGridViewState>? groupedGridViewKey;

  const GalleryContentView({
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
  ConsumerState<GalleryContentView> createState() => _GalleryContentViewState();
}

class _GalleryContentViewState extends ConsumerState<GalleryContentView> {
  /// Aspect ratio cache
  /// 宽高比缓存
  final Map<String, double> _aspectRatioCache = {};

  /// Show image detail viewer
  /// 显示图像详情查看器
  void _showImageDetailViewer(List<LocalImageRecord> images, int initialIndex) {
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
        onReuseMetadata: widget.onReuseMetadata != null
            ? (data) {
                if (data is LocalImageDetailData) {
                  widget.onReuseMetadata!(data.record);
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

  /// Calculate aspect ratio from metadata or image file
  /// 计算图片宽高比
  Future<double> _calculateAspectRatio(LocalImageRecord record) async {
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

    // Default aspect ratio (based on common NAI generation dimensions)
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localGalleryNotifierProvider);
    final selectionState = ref.watch(localGallerySelectionNotifierProvider);
    final theme = Theme.of(context);

    // Grouped view
    if (state.isGroupedView) {
      return _buildGroupedView(state, selectionState, theme);
    }

    // Check for filtered empty state
    if (state.filteredFiles.isEmpty && state.hasFilters) {
      return GalleryNoResultsView(
        onClearFilters: () {
          ref.read(localGalleryNotifierProvider.notifier).clearAllFilters();
        },
      );
    }

    // Loading skeleton
    if (state.isPageLoading) {
      return _buildLoadingSkeleton(state);
    }

    // 3D card view mode
    if (widget.use3DCardView) {
      return _build3DCardView(state, selectionState);
    }

    // Classic masonry view
    return _buildMasonryView(state, selectionState);
  }

  /// Build grouped view
  /// 构建分组视图
  Widget _buildGroupedView(
    LocalGalleryState state,
    SelectionModeState selectionState,
    ThemeData theme,
  ) {
    // Loading skeleton in grouped view
    if (state.isGroupedLoading) {
      return const GalleryGroupedLoadingView();
    }

    // No results in grouped view
    if (state.groupedImages.isEmpty) {
      return GalleryNoResultsView(
        onClearFilters: () {
          ref.read(localGalleryNotifierProvider.notifier).clearAllFilters();
        },
      );
    }

    // Show grouped view
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
          _calculateAspectRatio(record).then((value) {
            if (mounted && value != aspectRatio) {
              setState(() {
                _aspectRatioCache[record.path] = value;
              });
            }
          });
        }

        return LocalImageCard(
          record: record,
          itemWidth: widget.itemWidth,
          aspectRatio: aspectRatio,
          selectionMode: selectionState.isActive,
          isSelected: isSelected,
          onSelectionToggle: () {
            ref
                .read(localGallerySelectionNotifierProvider.notifier)
                .toggle(record.path);
          },
          onLongPress: () {
            if (!selectionState.isActive) {
              ref
                  .read(localGallerySelectionNotifierProvider.notifier)
                  .enterAndSelect(record.path);
            }
          },
          onDeleted: () {
            // Refresh grouped view
            ref.read(localGalleryNotifierProvider.notifier).refresh();
            widget.onDeleted?.call();
          },
          onReuseMetadata: widget.onReuseMetadata,
          onSendToImg2Img: widget.onSendToImg2Img,
          onFavoriteToggle: (record) {
            ref
                .read(localGalleryNotifierProvider.notifier)
                .toggleFavorite(record.path);
          },
        );
      },
    );
  }

  /// Build loading skeleton
  /// 构建加载骨架屏
  Widget _buildLoadingSkeleton(LocalGalleryState state) {
    return GridView.builder(
      key: const PageStorageKey<String>('local_gallery_grid_loading'),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount:
          state.currentImages.isNotEmpty ? state.currentImages.length : 20,
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
    LocalGalleryState state,
    SelectionModeState selectionState,
  ) {
    final selectedIndices = <int>{};

    // Convert paths to indices
    for (int i = 0; i < state.currentImages.length; i++) {
      if (selectionState.selectedIds.contains(state.currentImages[i].path)) {
        selectedIndices.add(i);
      }
    }

    return VirtualGalleryGrid(
      // 使用动态 key，当选择模式变化时强制重建，确保 onTap 回调使用最新状态
      key: PageStorageKey<String>(
          'local_gallery_3d_grid_${selectionState.isActive}'),
      images: state.currentImages,
      columns: widget.columns,
      spacing: 12,
      padding: const EdgeInsets.all(16),
      selectedIndices: selectionState.isActive ? selectedIndices : null,
      onTap: (record, index) {
        // 实时读取最新的选择状态，避免闭包捕获旧值
        final currentSelectionState =
            ref.read(localGallerySelectionNotifierProvider);
        if (currentSelectionState.isActive) {
          // Selection mode: toggle selection
          ref
              .read(localGallerySelectionNotifierProvider.notifier)
              .toggle(record.path);
        } else {
          // Normal mode: open fullscreen preview
          _showImageDetailViewer(state.currentImages, index);
        }
      },
      onDoubleTap: (record, index) {
        // Double tap to open fullscreen preview
        _showImageDetailViewer(state.currentImages, index);
      },
      onLongPress: (record, index) {
        if (!selectionState.isActive) {
          // Long press to enter selection mode and select current item
          ref
              .read(localGallerySelectionNotifierProvider.notifier)
              .enterAndSelect(record.path);
        }
      },
      onSecondaryTapDown: (record, index, details) {
        // Right-click menu
        widget.onContextMenu?.call(record, details.globalPosition);
      },
      onFavoriteToggle: (record, index) {
        ref
            .read(localGalleryNotifierProvider.notifier)
            .toggleFavorite(record.path);
      },
    );
  }

  /// Build masonry view
  /// 构建瀑布流视图
  Widget _buildMasonryView(
    LocalGalleryState state,
    SelectionModeState selectionState,
  ) {
    return MasonryGridView.count(
      key: const PageStorageKey<String>('local_gallery_grid'),
      crossAxisCount: widget.columns,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: state.currentImages.length,
      itemBuilder: (c, i) {
        final record = state.currentImages[i];
        final isSelected = ref.watch(
          localGallerySelectionNotifierProvider
              .select((state) => state.selectedIds.contains(record.path)),
        );
        final selectionMode = ref.watch(
          localGallerySelectionNotifierProvider
              .select((state) => state.isActive),
        );

        // Get or calculate aspect ratio
        final double aspectRatio = _aspectRatioCache[record.path] ?? 1.0;

        // Calculate and cache aspect ratio asynchronously
        if (!_aspectRatioCache.containsKey(record.path)) {
          _calculateAspectRatio(record).then((value) {
            if (mounted && value != aspectRatio) {
              setState(() {
                _aspectRatioCache[record.path] = value;
              });
            }
          });
        }

        return LocalImageCard(
          record: record,
          itemWidth: widget.itemWidth,
          aspectRatio: aspectRatio,
          selectionMode: selectionMode,
          isSelected: isSelected,
          onSelectionToggle: () {
            ref
                .read(localGallerySelectionNotifierProvider.notifier)
                .toggle(record.path);
          },
          onLongPress: () {
            if (!selectionMode) {
              ref
                  .read(localGallerySelectionNotifierProvider.notifier)
                  .enterAndSelect(record.path);
            }
          },
          onDeleted: () {
            // Refresh current page
            ref
                .read(localGalleryNotifierProvider.notifier)
                .loadPage(state.currentPage);
            widget.onDeleted?.call();
          },
          onReuseMetadata: widget.onReuseMetadata,
          onSendToImg2Img: widget.onSendToImg2Img,
          onFavoriteToggle: (record) {
            ref
                .read(localGalleryNotifierProvider.notifier)
                .toggleFavorite(record.path);
          },
        );
      },
    );
  }
}
