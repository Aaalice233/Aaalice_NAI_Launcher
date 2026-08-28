import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../core/cache/online_gallery_preload_policy.dart';
import '../../providers/online_gallery_provider.dart';
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
        return MasonryGridView.count(
          key: PageStorageKey<String>(
            'online_gallery_$storageScope:${state.currentCacheKey}',
          ),
          controller: controller.scrollController,
          cacheExtent: OnlineGalleryPreloadPolicy.cacheExtent(viewportHeight),
          padding: const EdgeInsets.all(12),
          crossAxisCount: columnCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          itemCount: state.posts.length + 1,
          itemBuilder: (context, index) =>
              itemBuilder(context, index, itemWidth, columnCount),
        );
      },
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
    if (!_hasBeenVisible && value && mounted) {
      setState(() => _isScrolling = value);
    } else {
      _isScrolling = value;
    }
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
        if (visible && !_hasBeenVisible && mounted) {
          _stopListeningForScrolling();
          setState(() => _hasBeenVisible = true);
        }
      },
      child: widget.builder(context, _hasBeenVisible, _isScrolling),
    );
  }
}
