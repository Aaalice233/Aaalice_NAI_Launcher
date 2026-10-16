import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'adaptive_pinned_header_sliver.dart';

/// Where the footer of a scroll view led by an [AdaptivePinnedHeaderSliver]
/// goes: fixed below the scroll view while the header, the footer and
/// [AdaptivePinnedHeaderSliver.minContentExtent] all fit, otherwise last in
/// the scroll view.
@immutable
class AdaptiveChromePlacement {
  const AdaptiveChromePlacement({
    required this.footerFixed,
    required this.footerExtent,
  });

  // Scrolling never overflows, so it is the safe choice before measuring.
  static const unmeasured = AdaptiveChromePlacement(
    footerFixed: false,
    footerExtent: 0,
  );

  final bool footerFixed;
  final double footerExtent;

  /// The [AdaptivePinnedHeaderSliver.trailingExtent] that keeps the header
  /// pinned only together with the footer.
  double get trailingExtent => footerFixed ? 0 : footerExtent;

  @override
  bool operator ==(Object other) =>
      other is AdaptiveChromePlacement &&
      other.footerFixed == footerFixed &&
      other.footerExtent == footerExtent;

  @override
  int get hashCode => Object.hash(footerFixed, footerExtent);
}

/// Measures the header and footer whose extents decide the placement.
class AdaptiveChromeProbes {
  AdaptiveChromeProbes._(this._extents);

  final _ChromeExtents _extents;

  Widget header(Widget child) =>
      _ChromeExtentProbe(onLayout: _extents.recordHeader, child: child);

  Widget footer(Widget child) =>
      _ChromeExtentProbe(onLayout: _extents.recordFooter, child: child);
}

/// Builds a header, scroll view and footer for the footer placement that the
/// measured header and footer allow within the incoming height.
///
/// Wrap the header and footer with the given probes. A first layout, or a
/// header or footer that changed size, is laid out once more in the same frame
/// instead of being corrected on the next one.
class AdaptiveChromePlacementBuilder extends StatefulWidget {
  const AdaptiveChromePlacementBuilder({
    super.key,
    this.reservedExtent = 0,
    required this.builder,
  });

  /// Height the surroundings of the scroll view take while the footer is
  /// fixed, such as padding around it.
  final double reservedExtent;

  final Widget Function(
    BuildContext context,
    AdaptiveChromePlacement placement,
    AdaptiveChromeProbes probes,
  )
  builder;

  @override
  State<AdaptiveChromePlacementBuilder> createState() =>
      _AdaptiveChromePlacementBuilderState();
}

class _AdaptiveChromePlacementBuilderState
    extends State<AdaptiveChromePlacementBuilder> {
  final _extents = _ChromeExtents();
  late final _probes = AdaptiveChromeProbes._(_extents);

  @override
  Widget build(BuildContext context) {
    return _ChromePlacementBuilder(
      extents: _extents,
      reservedExtent: widget.reservedExtent,
      builder: (context, placement) =>
          widget.builder(context, placement, _probes),
    );
  }
}

/// The header and footer extents from their latest layout.
class _ChromeExtents {
  double? _header;
  double? _footer;

  void recordHeader(double extent) => _header = extent;

  void recordFooter(double extent) => _footer = extent;

  AdaptiveChromePlacement placementWithin(
    double availableExtent,
    double reservedExtent,
  ) {
    final header = _header;
    final footer = _footer;
    if (header == null || footer == null) {
      return AdaptiveChromePlacement.unmeasured;
    }
    return AdaptiveChromePlacement(
      footerFixed: AdaptivePinnedHeaderSliver.chromeFits(
        header + footer,
        availableExtent - reservedExtent,
      ),
      footerExtent: footer,
    );
  }
}

class _ChromePlacementBuilder
    extends AbstractLayoutBuilder<AdaptiveChromePlacement> {
  const _ChromePlacementBuilder({
    required this.extents,
    required this.reservedExtent,
    required this.builder,
  });

  final _ChromeExtents extents;
  final double reservedExtent;

  @override
  final Widget Function(BuildContext context, AdaptiveChromePlacement placement)
  builder;

  @override
  _RenderChromePlacement createRenderObject(BuildContext context) =>
      _RenderChromePlacement(extents, reservedExtent);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderChromePlacement renderObject,
  ) {
    renderObject
      ..extents = extents
      ..reservedExtent = reservedExtent;
  }
}

class _RenderChromePlacement extends RenderProxyBox
    with
        RenderObjectWithLayoutCallbackMixin,
        RenderAbstractLayoutBuilderMixin<AdaptiveChromePlacement, RenderBox> {
  _RenderChromePlacement(this.extents, this._reservedExtent);

  _ChromeExtents extents;
  AdaptiveChromePlacement _placement = AdaptiveChromePlacement.unmeasured;

  double get reservedExtent => _reservedExtent;
  double _reservedExtent;
  set reservedExtent(double value) {
    if (value == _reservedExtent) return;
    _reservedExtent = value;
    markNeedsLayout();
  }

  @override
  AdaptiveChromePlacement get layoutInfo => _placement;

  @override
  void performLayout() {
    _placement = _measuredPlacement();
    runLayoutCallback();
    child!.layout(constraints, parentUsesSize: true);
    final measured = _measuredPlacement();
    if (measured != _placement) {
      _placement = measured;
      runLayoutCallback();
      child!.layout(constraints, parentUsesSize: true);
    }
    size = constraints.constrain(child!.size);
  }

  AdaptiveChromePlacement _measuredPlacement() =>
      extents.placementWithin(constraints.maxHeight, _reservedExtent);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    assert(
      debugCannotComputeDryLayout(
        reason:
            'The footer placement depends on the laid out header and footer.',
      ),
    );
    return Size.zero;
  }
}

class _ChromeExtentProbe extends SingleChildRenderObjectWidget {
  const _ChromeExtentProbe({required this.onLayout, required super.child});

  final ValueSetter<double> onLayout;

  @override
  _RenderChromeExtentProbe createRenderObject(BuildContext context) =>
      _RenderChromeExtentProbe(onLayout);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderChromeExtentProbe renderObject,
  ) {
    renderObject.onLayout = onLayout;
  }
}

class _RenderChromeExtentProbe extends RenderProxyBox {
  _RenderChromeExtentProbe(this.onLayout);

  ValueSetter<double> onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout(size.height);
  }
}
