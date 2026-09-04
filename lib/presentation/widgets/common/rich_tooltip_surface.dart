import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 可滚动的富内容悬浮层壳层。
///
/// 普通 [Tooltip] 的默认色面在部分自定义主题中会与页面背景接近；这里使用
/// 独立 Overlay 色面和阴影，并把超长内容收纳到可滚动视口。
class RichTooltipSurface extends StatefulWidget {
  const RichTooltipSurface({
    super.key,
    required this.child,
    this.maxWidth = 380,
    this.maxHeight = 640,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 12,
  });

  final Widget child;
  final double maxWidth;
  final double maxHeight;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  State<RichTooltipSurface> createState() => _RichTooltipSurfaceState();
}

class _RichTooltipSurfaceState extends State<RichTooltipSurface> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewport = MediaQuery.sizeOf(context);
    final width = math.min(widget.maxWidth, math.max(0.0, viewport.width - 32));
    final height = math.min(
      widget.maxHeight,
      math.max(0.0, viewport.height - 32),
    );
    final surfaceColor = Color.alphaBlend(
      colorScheme.onSurface.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.075 : 0.025,
      ),
      colorScheme.surfaceContainerHigh,
    );

    return Material(
      key: const ValueKey('rich-tooltip-surface'),
      color: surfaceColor,
      surfaceTintColor: Colors.transparent,
      elevation: 18,
      shadowColor: Colors.black.withValues(alpha: 0.42),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: SizedBox(
        width: width,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height),
          child: Padding(
            padding: widget.padding,
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              interactive: true,
              thickness: 4,
              radius: const Radius.circular(4),
              child: SingleChildScrollView(
                controller: _scrollController,
                primary: false,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 富内容 Tooltip 的透明外壳装饰，实际层级由 [RichTooltipSurface] 表达。
const richTooltipOuterDecoration = BoxDecoration(color: Colors.transparent);
