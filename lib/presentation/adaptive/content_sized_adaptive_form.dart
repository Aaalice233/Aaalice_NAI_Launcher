import 'package:flutter/material.dart';

import 'adaptive_chrome_placement.dart';
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
///
/// In debug builds a body that never reads the header is reported after its
/// first frame, since the panel title and close button would be missing.
class AdaptivePanelHeaderScope extends InheritedWidget {
  const AdaptivePanelHeaderScope({
    super.key,
    required this.header,
    required super.child,
  });

  final Widget header;

  static Widget? maybeHeaderOf(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AdaptivePanelHeaderScope>();
    if (element is! _AdaptivePanelHeaderScopeElement) return null;
    context.dependOnInheritedElement(element);
    element.debugMarkHosted();
    return element.widget.header;
  }

  @override
  InheritedElement createElement() => _AdaptivePanelHeaderScopeElement(this);

  @override
  bool updateShouldNotify(AdaptivePanelHeaderScope oldWidget) =>
      header != oldWidget.header;
}

class _AdaptivePanelHeaderScopeElement extends InheritedElement {
  _AdaptivePanelHeaderScopeElement(AdaptivePanelHeaderScope super.widget);

  bool _debugHosted = false;

  @override
  AdaptivePanelHeaderScope get widget =>
      super.widget as AdaptivePanelHeaderScope;

  void debugMarkHosted() {
    assert(() {
      _debugHosted = true;
      return true;
    }());
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    assert(() {
      // Bodies behind a LayoutBuilder only build during layout, so check after
      // the first frame instead of right after this subtree builds.
      WidgetsBinding.instance.addPostFrameCallback((_) => _debugCheckHosted());
      return true;
    }());
  }

  void _debugCheckHosted() {
    if (!mounted || _debugHosted) return;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: FlutterError.fromParts([
          ErrorSummary('The adaptive panel header was never hosted.'),
          ErrorDescription(
            'AdaptivePresenter.showForm(headerScrollsWithContent: true) hands '
            'the title and close button to the body through '
            'AdaptivePanelHeaderScope, and this body never read it, so the '
            'panel shows neither.',
          ),
          ErrorHint(
            'Build the body with ContentSizedAdaptiveForm, or put '
            'AdaptivePanelHeaderScope.maybeHeaderOf(context) first in its '
            'scroll view.',
          ),
        ]),
        library: 'adaptive presenter',
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    return AdaptiveChromePlacementBuilder(
      builder: (context, placement, probes) => _buildForm(placement, probes),
    );
  }

  Widget _buildForm(
    AdaptiveChromePlacement placement,
    AdaptiveChromeProbes probes,
  ) {
    final footer = widget.footer == null
        ? null
        : probes.footer(KeyedSubtree(key: _footerKey, child: widget.footer!));
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
                child: probes.header(widget.header),
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
