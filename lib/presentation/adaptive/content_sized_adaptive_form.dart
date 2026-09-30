import 'package:flutter/material.dart';

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

/// Pins the hosted header while the panel has room and lets it scroll away on
/// short viewports, where the footer also scrolls after the content.
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
  static const double _minHeightForFixedFooter = 320;

  final _footerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final footer = widget.footer == null
            ? null
            : KeyedSubtree(key: _footerKey, child: widget.footer!);
        final footerScrolls =
            footer != null && constraints.maxHeight < _minHeightForFixedFooter;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: CustomScrollView(
                key: widget.scrollViewKey,
                controller: widget.scrollController,
                shrinkWrap: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  AdaptivePinnedHeaderSliver(child: widget.header),
                  SliverPadding(
                    padding: widget.padding,
                    sliver: SliverList.list(children: widget.content),
                  ),
                  if (footerScrolls) SliverToBoxAdapter(child: footer),
                ],
              ),
            ),
            if (footer != null && !footerScrolls) footer,
          ],
        );
      },
    );
  }
}
