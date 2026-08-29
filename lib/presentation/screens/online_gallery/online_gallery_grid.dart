import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../core/cache/online_gallery_preload_policy.dart';
import '../../providers/online_gallery_provider.dart';
import '../../widgets/online_gallery/online_gallery_image_placeholder.dart';
import 'online_gallery_screen_controller.dart';

typedef OnlineGalleryGridItemBuilder =
    Widget Function(
      BuildContext context,
      int index,
      double itemWidth,
      int columnCount,
    );

typedef OnlineGalleryVisibilityItemBuilder =
    Widget Function(
      BuildContext context,
      bool hasBeenVisible,
      bool isScrolling,
    );

/// Responsive masonry grid. Item interaction is supplied as commands so this
/// leaf never reaches into the screen State.
class OnlineGalleryGrid extends StatelessWidget {
  const OnlineGalleryGrid({
    super.key,
    required this.state,
    required this.controller,
    required this.itemBuilder,
  });

  final OnlineGalleryState state;
  final OnlineGalleryScreenController controller;
  final OnlineGalleryGridItemBuilder itemBuilder;

  int _placeholderCount() {
    if (!(state.isLoadingMore || (state.isLoading && state.posts.isEmpty))) {
      return 0;
    }
    if (!state.hasMore) return 0;
    if (state.randomEnabled) return 1;
    // Keep one immutable runway for the whole request. Deriving this from a
    // total that may arrive mid-request shrinks the sliver while it is being
    // scrolled and defeats the placeholder's purpose.
    return onlineGalleryPageSize;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 24.0;
        const spacing = 6.0;
        final availableWidth = (constraints.maxWidth - padding).clamp(
          0.0,
          double.infinity,
        );
        final columnCount = ((availableWidth + spacing) / (160 + spacing))
            .floor()
            .clamp(1, 8);
        final itemWidth =
            (availableWidth - (columnCount - 1) * spacing) / columnCount;
        final viewportHeight = controller.scrollController.hasClients
            ? controller.scrollController.position.viewportDimension
            : constraints.maxHeight;

        final storageScope = state.randomEnabled
            ? 'random:${state.randomSession.scopeKey}'
            : 'normal';
        final placeholderCount = _placeholderCount();
        return CustomScrollView(
          key: PageStorageKey<String>(
            'online_gallery_$storageScope:${state.currentCacheKey}',
          ),
          controller: controller.scrollController,
          scrollCacheExtent: ScrollCacheExtent.pixels(
            OnlineGalleryPreloadPolicy.cacheExtent(viewportHeight),
          ),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                state.posts.isEmpty ? 0 : 6,
              ),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: columnCount,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childCount: state.posts.length,
                itemBuilder: (context, index) =>
                    itemBuilder(context, index, itemWidth, columnCount),
              ),
            ),
            if (placeholderCount > 0)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  state.posts.isEmpty ? 12 : 0,
                  12,
                  0,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnCount,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, placeholderIndex) => OnlineGalleryPendingCard(
                      key: ValueKey(
                        'online-gallery-pending:'
                        '${state.currentCacheKey}:$placeholderIndex',
                      ),
                      itemWidth: itemWidth,
                    ),
                    childCount: placeholderCount,
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, _) => itemBuilder(
                    context,
                    state.posts.length,
                    itemWidth,
                    columnCount,
                  ),
                  childCount: 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class OnlineGalleryPendingCard extends StatelessWidget {
  const OnlineGalleryPendingCard({super.key, required this.itemWidth});

  final double itemWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemWidth,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: const OnlineGalleryImagePlaceholder(loading: true),
      ),
    );
  }
}

class OnlineGalleryVisibilityDrivenItem extends StatefulWidget {
  const OnlineGalleryVisibilityDrivenItem({
    super.key,
    required this.visibilityKey,
    required this.scrolling,
    required this.onVisibilityChanged,
    required this.builder,
  });

  final String visibilityKey;
  final ValueListenable<bool> scrolling;
  final void Function(bool visible, double visibleTop) onVisibilityChanged;
  final OnlineGalleryVisibilityItemBuilder builder;

  @override
  State<OnlineGalleryVisibilityDrivenItem> createState() =>
      OnlineGalleryVisibilityDrivenItemState();
}

class OnlineGalleryVisibilityDrivenItemState
    extends State<OnlineGalleryVisibilityDrivenItem> {
  bool _hasBeenVisible = false;
  bool _isVisible = false;
  late bool _isScrolling;
  bool _listensForScrolling = false;

  @override
  void initState() {
    super.initState();
    _isScrolling = widget.scrolling.value;
    _startListeningForScrolling();
  }

  @override
  void didUpdateWidget(covariant OnlineGalleryVisibilityDrivenItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrolling == widget.scrolling) return;
    if (_listensForScrolling) {
      oldWidget.scrolling.removeListener(_handleScrollingChanged);
      _listensForScrolling = false;
    }
    _isScrolling = widget.scrolling.value;
    _startListeningForScrolling();
  }

  void _startListeningForScrolling() {
    if (_hasBeenVisible || _listensForScrolling) return;
    widget.scrolling.addListener(_handleScrollingChanged);
    _listensForScrolling = true;
  }

  void _stopListeningForScrolling() {
    if (!_listensForScrolling) return;
    widget.scrolling.removeListener(_handleScrollingChanged);
    _listensForScrolling = false;
  }

  void _handleScrollingChanged() {
    final value = widget.scrolling.value;
    if (_isScrolling == value) return;
    if (_hasBeenVisible || !mounted) {
      _isScrolling = value;
      return;
    }
    if (!value && _isVisible) {
      _stopListeningForScrolling();
      setState(() {
        _isScrolling = false;
        _hasBeenVisible = true;
      });
      return;
    }
    if (!value) {
      _isScrolling = false;
      return;
    }
    setState(() => _isScrolling = value);
  }

  @override
  void dispose() {
    _stopListeningForScrolling();
    if (_isVisible) widget.onVisibilityChanged(false, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey('gallery-visibility:${widget.visibilityKey}'),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > 0;
        if (visible) {
          widget.onVisibilityChanged(true, info.visibleBounds.top);
        } else if (_isVisible) {
          widget.onVisibilityChanged(false, 0);
        }
        if (_isVisible == visible) return;
        _isVisible = visible;
        if (visible && !_hasBeenVisible && !_isScrolling && mounted) {
          _stopListeningForScrolling();
          setState(() => _hasBeenVisible = true);
        }
      },
      child: widget.builder(context, _hasBeenVisible, _isScrolling),
    );
  }
}
