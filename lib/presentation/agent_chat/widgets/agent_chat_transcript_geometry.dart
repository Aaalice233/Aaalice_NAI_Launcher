import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// Average-based extrapolation jumps whenever a tall turn enters the window.
class AgentChatTranscriptChildDelegate extends SliverChildBuilderDelegate {
  AgentChatTranscriptChildDelegate(
    super.builder, {
    required int super.childCount,
    required this.measuredExtentOf,
    required this.unmeasuredExtent,
  });

  final double? Function(int index) measuredExtentOf;

  // Read during layout so heights measured earlier in the same pass count.
  final double Function() unmeasuredExtent;

  @override
  double? estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) {
    final count = estimatedChildCount;
    if (count == null) return null;
    final fallback = unmeasuredExtent();
    var extent = 0.0;
    for (var index = 0; index < count; index++) {
      extent += measuredExtentOf(index) ?? fallback;
    }
    // SliverList asserts the estimate never ends before laid-out content.
    return math.max(extent, trailingScrollOffset);
  }

  // Median: one huge or still-streaming turn must not inflate every estimate.
  static double medianExtent(
    Iterable<double> extents, {
    required double whenEmpty,
  }) {
    final sorted = extents.where((extent) => extent > 0).toList()..sort();
    if (sorted.isEmpty) return whenEmpty;
    return sorted[sorted.length ~/ 2];
  }
}

// Scroll-coordinate metric: scrolling never reads as drift, only resizing.
class AgentChatPausedDriftCorrection {
  AgentChatPausedDriftCorrection({
    required bool Function() isEnabled,
    required double Function() minimumCorrection,
  }) : _isEnabled = isEnabled,
       _minimumCorrection = minimumCorrection;

  static const double _tolerance = 0.5;

  final bool Function() _isEnabled;
  final double Function() _minimumCorrection;
  double? Function()? _readMetric;
  double? _referenceMetric;

  void track(double? Function() readMetric) {
    final metric = readMetric();
    _readMetric = metric == null ? null : readMetric;
    _referenceMetric = metric;
  }

  void clear() {
    _readMetric = null;
    _referenceMetric = null;
  }

  // The list's own correction already moves the anchor and pixels together.
  void rebase(double correction) {
    final reference = _referenceMetric;
    if (reference == null) return;
    _referenceMetric = reference + correction;
  }

  double? takeCorrection() {
    final readMetric = _readMetric;
    final reference = _referenceMetric;
    if (readMetric == null || reference == null || !_isEnabled()) return null;
    final current = readMetric();
    if (current == null) return null;
    final drift = current - reference;
    if (drift.abs() < _tolerance) return null;
    _referenceMetric = current;
    // Shrinking below the live edge would overscroll and bounce back.
    final correction = math.max(drift, _minimumCorrection());
    return correction.abs() < _tolerance ? null : correction;
  }

  // Parent data only: reading a grandchild size during layout asserts.
  static double? topEdgeOf(RenderObject? descendant, double? measuredHeight) {
    if (measuredHeight == null || descendant == null || !descendant.attached) {
      return null;
    }
    RenderObject? node = descendant;
    while (node != null && node.parent is! RenderSliver) {
      node = node.parent;
    }
    final parentData = node?.parentData;
    if (parentData is! SliverMultiBoxAdaptorParentData ||
        parentData.keptAlive) {
      return null;
    }
    final layoutOffset = parentData.layoutOffset;
    return layoutOffset == null ? null : layoutOffset + measuredHeight;
  }
}

// Correcting inside layout avoids painting one frame at the drifted offset.
class AgentChatDriftCorrectingSliver extends SingleChildRenderObjectWidget {
  const AgentChatDriftCorrectingSliver({
    super.key,
    required this.drift,
    required Widget sliver,
  }) : super(child: sliver);

  final AgentChatPausedDriftCorrection drift;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAgentChatDriftCorrectingSliver(drift);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderAgentChatDriftCorrectingSliver renderObject,
  ) {
    renderObject.drift = drift;
  }
}

class RenderAgentChatDriftCorrectingSliver extends RenderProxySliver {
  RenderAgentChatDriftCorrectingSliver(this.drift);

  AgentChatPausedDriftCorrection drift;

  @override
  void performLayout() {
    super.performLayout();
    final listCorrection = geometry?.scrollOffsetCorrection;
    if (listCorrection != null) {
      drift.rebase(listCorrection);
      return;
    }
    final correction = drift.takeCorrection();
    if (correction == null) return;
    geometry = SliverGeometry(scrollOffsetCorrection: correction);
  }
}
