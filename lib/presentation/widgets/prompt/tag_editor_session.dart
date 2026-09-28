import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/prompt_edit_document.dart';
import 'tag_editor_projection.dart';
import 'tag_editor_grouping.dart';

class PromptEditorTag {
  const PromptEditorTag(this.id, this.span, this.children);
  final int id;
  final PromptEditSpan span;
  final List<PromptEditorTag> children;
  Iterable<PromptEditorTag> get leaves sync* {
    if (children.isEmpty) {
      yield this;
    } else {
      for (final child in children) {
        yield* child.leaves;
      }
    }
  }
}

class PromptTextPatch {
  const PromptTextPatch(this.start, this.end, this.text);
  final int start;
  final int end;
  final String text;
}

/// UI identity, selection and undo belong to the editor, while the controller
/// remains the only owner of prompt content. Both views use these transactions.
class TagEditorSession extends ChangeNotifier {
  TagEditorSession(this.controller, {this.onCommandChanged}) {
    _previous = controller.value;
    _reparse(const {});
    controller.addListener(_changed);
  }
  final TextEditingController controller;
  final ValueChanged<String>? onCommandChanged;
  late TextEditingValue _previous;
  List<PromptEditorTag> tags = [];
  List<PromptEditorTag> _leaves = [];
  Map<int, PromptEditorTag> _leafIndex = {};
  Map<int, PromptEditorTag> _nodeIndex = {};
  final Set<int> selected = {};
  // The structural path distinguishes nested groups with identical leaves,
  // including weight edits that replace a wrapper.
  List<int>? _selectedGroupPath;
  final List<TextEditingValue> _past = [];
  final List<TextEditingValue> _future = [];
  int _nextId = 0;
  bool _applying = false;
  bool _restoring = false;
  DateTime? _lastTyping;
  int? anchor;
  int? editing;
  TextRange? _editingRange;
  PromptEditSpan? _draftSpan;
  bool selectTextOnEdit = true;
  bool tagMode = false;
  bool touchSelection = false;
  double scrollOffset = 0;

  bool get canUndo => _past.isNotEmpty;
  bool get canRedo => _future.isNotEmpty;
  Iterable<PromptEditorTag> get leaves => _leaves;
  Iterable<PromptEditorTag> get nodes => _nodeIndex.values;
  PromptEditorTag? nodeById(int id) => _nodeIndex[id];
  List<PromptEditorTag> get selectedTags =>
      leaves.where((tag) => selected.contains(tag.id)).toList();
  bool get structureComplete => tags.every((tag) => tag.span.complete);

  List<PromptEditorTag> get textSelectionTags {
    final range = controller.selection;
    if (!structureComplete || !range.isValid || range.isCollapsed) return [];
    return leaves
        .where(
          (tag) => tag.span.start < range.end && tag.span.end > range.start,
        )
        .toList();
  }

  void setTextSelectionEnabled(bool enabled) {
    final before = controller.selection;
    final ids = textSelectionTags.map((tag) => tag.id).toList();
    if (ids.isEmpty) return;
    toggleEnabled(ids, enabled: enabled);
    final targets = ids.map(byId).whereType<PromptEditorTag>().toList();
    if (targets.isEmpty) return;
    // Operate on whole tags, preserving their weight shells and delimiters.
    // Retain the selected range so the same toolbar can reverse the action.
    final start = targets.first.span.start;
    final end = targets.last.span.end;
    final forward = before.baseOffset <= before.extentOffset;
    controller.selection = before.copyWith(
      baseOffset: forward ? start : end,
      extentOffset: forward ? end : start,
    );
  }

  PromptEditorTag? get selectedGroup {
    PromptEditorTag? match;
    PromptEditorTag? explicitMatch;
    void visit(List<PromptEditorTag> siblings, List<int> parent) {
      for (var i = 0; i < siblings.length; i++) {
        final tag = siblings[i];
        if (tag.children.isEmpty) continue;
        final path = [...parent, i];
        final ids = tag.leaves.map((leaf) => leaf.id).toSet();
        if (ids.length == selected.length && ids.containsAll(selected)) {
          match = tag;
          if (listEquals(path, _selectedGroupPath)) explicitMatch = tag;
        }
        visit(tag.children, path);
      }
    }

    visit(tags, const []);
    return explicitMatch ?? match;
  }

  void selectGroup(PromptEditorTag group) {
    List<int>? locate(List<PromptEditorTag> siblings, List<int> parent) {
      for (var i = 0; i < siblings.length; i++) {
        final path = [...parent, i];
        if (identical(siblings[i], group)) return path;
        final nested = locate(siblings[i].children, path);
        if (nested != null) return nested;
      }
      return null;
    }

    _endEditing();
    _selectedGroupPath = locate(tags, const []);
    selected
      ..clear()
      ..addAll(group.leaves.map((tag) => tag.id));
    notifyListeners();
  }

  PromptEditorTag? byId(int id) {
    return _leafIndex[id];
  }

  void _reparse(Map<int, int> identities) {
    final spans = projectPromptDraft(controller.text, _draftSpan);
    var retainedEditing = false;
    PromptEditorTag build(PromptEditSpan span) {
      final range = _editingRange;
      final retainsEdit =
          !retainedEditing &&
          editing != null &&
          range != null &&
          span.children.isEmpty &&
          span.editStart >= range.start &&
          span.editStart <= range.end;
      if (retainsEdit) retainedEditing = true;
      return PromptEditorTag(
        retainsEdit ? editing! : identities[span.start] ?? _nextId++,
        span,
        span.children.map(build).toList(),
      );
    }

    tags = spans.map(build).toList();
    _leaves = tags.expand((tag) => tag.leaves).toList();
    _leafIndex = {for (final tag in _leaves) tag.id: tag};
    _nodeIndex = {};
    void index(List<PromptEditorTag> siblings) {
      for (final tag in siblings) {
        _nodeIndex[tag.id] = tag;
        index(tag.children);
      }
    }

    index(tags);
    final ids = _leafIndex.keys.toSet();
    selected.removeWhere((id) => !ids.contains(id));
    if (!ids.contains(editing)) editing = null;
  }

  void _changed() {
    if (_applying) return;
    final value = controller.value;
    if (value.text != _previous.text) {
      _draftSpan = null;
      _editingRange = null;
      editing = null;
      final before = _previous.text;
      var prefix = 0;
      while (prefix < before.length &&
          prefix < value.text.length &&
          before[prefix] == value.text[prefix]) {
        prefix++;
      }
      var suffix = 0;
      while (suffix < before.length - prefix &&
          suffix < value.text.length - prefix &&
          before[before.length - suffix - 1] ==
              value.text[value.text.length - suffix - 1]) {
        suffix++;
      }
      final delta = value.text.length - before.length;
      final identities = <int, int>{};
      for (final tag in nodes) {
        final start = tag.span.start;
        if (tag.span.end <= prefix) {
          identities[start] = tag.id;
        } else if (start >= before.length - suffix) {
          identities[start + delta] = tag.id;
        } else if (start <= prefix) {
          identities[start] = tag.id;
        }
      }
      if (!_restoring) {
        final now = DateTime.now();
        if (_lastTyping == null ||
            now.difference(_lastTyping!) > const Duration(milliseconds: 400)) {
          _past.add(_previous);
        }
        _lastTyping = now;
        _future.clear();
      }
      _reparse(identities);
    } else if (tagMode &&
        editing == null &&
        value.selection != _previous.selection) {
      final range = value.selection;
      if (range.isValid && !range.isCollapsed) {
        selected
          ..clear()
          ..addAll(
            leaves
                .where(
                  (tag) =>
                      tag.span.start < range.end && tag.span.end > range.start,
                )
                .map((tag) => tag.id),
          );
      }
    }
    _previous = value;
    notifyListeners();
  }

  void select(int id, {bool additive = false, bool range = false}) {
    _selectedGroupPath = null;
    _endEditing();
    if (range && anchor != null) {
      final list = leaves.toList();
      final a = list.indexWhere((tag) => tag.id == anchor);
      final b = list.indexWhere((tag) => tag.id == id);
      if (a >= 0 && b >= 0) {
        selected.clear();
        for (var i = a < b ? a : b; i <= (a > b ? a : b); i++) {
          selected.add(list[i].id);
        }
      }
    } else if (additive || touchSelection) {
      if (!selected.remove(id)) selected.add(id);
      anchor = id;
    } else {
      selected
        ..clear()
        ..add(id);
      anchor = id;
    }
    editing = null;
    _lastTyping = null;
    notifyListeners();
  }

  void selectAll() {
    _selectedGroupPath = null;
    _endEditing();
    editing = null;
    selected
      ..clear()
      ..addAll(leaves.map((tag) => tag.id));
    notifyListeners();
  }

  void beginTouchSelection(int id) {
    _endEditing();
    touchSelection = true;
    selected.add(id);
    anchor = id;
    notifyListeners();
  }

  void clearSelection() {
    _selectedGroupPath = null;
    _endEditing();
    selected.clear();
    editing = null;
    touchSelection = false;
    anchor = null;
    notifyListeners();
  }

  void edit(int id, {bool selectText = true}) {
    final span = byId(id)?.span;
    if (span == null) return;
    _editingRange = TextRange(start: span.editStart, end: span.editEnd);
    selected
      ..clear()
      ..add(id);
    editing = id;
    touchSelection = false;
    _lastTyping = null;
    selectTextOnEdit = selectText;
    notifyListeners();
  }

  void endEdit() {
    _endEditing();
    notifyListeners();
  }

  void _endEditing() {
    final hadDraft = _draftSpan != null;
    editing = null;
    _editingRange = null;
    _draftSpan = null;
    if (hadDraft) _reparse({for (final tag in nodes) tag.span.start: tag.id});
    _lastTyping = null;
  }

  void apply(
    List<PromptTextPatch> patches, {
    bool typing = false,
    Map<int, int> relocatedIdentities = const {},
  }) {
    if (patches.isEmpty) return;
    final ordered = [...patches]..sort((a, b) => a.start.compareTo(b.start));
    var lastEnd = -1;
    for (final patch in ordered) {
      if (patch.start < lastEnd ||
          patch.start < 0 ||
          patch.end > controller.text.length ||
          patch.end < patch.start) {
        throw ArgumentError('Overlapping or invalid prompt edit range');
      }
      lastEnd = patch.end;
    }
    var text = controller.text;
    for (final patch in ordered.reversed) {
      text = text.replaceRange(patch.start, patch.end, patch.text);
    }
    if (text == controller.text) return;
    final now = DateTime.now();
    if (!typing ||
        _lastTyping == null ||
        now.difference(_lastTyping!) > const Duration(milliseconds: 400)) {
      _past.add(controller.value);
    }
    _lastTyping = typing ? now : null;
    _future.clear();
    final identities = <int, int>{};
    for (final tag in nodes) {
      var offset = tag.span.start;
      var removed = false;
      for (final patch in ordered) {
        if (patch.end <= tag.span.start && patch.start != tag.span.start) {
          offset += patch.text.length - (patch.end - patch.start);
        } else if (patch.start <= tag.span.start &&
            patch.end > tag.span.start) {
          if (patch.start == tag.span.start && patch.text.isNotEmpty) {
            offset =
                patch.start +
                ordered
                    .where((p) => p.end <= patch.start && p != patch)
                    .fold<int>(
                      0,
                      (n, p) => n + p.text.length - (p.end - p.start),
                    );
          } else {
            removed = true;
          }
        }
      }
      if (!removed) identities[offset] = tag.id;
    }
    final cursor =
        (ordered.last.start +
                ordered.last.text.length +
                ordered
                    .take(ordered.length - 1)
                    .fold<int>(
                      0,
                      (n, p) => n + p.text.length - (p.end - p.start),
                    ))
            .clamp(0, text.length);
    _applying = true;
    try {
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: cursor),
      );
      _previous = controller.value;
      final relocatedIds = relocatedIdentities.values.toSet();
      identities.removeWhere((_, id) => relocatedIds.contains(id));
      identities.addAll(relocatedIdentities);
      _reparse(identities);
    } finally {
      _applying = false;
    }
    notifyListeners();
    onCommandChanged?.call(controller.text);
  }

  void replaceLabel(int id, String label, {bool composing = false}) {
    final previousText = controller.text;
    final tag = byId(id);
    if (tag == null) return;
    final span = tag.span;
    final range = editing == id ? _editingRange : null;
    final start = range?.start ?? span.editStart;
    final end = range?.end ?? span.editEnd;
    if (editing == id && !span.disabled) {
      _editingRange = TextRange(start: start, end: start + label.length);
    }
    final replacement = span.disabled
        ? PromptEditDocument.disable(label)
        : label;
    final patchStart = span.disabled ? span.start : start;
    final patchEnd = span.disabled ? span.end : end;
    final outerStart = span.start < patchStart ? span.start : patchStart;
    final originalEnd = span.end > patchEnd ? span.end : patchEnd;
    final outerEnd = originalEnd + replacement.length - (patchEnd - patchStart);
    _draftSpan = composing || label.trim().isEmpty
        ? PromptEditSpan(
            outerStart,
            outerEnd,
            controller.text.substring(outerStart, patchStart) +
                replacement +
                controller.text.substring(patchEnd, originalEnd),
            contentStart: span.disabled ? null : patchStart,
            contentEnd: span.disabled ? null : patchStart + replacement.length,
          )
        : null;
    apply([
      span.disabled
          ? PromptTextPatch(
              span.start,
              span.end,
              PromptEditDocument.disable(label),
            )
          : PromptTextPatch(start, end, label),
    ], typing: true);
    if (previousText == controller.text) {
      _reparse({for (final tag in nodes) tag.span.start: tag.id});
      notifyListeners();
    }
  }

  void toggleEnabled(Iterable<int> ids, {bool? enabled}) {
    final targets = ids.map(byId).whereType<PromptEditorTag>();
    apply([
      for (final tag in targets)
        if (tag.span.complete &&
            (enabled == null || tag.span.disabled == enabled))
          PromptTextPatch(
            tag.span.start,
            tag.span.end,
            tag.span.disabled
                ? tag.span.text
                : PromptEditDocument.disable(tag.span.raw),
          ),
    ]);
  }

  List<PromptTextPatch> _deletions(Set<int> ids) {
    bool included(PromptEditorTag tag) => tag.children.isEmpty
        ? ids.contains(tag.id)
        : tag.leaves.every((leaf) => ids.contains(leaf.id));
    final patches = <PromptTextPatch>[];
    void visit(List<PromptEditorTag> siblings) {
      var i = 0;
      while (i < siblings.length) {
        if (!included(siblings[i])) {
          visit(siblings[i].children);
          i++;
          continue;
        }
        final first = i;
        while (i + 1 < siblings.length && included(siblings[i + 1])) {
          i++;
        }
        final last = i;
        var start = siblings[first].span.start;
        var end = siblings[last].span.end;
        if (last + 1 < siblings.length) {
          end = siblings[last + 1].span.start;
        } else if (first > 0) {
          start = siblings[first - 1].span.end;
        }
        patches.add(PromptTextPatch(start, end, ''));
        i++;
      }
    }

    visit(tags);
    return patches;
  }

  void deleteSelected() {
    apply(_deletions(selected));
    clearSelection();
  }

  void insert(String text, {int? at}) {
    if (text.isEmpty) return;
    final source = controller.text;
    if (at != null) {
      if (at < 0 || at > source.length) {
        throw RangeError.range(at, 0, source.length);
      }
      apply([PromptTextPatch(at, at, text)]);
      return;
    }
    final separator = source.trim().isEmpty || source.trimRight().endsWith(',')
        ? ''
        : ', ';
    apply([PromptTextPatch(source.length, source.length, '$separator$text')]);
  }

  void setSelection(Iterable<int> ids) {
    _selectedGroupPath = null;
    selected
      ..clear()
      ..addAll(ids.where((id) => byId(id) != null));
    notifyListeners();
  }

  void moveSelectedBefore(int? targetId) {
    if (!structureComplete || selected.isEmpty || selected.contains(targetId)) {
      return;
    }
    if (selected.length == leaves.length) return;
    final selectedList = selectedTags;
    final target = targetId == null ? null : byId(targetId);
    final insertion = target?.span.start ?? controller.text.length;
    final deletions = _deletions(selected);
    if (deletions.any(
      (patch) => insertion > patch.start && insertion < patch.end,
    )) {
      return;
    }
    Iterable<PromptEditorTag> fragments(List<PromptEditorTag> siblings) sync* {
      for (final tag in siblings) {
        if (tag.leaves.every((leaf) => selected.contains(leaf.id))) {
          yield tag;
        } else {
          yield* fragments(tag.children);
        }
      }
    }

    final moving = fragments(tags).toList();
    final fragment = moving.map((tag) => tag.span.raw).join(', ');
    final patch = PromptTextPatch(
      insertion,
      insertion,
      target == null ? '${insertion == 0 ? '' : ', '}$fragment' : '$fragment, ',
    );
    final movedStart =
        insertion +
        deletions
            .where((p) => p.end <= insertion)
            .fold<int>(0, (offset, p) => offset - (p.end - p.start)) +
        (target == null && insertion != 0 ? 2 : 0);
    final movedIdentities = <int, int>{};
    var position = movedStart;
    for (final tag in moving) {
      for (final leaf in tag.leaves) {
        movedIdentities[position + leaf.span.start - tag.span.start] = leaf.id;
      }
      position += tag.span.raw.length + 2;
    }
    apply([...deletions, patch]);
    final identities = {for (final tag in nodes) tag.span.start: tag.id};
    identities.removeWhere((_, id) => selectedList.any((tag) => tag.id == id));
    identities.addAll(movedIdentities);
    _reparse(identities);
    setSelection(selectedList.map((tag) => tag.id));
  }

  PromptSelectionGrouping get selectionGrouping =>
      PromptSelectionGrouping.create(
        tags.map((tag) => tag.span).toList(),
        selectedTags.map((tag) => tag.span.start).toSet(),
      );

  void groupSelected(
    PromptSelectionGrouping plan,
    String prefix,
    String suffix,
  ) {
    final fragment = plan.wrap(prefix, suffix);
    final ids = {for (final tag in leaves) tag.span.start: tag.id};
    _selectedGroupPath = null;
    apply(
      [PromptTextPatch(plan.start, plan.end, fragment.text)],
      relocatedIdentities: {
        for (final entry in fragment.leafOffsets.entries)
          plan.start + entry.value: ids[entry.key]!,
      },
    );
    final group = selectedGroup;
    if (group != null) selectGroup(group);
  }

  String copySelection({bool effective = false}) {
    String? copy(PromptEditorTag tag) {
      if (tag.leaves.every((leaf) => selected.contains(leaf.id))) {
        return tag.span.raw;
      }
      final children = tag.children.map(copy).whereType<String>().toList();
      if (children.isEmpty) return null;
      return '${tag.span.prefix}${children.join(', ')}${tag.span.suffix}';
    }

    final text = tags.map(copy).whereType<String>().join(', ');
    return effective ? PromptEditDocument.effectiveText(text) : text;
  }

  void undo() {
    if (!canUndo) return;
    _future.add(controller.value);
    _restore(_past.removeLast());
  }

  void redo() {
    if (!canRedo) return;
    _past.add(controller.value);
    _restore(_future.removeLast());
  }

  void _restore(TextEditingValue value) {
    editing = null;
    _draftSpan = null;
    _editingRange = null;
    selected.clear();
    _lastTyping = null;
    _restoring = true;
    try {
      controller.value = value.copyWith(composing: TextRange.empty);
    } finally {
      _restoring = false;
    }
    onCommandChanged?.call(controller.text);
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    super.dispose();
  }
}
