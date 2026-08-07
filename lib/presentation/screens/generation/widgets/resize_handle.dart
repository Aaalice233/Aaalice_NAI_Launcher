import 'package:flutter/material.dart';

/// 水平拖拽分隔条
///
/// 用于左右面板之间的宽度调整，提供视觉指示器和拖拽交互。
class ResizeHandle extends StatelessWidget {
  final void Function(double delta) onDrag;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final double width;

  const ResizeHandle({
    super.key,
    required this.onDrag,
    this.onDragStart,
    this.onDragEnd,
    this.width = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: onDragStart != null
            ? (_) => onDragStart!()
            : null,
        onHorizontalDragEnd: onDragEnd != null ? (_) => onDragEnd!() : null,
        onHorizontalDragUpdate: (details) {
          final delta = details.primaryDelta ?? details.delta.dx;
          if (delta == 0) return;
          onDrag(delta);
        },
        child: Container(
          width: width,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 2,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 垂直拖拽分隔条
///
/// 用于上下区域之间的高度调整，提供视觉指示器和拖拽交互。
/// 悬停时指示条加宽变色，明确提示可拖动。
class VerticalResizeHandle extends StatefulWidget {
  final void Function(double delta) onDrag;
  final double height;

  const VerticalResizeHandle({
    super.key,
    required this.onDrag,
    this.height = 8.0,
  });

  @override
  State<VerticalResizeHandle> createState() => _VerticalResizeHandleState();
}

class _VerticalResizeHandleState extends State<VerticalResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (details) {
          final delta = details.primaryDelta ?? details.delta.dy;
          if (delta == 0) return;
          widget.onDrag(delta);
        },
        child: Container(
          height: widget.height,
          color: Colors.transparent,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: _hovered ? 72 : 48,
              height: _hovered ? 4 : 3,
              decoration: BoxDecoration(
                color: _hovered
                    ? theme.colorScheme.primary.withValues(alpha: 0.9)
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
