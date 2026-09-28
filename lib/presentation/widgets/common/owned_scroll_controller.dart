import 'package:flutter/material.dart';

/// Keeps one bounded viewport offset above transient ScrollPosition instances.
/// Invalid zero-sized layouts never replace the last usable position.
class OwnedViewportOffset {
  double _pixels = 0;
  bool _hasValue = false;

  bool get hasValue => _hasValue;
  double get pixels => _hasValue ? _pixels : 0;

  void replace(double pixels) {
    if (!pixels.isFinite) return;
    _pixels = pixels < 0 ? 0 : pixels;
    _hasValue = true;
  }

  void record(ScrollMetrics metrics) {
    if (!hasUsableViewport(metrics)) return;
    replace(metrics.pixels);
  }

  static bool hasUsableViewport(ScrollMetrics metrics) =>
      metrics.hasPixels &&
      metrics.hasContentDimensions &&
      metrics.viewportDimension > 0 &&
      metrics.pixels.isFinite;
}

/// A ScrollController whose owner, rather than PageStorage, owns restoration.
///
/// New positions start at the last valid offset. A caller that can translate a
/// stable item anchor after a responsive geometry change may also request a
/// correction during sliver layout, before the restored frame is painted.
class OwnedScrollController extends ScrollController {
  OwnedScrollController({OwnedViewportOffset? viewport})
    : viewport = viewport ?? OwnedViewportOffset(),
      super(keepScrollOffset: false);

  final OwnedViewportOffset viewport;
  final Set<ScrollPosition> _positions = <ScrollPosition>{};
  ScrollPosition? _activePosition;
  double? _layoutRestoreOffset;

  @override
  ScrollPosition get position => _activePosition ?? super.position;

  void restoreDuringLayout(double pixels) {
    if (!pixels.isFinite) return;
    _layoutRestoreOffset = pixels < 0 ? 0 : pixels;
  }

  void clearLayoutRestore() {
    _layoutRestoreOffset = null;
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _OwnedScrollPosition(
    physics: physics,
    context: context,
    initialPixels: _layoutRestoreOffset ?? viewport.pixels,
    oldPosition: oldPosition,
    controller: this,
  );

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    _positions.add(position);
    _activePosition = position;
    position.addListener(_recordActivePosition);
  }

  @override
  void detach(ScrollPosition position) {
    if (identical(position, _activePosition)) {
      viewport.record(position);
    }
    position.removeListener(_recordActivePosition);
    _positions.remove(position);
    if (identical(position, _activePosition)) {
      _activePosition = _positions.isEmpty ? null : _positions.last;
    }
    super.detach(position);
  }

  void _recordActivePosition() {
    final activePosition = _activePosition;
    if (activePosition != null) viewport.record(activePosition);
  }

  double? _takeLayoutRestoreOffset({
    required double minScrollExtent,
    required double maxScrollExtent,
    required double viewportDimension,
  }) {
    final requested = _layoutRestoreOffset;
    if (requested == null || viewportDimension <= 0) return null;
    _layoutRestoreOffset = null;
    return requested.clamp(minScrollExtent, maxScrollExtent).toDouble();
  }
}

class _OwnedScrollPosition extends ScrollPositionWithSingleContext {
  _OwnedScrollPosition({
    required super.physics,
    required super.context,
    required super.initialPixels,
    required this.controller,
    super.oldPosition,
  }) : super(keepScrollOffset: false);

  final OwnedScrollController controller;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final accepted = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    final target = controller._takeLayoutRestoreOffset(
      minScrollExtent: minScrollExtent,
      maxScrollExtent: maxScrollExtent,
      viewportDimension: viewportDimension,
    );
    if (target == null || (pixels - target).abs() < 0.5) return accepted;
    correctPixels(target);
    controller.viewport.replace(target);
    return false;
  }
}
