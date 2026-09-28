import 'package:flutter/material.dart';

/// App-wide window size classes based on the safe usable pane width.
enum WindowSizeClass {
  compact,
  medium,
  expanded,
  wide;

  static const double mediumMinWidth = 600;
  static const double expandedMinWidth = 840;
  static const double wideMinWidth = 1180;

  static WindowSizeClass fromWidth(double width) {
    if (width.isNaN || width < mediumMinWidth) {
      return WindowSizeClass.compact;
    }
    if (width < expandedMinWidth) return WindowSizeClass.medium;
    if (width < wideMinWidth) return WindowSizeClass.expanded;
    return WindowSizeClass.wide;
  }

  bool get isCompact => this == WindowSizeClass.compact;
  bool get isMedium => this == WindowSizeClass.medium;
  bool get isExpanded => this == WindowSizeClass.expanded;
  bool get isWide => this == WindowSizeClass.wide;
  bool get isExpandedOrWider => index >= WindowSizeClass.expanded.index;
}

@immutable
class AdaptiveWindowMetrics {
  const AdaptiveWindowMetrics({
    required this.paneSize,
    required this.safeUsableSize,
    required this.unobscuredSize,
    required this.safePadding,
    required this.viewInsets,
    required this.sizeClass,
  });

  factory AdaptiveWindowMetrics.of(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safeUsableWidth =
        (mediaQuery.size.width - mediaQuery.padding.horizontal)
            .clamp(0.0, double.infinity)
            .toDouble();
    final safeUsableHeight =
        (mediaQuery.size.height - mediaQuery.padding.vertical)
            .clamp(0.0, double.infinity)
            .toDouble();
    final safeUsableSize = Size(safeUsableWidth, safeUsableHeight);
    return AdaptiveWindowMetrics(
      paneSize: mediaQuery.size,
      safeUsableSize: safeUsableSize,
      unobscuredSize: Size(
        (safeUsableWidth - mediaQuery.viewInsets.horizontal)
            .clamp(0.0, double.infinity)
            .toDouble(),
        (safeUsableHeight - mediaQuery.viewInsets.vertical)
            .clamp(0.0, double.infinity)
            .toDouble(),
      ),
      safePadding: mediaQuery.padding,
      viewInsets: mediaQuery.viewInsets,
      // The software keyboard must not change the horizontal layout class.
      sizeClass: WindowSizeClass.fromWidth(safeUsableWidth),
    );
  }

  /// Size of the unobstructed pane selected by the app root.
  final Size paneSize;

  /// Pane size after system safe-area padding, before software keyboard insets.
  final Size safeUsableSize;

  /// Safe usable size currently visible above platform view insets.
  final Size unobscuredSize;
  final EdgeInsets safePadding;
  final EdgeInsets viewInsets;
  final WindowSizeClass sizeClass;

  /// Backwards-compatible aliases while callers migrate to explicit names.
  Size get size => paneSize;
  Size get usableSize => safeUsableSize;

  bool get isCompact => sizeClass.isCompact;
  bool get isMedium => sizeClass.isMedium;
  bool get isExpanded => sizeClass.isExpanded;
  bool get isWide => sizeClass.isWide;
  bool get isExpandedOrWider => sizeClass.isExpandedOrWider;
}

extension AdaptiveWindowBuildContext on BuildContext {
  AdaptiveWindowMetrics get adaptiveWindow => AdaptiveWindowMetrics.of(this);
}

EdgeInsets _insetsWithinPane(EdgeInsets insets, Size fullSize, Rect pane) {
  double bounded(double value, double maximum) =>
      value.clamp(0.0, maximum).toDouble();

  return EdgeInsets.fromLTRB(
    bounded(insets.left - pane.left, pane.width),
    bounded(insets.top - pane.top, pane.height),
    bounded(pane.right - (fullSize.width - insets.right), pane.width),
    bounded(pane.bottom - (fullSize.height - insets.bottom), pane.height),
  );
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
        .copyWith(
          size: largest.size,
          padding: _insetsWithinPane(
            mediaQuery.padding,
            mediaQuery.size,
            largest,
          ),
          viewPadding: _insetsWithinPane(
            mediaQuery.viewPadding,
            mediaQuery.size,
            largest,
          ),
          viewInsets: _insetsWithinPane(
            mediaQuery.viewInsets,
            mediaQuery.size,
            largest,
          ),
          systemGestureInsets: _insetsWithinPane(
            mediaQuery.systemGestureInsets,
            mediaQuery.size,
            largest,
          ),
        );
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
