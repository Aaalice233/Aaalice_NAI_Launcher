import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'interaction_policy.dart';
import 'window_size_class.dart';

export 'window_size_class.dart' show WindowSizeClass;

/// Shared constraint breakpoints. These classify the space a component is
/// actually given; callers must not infer layout from the physical device.
abstract final class AdaptiveBreakpoints {
  static const double compact = WindowSizeClass.mediumMinWidth;
  static const double medium = WindowSizeClass.expandedMinWidth;
  static const double expanded = WindowSizeClass.wideMinWidth;
  static const double readableContentMaxWidth = 960;
  static const double workspaceContentMaxWidth = 1200;

  static WindowSizeClass classifyWidth(double width) =>
      WindowSizeClass.fromWidth(width);

  static double horizontalPadding(WindowSizeClass sizeClass) =>
      switch (sizeClass) {
        WindowSizeClass.compact => 12,
        WindowSizeClass.medium => 20,
        WindowSizeClass.expanded => 24,
        WindowSizeClass.wide => 32,
      };
}

typedef AdaptiveWidgetBuilder = Widget Function(BuildContext context);

/// Picks a layout branch from local constraints while allowing adjacent
/// classes to share the same implementation.
class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
    this.wide,
  });

  final AdaptiveWidgetBuilder compact;
  final AdaptiveWidgetBuilder? medium;
  final AdaptiveWidgetBuilder? expanded;
  final AdaptiveWidgetBuilder? wide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = AdaptiveBreakpoints.classifyWidth(
          constraints.maxWidth,
        );
        final builder = switch (sizeClass) {
          WindowSizeClass.compact => compact,
          WindowSizeClass.medium => medium ?? compact,
          WindowSizeClass.expanded => expanded ?? medium ?? compact,
          WindowSizeClass.wide => wide ?? expanded ?? medium ?? compact,
        };
        return builder(context);
      },
    );
  }
}

@immutable
class AdaptiveSlotAreas {
  const AdaptiveSlotAreas({
    required this.constraints,
    required this.sizeClass,
    required this.horizontalPadding,
    required this.workspaceContentMaxWidth,
    required this.minimumTargetExtent,
  });

  final BoxConstraints constraints;
  final WindowSizeClass sizeClass;
  final double horizontalPadding;
  final double workspaceContentMaxWidth;
  final double minimumTargetExtent;

  bool get isCompact => sizeClass.isCompact;
  bool get usesNavigationRail => !sizeClass.isCompact;

  bool canFitSupportingPane({
    required double mainMinimumWidth,
    required double supportingMinimumWidth,
    double gap = 16,
  }) {
    final usableWidth = math.max(
      0,
      constraints.maxWidth - horizontalPadding * 2,
    );
    return usableWidth >= mainMinimumWidth + supportingMinimumWidth + gap;
  }
}

/// Computes the shared page slots from local constraints and current input
/// capabilities. Pages consume these values instead of re-declaring widths.
class AdaptiveSlotLayout extends StatelessWidget {
  const AdaptiveSlotLayout({super.key, required this.builder});

  final Widget Function(BuildContext context, AdaptiveSlotAreas areas) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = AdaptiveBreakpoints.classifyWidth(
          constraints.maxWidth,
        );
        final horizontalPadding = AdaptiveBreakpoints.horizontalPadding(
          sizeClass,
        );
        return builder(
          context,
          AdaptiveSlotAreas(
            constraints: constraints,
            sizeClass: sizeClass,
            horizontalPadding: horizontalPadding,
            workspaceContentMaxWidth: math.min(
              AdaptiveBreakpoints.workspaceContentMaxWidth,
              math.max(0, constraints.maxWidth - horizontalPadding * 2),
            ),
            minimumTargetExtent: context.interactionPolicy.minimumControlExtent,
          ),
        );
      },
    );
  }
}

/// Centers readable content without forcing full-width controls on large
/// windows. Compact content remains edge-to-edge within its page padding.
class AdaptiveContentBounds extends StatelessWidget {
  const AdaptiveContentBounds({
    super.key,
    required this.child,
    this.maxWidth = AdaptiveBreakpoints.readableContentMaxWidth,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
