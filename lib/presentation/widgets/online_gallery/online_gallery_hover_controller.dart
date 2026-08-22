import 'dart:async';

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
          final safeWidth = (mediaSize.width - 32)
              .clamp(0.0, previewSize.width)
              .toDouble();
          final safeHeight = (mediaSize.height - 32)
              .clamp(0.0, previewSize.height)
              .toDouble();
          final resolvedSize = Size(safeWidth, safeHeight);
          final renderObject = context.findRenderObject();
          final liveTargetRect =
              renderObject is RenderBox && renderObject.attached
              ? renderObject.localToGlobal(Offset.zero) & renderObject.size
              : targetRect;
          const gap = 12.0;
          final fitsRight =
              liveTargetRect.right + gap + resolvedSize.width <=
              mediaSize.width - 16;
          final desiredLeft = fitsRight
              ? liveTargetRect.width + gap
              : -resolvedSize.width - gap;
          final desiredTop =
              (liveTargetRect.center.dy - resolvedSize.height / 2).clamp(
                16.0,
                mediaSize.height - resolvedSize.height - 16,
              );
          final offset = Offset(desiredLeft, desiredTop - liveTargetRect.top);
          return Positioned(
            left: 0,
            top: 0,
            width: resolvedSize.width,
            height: resolvedSize.height,
            child: IgnorePointer(
              child: CompositedTransformFollower(
                link: layerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.topLeft,
                followerAnchor: Alignment.topLeft,
                offset: offset,
                child: Builder(builder: builder),
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
