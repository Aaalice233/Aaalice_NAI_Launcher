import 'package:flutter/material.dart';

export '../../../widgets/common/vertical_resize_handle.dart';

/// 水平拖拽分隔条
///
/// 用于左右面板之间的宽度调整，提供视觉指示器和拖拽交互。
class ResizeHandle extends StatelessWidget {
  static const double defaultWidth = 8.0;

  final void Function(double delta) onDrag;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final double width;

  const ResizeHandle({
    super.key,
    required this.onDrag,
    this.onDragStart,
    this.onDragEnd,
    this.width = defaultWidth,
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
