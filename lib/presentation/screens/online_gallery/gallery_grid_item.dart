import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/cache/online_gallery_detail_coordinator.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/online_gallery/danbooru_post.dart';
import 'online_gallery_grid.dart';
import '../../agent_chat/widgets/agent_resource_drop_region.dart';
import '../../widgets/online_gallery/online_gallery_image_placeholder.dart';

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
    required this.anchorKey,
    required this.onVisibilityChanged,
    required this.detailRequestScope,
    required this.loadDetail,
    required this.buildCard,
  });

  final GalleryItem post;
  final int index;
  final double itemWidth;
  final int columnCount;
  final ValueListenable<bool> scrolling;
  final GlobalKey? anchorKey;
  final void Function(
    int index,
    GalleryItem item,
    double itemWidth,
    int columnCount,
    bool visible,
    double visibleTop,
  )
  onVisibilityChanged;
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
    GalleryDetail? detail,
  })
  buildCard;

  @override
  State<GalleryGridItem> createState() => _GalleryGridItemState();
}

class _GalleryGridItemState extends State<GalleryGridItem> {
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

  void _handleVisibility(bool visible, double visibleTop) {
    _isVisible = visible;
    widget.onVisibilityChanged(
      widget.index,
      widget.post,
      widget.itemWidth,
      widget.columnCount,
      visible,
      visibleTop,
    );
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
        detail: detail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final layoutAspectRatio = post.width > 0 && post.height > 0
        ? post.width / post.height
        : 1.0;
    return KeyedSubtree(
      key: widget.anchorKey,
      child: OnlineGalleryVisibilityDrivenItem(
        key: ValueKey('visible:${post.stableKey}'),
        visibilityKey: post.stableKey,
        scrolling: widget.scrolling,
        onVisibilityChanged: _handleVisibility,
        builder: (context, hasBeenVisible, isScrolling) {
          if (!_needsDetail) {
            return _buildResourceCard(
              context,
              post,
              layoutAspectRatio,
              loadMedia: hasBeenVisible,
            );
          }
          if (!hasBeenVisible) {
            return SizedBox(
              height: (widget.itemWidth / layoutAspectRatio).clamp(
                80.0,
                widget.itemWidth * 2.5,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const OnlineGalleryImagePlaceholder(),
              ),
            );
          }
          if (_detailFuture == null) {
            return const AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                child: OnlineGalleryImagePlaceholder(),
              ),
            );
          }
          return FutureBuilder<GalleryDetail>(
            key: ValueKey((post.detailStableKey, widget.detailRequestScope)),
            future: _detailFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AspectRatio(
                  aspectRatio: 1,
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
                return const AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    child: OnlineGalleryImagePlaceholder(),
                  ),
                );
              }
              return _buildResourceCard(
                context,
                resolved,
                layoutAspectRatio,
                loadMedia: true,
                detail: detail,
              );
            },
          );
        },
      ),
    );
  }
}
