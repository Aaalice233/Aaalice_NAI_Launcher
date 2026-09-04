import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

enum CardHoverPreviewVerticalAlignment { center, targetTop }

/// 在根 Overlay 中显示卡片悬浮预览，并自动避让窗口边缘。
class CardHoverPreviewController {
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
    CardHoverPreviewVerticalAlignment verticalAlignment =
        CardHoverPreviewVerticalAlignment.center,
    Duration delay = const Duration(milliseconds: 280),
  }) {
    onIntent?.call();
    dismiss();
    final revision = ++_revision;
    _stableKey = stableKey;
    _showTimer = Timer(delay, () {
      if (_revision != revision ||
          _stableKey != stableKey ||
          !context.mounted) {
        return;
      }
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
                    verticalAlignment: verticalAlignment,
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
    required this.verticalAlignment,
  });

  final Rect targetRect;
  final Size viewportSize;
  final Size maxPreviewSize;
  final CardHoverPreviewVerticalAlignment verticalAlignment;

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
    final right = targetRect.right + gap;
    final left = targetRect.left - childSize.width - gap;
    final maxLeft = max(
      viewportMargin,
      viewportSize.width - childSize.width - viewportMargin,
    );
    final globalLeft =
        right + childSize.width <= viewportSize.width - viewportMargin
        ? right
        : left >= viewportMargin
        ? left
        : (targetRect.center.dx - childSize.width / 2).clamp(
            viewportMargin,
            maxLeft,
          );

    final maxTop = max(
      viewportMargin,
      viewportSize.height - childSize.height - viewportMargin,
    );
    final preferredTop = switch (verticalAlignment) {
      CardHoverPreviewVerticalAlignment.center =>
        targetRect.center.dy - childSize.height / 2,
      CardHoverPreviewVerticalAlignment.targetTop => targetRect.top,
    };
    final globalTop = preferredTop.clamp(viewportMargin, maxTop);
    return Offset(globalLeft - targetRect.left, globalTop - targetRect.top);
  }

  @override
  bool shouldRelayout(covariant _HoverFollowerLayoutDelegate oldDelegate) =>
      targetRect != oldDelegate.targetRect ||
      viewportSize != oldDelegate.viewportSize ||
      maxPreviewSize != oldDelegate.maxPreviewSize ||
      verticalAlignment != oldDelegate.verticalAlignment;
}
