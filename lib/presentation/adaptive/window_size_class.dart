import 'package:flutter/material.dart';

/// Material-aligned window size classes based on the usable pane width.
enum WindowSizeClass {
  compact,
  medium,
  expanded;

  static WindowSizeClass fromWidth(double width) {
    if (width < 600) return WindowSizeClass.compact;
    if (width < 840) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }

  bool get isCompact => this == WindowSizeClass.compact;
  bool get isMedium => this == WindowSizeClass.medium;
  bool get isExpanded => this == WindowSizeClass.expanded;
}

@immutable
class AdaptiveWindowMetrics {
  const AdaptiveWindowMetrics({
    required this.size,
    required this.usableSize,
    required this.sizeClass,
  });

  factory AdaptiveWindowMetrics.of(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final usableWidth = (mediaQuery.size.width - mediaQuery.padding.horizontal)
        .clamp(0.0, double.infinity)
        .toDouble();
    final usableHeight = (mediaQuery.size.height - mediaQuery.padding.vertical)
        .clamp(0.0, double.infinity)
        .toDouble();
    final usableSize = Size(usableWidth, usableHeight);
    return AdaptiveWindowMetrics(
      size: mediaQuery.size,
      usableSize: usableSize,
      sizeClass: WindowSizeClass.fromWidth(usableWidth),
    );
  }

  final Size size;
  final Size usableSize;
  final WindowSizeClass sizeClass;

  bool get isCompact => sizeClass.isCompact;
  bool get isMedium => sizeClass.isMedium;
  bool get isExpanded => sizeClass.isExpanded;
}

extension AdaptiveWindowBuildContext on BuildContext {
  AdaptiveWindowMetrics get adaptiveWindow => AdaptiveWindowMetrics.of(this);
}

/// Keeps the app inside the largest unobstructed pane on dual-screen and
/// half-open foldables. Flat zero-width folds remain available as one canvas.
class LargestDisplayFeatureSubScreen extends StatelessWidget {
  const LargestDisplayFeatureSubScreen({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final avoidBounds = DisplayFeatureSubScreen.avoidBounds(
      mediaQuery,
    ).toList();
    if (avoidBounds.isEmpty) return child;

    final bounds = Offset.zero & mediaQuery.size;
    final subScreens = DisplayFeatureSubScreen.subScreensInBounds(
      bounds,
      avoidBounds,
    ).toList();
    if (subScreens.isEmpty) return child;

    final largest = subScreens.reduce(
      (current, candidate) =>
          candidate.width * candidate.height > current.width * current.height
          ? candidate
          : current,
    );
    final paneMediaQuery = mediaQuery
        .removeDisplayFeatures(largest)
        .copyWith(size: largest.size);
    return Padding(
      padding: EdgeInsets.only(
        left: largest.left,
        top: largest.top,
        right: mediaQuery.size.width - largest.right,
        bottom: mediaQuery.size.height - largest.bottom,
      ),
      child: MediaQuery(data: paneMediaQuery, child: child),
    );
  }
}
