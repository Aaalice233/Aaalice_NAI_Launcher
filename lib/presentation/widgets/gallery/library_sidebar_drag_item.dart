import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/gallery_tree_drop_slot.dart';
import '../../adaptive/interaction_policy.dart';
import '../../themes/core/layered_surface_style.dart';
import '../../providers/library_sidebar_sort_provider.dart';
import '../common/app_toast.dart';

/// Shared drag geometry; callers retain ownership of hierarchy and persistence.
class LibrarySidebarDragItem<T extends Object> extends StatefulWidget {
  const LibrarySidebarDragItem({
    super.key,
    required this.item,
    required this.label,
    required this.icon,
    required this.child,
    required this.canDrop,
    required this.onDrop,
    this.allowChildren = true,
    this.onExpand,
  });

  final T item;
  final String label;
  final IconData icon;
  final Widget child;
  final bool allowChildren;
  final bool Function(T source, GalleryTreeDropSlot slot) canDrop;
  final Future<bool> Function(T source, GalleryTreeDropSlot slot) onDrop;
  final VoidCallback? onExpand;

  @override
  State<LibrarySidebarDragItem<T>> createState() =>
      _LibrarySidebarDragItemState<T>();
}

class _LibrarySidebarDragItemState<T extends Object>
    extends State<LibrarySidebarDragItem<T>> {
  Timer? _expandTimer;
  bool _saving = false;

  @override
  void dispose() {
    _expandTimer?.cancel();
    super.dispose();
  }

  void _cancelExpand() {
    _expandTimer?.cancel();
    _expandTimer = null;
  }

  void _scheduleExpand() {
    if (widget.onExpand == null || _expandTimer != null) return;
    _expandTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) widget.onExpand?.call();
    });
  }

  Future<void> _accept(T source, GalleryTreeDropSlot slot) async {
    _cancelExpand();
    if (_saving || !widget.canDrop(source, slot)) return;
    setState(() => _saving = true);
    try {
      final changed = await widget.onDrop(source, slot);
      if (!mounted || !changed) return;
      HapticFeedback.heavyImpact();
      if (slot == GalleryTreeDropSlot.child) widget.onExpand?.call();
    } catch (error, stack) {
      AppLogger.e(
        'Sidebar drop failed: ${widget.label} ($slot)',
        error,
        stack,
        'GallerySidebar',
      );
      if (mounted) {
        AppToast.error(
          context,
          error is SidebarSortPreferenceSaveException
              ? context.l10n.sidebarSort_saveAfterMoveFailed(
                  error.cause.toString(),
                )
              : context.l10n.categoryError_moveFailed(error.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: Column(
            children: [
              Expanded(child: _dropZone(GalleryTreeDropSlot.before)),
              if (widget.allowChildren)
                Expanded(flex: 2, child: _dropZone(GalleryTreeDropSlot.child)),
              Expanded(child: _dropZone(GalleryTreeDropSlot.after)),
            ],
          ),
        ),
      ],
    );
    final feedback = _feedback(context);
    final dragging = Opacity(opacity: 0.4, child: widget.child);
    if (context.interactionPolicy.shouldExposeTouchAlternatives) {
      return LongPressDraggable<T>(
        data: widget.item,
        maxSimultaneousDrags: _saving ? 0 : 1,
        feedback: feedback,
        childWhenDragging: dragging,
        onDragStarted: () => HapticFeedback.mediumImpact(),
        onDragEnd: (_) => _cancelExpand(),
        child: content,
      );
    }
    return Draggable<T>(
      data: widget.item,
      maxSimultaneousDrags: _saving ? 0 : 1,
      feedback: feedback,
      childWhenDragging: dragging,
      onDragStarted: () => HapticFeedback.mediumImpact(),
      onDragEnd: (_) => _cancelExpand(),
      child: content,
    );
  }

  Widget _dropZone(GalleryTreeDropSlot slot) => DragTarget<T>(
    onWillAcceptWithDetails: (details) {
      final accepts = !_saving && widget.canDrop(details.data, slot);
      if (accepts && slot == GalleryTreeDropSlot.child) _scheduleExpand();
      return accepts;
    },
    onLeave: (_) => _cancelExpand(),
    onAcceptWithDetails: (details) => unawaited(_accept(details.data, slot)),
    builder: (context, candidates, rejected) {
      final colors = Theme.of(context).colorScheme;
      // Keep hit testing translucent: a drop region must not cover row buttons.
      return IgnorePointer(
        child: rejected.isNotEmpty
            ? ColoredBox(color: colors.error.withValues(alpha: 0.12))
            : candidates.isEmpty
            ? const SizedBox.expand()
            : slot == GalleryTreeDropSlot.child
            ? ColoredBox(color: colors.primary.withValues(alpha: 0.12))
            : Align(
                alignment: slot == GalleryTreeDropSlot.before
                    ? Alignment.topCenter
                    : Alignment.bottomCenter,
                child: Container(
                  key: ValueKey('sidebar-drop-indicator-${slot.name}'),
                  height: 2,
                  color: colors.primary,
                ),
              ),
      );
    },
  );

  Widget _feedback(BuildContext context) => Material(
    elevation: 8,
    borderRadius: BorderRadius.circular(8),
    color: overlaySurfaceColor(Theme.of(context).colorScheme),
    child: SizedBox(
      width: math.min(240, MediaQuery.sizeOf(context).width - 32),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(widget.icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
