import 'package:flutter/material.dart';

import '../../adaptive/interaction_policy.dart';

/// 左右面板之间的通用宽度调整手柄。
class ResizeHandle extends StatefulWidget {
  static const double defaultWidth = 8;

  const ResizeHandle({
    super.key,
    required this.onDrag,
    this.onDragStart,
    this.onDragEnd,
    this.width = defaultWidth,
  });

  final ValueChanged<double> onDrag;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final double width;

  @override
  State<ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<ResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final interactionPolicy = context.interactionPolicy;
    final hitWidth =
        interactionPolicy.prefersTouchPresentation &&
            widget.width < interactionPolicy.minimumControlExtent
        ? interactionPolicy.minimumControlExtent
        : widget.width;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: widget.onDragStart != null
            ? (_) => widget.onDragStart!()
            : null,
        onHorizontalDragEnd: widget.onDragEnd != null
            ? (_) => widget.onDragEnd!()
            : null,
        onHorizontalDragUpdate: (details) {
          final delta = details.primaryDelta ?? details.delta.dx;
          if (delta != 0) widget.onDrag(delta);
        },
        child: SizedBox(
          width: hitWidth,
          child: Center(
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              width: _hovered ? 3 : 2,
              height: _hovered ? 64 : 40,
              decoration: BoxDecoration(
                color: _hovered
                    ? colorScheme.primary.withValues(alpha: 0.72)
                    : colorScheme.outline.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
