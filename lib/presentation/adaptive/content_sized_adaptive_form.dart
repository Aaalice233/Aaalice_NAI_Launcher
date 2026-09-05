import 'package:flutter/material.dart';

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
