import 'package:flutter/material.dart';

import '../../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../../../data/models/tag_library/tag_library_entry_order.dart';
import '../../../../adaptive/interaction_policy.dart';
import '../../../../selection/card_selection.dart';
import '../../../../selection/card_selection_scope.dart';
import '../../../../widgets/gallery/library_drag_feedback.dart';
import 'entry_reorder_scope.dart';

/// 让条目成为拖拽重排的落点；触屏上自定义排序时长按即可拖动
class EntryReorderItem extends StatefulWidget {
  const EntryReorderItem({
    super.key,
    required this.entry,
    required this.axis,
    required this.builder,
  });

  final TagLibraryEntry entry;

  /// 网格传 [Axis.horizontal] 按左右半区插入，列表传 [Axis.vertical]
  final Axis axis;

  /// [longPressSelects] 为 false 时长按已交给拖动排序，条目不应再用长按进入多选
  final Widget Function(BuildContext context, {required bool longPressSelects})
  builder;

  @override
  State<EntryReorderItem> createState() => _EntryReorderItemState();
}

class _EntryReorderItemState extends State<EntryReorderItem> {
  int? _pointer;
  bool _dragging = false;

  void _setDragging(bool value) {
    if (mounted && _dragging != value) setState(() => _dragging = value);
  }

  @override
  Widget build(BuildContext context) {
    final scope = EntryReorderScope.maybeOf(context);
    if (scope == null) return widget.builder(context, longPressSelects: true);

    final entry = widget.entry;
    // 桌面由卡片自身的原生拖动源承担，两者互斥，同一张卡片只有一个拖动源
    final touchDrag =
        scope.enabled && !context.interactionPolicy.usesAnchoredMenus;
    final dragIds = _dragIds(context);

    return MetaData(
      metaData: EntryReorderTarget(
        scope: scope,
        entryId: entry.id,
        axis: widget.axis,
        textDirection: Directionality.of(context),
      ),
      behavior: HitTestBehavior.opaque,
      child: Listener(
        onPointerDown: (event) => _pointer = event.pointer,
        child: LongPressDraggable<List<String>>(
          data: dragIds,
          maxSimultaneousDrags: touchDrag ? 1 : 0,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: FractionalTranslation(
            translation: const Offset(-0.5, -1.25),
            child: LibraryDragFeedback(
              icon: Icons.library_books_outlined,
              label: entry.displayName,
              count: dragIds.length,
            ),
          ),
          onDragStarted: () {
            final pointer = _pointer;
            if (pointer == null) return;
            scope.beginTouchDrag(dragIds, pointer: pointer);
            _setDragging(true);
          },
          onDragEnd: (_) => _setDragging(false),
          child: Opacity(
            opacity: _dragging ? 0.3 : 1,
            child: ValueListenableBuilder<TagLibraryEntryAnchor?>(
              valueListenable: scope.hovered,
              builder: (context, anchor, child) => Stack(
                fit: StackFit.passthrough,
                children: [
                  child!,
                  if (anchor != null && anchor.entryId == entry.id)
                    _InsertionIndicator(axis: widget.axis, after: anchor.after),
                ],
              ),
              child: widget.builder(context, longPressSelects: !touchDrag),
            ),
          ),
        ),
      ),
    );
  }

  // 拖动选中的条目时整组一起移动，顺序按当前显示
  List<String> _dragIds(BuildContext context) {
    final selection = CardSelectionScope.maybeOf(context);
    final id = widget.entry.id;
    if (selection == null) return [id];
    return CardSelection.targets(selection.selection, id, selection.orderedIds);
  }
}

class _InsertionIndicator extends StatelessWidget {
  const _InsertionIndicator({required this.axis, required this.after});

  static const _thickness = 3.0;
  static const _inset = 6.0;

  final Axis axis;
  final bool after;

  @override
  Widget build(BuildContext context) {
    final bar = IgnorePointer(
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: ValueKey(
            'tag-library-reorder-indicator-${after ? 'after' : 'before'}',
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(_thickness),
          ),
        ),
      ),
    );
    return switch (axis) {
      Axis.horizontal => PositionedDirectional(
        start: after ? null : 0,
        end: after ? 0 : null,
        top: _inset,
        bottom: _inset,
        width: _thickness,
        child: bar,
      ),
      Axis.vertical => PositionedDirectional(
        start: _inset,
        end: _inset,
        top: after ? null : 0,
        bottom: after ? 0 : null,
        height: _thickness,
        child: bar,
      ),
    };
  }
}
