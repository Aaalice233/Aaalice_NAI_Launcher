import '../../../core/utils/prompt_edit_document.dart';

/// Maps editable text to its lossless source. Disabled wrappers and their
/// escaping belong to storage, not to the native editor's character offsets.
class PromptTextProjection {
  PromptTextProjection(this.source) {
    var cursor = 0;
    final output = StringBuffer();
    for (final range in PromptEditDocument.disabledRanges(
      source,
      allowIncomplete: true,
    )) {
      // An unfinished literal must remain editable until its closing delimiter
      // exists; otherwise the user could not repair imported malformed syntax.
      if (PromptEditDocument.disabledEnd(source, range.$1) < 0) break;
      _append(cursor, range.$1, false, output);
      final hasContent =
          range.$2 - range.$1 > PromptEditDocument.disabledPrefix.length + 2;
      _append(range.$1, range.$2, hasContent, output);
      cursor = range.$2;
    }
    _append(cursor, source.length, false, output);
    text = output.toString();
  }

  final String source;
  late final String text;
  final List<int> characterOffsets = [];
  final List<_TextSegment> _segments = [];

  PromptTextProjection._edited(List<(String, bool)> parts)
    : source = parts.map((part) => part.$1).join() {
    final output = StringBuffer();
    var cursor = 0;
    for (final part in parts) {
      _append(cursor, cursor + part.$1.length, part.$2, output);
      cursor += part.$1.length;
    }
    text = output.toString();
  }

  void _append(int start, int end, bool disabled, StringBuffer output) {
    if (start == end) return;
    final displayStart = output.length;
    final contentStart = disabled
        ? start + PromptEditDocument.disabledPrefix.length
        : start;
    final contentEnd = disabled ? end - 2 : end;
    for (var i = contentStart; i < contentEnd; i++) {
      if (disabled &&
          source[i] == r'\' &&
          i + 1 < contentEnd &&
          (source[i + 1] == r'\' || source[i + 1] == '/')) {
        i++;
      }
      characterOffsets.add(i);
      output.write(source[i]);
    }
    _segments.add(
      _TextSegment(start, end, displayStart, output.length, disabled),
    );
  }

  int toDisplay(int sourceOffset) {
    if (sourceOffset < 0) return -1;
    var low = 0;
    var high = characterOffsets.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (characterOffsets[middle] < sourceOffset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  int toSource(int displayOffset, {bool end = false}) {
    if (displayOffset < 0) return -1;
    RangeError.checkValueInInterval(displayOffset, 0, text.length);
    if (end && displayOffset > 0) {
      return characterOffsets[displayOffset - 1] + 1;
    }
    return displayOffset < characterOffsets.length
        ? characterOffsets[displayOffset]
        : source.length;
  }

  /// Whole-fragment selections include their wrappers for source commands such
  /// as disabling, copying or deleting; partial selections keep content offsets.
  int selectionBoundary(int offset, {required bool end}) {
    for (final segment in _segments) {
      if (segment.disabled &&
          offset == (end ? segment.displayEnd : segment.displayStart)) {
        return end ? segment.sourceEnd : segment.sourceStart;
      }
    }
    return toSource(offset, end: end);
  }

  PromptTextProjection replace(int start, int end, String replacement) {
    for (final segment in _segments) {
      if (segment.disabled &&
          start >= segment.displayStart &&
          end <= segment.displayEnd) {
        final content = text.substring(
          segment.displayStart,
          segment.displayEnd,
        );
        final updated = content.replaceRange(
          start - segment.displayStart,
          end - segment.displayStart,
          replacement,
        );
        return PromptTextProjection._edited([
          ..._slice(0, segment.displayStart),
          if (updated.isNotEmpty) (PromptEditDocument.disable(updated), true),
          ..._slice(segment.displayEnd, text.length),
        ]);
      }
    }
    return PromptTextProjection._edited([
      ..._slice(0, start),
      (replacement, false),
      ..._slice(end, text.length),
    ]);
  }

  Iterable<(String, bool)> _slice(int start, int end) sync* {
    for (final segment in _segments) {
      final left = start > segment.displayStart ? start : segment.displayStart;
      final right = end < segment.displayEnd ? end : segment.displayEnd;
      if (left >= right) continue;
      if (left == segment.displayStart && right == segment.displayEnd) {
        yield (
          source.substring(segment.sourceStart, segment.sourceEnd),
          segment.disabled,
        );
      } else {
        final content = text.substring(left, right);
        yield (
          segment.disabled ? PromptEditDocument.disable(content) : content,
          segment.disabled,
        );
      }
    }
  }
}

class _TextSegment {
  const _TextSegment(
    this.sourceStart,
    this.sourceEnd,
    this.displayStart,
    this.displayEnd,
    this.disabled,
  );
  final int sourceStart;
  final int sourceEnd;
  final int displayStart;
  final int displayEnd;
  final bool disabled;
}
