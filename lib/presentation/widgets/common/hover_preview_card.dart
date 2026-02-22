import 'dart:async';

import 'package:flutter/material.dart';

/// 悬浮预览卡片组件
///
/// 鼠标悬浮一段时间后显示预览内容
class HoverPreviewCard extends StatefulWidget {
  /// 子组件
  final Widget child;

  /// 预览内容构建器
  final Widget Function(BuildContext context) previewBuilder;

  /// 悬浮延迟时间（避免快速滑过触发）
  final Duration hoverDelay;

  /// 预览卡片最大宽度
  final double maxWidth;

  /// 预览卡片位置偏移
  final Offset offset;

  const HoverPreviewCard({
    super.key,
    required this.child,
    required this.previewBuilder,
    this.hoverDelay = const Duration(milliseconds: 300),
    this.maxWidth = 280,
    this.offset = const Offset(12, 0),
  });

  @override
  State<HoverPreviewCard> createState() => _HoverPreviewCardState();
}

class _HoverPreviewCardState extends State<HoverPreviewCard> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _hoverTimer;
  bool _isHovering = false;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onEnter() {
    _isHovering = true;
    _hoverTimer?.cancel();
    _hoverTimer = Timer(widget.hoverDelay, () {
      if (_isHovering && mounted) {
        _showOverlay();
      }
    });
  }

  void _onExit() {
    _isHovering = false;
    _hoverTimer?.cancel();
    _removeOverlay();
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
      width: widget.maxWidth,
      child: CompositedTransformFollower(
        link: _layerLink,
        targetAnchor: Alignment.topRight,
        followerAnchor: Alignment.topLeft,
        offset: widget.offset,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: widget.maxWidth,
              maxHeight: 320,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: widget.previewBuilder(context),
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
        onEnter: (_) => _onEnter(),
        onExit: (_) => _onExit(),
        child: widget.child,
      ),
    );
  }
}

/// 预览卡片加载骨架屏
class PreviewCardSkeleton extends StatelessWidget {
  const PreviewCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final skeletonColor = colorScheme.surfaceContainerHighest;

    Widget skeletonLine(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: skeletonColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          skeletonLine(120, 16),
          const SizedBox(height: 8),
          skeletonLine(80, 12),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(
              6,
              (index) => Container(
                width: 50 + (index % 3) * 20.0,
                height: 24,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 预览卡片错误状态
class PreviewCardError extends StatelessWidget {
  final String message;

  const PreviewCardError({
    super.key,
    this.message = '无法加载预览',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 32,
            color: colorScheme.error,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
