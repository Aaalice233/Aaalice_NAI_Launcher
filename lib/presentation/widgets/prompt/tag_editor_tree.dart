import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import 'prompt_translation_controller.dart';
import 'tag_editor_capsule.dart';
import 'tag_editor_session.dart';
import 'tag_editor_weight_label.dart';
import 'tag_drag_preview.dart';
import '../autocomplete/autocomplete_overlay_handle.dart';

/// Presents the source hierarchy; all mutations remain session transactions.
class TagEditorTree extends StatefulWidget {
  const TagEditorTree({
    super.key,
    required this.session,
    required this.width,
    required this.keys,
    required this.enabled,
    required this.enableAutocomplete,
    required this.showTranslation,
    required this.translations,
    required this.onRetryTranslation,
    required this.onSelect,
    required this.onEdit,
    required this.onMenu,
    required this.onWheel,
    required this.autocompleteOverlay,
    this.pendingAddition,
    required this.addition,
    required this.onDraggingChanged,
  });
  final AutocompleteOverlayHandle autocompleteOverlay;
  final TextRange? pendingAddition;
  final TagEditorSession session;
  final double width;
  final Map<int, GlobalKey> keys;
  final bool enabled, enableAutocomplete, showTranslation;
  final Map<String, PromptTranslation>? translations;
  final VoidCallback onRetryTranslation;
  final ValueChanged<PromptEditorTag> onSelect;
  final void Function(PromptEditorTag, TextEditingValue) onEdit;
  final void Function(Offset, PromptEditorTag) onMenu;
  final void Function(PointerSignalEvent, int) onWheel;
  final Widget addition;
  final ValueChanged<bool> onDraggingChanged;
  @override
  State<TagEditorTree> createState() => _TagEditorTreeState();
}

class _TagEditorTreeState extends State<TagEditorTree> {
  Set<int> _dragIds = {};
  TagEditorSession? _dragSession;
  String? _dragSource;
  int? _dropBefore;
  bool _showDrop = false;

  bool _canDrop(Set<int> ids) =>
      widget.enabled &&
      identical(widget.session, _dragSession) &&
      widget.session.controller.text == _dragSource &&
      widget.session.structureComplete &&
      _dragIds.isNotEmpty &&
      ids.every((id) => widget.session.byId(id) != null);

  void _hover(int? id) {
    if (_showDrop && _dropBefore == id) return;
    setState(() {
      _showDrop = true;
      _dropBefore = id;
    });
  }

  void _finishDrag() {
    if (!mounted) return;
    setState(() {
      _dragIds = {};
      _dragSession = null;
      _dragSource = null;
      _showDrop = false;
      _dropBefore = null;
    });
    widget.onDraggingChanged(false);
  }

  void _drop(Set<int> ids, int? before) {
    if (!_canDrop(ids)) return;
    widget.session.setSelection(ids);
    widget.session.moveSelectedBefore(before);
    _finishDrag();
  }

  Widget _preview(BuildContext context, {bool placeholder = false}) =>
      TagDragPreview(
        tags: widget.session.leaves
            .where((tag) => _dragIds.contains(tag.id))
            .toList(),
        maxWidth: widget.width,
        placeholder: placeholder,
      );

  Widget _placeholder(BuildContext context, int? before) =>
      DragTarget<Set<int>>(
        onWillAcceptWithDetails: (details) => _canDrop(details.data),
        onAcceptWithDetails: (details) => _drop(details.data, before),
        builder: (context, _, _) => _preview(context, placeholder: true),
      );

  Iterable<Widget> _items(
    BuildContext context,
    List<PromptEditorTag> tags,
    double width,
  ) sync* {
    for (final tag in tags) {
      if (_showDrop && _dropBefore == tag.id) {
        yield _placeholder(context, tag.id);
      }
      yield _tag(context, tag, width);
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      ..._items(context, widget.session.tags, widget.width),
      if (_showDrop && _dropBefore == null) _placeholder(context, null),
      DragTarget<Set<int>>(
        key: const ValueKey('tag-list-end-target'),
        onWillAcceptWithDetails: (details) => _canDrop(details.data),
        onMove: (_) => _hover(null),
        onAcceptWithDetails: (details) => _drop(details.data, null),
        builder: (context, _, _) => widget.addition,
      ),
    ],
  );
  Widget _tag(BuildContext context, PromptEditorTag tag, double width) {
    final pending = widget.pendingAddition;
    if (pending != null &&
        tag.span.start >= pending.start &&
        tag.span.end <= pending.end) {
      return const SizedBox.shrink();
    }
    return tag.children.isNotEmpty
        ? _group(context, tag, width)
        : _leaf(context, tag, width);
  }

  Widget _group(BuildContext context, PromptEditorTag tag, double width) {
    return Semantics(
      label: context.l10n.tagMode_group,
      child: Container(
        key: ValueKey('tag-weight-group-${tag.id}'),
        constraints: BoxConstraints(maxWidth: width),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: BorderDirectional(
            start: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TagEditorWeightLabel(span: tag.span),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _items(
                context,
                tag.children,
                (width - 14).clamp(0, width),
              ).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leaf(BuildContext context, PromptEditorTag tag, double width) {
    final session = widget.session;
    final selected = session.selected.contains(tag.id);
    final editing = session.editing == tag.id;
    final dragData = {...session.selected, tag.id};
    final capsule = TagEditorCapsule(
      key: ValueKey(tag.id),
      autocompleteOverlay: widget.autocompleteOverlay,
      tag: tag,
      selected: selected,
      editing: editing,
      maxWidth: (width - 20).clamp(0, width),
      selectTextOnEdit: session.selectTextOnEdit,
      enableAutocomplete: widget.enableAutocomplete,
      showTranslation: widget.showTranslation,
      translation: widget.translations?[tag.span.label],
      onRetryTranslation: widget.onRetryTranslation,
      onTap: () => widget.onSelect(tag),
      onChanged: (value) => widget.onEdit(tag, value),
      onSubmitted: session.endEdit,
      onTapOutside: session.clearSelection,
    );
    return DragTarget<Set<int>>(
      onWillAcceptWithDetails: (details) =>
          _canDrop(details.data) && !details.data.contains(tag.id),
      onMove: (details) {
        if (!details.data.contains(tag.id)) _hover(tag.id);
      },
      onAcceptWithDetails: (details) => _drop(details.data, tag.id),
      builder: (context, _, _) => Container(
        key: widget.keys.putIfAbsent(tag.id, GlobalKey.new),
        constraints: BoxConstraints(maxWidth: width),
        child: Listener(
          onPointerSignal: (event) => widget.onWheel(event, tag.id),
          onPointerDown: (event) {
            if (event.buttons == kMiddleMouseButton && widget.enabled) {
              session.toggleEnabled([tag.id]);
            }
          },
          child: GestureDetector(
            onSecondaryTapDown: (details) =>
                widget.onMenu(details.globalPosition, tag),
            child: Semantics(
              hint: widget.enabled && session.structureComplete && !editing
                  ? context.l10n.tagMode_drag
                  : null,
              child: _draggable(tag, width, dragData, capsule),
            ),
          ),
        ),
      ),
    );
  }

  Widget _draggable(
    PromptEditorTag tag,
    double width,
    Set<int> dragData,
    Widget capsule,
  ) {
    final session = widget.session;
    final editing = session.editing == tag.id;
    return LongPressDraggable<Set<int>>(
      data: dragData,
      maxSimultaneousDrags:
          widget.enabled &&
              session.structureComplete &&
              !editing &&
              _dragIds.isEmpty
          ? 1
          : 0,
      delay: const Duration(milliseconds: 350),
      onDragStarted: () {
        setState(() {
          _dragIds = dragData;
          // A different input or an external text replacement invalidates this
          // gesture's source ranges; it must never reorder the new document.
          _dragSession = session;
          _dragSource = session.controller.text;
          _showDrop = false;
        });
        widget.onDraggingChanged(true);
        session.beginTouchSelection(tag.id);
      },
      onDragEnd: (_) => _finishDrag(),
      feedback: TagDragPreview(
        tags: session.leaves.where((tag) => dragData.contains(tag.id)).toList(),
        maxWidth: width,
      ),
      child: Opacity(
        opacity: _dragIds.contains(tag.id) ? 0.28 : 1,
        child: capsule,
      ),
    );
  }
}
