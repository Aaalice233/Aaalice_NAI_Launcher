import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderAbstractViewport, ScrollCacheExtent;
import 'package:visibility_detector/visibility_detector.dart';

import '../../../core/cache/online_gallery_preload_policy.dart';
import '../../providers/online_gallery_provider.dart';
import 'online_gallery_masonry_layout.dart';
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
      bool isVisible,
    );

void _revealImmediately(VoidCallback reveal) => reveal();

typedef OnlineGalleryGridFooterBuilder =
    Widget Function(BuildContext context, double itemWidth, int columnCount);

/// Responsive masonry grid. Item interaction is supplied as commands so this
/// leaf never reaches into the screen State.
class OnlineGalleryGrid extends StatelessWidget {
  const OnlineGalleryGrid({
    super.key,
    required this.state,
    required this.controller,
    required this.itemBuilder,
    this.footerBuilder,
  });

  final OnlineGalleryState state;
  final OnlineGalleryScreenController controller;
  final OnlineGalleryGridItemBuilder itemBuilder;
  final OnlineGalleryGridFooterBuilder? footerBuilder;

  int _placeholderCount({
    required double viewportHeight,
    required double itemWidth,
    required int columnCount,
    required double spacing,
  }) {
    if (!state.hasMore) return 0;
    // Keep the runway in the same geometry snapshot as loaded cards so page
    // appends replace stable slots instead of moving the viewport between
    // independently measured slivers.
    return controller.paginationDemand.placeholderCount(
      viewportDimension: viewportHeight,
      itemWidth: itemWidth,
      columnCount: columnCount,
      spacing: spacing,
      pageSize: onlineGalleryPageSize,
    );
  }

  Widget _buildFooterSliver(
    BuildContext context,
    double itemWidth,
    int columnCount,
  ) {
    final buildFooter = footerBuilder!;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, _) => buildFooter(context, itemWidth, columnCount),
          childCount: 1,
        ),
      ),
    );
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
        final viewportScope = state.randomEnabled
            ? 'random:${state.randomSession.scopeKey}'
            : state.currentCacheKey;
        final activeCache = state.randomEnabled
            ? state.randomSession.cache
            : state.currentCache;
        if (availableWidth <= 0 || constraints.maxHeight <= 0) {
          controller.markViewportUnavailable(
            scope: viewportScope,
            posts: state.posts,
          );
          return const SizedBox.shrink();
        }
        const minimumTileWidth = 140.0;
        final columnCount =
            ((availableWidth + spacing) / (minimumTileWidth + spacing))
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
        final showFooterBeforeRunway = activeCache.appendErrorCode != null;
        final placeholderCount = showFooterBeforeRunway
            ? 0
            : _placeholderCount(
                viewportHeight: viewportHeight,
                itemWidth: itemWidth,
                columnCount: columnCount,
                spacing: spacing,
              );
        controller.traceGridLayout(
          constraints: constraints,
          columnCount: columnCount,
          itemWidth: itemWidth,
          postCount: state.posts.length,
          placeholderCount: placeholderCount,
          cacheKey: state.currentCacheKey,
        );
        final layoutStopwatch = kDebugMode ? (Stopwatch()..start()) : null;
        final masonryLayout = OnlineGalleryMasonryLayoutSnapshot(
          aspectRatios: [
            for (final post in state.posts)
              post.width > 0 && post.height > 0
                  ? post.width / post.height
                  : 1.0,
          ],
          placeholderCount: placeholderCount,
          columnCount: columnCount,
          itemWidth: itemWidth,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
        );
        layoutStopwatch?.stop();
        controller.traceMasonrySnapshot(
          childCount: masonryLayout.childCount,
          maxScrollExtent: masonryLayout.maxScrollExtent,
          elapsed: layoutStopwatch?.elapsed ?? Duration.zero,
        );
        controller.prepareGridViewport(
          scope: viewportScope,
          cache: activeCache,
          posts: state.posts,
          layout: masonryLayout,
          columnCount: columnCount,
          itemWidth: itemWidth,
        );
        final slotKeyPrefix =
            'gallery-slot:$storageScope:${state.currentCacheKey}:';
        int? findSlotIndex(Key key) {
          if (key is! ValueKey<String> ||
              !key.value.startsWith(slotKeyPrefix)) {
            return null;
          }
          final index = int.tryParse(key.value.substring(slotKeyPrefix.length));
          final childCount = state.posts.length + placeholderCount;
          return index != null && index >= 0 && index < childCount
              ? index
              : null;
        }

        Widget buildSlot(BuildContext context, int index) {
          final pending = index >= state.posts.length;
          controller.recordGridSlotBuild(pending: pending);
          final slotKey = ValueKey<String>('$slotKeyPrefix$index');
          if (!pending) {
            return KeyedSubtree(
              key: slotKey,
              child: itemBuilder(context, index, itemWidth, columnCount),
            );
          }
          return OnlineGalleryPendingCard(key: slotKey, itemWidth: itemWidth);
        }

        return CustomScrollView(
          key: ValueKey<String>('online-gallery-scroll:$viewportScope'),
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
                state.posts.isEmpty && placeholderCount == 0 ? 0 : 6,
              ),
              sliver: SliverGrid(
                gridDelegate: OnlineGalleryMasonryGridDelegate(
                  snapshot: masonryLayout,
                ),
                delegate: SliverChildBuilderDelegate(
                  buildSlot,
                  childCount: state.posts.length + placeholderCount,
                  findChildIndexCallback: findSlotIndex,
                  addAutomaticKeepAlives: false,
                ),
              ),
            ),
            if (footerBuilder != null)
              _buildFooterSliver(context, itemWidth, columnCount),
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class OnlineGalleryVisibilityDrivenItem extends StatefulWidget {
  const OnlineGalleryVisibilityDrivenItem({
    super.key,
    required this.visibilityKey,
    required this.scrolling,
    this.initiallyLoadMedia = false,
    required this.onVisibilityChanged,
    this.onGeometryMeasured,
    this.onVisibilityTransition,
    this.onVisibilityDrivenRebuild,
    this.scheduleReveal = _revealImmediately,
    required this.builder,
  });

  final Object visibilityKey;
  final ValueListenable<bool> scrolling;
  final bool initiallyLoadMedia;
  final void Function(
    bool visible,
    double leadingScrollOffset,
    Object visibilityToken,
  )
  onVisibilityChanged;
  final ValueChanged<Duration>? onGeometryMeasured;
  final VoidCallback? onVisibilityTransition;
  final VoidCallback? onVisibilityDrivenRebuild;
  final void Function(VoidCallback reveal) scheduleReveal;
  final OnlineGalleryVisibilityItemBuilder builder;

  @override
  State<OnlineGalleryVisibilityDrivenItem> createState() =>
      OnlineGalleryVisibilityDrivenItemState();
}

class OnlineGalleryVisibilityDrivenItemState
    extends State<OnlineGalleryVisibilityDrivenItem> {
  final Object _visibilityToken = Object();
  bool _hasBeenVisible = false;
  bool _isVisible = false;
  late bool _isScrolling;
  bool _listensForScrolling = false;
  bool _revealQueued = false;

  @override
  void initState() {
    super.initState();
    _isScrolling = widget.scrolling.value;
    _hasBeenVisible = widget.initiallyLoadMedia && !_isScrolling;
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
    _isScrolling = value;
    if (_hasBeenVisible || !mounted) return;
    if (!value && _isVisible) {
      _queueReveal();
    }
  }

  void _queueReveal() {
    if (_hasBeenVisible || _revealQueued || !mounted) return;
    _revealQueued = true;
    widget.scheduleReveal(() {
      _revealQueued = false;
      if (!mounted || _hasBeenVisible) return;
      if (!_isVisible || _isScrolling) {
        _startListeningForScrolling();
        return;
      }
      _stopListeningForScrolling();
      widget.onVisibilityDrivenRebuild?.call();
      setState(() => _hasBeenVisible = true);
    });
  }

  @override
  void dispose() {
    _stopListeningForScrolling();
    if (_isVisible) {
      widget.onVisibilityChanged(false, 0, _visibilityToken);
    }
    super.dispose();
  }

  double _leadingScrollOffset() {
    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    try {
      final renderObject = context.findRenderObject();
      if (renderObject == null || !renderObject.attached) return 0;
      final viewport = RenderAbstractViewport.maybeOf(renderObject);
      return viewport?.getOffsetToReveal(renderObject, 0).offset ?? 0;
    } finally {
      if (stopwatch != null) {
        stopwatch.stop();
        widget.onGeometryMeasured?.call(stopwatch.elapsed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey(('gallery-visibility', widget.visibilityKey)),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > 0;
        if (visible) {
          widget.onVisibilityChanged(
            true,
            _leadingScrollOffset(),
            _visibilityToken,
          );
        } else if (_isVisible) {
          widget.onVisibilityChanged(false, 0, _visibilityToken);
        }
        if (_isVisible == visible) return;
        _isVisible = visible;
        widget.onVisibilityTransition?.call();
        if (visible && !_hasBeenVisible && !_isScrolling && mounted) {
          _queueReveal();
        }
      },
      child: widget.builder(context, _hasBeenVisible, _isScrolling, _isVisible),
    );
  }
}
