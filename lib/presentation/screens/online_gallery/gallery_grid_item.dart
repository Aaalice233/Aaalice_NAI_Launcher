import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/cache/online_gallery_detail_coordinator.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/online_gallery/danbooru_post.dart';
import 'online_gallery_grid.dart';
import 'online_gallery_viewport_tracker.dart';
import '../../agent_chat/widgets/agent_resource_drop_region.dart';
import '../../widgets/online_gallery/online_gallery_image_placeholder.dart';

void _scheduleRevealImmediately(VoidCallback reveal) => reveal();

/// Owns one gallery tile's visibility and detail request lifecycle.
///
/// AI TAG items without a preview resolve their detail once when they first
/// become visible. Rebuilds caused by scrolling, selection, or theme changes
/// reuse the same future instead of starting new business work from build.
class GalleryGridItem extends StatefulWidget {
  const GalleryGridItem({
    super.key,
    required this.post,
    required this.index,
    required this.itemWidth,
    required this.columnCount,
    required this.scrolling,
    this.initiallyLoadMedia = false,
    required this.anchorKey,
    required this.onVisibilityChanged,
    this.onGeometryMeasured,
    this.onTileBuild,
    this.onVisibilityTransition,
    this.onVisibilityDrivenRebuild,
    this.scheduleReveal = _scheduleRevealImmediately,
    required this.viewportGeneration,
    required this.detailRequestScope,
    required this.loadDetail,
    required this.buildCard,
  });

  final GalleryItem post;
  final int index;
  final double itemWidth;
  final int columnCount;
  final ValueListenable<bool> scrolling;
  final bool initiallyLoadMedia;
  final GlobalKey? anchorKey;
  final ValueChanged<OnlineGalleryViewportVisibilityEvent> onVisibilityChanged;
  final ValueChanged<Duration>? onGeometryMeasured;
  final VoidCallback? onTileBuild;
  final VoidCallback? onVisibilityTransition;
  final VoidCallback? onVisibilityDrivenRebuild;
  final void Function(VoidCallback reveal) scheduleReveal;
  final int viewportGeneration;
  final Object detailRequestScope;
  final Future<GalleryDetail> Function(
    GalleryItem item, {
    required GalleryDetailPriority priority,
    bool forceRefresh,
  })
  loadDetail;
  final Widget Function(
    BuildContext context,
    GalleryItem item,
    double itemWidth, {
    required double layoutAspectRatio,
    required bool loadMedia,
    required bool mediaRequestActive,
    GalleryDetail? detail,
  })
  buildCard;

  @override
  State<GalleryGridItem> createState() => _GalleryGridItemState();
}

class _GalleryGridItemState extends State<GalleryGridItem> {
  static int _nextVisibilityTokenSequence = 0;

  final int _visibilityTokenSequence = ++_nextVisibilityTokenSequence;
  Future<GalleryDetail>? _detailFuture;
  bool _isVisible = false;

  bool get _needsDetail =>
      widget.post.sourceId == GallerySourceId.aiTag &&
      !widget.post.hasValidPreview;

  Future<GalleryDetail> _loadDetail() =>
      widget.loadDetail(widget.post, priority: GalleryDetailPriority.visible);

  @override
  void didUpdateWidget(covariant GalleryGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.detailStableKey != widget.post.detailStableKey ||
        oldWidget.detailRequestScope != widget.detailRequestScope) {
      _detailFuture = null;
      if (_isVisible && _needsDetail) {
        _detailFuture = _loadDetail();
      }
    }
  }

  void _handleVisibility(bool visible, double leadingScrollOffset, Object _) {
    _isVisible = visible;
    widget.onVisibilityChanged(
      OnlineGalleryViewportVisibilityEvent(
        index: widget.index,
        item: widget.post,
        itemWidth: widget.itemWidth,
        columnCount: widget.columnCount,
        visible: visible,
        leadingScrollOffset: leadingScrollOffset,
        viewportGeneration: widget.viewportGeneration,
        tokenSequence: _visibilityTokenSequence,
      ),
    );
    if (!mounted) return;
    if (visible && _needsDetail && _detailFuture == null) {
      setState(() {
        _detailFuture = _loadDetail();
      });
    }
  }

  void _retryDetail() {
    setState(() {
      _detailFuture = widget.loadDetail(
        widget.post,
        priority: GalleryDetailPriority.visible,
        forceRefresh: true,
      );
    });
  }

  Widget _buildResourceCard(
    BuildContext context,
    GalleryItem item,
    double layoutAspectRatio, {
    required bool loadMedia,
    required bool mediaRequestActive,
    GalleryDetail? detail,
  }) {
    return AgentResourceDragSource(
      reference: AgentChatResourceReference(
        kind: AgentChatResourceKind.onlineGalleryMedia,
        source: item.sourceId.key,
        resourceId: item.sourceWorkId,
        mediaId: item.cover.id,
        display: {
          if (item.title?.trim().isNotEmpty == true)
            'title': item.title!.trim(),
          if (item.author?.trim().isNotEmpty == true)
            'author': item.author!.trim(),
        },
      ),
      child: widget.buildCard(
        context,
        item,
        widget.itemWidth,
        layoutAspectRatio: layoutAspectRatio,
        loadMedia: loadMedia,
        mediaRequestActive: mediaRequestActive,
        detail: detail,
      ),
    );
  }

  Widget _buildDeferredCard(double layoutAspectRatio) {
    return SizedBox(
      height: (widget.itemWidth / layoutAspectRatio).clamp(
        80.0,
        widget.itemWidth * 2.5,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: const OnlineGalleryImagePlaceholder(loading: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    widget.onTileBuild?.call();
    final post = widget.post;
    final layoutAspectRatio = post.width > 0 && post.height > 0
        ? post.width / post.height
        : 1.0;
    return KeyedSubtree(
      key: widget.anchorKey,
      child: OnlineGalleryVisibilityDrivenItem(
        key: ValueKey('visible:${post.stableKey}'),
        visibilityKey: (widget.viewportGeneration, post.stableKey),
        scrolling: widget.scrolling,
        initiallyLoadMedia: widget.initiallyLoadMedia,
        onVisibilityChanged: _handleVisibility,
        onGeometryMeasured: widget.onGeometryMeasured,
        onVisibilityTransition: widget.onVisibilityTransition,
        onVisibilityDrivenRebuild: widget.onVisibilityDrivenRebuild,
        scheduleReveal: widget.scheduleReveal,
        builder: (context, hasBeenVisible, isScrolling, isVisible) {
          if (!hasBeenVisible) {
            return _buildDeferredCard(layoutAspectRatio);
          }
          if (!_needsDetail) {
            return _buildResourceCard(
              context,
              post,
              layoutAspectRatio,
              loadMedia: hasBeenVisible,
              mediaRequestActive: hasBeenVisible,
            );
          }
          if (_detailFuture == null) {
            return _buildDeferredCard(layoutAspectRatio);
          }
          return FutureBuilder<GalleryDetail>(
            key: ValueKey((post.detailStableKey, widget.detailRequestScope)),
            future: _detailFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final error = snapshot.error;
                if (error is DioException &&
                    error.type == DioExceptionType.cancel) {
                  return _buildDeferredCard(layoutAspectRatio);
                }
                return SizedBox(
                  height: (widget.itemWidth / layoutAspectRatio).clamp(
                    80.0,
                    widget.itemWidth * 2.5,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: _retryDetail,
                        icon: const Icon(Icons.refresh),
                        label: Text(context.l10n.common_retry),
                      ),
                    ),
                  ),
                );
              }
              final detail = snapshot.data;
              final resolved = detail?.item;
              if (resolved == null) {
                return _buildDeferredCard(layoutAspectRatio);
              }
              return _buildResourceCard(
                context,
                resolved,
                layoutAspectRatio,
                loadMedia: hasBeenVisible,
                mediaRequestActive: hasBeenVisible,
                detail: detail,
              );
            },
          );
        },
      ),
    );
  }
}
