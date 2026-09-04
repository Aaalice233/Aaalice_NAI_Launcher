import 'package:flutter/material.dart';

import '../../adaptive/interaction_policy.dart';

/// Reusable handle for resizing vertically stacked editor or panel regions.
class VerticalResizeHandle extends StatefulWidget {
  const VerticalResizeHandle({
    super.key,
    required this.onDrag,
    this.height = 8,
  });

  final ValueChanged<double> onDrag;
  final double height;

  @override
  State<VerticalResizeHandle> createState() => _VerticalResizeHandleState();
}

class _VerticalResizeHandleState extends State<VerticalResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final interactionPolicy = context.interactionPolicy;
    final hitHeight =
        interactionPolicy.prefersTouchPresentation &&
            widget.height < interactionPolicy.minimumControlExtent
        ? interactionPolicy.minimumControlExtent
        : widget.height;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (details) {
          final delta = details.primaryDelta ?? details.delta.dy;
          if (delta != 0) widget.onDrag(delta);
        },
        child: SizedBox(
          height: hitHeight,
          child: Center(
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              width: _hovered ? 72 : 48,
              height: _hovered ? 4 : 3,
              decoration: BoxDecoration(
                color: _hovered
                    ? colorScheme.primary.withValues(alpha: 0.9)
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
