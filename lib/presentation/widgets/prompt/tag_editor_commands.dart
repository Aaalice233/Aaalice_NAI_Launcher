import '../../../l10n/app_localizations.dart';
import 'nai_syntax_controller.dart';
import 'prompt_weight_editing.dart';
import 'tag_editor_session.dart';

enum TagEditorAction {
  edit,
  weight,
  enable,
  disable,
  copy,
  copyEffective,
  cut,
  paste,
  delete,
  selectAll,
  previous,
  next,
  first,
  last,
  undo,
  redo,
}

String tagEditorActionLabel(TagEditorAction action, AppLocalizations l10n) =>
    switch (action) {
      TagEditorAction.edit => l10n.common_edit,
      TagEditorAction.weight => l10n.tagMode_weight,
      TagEditorAction.enable => l10n.tagMode_enable,
      TagEditorAction.disable => l10n.tagMode_disable,
      TagEditorAction.copy => l10n.common_copy,
      TagEditorAction.copyEffective => l10n.tagMode_copyEffective,
      TagEditorAction.cut => l10n.tagMode_cut,
      TagEditorAction.paste => l10n.common_paste,
      TagEditorAction.delete => l10n.common_delete,
      TagEditorAction.selectAll => l10n.common_selectAll,
      TagEditorAction.previous => l10n.tagMode_movePrevious,
      TagEditorAction.next => l10n.tagMode_moveNext,
      TagEditorAction.first => l10n.tagMode_moveFirst,
      TagEditorAction.last => l10n.tagMode_moveLast,
      TagEditorAction.undo => l10n.common_undo,
      TagEditorAction.redo => l10n.common_redo,
    };

class TagEditorCommands {
  const TagEditorCommands(this.session);
  final TagEditorSession session;
  bool get canAdjust =>
      session.structureComplete && session.selectedTags.isNotEmpty;
  double? get weight {
    final weights = session.selectedTags
        .map(
          (tag) => PromptWeightEditing.parseWeightSyntax(tag.span.text).weight,
        )
        .toSet();
    return weights.length == 1 ? weights.single : null;
  }

  void adjustWeight({double? value, double? step}) {
    if (!canAdjust) return;
    final controller = session.controller;
    final numeric =
        controller is! NaiSyntaxController || controller.numericEmphasisEnabled;
    session.apply([
      for (final tag in session.selectedTags)
        PromptTextPatch(
          tag.span.start,
          tag.span.end,
          PromptWeightEditing.withWeight(
            tag.span.raw,
            value ??
                PromptWeightEditing.parseWeightSyntax(tag.span.text).weight +
                    step!,
            numericEmphasisEnabled: numeric,
          ),
        ),
    ]);
  }

  bool available(TagEditorAction action) => switch (action) {
    TagEditorAction.undo => session.canUndo,
    TagEditorAction.redo => session.canRedo,
    TagEditorAction.selectAll => session.tags.isNotEmpty,
    TagEditorAction.paste => true,
    TagEditorAction.edit => session.selected.length == 1,
    TagEditorAction.previous ||
    TagEditorAction.next ||
    TagEditorAction.first ||
    TagEditorAction.last =>
      session.structureComplete &&
          session.selected.isNotEmpty &&
          session.selected.length < session.leaves.length,
    TagEditorAction.weight ||
    TagEditorAction.enable ||
    TagEditorAction.disable => canAdjust,
    _ => session.selected.isNotEmpty,
  };
  void move(TagEditorAction action) {
    if (!available(action)) return;
    final all = session.leaves.toList();
    final first = all.indexWhere((tag) => session.selected.contains(tag.id));
    final last = all.lastIndexWhere((tag) => session.selected.contains(tag.id));
    int? target;
    switch (action) {
      case TagEditorAction.previous:
        if (first == 0) return;
        target = all[first - 1].id;
      case TagEditorAction.next:
        if (last == all.length - 1) return;
        target = last + 2 < all.length ? all[last + 2].id : null;
      case TagEditorAction.first:
        target = all.first.id;
      case TagEditorAction.last:
        target = null;
      default:
        return;
    }
    session.moveSelectedBefore(target);
  }
}
