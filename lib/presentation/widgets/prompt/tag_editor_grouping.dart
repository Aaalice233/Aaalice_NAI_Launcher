import '../../../core/utils/prompt_edit_document.dart';

/// A selection is gathered at its nearest common parent, retaining any
/// partially selected inner wrappers on both sides of the split.
class PromptSelectionGrouping {
  PromptSelectionGrouping._(
    this.start,
    this.end,
    this.selected,
    this.remaining,
    this.numericEmphasisAllowed,
  );

  final int start;
  final int end;
  final PromptGroupFragment selected;
  final PromptGroupFragment remaining;
  final bool numericEmphasisAllowed;

  static PromptSelectionGrouping create(
    List<PromptEditSpan> roots,
    Set<int> selectedStarts,
  ) {
    var siblings = roots;
    var weightedParent = false;
    while (true) {
      final containing = siblings
          .where(
            (span) =>
                span.children.isNotEmpty &&
                span.leaves
                        .where((leaf) => selectedStarts.contains(leaf.start))
                        .length ==
                    selectedStarts.length,
          )
          .firstOrNull;
      if (containing == null) break;
      weightedParent |=
          containing.prefix.endsWith('::') ||
          containing.prefix.endsWith('{') ||
          containing.prefix.endsWith('[');
      siblings = containing.children;
    }
    bool affected(PromptEditSpan span) =>
        span.leaves.any((leaf) => selectedStarts.contains(leaf.start));
    final first = siblings.indexWhere(affected);
    final last = siblings.lastIndexWhere(affected);
    if (first < 0) throw StateError('No tags selected for grouping');
    final region = siblings.sublist(first, last + 1);

    PromptGroupFragment? split(PromptEditSpan span, bool keepSelected) {
      final leaves = span.leaves.toList();
      final count = leaves
          .where((leaf) => selectedStarts.contains(leaf.start) == keepSelected)
          .length;
      if (count == 0) return null;
      if (count == leaves.length) {
        return PromptGroupFragment(span.raw, {
          for (final leaf in leaves) leaf.start: leaf.start - span.start,
        });
      }
      return PromptGroupFragment.join(
        span.children
            .map((child) => split(child, keepSelected))
            .whereType<PromptGroupFragment>(),
      ).wrap(span.prefix, span.suffix);
    }

    final selected = PromptGroupFragment.join(
      region.map((span) => split(span, true)).whereType<PromptGroupFragment>(),
    );
    return PromptSelectionGrouping._(
      region.first.start,
      region.last.end,
      selected,
      PromptGroupFragment.join(
        region
            .map((span) => split(span, false))
            .whereType<PromptGroupFragment>(),
      ),
      !weightedParent && !selected.text.contains('::'),
    );
  }

  PromptGroupFragment wrap(String prefix, String suffix) =>
      PromptGroupFragment.join([selected.wrap(prefix, suffix), remaining]);
}

class PromptGroupFragment {
  const PromptGroupFragment(this.text, this.leafOffsets);
  final String text;
  // Original source starts map to offsets in this fragment, including wrappers.
  final Map<int, int> leafOffsets;

  static PromptGroupFragment join(Iterable<PromptGroupFragment> fragments) {
    final buffer = StringBuffer();
    final offsets = <int, int>{};
    for (final fragment in fragments) {
      if (fragment.text.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.write(', ');
      final start = buffer.length;
      offsets.addAll(
        fragment.leafOffsets.map((key, value) => MapEntry(key, start + value)),
      );
      buffer.write(fragment.text);
    }
    return PromptGroupFragment(buffer.toString(), offsets);
  }

  PromptGroupFragment wrap(String prefix, String suffix) => PromptGroupFragment(
    '$prefix$text$suffix',
    leafOffsets.map((key, value) => MapEntry(key, prefix.length + value)),
  );
}
