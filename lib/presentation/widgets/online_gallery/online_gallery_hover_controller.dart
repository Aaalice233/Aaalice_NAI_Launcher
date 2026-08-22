import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class OnlineGalleryHoverController {
  OverlayEntry? _entry;
  Timer? _showTimer;
  int _revision = 0;
  String? _stableKey;

  String? get activeStableKey => _stableKey;
  bool get isShowing => _entry != null;

  void schedule({
    required BuildContext context,
    required String stableKey,
    required LayerLink layerLink,
    required Rect targetRect,
    required Size previewSize,
    required WidgetBuilder builder,
    VoidCallback? onIntent,
    Duration delay = const Duration(milliseconds: 280),
  }) {
    onIntent?.call();
    dismiss();
    final revision = ++_revision;
    _stableKey = stableKey;
    _showTimer = Timer(delay, () {
      if (_revision != revision || _stableKey != stableKey) return;
      final overlay = Overlay.of(context, rootOverlay: true);
      _entry = OverlayEntry(
        builder: (overlayContext) {
          final mediaSize = MediaQuery.sizeOf(overlayContext);
          final safeWidth = (mediaSize.width - 20)
              .clamp(0.0, previewSize.width)
              .toDouble();
          final safeHeight = (mediaSize.height - 20)
              .clamp(0.0, previewSize.height)
              .toDouble();
          final renderObject = context.findRenderObject();
          final liveTargetRect =
              renderObject is RenderBox && renderObject.attached
              ? renderObject.localToGlobal(Offset.zero) & renderObject.size
              : targetRect;
          return Positioned.fill(
            child: IgnorePointer(
              child: CompositedTransformFollower(
                link: layerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.topLeft,
                followerAnchor: Alignment.topLeft,
                child: CustomSingleChildLayout(
                  delegate: _HoverFollowerLayoutDelegate(
                    targetRect: liveTargetRect,
                    viewportSize: mediaSize,
                    maxPreviewSize: Size(safeWidth, safeHeight),
                  ),
                  child: Builder(builder: builder),
                ),
              ),
            ),
          );
        },
      );
      overlay.insert(_entry!);
    });
  }

  void dismissFor(String stableKey) {
    if (_stableKey == stableKey) dismiss();
  }

  void dismiss() {
    _revision++;
    _showTimer?.cancel();
    _showTimer = null;
    _entry?.remove();
    _entry = null;
    _stableKey = null;
  }

  void dispose() => dismiss();
}

class _HoverFollowerLayoutDelegate extends SingleChildLayoutDelegate {
  const _HoverFollowerLayoutDelegate({
    required this.targetRect,
    required this.viewportSize,
    required this.maxPreviewSize,
  });

  final Rect targetRect;
  final Size viewportSize;
  final Size maxPreviewSize;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: maxPreviewSize.width,
        maxHeight: maxPreviewSize.height,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const gap = 12.0;
    const viewportMargin = 10.0;
    final fitsRight =
        targetRect.right + gap + childSize.width <=
        viewportSize.width - viewportMargin;
    final left = fitsRight ? targetRect.width + gap : -childSize.width - gap;
    final maxTop = max(
      viewportMargin,
      viewportSize.height - childSize.height - viewportMargin,
    );
    final top = (targetRect.center.dy - childSize.height / 2).clamp(
      viewportMargin,
      maxTop,
    );
    return Offset(left, top - targetRect.top);
  }

  @override
  bool shouldRelayout(covariant _HoverFollowerLayoutDelegate oldDelegate) =>
      targetRect != oldDelegate.targetRect ||
      viewportSize != oldDelegate.viewportSize ||
      maxPreviewSize != oldDelegate.maxPreviewSize;
}
