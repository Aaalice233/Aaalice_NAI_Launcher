import 'dart:async';

import 'package:flutter/material.dart';

/// Each preview waits independently, including when another preview is open.
/// The exit delay lets the pointer cross the gap and scroll the preview.
class DelayedRichTooltip extends StatefulWidget {
  const DelayedRichTooltip({
    super.key,
    required this.content,
    required this.child,
  });

  final Widget content;
  final Widget child;

  @override
  State<DelayedRichTooltip> createState() => _DelayedRichTooltipState();
}

class _DelayedRichTooltipState extends State<DelayedRichTooltip> {
  static _DelayedRichTooltipState? _active;
  final _overlay = OverlayPortalController();
  Timer? _showTimer;
  Timer? _hideTimer;

  void _enter() {
    _active?._hide();
    _active = this;
    _hideTimer?.cancel();
    _showTimer?.cancel();
    _showTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _overlay.show();
    });
  }

  void _exit() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 300), _hide);
  }

  void _hide() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (_active == this) _active = null;
    if (mounted) _overlay.hide();
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (_active == this) _active = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal.overlayChildLayoutBuilder(
    controller: _overlay,
    overlayChildBuilder: (context, info) {
      final anchor = MatrixUtils.transformRect(
        info.childPaintTransform,
        Offset.zero & info.childSize,
      );
      return CustomSingleChildLayout(
        delegate: _PreviewPosition(anchor, MediaQuery.paddingOf(context)),
        child: MouseRegion(
          onEnter: (_) => _hideTimer?.cancel(),
          onExit: (_) => _exit(),
          child: widget.content,
        ),
      );
    },
    child: MouseRegion(
      onEnter: (_) => _enter(),
      onExit: (_) => _exit(),
      child: Listener(onPointerDown: (_) => _hide(), child: widget.child),
    ),
  );
}

class _PreviewPosition extends SingleChildLayoutDelegate {
  const _PreviewPosition(this.anchor, this.padding);
  final Rect anchor;
  final EdgeInsets padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.deflate(padding + const EdgeInsets.all(8)).loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final available = Size(
      size.width - padding.horizontal,
      size.height - padding.vertical,
    );
    return Offset(padding.left, padding.top) +
        positionDependentBox(
          size: available,
          childSize: childSize,
          target: anchor.center - Offset(padding.left, padding.top),
          verticalOffset: anchor.height / 2 + 8,
          preferBelow: true,
          margin: 8,
        );
  }

  @override
  bool shouldRelayout(_PreviewPosition oldDelegate) =>
      anchor != oldDelegate.anchor || padding != oldDelegate.padding;
}
