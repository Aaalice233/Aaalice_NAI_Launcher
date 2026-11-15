import 'package:flutter/material.dart';

import '../../../../adaptive/interaction_policy.dart';

class FixedTagsNegativeResizeDivider extends StatelessWidget {
  const FixedTagsNegativeResizeDivider({
    super.key,
    required this.isActive,
    required this.onHoverChanged,
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
    required this.onVerticalDragCancel,
  });

  final bool isActive;
  final ValueChanged<bool> onHoverChanged;
  final GestureDragStartCallback onVerticalDragStart;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;
  final GestureDragCancelCallback onVerticalDragCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final interactionPolicy = context.interactionPolicy;
    final hitHeight = interactionPolicy.prefersTouchPresentation
        ? interactionPolicy.minimumControlExtent
        : 16.0;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        key: const ValueKey('fixed-tags-pane-resize-divider'),
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: onVerticalDragStart,
        onVerticalDragUpdate: onVerticalDragUpdate,
        onVerticalDragEnd: onVerticalDragEnd,
        onVerticalDragCancel: onVerticalDragCancel,
        child: SizedBox(
          height: hitHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Divider(
                height: 1,
                indent: 12,
                endIndent: 12,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              AnimatedContainer(
                key: const ValueKey('fixed-tags-pane-resize-indicator'),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                width: isActive ? 48 : 40,
                height: isActive ? 3 : 2,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: isActive ? 0.95 : 0.8,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
