import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'adaptive_pinned_header_sliver.dart';

/// A form body that follows its content until the presenter-imposed height cap
/// is reached, then scrolls without moving the footer off-screen.
///
/// Use this for short and medium editing forms shown by
/// [AdaptivePresenter.showForm]. Long collections and workspace-like dialogs
/// should keep an explicitly viewport-sized layout instead.
class ContentSizedAdaptiveForm extends StatelessWidget {
  const ContentSizedAdaptiveForm({
    super.key,
    required this.scrollController,
    required this.content,
    this.footer,
    this.scrollViewKey,
    this.padding = const EdgeInsets.all(16),
  });

  final ScrollController? scrollController;
  final List<Widget> content;

  /// Omit when actions should scroll together with the content on short screens.
  final Widget? footer;
  final Key? scrollViewKey;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final hostedHeader = AdaptivePanelHeaderScope.maybeHeaderOf(context);
    if (hostedHeader != null) {
      return _HostedHeaderForm(
        header: hostedHeader,
        scrollController: scrollController,
        content: content,
        footer: footer,
        scrollViewKey: scrollViewKey,
        padding: padding,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: ListView(
            key: scrollViewKey,
            controller: scrollController,
            shrinkWrap: true,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: padding,
            children: content,
          ),
        ),
        if (footer != null) footer!,
      ],
    );
  }
}

/// Hands the panel header of [AdaptivePresenter.showForm] to the body below
/// it, which places it first in its only scroll view; [ContentSizedAdaptiveForm]
/// does so automatically.
class AdaptivePanelHeaderScope extends InheritedWidget {
  const AdaptivePanelHeaderScope({
    super.key,
    required this.header,
    required super.child,
  });

  final Widget header;

  static Widget? maybeHeaderOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AdaptivePanelHeaderScope>()
      ?.header;

  @override
  bool updateShouldNotify(AdaptivePanelHeaderScope oldWidget) =>
      header != oldWidget.header;
}

/// Pins the hosted header and keeps the footer below the scroll view while
/// both leave [AdaptivePinnedHeaderSliver.minContentExtent] for the content;
/// on shorter viewports both scroll with it.
class _HostedHeaderForm extends StatefulWidget {
  const _HostedHeaderForm({
    required this.header,
    required this.scrollController,
    required this.content,
    required this.footer,
    required this.scrollViewKey,
    required this.padding,
  });

  final Widget header;
  final ScrollController? scrollController;
  final List<Widget> content;
  final Widget? footer;
  final Key? scrollViewKey;
  final EdgeInsetsGeometry padding;

  @override
  State<_HostedHeaderForm> createState() => _HostedHeaderFormState();
}

class _HostedHeaderFormState extends State<_HostedHeaderForm> {
  final _footerKey = GlobalKey();
  final _extents = _ChromeExtents();

  @override
  Widget build(BuildContext context) {
    return _ChromePlacementBuilder(
      extents: _extents,
      builder: (context, placement) => _buildForm(placement),
    );
  }

  Widget _buildForm(_ChromePlacement placement) {
    final footer = widget.footer == null
        ? null
        : _ChromeExtentProbe(
            onLayout: _extents.recordFooter,
            child: KeyedSubtree(key: _footerKey, child: widget.footer!),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: CustomScrollView(
            key: widget.scrollViewKey,
            controller: widget.scrollController,
            shrinkWrap: true,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              AdaptivePinnedHeaderSliver(
                trailingExtent: footer == null ? 0 : placement.trailingExtent,
                child: _ChromeExtentProbe(
                  onLayout: _extents.recordHeader,
                  child: widget.header,
                ),
              ),
              SliverPadding(
                padding: widget.padding,
                sliver: SliverList.list(children: widget.content),
              ),
              if (footer != null && !placement.footerFixed)
                SliverToBoxAdapter(child: footer),
            ],
          ),
        ),
        if (footer != null && placement.footerFixed) footer,
      ],
    );
  }
}

@immutable
class _ChromePlacement {
  const _ChromePlacement({
    required this.footerFixed,
    required this.footerExtent,
  });

  // Scrolling never overflows, so it is the safe choice before measuring.
  static const unmeasured = _ChromePlacement(
    footerFixed: false,
    footerExtent: 0,
  );

  final bool footerFixed;
  final double footerExtent;

  double get trailingExtent => footerFixed ? 0 : footerExtent;

  @override
  bool operator ==(Object other) =>
      other is _ChromePlacement &&
      other.footerFixed == footerFixed &&
      other.footerExtent == footerExtent;

  @override
  int get hashCode => Object.hash(footerFixed, footerExtent);
}

/// The header and footer extents from their latest layout.
class _ChromeExtents {
  double? _header;
  double? _footer;

  void recordHeader(double extent) => _header = extent;

  void recordFooter(double extent) => _footer = extent;

  _ChromePlacement placementWithin(double availableExtent) {
    final header = _header;
    final footer = _footer;
    if (header == null || footer == null) return _ChromePlacement.unmeasured;
    return _ChromePlacement(
      footerFixed: AdaptivePinnedHeaderSliver.chromeFits(
        header + footer,
        availableExtent,
      ),
      footerExtent: footer,
    );
  }
}

/// Builds the form for the footer placement that the measured chrome allows
/// within the incoming height.
class _ChromePlacementBuilder extends AbstractLayoutBuilder<_ChromePlacement> {
  const _ChromePlacementBuilder({required this.extents, required this.builder});

  final _ChromeExtents extents;

  @override
  final Widget Function(BuildContext context, _ChromePlacement placement)
  builder;

  @override
  _RenderChromePlacement createRenderObject(BuildContext context) =>
      _RenderChromePlacement(extents);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderChromePlacement renderObject,
  ) {
    renderObject.extents = extents;
  }
}

class _RenderChromePlacement extends RenderProxyBox
    with
        RenderObjectWithLayoutCallbackMixin,
        RenderAbstractLayoutBuilderMixin<_ChromePlacement, RenderBox> {
  _RenderChromePlacement(this.extents);

  _ChromeExtents extents;
  _ChromePlacement _placement = _ChromePlacement.unmeasured;

  @override
  _ChromePlacement get layoutInfo => _placement;

  @override
  void performLayout() {
    _placement = extents.placementWithin(constraints.maxHeight);
    runLayoutCallback();
    child!.layout(constraints, parentUsesSize: true);
    // The first layout, or a header or footer that changed size, can only be
    // placed once it has been measured, so build and lay out once more.
    final measured = extents.placementWithin(constraints.maxHeight);
    if (measured != _placement) {
      _placement = measured;
      runLayoutCallback();
      child!.layout(constraints, parentUsesSize: true);
    }
    size = constraints.constrain(child!.size);
  }

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
