import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

@immutable
class OnlineGalleryMasonryPlacement {
  const OnlineGalleryMasonryPlacement({
    required this.column,
    required this.scrollOffset,
    required this.mainAxisExtent,
  });

  final int column;
  final double scrollOffset;
  final double mainAxisExtent;

  double get trailingScrollOffset => scrollOffset + mainAxisExtent;
}

/// Immutable geometry for one online-gallery masonry layout.
///
/// Unlike measurement-driven masonry renderers, this snapshot knows every
/// slot's geometry before any widget is built. Flutter's native SliverGrid can
/// therefore jump directly to the viewport/cache neighborhood instead of
/// constructing every tile crossed by a fast scroll.
@immutable
class OnlineGalleryMasonryLayoutSnapshot {
  OnlineGalleryMasonryLayoutSnapshot({
    required List<double> aspectRatios,
    required this.placeholderCount,
    required this.columnCount,
    required this.itemWidth,
    required this.mainAxisSpacing,
    required this.crossAxisSpacing,
  }) : assert(placeholderCount >= 0),
       assert(columnCount > 0),
       assert(itemWidth >= 0),
       assert(mainAxisSpacing >= 0),
       assert(crossAxisSpacing >= 0),
       _loadedCount = aspectRatios.length {
    final columnEnds = List<double>.filled(columnCount, 0);
    final placements = <OnlineGalleryMasonryPlacement>[];
    final leadingOffsets = <double>[];
    final prefixMaxTrailingOffsets = <double>[];
    var prefixMaxTrailing = 0.0;

    final childCount = aspectRatios.length + placeholderCount;
    for (var index = 0; index < childCount; index++) {
      var column = 0;
      for (var candidate = 1; candidate < columnCount; candidate++) {
        if (columnEnds[candidate] < columnEnds[column]) column = candidate;
      }
      final aspectRatio = index < aspectRatios.length
          ? aspectRatios[index]
          : 1.0;
      final extent = mainAxisExtentFor(
        itemWidth: itemWidth,
        aspectRatio: aspectRatio,
      );
      final leading = columnEnds[column];
      final placement = OnlineGalleryMasonryPlacement(
        column: column,
        scrollOffset: leading,
        mainAxisExtent: extent,
      );
      placements.add(placement);
      leadingOffsets.add(leading);
      prefixMaxTrailing = math.max(
        prefixMaxTrailing,
        placement.trailingScrollOffset,
      );
      prefixMaxTrailingOffsets.add(prefixMaxTrailing);
      columnEnds[column] = placement.trailingScrollOffset + mainAxisSpacing;
    }

    _placements = List.unmodifiable(placements);
    _leadingOffsets = List.unmodifiable(leadingOffsets);
    _prefixMaxTrailingOffsets = List.unmodifiable(prefixMaxTrailingOffsets);
    maxScrollExtent = prefixMaxTrailing;
  }

  final int placeholderCount;
  final int columnCount;
  final double itemWidth;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final int _loadedCount;
  late final List<OnlineGalleryMasonryPlacement> _placements;
  late final List<double> _leadingOffsets;
  late final List<double> _prefixMaxTrailingOffsets;
  late final double maxScrollExtent;

  int get childCount => _placements.length;
  int get loadedCount => _loadedCount;

  OnlineGalleryMasonryPlacement placementFor(int index) => _placements[index];

  static double mainAxisExtentFor({
    required double itemWidth,
    required double aspectRatio,
  }) {
    final safeAspectRatio = aspectRatio.isFinite && aspectRatio > 0
        ? aspectRatio
        : 1.0;
    return (itemWidth / safeAspectRatio).clamp(80.0, itemWidth * 2.5);
  }

  int minIndexForScrollOffset(double scrollOffset) {
    if (_placements.isEmpty || scrollOffset <= 0) return 0;
    var low = 0;
    var high = _prefixMaxTrailingOffsets.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (_prefixMaxTrailingOffsets[middle] >= scrollOffset) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }
    return low.clamp(0, _placements.length - 1);
  }

  int maxIndexForScrollOffset(double scrollOffset) {
    if (_placements.isEmpty || scrollOffset <= 0) return 0;
    var low = 0;
    var high = _leadingOffsets.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (_leadingOffsets[middle] <= scrollOffset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return (low - 1).clamp(0, _placements.length - 1);
  }

  double maxScrollOffsetForChildCount(int childCount) {
    if (childCount <= 0 || _prefixMaxTrailingOffsets.isEmpty) return 0;
    final lastIndex =
        math.min(childCount, _prefixMaxTrailingOffsets.length) - 1;
    return _prefixMaxTrailingOffsets[lastIndex];
  }
}

class OnlineGalleryMasonryGridDelegate extends SliverGridDelegate {
  const OnlineGalleryMasonryGridDelegate({required this.snapshot});

  final OnlineGalleryMasonryLayoutSnapshot snapshot;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    return OnlineGalleryMasonrySliverLayout(
      snapshot: snapshot,
      crossAxisExtent: constraints.crossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(OnlineGalleryMasonryGridDelegate oldDelegate) =>
      oldDelegate.snapshot != snapshot;
}

class OnlineGalleryMasonrySliverLayout extends SliverGridLayout {
  const OnlineGalleryMasonrySliverLayout({
    required this.snapshot,
    required this.crossAxisExtent,
    required this.reverseCrossAxis,
  });

  final OnlineGalleryMasonryLayoutSnapshot snapshot;
  final double crossAxisExtent;
  final bool reverseCrossAxis;

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) =>
      snapshot.minIndexForScrollOffset(scrollOffset);

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) =>
      snapshot.maxIndexForScrollOffset(scrollOffset);

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    if (snapshot.childCount == 0) {
      return SliverGridGeometry(
        scrollOffset: 0,
        crossAxisOffset: 0,
        mainAxisExtent: snapshot.itemWidth,
        crossAxisExtent: snapshot.itemWidth,
      );
    }
    final placement = snapshot.placementFor(index);
    final logicalCrossAxisOffset =
        placement.column * (snapshot.itemWidth + snapshot.crossAxisSpacing);
    final crossAxisOffset = reverseCrossAxis
        ? crossAxisExtent - logicalCrossAxisOffset - snapshot.itemWidth
        : logicalCrossAxisOffset;
    return SliverGridGeometry(
      scrollOffset: placement.scrollOffset,
      crossAxisOffset: crossAxisOffset,
      mainAxisExtent: placement.mainAxisExtent,
      crossAxisExtent: snapshot.itemWidth,
    );
  }

  @override
  double computeMaxScrollOffset(int childCount) =>
      snapshot.maxScrollOffsetForChildCount(childCount);
}
