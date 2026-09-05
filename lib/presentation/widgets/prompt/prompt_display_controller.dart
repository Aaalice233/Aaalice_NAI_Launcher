import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/themed_text_selection_toolbar.dart';
import 'prompt_text_projection.dart';

/// A native editing view over a source controller. All persistent edits and
/// undo transactions still belong to the source; only offsets are projected.
class PromptDisplayController extends TextEditingController {
  PromptDisplayController(this.source) {
    _projection = PromptTextProjection(source.text);
    _readSource();
    source.addListener(_readSource);
  }

  final TextEditingController source;
  late PromptTextProjection _projection;
  bool _syncing = false;

  bool get hasProjectedSelection =>
      selection.isValid &&
      !selection.isCollapsed &&
      source.selection.textInside(source.text) != selection.textInside(text);

  void deleteSelection() {
    if (!selection.isValid || selection.isCollapsed) return;
    value = TextEditingValue(
      text: selection.textBefore(text) + selection.textAfter(text),
      selection: TextSelection.collapsed(offset: selection.start),
    );
  }

  bool copySelection({required bool cut}) {
    if (!hasProjectedSelection) return false;
    unawaited(
      Clipboard.setData(
        ClipboardData(text: source.selection.textInside(source.text)),
      ),
    );
    if (cut) deleteSelection();
    return true;
  }

  Action<CopySelectionTextIntent> clipboardAction({required bool enabled}) =>
      _ProjectedCopyAction(this, enabled);

  Widget buildContextMenu(BuildContext context, EditableTextState editable) {
    final items = editable.contextMenuButtonItems.map((item) {
      if (item.type != ContextMenuButtonType.copy &&
          item.type != ContextMenuButtonType.cut) {
        return item;
      }
      return ContextMenuButtonItem(
        type: item.type,
        label: item.label,
        onPressed: () {
          if (copySelection(
            cut:
                item.type == ContextMenuButtonType.cut &&
                !editable.widget.readOnly,
          )) {
            editable.hideToolbar();
          } else {
            item.onPressed?.call();
          }
        },
      );
    }).toList();
    return buildThemedTextSelectionToolbar(
      context,
      anchors: editable.contextMenuAnchors,
      buttonItems: items,
    );
  }

  void _readSource() {
    if (_syncing) return;
    final sourceChanged = _projection.source != source.text;
    if (sourceChanged) {
      _projection = PromptTextProjection(source.text);
    }
    final raw = source.value;
    final projected = TextEditingValue(
      text: _projection.text,
      selection: raw.selection.copyWith(
        baseOffset: _projection.toDisplay(raw.selection.baseOffset),
        extentOffset: _projection.toDisplay(raw.selection.extentOffset),
      ),
      composing: raw.composing.isValid
          ? TextRange(
              start: _projection.toDisplay(raw.composing.start),
              end: _projection.toDisplay(raw.composing.end),
            )
          : TextRange.empty,
    );
    if (sourceChanged && projected == super.value) {
      // Toggling a wrapper changes styling without changing visible text.
      notifyListeners();
    } else {
      super.value = projected;
    }
  }

  @override
  set value(TextEditingValue next) {
    final previous = super.value;
    if (next == previous) return;
    var projection = _projection;
    if (next.text != previous.text) {
      var start = 0;
      // Selection constrains the diff so repeated adjacent letters cannot move
      // an edit across a formatting boundary.
      final limit = previous.selection.isValid
          ? previous.selection.start
          : previous.text.length;
      while (start < limit &&
          start < previous.text.length &&
          start < next.text.length &&
          previous.text[start] == next.text[start]) {
        start++;
      }
      var suffix = 0;
      while (suffix < previous.text.length - start &&
          suffix < next.text.length - start &&
          previous.text[previous.text.length - suffix - 1] ==
              next.text[next.text.length - suffix - 1]) {
        suffix++;
      }
      projection = _projection.replace(
        start,
        previous.text.length - suffix,
        next.text.substring(start, next.text.length - suffix),
      );
    }
    final selection = next.selection;
    int mapSelection(int offset, {required bool end}) {
      if (offset < 0) return -1;
      return selection.isCollapsed
          ? projection.toSource(offset)
          : projection.selectionBoundary(offset, end: end);
    }

    _syncing = true;
    try {
      source.value = TextEditingValue(
        text: projection.source,
        selection: selection.copyWith(
          baseOffset: mapSelection(
            selection.baseOffset,
            end: selection.baseOffset > selection.extentOffset,
          ),
          extentOffset: mapSelection(
            selection.extentOffset,
            end: selection.extentOffset > selection.baseOffset,
          ),
        ),
        composing: next.composing.isValid
            ? TextRange(
                start: projection.toSource(next.composing.start),
                end: projection.toSource(next.composing.end, end: true),
              )
            : TextRange.empty,
      );
    } finally {
      _syncing = false;
    }
    _readSource();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final original = source.buildTextSpan(
      context: context,
      style: style,
      withComposing: withComposing,
    );
    final spans = <InlineSpan>[];
    var rawOffset = 0;
    var displayOffset = 0;
    original.visitChildren((span) {
      if (span is! TextSpan || span.text == null) return true;
      final rawEnd = rawOffset + span.text!.length;
      final start = displayOffset;
      while (displayOffset < _projection.characterOffsets.length &&
          _projection.characterOffsets[displayOffset] < rawEnd) {
        displayOffset++;
      }
      if (start < displayOffset) {
        spans.add(
          TextSpan(
            text: text.substring(start, displayOffset),
            style: span.style,
          ),
        );
      }
      rawOffset = rawEnd;
      return true;
    });
    return TextSpan(style: original.style, children: spans);
  }

  @override
  void dispose() {
    source.removeListener(_readSource);
    super.dispose();
  }
}

class _ProjectedCopyAction extends Action<CopySelectionTextIntent> {
  _ProjectedCopyAction(this.controller, this.enabled);
  final PromptDisplayController controller;
  final bool enabled;

  @override
  Object? invoke(CopySelectionTextIntent intent) {
    if (controller.copySelection(cut: enabled && intent.collapseSelection)) {
      return null;
    }
    return callingAction?.invoke(intent);
  }

  @override
  bool get isActionEnabled => callingAction?.isActionEnabled ?? false;
}
