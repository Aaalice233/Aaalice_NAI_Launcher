import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../adaptive/interaction_policy.dart';

/// Exposes the active drop state to the classification row that owns the
/// visual surface. Keeping the feedback on that row avoids stacking a second
/// rounded highlight around its built-in pointer hover state.
class LibraryClassificationDropTargetStatus extends InheritedWidget {
  const LibraryClassificationDropTargetStatus({
    super.key,
    required this.isAccepting,
    required super.child,
  });

  final bool isAccepting;

  static bool isAcceptingOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<
              LibraryClassificationDropTargetStatus
            >()
            ?.isAccepting ??
        false;
  }

  @override
  bool updateShouldNotify(LibraryClassificationDropTargetStatus oldWidget) {
    return isAccepting != oldWidget.isAccepting;
  }
}

/// Shared in-app drag behavior for assigning library entries to sidebar
/// destinations. Touch layouts use explicit card actions instead.
class LibraryClassificationDragSource<T extends Object>
    extends StatelessWidget {
  const LibraryClassificationDragSource({
    super.key,
    required this.data,
    required this.label,
    required this.child,
    this.icon = Icons.drive_file_move_outline,
    this.enabled = true,
    this.onDragStarted,
    this.onDragEnded,
  });

  final T data;
  final String label;
  final Widget child;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnded;

  @override
  Widget build(BuildContext context) {
    final dragEnabled = enabled && context.interactionPolicy.usesAnchoredMenus;
    final theme = Theme.of(context);
    return Draggable<T>(
      data: data,
      maxSimultaneousDrags: dragEnabled ? null : 0,
      onDragStarted: () {
        HapticFeedback.mediumImpact();
        onDragStarted?.call();
      },
      onDragEnd: (_) => onDragEnded?.call(),
      feedback: dragEnabled
          ? Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              color: theme.colorScheme.surfaceContainerHigh,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(label, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
      childWhenDragging: Opacity(opacity: 0.4, child: child),
      child: child,
    );
  }
}

/// Shared visual and haptic response for Favorites and category/type targets.
class LibraryClassificationDropTarget<T extends Object>
    extends StatelessWidget {
  const LibraryClassificationDropTarget({
    super.key,
    required this.child,
    required this.onAccept,
    this.canAccept,
    this.enabled = true,
  });

  final Widget child;
  final ValueChanged<T> onAccept;
  final bool Function(T data)? canAccept;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return DragTarget<T>(
      onWillAcceptWithDetails: (details) =>
          canAccept?.call(details.data) ?? true,
      onAcceptWithDetails: (details) {
        HapticFeedback.heavyImpact();
        onAccept(details.data);
      },
      builder: (context, candidates, rejected) =>
          LibraryClassificationDropTargetStatus(
            isAccepting: candidates.isNotEmpty,
            child: child,
          ),
    );
  }
}
