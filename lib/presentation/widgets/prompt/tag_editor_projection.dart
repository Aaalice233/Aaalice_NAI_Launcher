import '../../../core/utils/prompt_edit_document.dart';

/// An IME composition owns its source range until commit. Temporary masking is
/// used only for parsing; source text and saved data never contain placeholders.
List<PromptEditSpan> projectPromptDraft(String source, PromptEditSpan? draft) {
  final projected = PromptEditDocument.parse(
    draft == null
        ? source
        : source.replaceRange(
            draft.start,
            draft.end,
            'x' * (draft.end - draft.start),
          ),
  );
  PromptEditSpan restore(PromptEditSpan span) {
    if (draft != null && span.start == draft.start && span.end == draft.end) {
      return draft;
    }
    return PromptEditSpan(
      span.start,
      span.end,
      source.substring(span.start, span.end),
      complete: span.complete,
      contentStart: span.contentStart,
      contentEnd: span.contentEnd,
      children: span.children.map(restore).toList(),
    );
  }

  var spans = projected.map(restore).toList();
  if (draft != null && draft.start == draft.end) {
    List<PromptEditSpan> insertDraft(List<PromptEditSpan> siblings) {
      for (var i = 0; i < siblings.length; i++) {
        final parent = siblings[i];
        if (parent.children.isNotEmpty &&
            draft.start >= parent.editStart &&
            draft.end <= parent.editEnd) {
          return [
            ...siblings.take(i),
            PromptEditSpan(
              parent.start,
              parent.end,
              parent.raw,
              complete: parent.complete,
              contentStart: parent.contentStart,
              contentEnd: parent.contentEnd,
              children: insertDraft(parent.children),
            ),
            ...siblings.skip(i + 1),
          ];
        }
      }
      return [...siblings, draft]..sort((a, b) => a.start.compareTo(b.start));
    }

    spans = insertDraft(spans);
  }
  return spans;
}
