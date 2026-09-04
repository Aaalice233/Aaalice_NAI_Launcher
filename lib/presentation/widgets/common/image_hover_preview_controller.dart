import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

enum ImageHoverPreviewVerticalAlignment { center, targetTop }

/// Coordinates delayed image previews in the root overlay and keeps them
/// inside the current safe viewport.
class ImageHoverPreviewController with WidgetsBindingObserver {
  OverlayEntry? _entry;
  Timer? _showTimer;
  int _revision = 0;
  String? _stableKey;
  bool _observingMetrics = false;
  bool _metricsRebuildScheduled = false;
  VoidCallback? _onDismissIntent;
  bool _intentStarted = false;

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
    VoidCallback? onDismissIntent,
    bool allowPointerInteraction = false,
    ImageHoverPreviewVerticalAlignment verticalAlignment =
        ImageHoverPreviewVerticalAlignment.center,
    Duration delay = const Duration(milliseconds: 280),
  }) {
    dismiss();
    final revision = ++_revision;
    _stableKey = stableKey;
    _onDismissIntent = onDismissIntent;
    _startObservingMetrics();
    _showTimer = Timer(delay, () {
      if (_revision != revision ||
          _stableKey != stableKey ||
          !context.mounted) {
        return;
      }
      _intentStarted = true;
      onIntent?.call();
      final overlay = Overlay.of(context, rootOverlay: true);
      _entry = OverlayEntry(
        builder: (overlayContext) {
          final mediaQuery = MediaQuery.of(overlayContext);
          final viewport = Offset.zero & mediaQuery.size;
          final safeViewport = _safeViewportRect(mediaQuery);
          final safeWidth = min(previewSize.width, safeViewport.width);
          final safeHeight = min(previewSize.height, safeViewport.height);
          final renderObject = context.findRenderObject();
          final liveTargetRect =
              renderObject is RenderBox && renderObject.attached
              ? renderObject.localToGlobal(Offset.zero) & renderObject.size
              : targetRect;
          if (!liveTargetRect.overlaps(viewport)) {
            return const SizedBox.shrink();
          }
          return Positioned.fill(
            child: IgnorePointer(
              ignoring: !allowPointerInteraction,
              child: CompositedTransformFollower(
                link: layerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.topLeft,
                followerAnchor: Alignment.topLeft,
                child: CustomSingleChildLayout(
                  delegate: _ImageHoverPreviewLayoutDelegate(
                    targetRect: liveTargetRect,
                    safeViewport: safeViewport,
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
    if (_intentStarted) _onDismissIntent?.call();
    _intentStarted = false;
    _onDismissIntent = null;
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

Rect _safeViewportRect(MediaQueryData mediaQuery) {
  const margin = 10.0;
  final left = mediaQuery.padding.left + margin;
  final top = mediaQuery.padding.top + margin;
  final right = mediaQuery.size.width - mediaQuery.padding.right - margin;
  final obstructedBottom = max(
    mediaQuery.padding.bottom,
    mediaQuery.viewInsets.bottom,
  );
  final bottom = mediaQuery.size.height - obstructedBottom - margin;
  return Rect.fromLTRB(left, top, max(left, right), max(top, bottom));
}

class _ImageHoverPreviewLayoutDelegate extends SingleChildLayoutDelegate {
  const _ImageHoverPreviewLayoutDelegate({
    required this.targetRect,
    required this.safeViewport,
    required this.maxPreviewSize,
    required this.verticalAlignment,
  });

  final Rect targetRect;
  final Rect safeViewport;
  final Size maxPreviewSize;
  final ImageHoverPreviewVerticalAlignment verticalAlignment;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: maxPreviewSize.width,
        maxHeight: maxPreviewSize.height,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const gap = 12.0;
    final right = targetRect.right + gap;
    final left = targetRect.left - gap - childSize.width;
    final fitsRight = right + childSize.width <= safeViewport.right;
    final fitsLeft = left >= safeViewport.left;
    final absoluteLeft = switch ((fitsRight, fitsLeft)) {
      (true, _) => right,
      (false, true) => left,
      _ =>
        (safeViewport.right - targetRect.right >=
                    targetRect.left - safeViewport.left
                ? right
                : left)
            .clamp(
              safeViewport.left,
              max(safeViewport.left, safeViewport.right - childSize.width),
            )
            .toDouble(),
    };
    final preferredTop = switch (verticalAlignment) {
      ImageHoverPreviewVerticalAlignment.center =>
        targetRect.center.dy - childSize.height / 2,
      ImageHoverPreviewVerticalAlignment.targetTop => targetRect.top,
    };
    final absoluteTop = preferredTop
        .clamp(
          safeViewport.top,
          max(safeViewport.top, safeViewport.bottom - childSize.height),
        )
        .toDouble();
    return Offset(absoluteLeft - targetRect.left, absoluteTop - targetRect.top);
  }

  @override
  bool shouldRelayout(covariant _ImageHoverPreviewLayoutDelegate oldDelegate) =>
      targetRect != oldDelegate.targetRect ||
      safeViewport != oldDelegate.safeViewport ||
      maxPreviewSize != oldDelegate.maxPreviewSize ||
      verticalAlignment != oldDelegate.verticalAlignment;
}
