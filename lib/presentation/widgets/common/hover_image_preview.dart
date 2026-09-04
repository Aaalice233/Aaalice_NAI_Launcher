import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../themes/core/layered_surface_style.dart';
import 'decoded_memory_image.dart';
import 'thumbnail_display.dart';

/// 鼠标悬浮时显示大图预览的组件
///
/// 将缩略图包装在此组件中，鼠标悬浮时会在附近显示放大后的图片
class HoverImagePreview extends StatefulWidget {
  /// 图片数据
  final Uint8List? imageBytes;

  /// 本地图片路径
  final String? imagePath;

  /// 缩略图组件
  final Widget child;

  /// 预览图最长边的最大尺寸
  final double previewMaxSize;

  /// 预览图宽高比
  final double previewAspectRatio;

  /// 本地缩略图水平偏移 (-1.0 ~ 1.0)
  final double imageOffsetX;

  /// 本地缩略图垂直偏移 (-1.0 ~ 1.0)
  final double imageOffsetY;

  /// 本地缩略图缩放比例 (1.0 ~ 3.0)
  final double imageScale;

  /// 悬浮延迟；内存图片默认保持即时预览。
  final Duration hoverDelay;

  const HoverImagePreview({
    super.key,
    required Uint8List this.imageBytes,
    required this.child,
    this.previewMaxSize = 300,
    this.hoverDelay = Duration.zero,
  }) : imagePath = null,
       previewAspectRatio = 1,
       imageOffsetX = 0,
       imageOffsetY = 0,
       imageScale = 1;

  const HoverImagePreview.file({
    super.key,
    required String imagePath,
    required this.child,
    this.previewMaxSize = 300,
    this.previewAspectRatio = 16 / 9,
    this.imageOffsetX = 0,
    this.imageOffsetY = 0,
    this.imageScale = 1,
    this.hoverDelay = Duration.zero,
  }) : assert(imagePath.length > 0),
       assert(previewAspectRatio > 0),
       imagePath = imagePath,
       imageBytes = null;

  @override
  State<HoverImagePreview> createState() => _HoverImagePreviewState();
}

class _HoverImagePreviewState extends State<HoverImagePreview> {
  static const _viewportMargin = 16.0;
  static const _targetGap = 12.0;

  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _hoverTimer;
  Rect? _targetRect;

  @override
  void didUpdateWidget(HoverImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageBytes != widget.imageBytes ||
        oldWidget.imagePath != widget.imagePath ||
        oldWidget.previewAspectRatio != widget.previewAspectRatio ||
        oldWidget.imageOffsetX != widget.imageOffsetX ||
        oldWidget.imageOffsetY != widget.imageOffsetY ||
        oldWidget.imageScale != widget.imageScale) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _scheduleOverlay() {
    _hoverTimer?.cancel();
    if (widget.hoverDelay == Duration.zero) {
      _showOverlay();
      return;
    }
    _hoverTimer = Timer(widget.hoverDelay, () {
      if (mounted) _showOverlay();
    });
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
    _hoverTimer?.cancel();
    _hoverTimer = null;
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
    final aspectRatio = widget.previewAspectRatio;
    final (previewWidth, previewHeight) = aspectRatio >= 1
        ? (() {
            final width = math.min(
              widget.previewMaxSize,
              math.min(horizontalSpace, verticalSpace * aspectRatio),
            );
            return (width, width / aspectRatio);
          })()
        : (() {
            final height = math.min(
              widget.previewMaxSize,
              math.min(verticalSpace, horizontalSpace / aspectRatio),
            );
            return (height * aspectRatio, height);
          })();
    if (previewWidth <= 0 || previewHeight <= 0) {
      return const SizedBox.shrink();
    }

    final showOnRight = rightSpace >= previewWidth || rightSpace >= leftSpace;
    final previewTop = (targetRect.center.dy - previewHeight / 2).clamp(
      _viewportMargin,
      viewport.height - _viewportMargin - previewHeight,
    );
    final verticalOffset = previewTop - targetRect.top;

    return Positioned(
      width: previewWidth,
      height: previewHeight,
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
            color: overlaySurfaceColor(Theme.of(context).colorScheme),
            child: _buildPreviewContent(
              context,
              previewWidth: previewWidth,
              previewHeight: previewHeight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewContent(
    BuildContext context, {
    required double previewWidth,
    required double previewHeight,
  }) {
    final imagePath = widget.imagePath;
    if (imagePath != null) {
      return ThumbnailDisplay(
        imagePath: imagePath,
        offsetX: widget.imageOffsetX,
        offsetY: widget.imageOffsetY,
        scale: widget.imageScale,
        width: previewWidth,
        height: previewHeight,
      );
    }

    return DecodedMemoryImage(
      bytes: widget.imageBytes!,
      fit: BoxFit.contain,
      maxLogicalWidth: previewWidth,
      maxLogicalHeight: previewHeight,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => _scheduleOverlay(),
        onExit: (_) => _removeOverlay(),
        child: widget.child,
      ),
    );
  }
}
