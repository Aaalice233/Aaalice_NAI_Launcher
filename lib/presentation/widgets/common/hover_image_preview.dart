import 'dart:typed_data';

import 'package:flutter/material.dart';

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
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isHovering = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildOverlay(),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildOverlay() {
    return Positioned(
      width: widget.previewMaxSize,
      child: CompositedTransformFollower(
        link: _layerLink,
        targetAnchor: Alignment.topRight,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(12, 0),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: widget.previewMaxSize,
              maxHeight: widget.previewMaxSize,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.memory(
              widget.imageBytes,
              fit: BoxFit.contain,
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
          setState(() => _isHovering = true);
          _showOverlay();
        },
        onExit: (_) {
          setState(() => _isHovering = false);
          _removeOverlay();
        },
        child: widget.child,
      ),
    );
  }
}
