import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'decoded_memory_image.dart';

/// 鼠标悬浮时显示大图预览的组件
///
/// 将缩略图包装在此组件中，鼠标悬浮时会在附近显示放大后的图片
class HoverImagePreview extends StatefulWidget {
  /// 图片数据
  final Uint8List imageBytes;

  /// 缩略图组件
  final Widget child;

  /// 预览图最大尺寸
  final double previewMaxSize;

  const HoverImagePreview({
    super.key,
    required this.imageBytes,
    required this.child,
    this.previewMaxSize = 300,
  });

  @override
  State<HoverImagePreview> createState() => _HoverImagePreviewState();
}

class _HoverImagePreviewState extends State<HoverImagePreview> {
  static const _viewportMargin = 16.0;
  static const _targetGap = 12.0;

  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Rect? _targetRect;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    final targetBox = context.findRenderObject();
    if (targetBox is! RenderBox || !targetBox.hasSize) return;
    _targetRect = targetBox.localToGlobal(Offset.zero) & targetBox.size;

    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _targetRect = null;
  }

  Widget _buildOverlay(BuildContext context) {
    final targetRect = _targetRect;
    if (targetRect == null) return const SizedBox.shrink();

    final viewport = MediaQuery.sizeOf(context);
    final rightSpace =
        viewport.width - _viewportMargin - targetRect.right - _targetGap;
    final leftSpace = targetRect.left - _viewportMargin - _targetGap;
    final horizontalSpace = math.max(rightSpace, leftSpace);
    final verticalSpace = viewport.height - (_viewportMargin * 2);
    final previewSize = math.min(
      widget.previewMaxSize,
      math.min(horizontalSpace, verticalSpace),
    );
    if (previewSize <= 0) return const SizedBox.shrink();

    final showOnRight = rightSpace >= previewSize || rightSpace >= leftSpace;
    final previewTop = (targetRect.center.dy - previewSize / 2).clamp(
      _viewportMargin,
      viewport.height - _viewportMargin - previewSize,
    );
    final verticalOffset = previewTop - targetRect.top;

    return Positioned(
      width: previewSize,
      height: previewSize,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: showOnRight ? Alignment.topRight : Alignment.topLeft,
        followerAnchor: showOnRight ? Alignment.topLeft : Alignment.topRight,
        offset: Offset(showOnRight ? _targetGap : -_targetGap, verticalOffset),
        child: Material(
          key: const ValueKey('hover-image-preview-overlay'),
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: DecodedMemoryImage(
              bytes: widget.imageBytes,
              fit: BoxFit.contain,
              maxLogicalWidth: previewSize,
              maxLogicalHeight: previewSize,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 100,
                  height: 100,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 32,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) {
          _showOverlay();
        },
        onExit: (_) {
          _removeOverlay();
        },
        child: widget.child,
      ),
    );
  }
}
