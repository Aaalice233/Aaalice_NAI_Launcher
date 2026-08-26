import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Coordinates delayed gallery previews in the root overlay.
///
/// The follower stays attached to its card while its layout delegate keeps the
/// preview inside the visible window, including when neither side has enough
/// room for the preferred size.
class GalleryHoverController with WidgetsBindingObserver {
  OverlayEntry? _entry;
  Timer? _showTimer;
  int _revision = 0;
  String? _stableKey;
  bool _observingMetrics = false;
  bool _metricsRebuildScheduled = false;

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
    _startObservingMetrics();
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
          if (!liveTargetRect.overlaps(Offset.zero & mediaSize)) {
            return const SizedBox.shrink();
          }
          return Positioned.fill(
            child: IgnorePointer(
              child: CompositedTransformFollower(
                link: layerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.topLeft,
                followerAnchor: Alignment.topLeft,
                child: CustomSingleChildLayout(
                  delegate: _GalleryHoverLayoutDelegate(
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

  void markNeedsBuild() => _entry?.markNeedsBuild();

  void _startObservingMetrics() {
    if (_observingMetrics) return;
    WidgetsBinding.instance.addObserver(this);
    _observingMetrics = true;
  }

  void _stopObservingMetrics() {
    if (!_observingMetrics) return;
    WidgetsBinding.instance.removeObserver(this);
    _observingMetrics = false;
    _metricsRebuildScheduled = false;
  }

  @override
  void didChangeMetrics() {
    if (_metricsRebuildScheduled) return;
    _metricsRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _metricsRebuildScheduled = false;
      _entry?.markNeedsBuild();
    });
  }

  void dismiss() {
    _revision++;
    _showTimer?.cancel();
    _showTimer = null;
    _entry?.remove();
    _entry = null;
    _stableKey = null;
    _stopObservingMetrics();
  }

  void dispose() => dismiss();
}

class _GalleryHoverLayoutDelegate extends SingleChildLayoutDelegate {
  const _GalleryHoverLayoutDelegate({
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
    final right = targetRect.right + gap;
    final left = targetRect.left - gap - childSize.width;
    final fitsRight =
        right + childSize.width <= viewportSize.width - viewportMargin;
    final fitsLeft = left >= viewportMargin;

    final absoluteLeft = switch ((fitsRight, fitsLeft)) {
      (true, _) => right,
      (false, true) => left,
      _ =>
        (viewportSize.width - targetRect.right >= targetRect.left
                ? right
                : left)
            .clamp(
              viewportMargin,
              max(
                viewportMargin,
                viewportSize.width - childSize.width - viewportMargin,
              ),
            )
            .toDouble(),
    };
    final maxTop = max(
      viewportMargin,
      viewportSize.height - childSize.height - viewportMargin,
    );
    final absoluteTop = (targetRect.center.dy - childSize.height / 2)
        .clamp(viewportMargin, maxTop)
        .toDouble();
    return Offset(absoluteLeft - targetRect.left, absoluteTop - targetRect.top);
  }

  @override
  bool shouldRelayout(covariant _GalleryHoverLayoutDelegate oldDelegate) =>
      targetRect != oldDelegate.targetRect ||
      viewportSize != oldDelegate.viewportSize ||
      maxPreviewSize != oldDelegate.maxPreviewSize;
}
