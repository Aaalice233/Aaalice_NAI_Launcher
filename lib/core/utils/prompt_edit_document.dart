import 'prompt_literal_scanner.dart';

/// A lossless projection of prompt text. Ranges always refer to the source,
/// including disabled wrappers; whitespace and separators are never rebuilt.
class PromptEditSpan {
  const PromptEditSpan(
    this.start,
    this.end,
    this.raw, {
    this.complete = true,
    this.children = const [],
    this.contentStart,
    this.contentEnd,
  });
  final int start;
  final int end;
  final String raw;
  final bool complete;
  final List<PromptEditSpan> children;
  final int? contentStart;
  final int? contentEnd;
  bool get disabled =>
      raw.startsWith(PromptEditDocument.disabledPrefix) &&
      PromptEditDocument.disabledEnd(raw, 0) == raw.length;
  String get text => disabled ? PromptEditDocument.decodeDisabled(raw) : raw;
  int get editStart => contentStart ?? start;
  int get editEnd => contentEnd ?? end;
  String get label =>
      disabled ? text : raw.substring(editStart - start, editEnd - start);
  String get prefix => raw.substring(0, editStart - start);
  String get suffix => raw.substring(editEnd - start);
  Iterable<PromptEditSpan> get leaves sync* {
    if (children.isEmpty) {
      yield this;
    } else {
      for (final child in children) {
        yield* child.leaves;
      }
    }
  }
}

class PromptEditDocument {
  const PromptEditDocument._();
  static const disabledPrefix = '/*disabled:';
  static final _numericOpening = RegExp(r'-?(?:\d+(?:\.\d*)?|\.\d+)::');

  static String disable(String text) =>
      '$disabledPrefix${text.replaceAll(r'\', r'\\').replaceAll('*/', r'*\/')}*/';

  static String decodeDisabled(String text) {
    if (!text.startsWith(disabledPrefix) || !text.endsWith('*/')) return text;
    final content = text.substring(disabledPrefix.length, text.length - 2);
    final result = StringBuffer();
    for (var i = 0; i < content.length; i++) {
      if (content[i] == r'\' &&
          i + 1 < content.length &&
          (content[i + 1] == r'\' || content[i + 1] == '/')) {
        i++;
      }
      result.write(content[i]);
    }
    return result.toString();
  }

  static int disabledEnd(String source, int start) {
    for (var i = start + disabledPrefix.length; i < source.length - 1; i++) {
      if (source[i] == r'\') {
        i++;
        continue;
      }
      if (source.startsWith('*/', i)) return i + 2;
    }
    return -1;
  }

  static List<(int, int)> disabledRanges(
    String source, {
    bool allowIncomplete = false,
  }) {
    final ranges = <(int, int)>[];
    for (var i = 0; i < source.length; i++) {
      if (source[i] == r'\') {
        i++;
        continue;
      }
      if (!source.startsWith(disabledPrefix, i)) continue;
      final end = disabledEnd(source, i);
      if (end < 0 && !allowIncomplete) {
        throw FormatException('Unclosed disabled prompt fragment', source, i);
      }
      ranges.add((i, end < 0 ? source.length : end));
      i = ranges.last.$2 - 1;
    }
    return ranges;
  }

  static List<PromptEditSpan> parse(String source) =>
      _parse(source, 0, source.length);

  static List<PromptEditSpan> _parse(String source, int lower, int upper) {
    final spans = <PromptEditSpan>[];
    var start = lower;
    final stack = <String>[];
    var pipe = false;
    var complete = true;
    void append(int end) {
      var left = start;
      var right = end;
      while (left < right && source[left].trim().isEmpty) {
        left++;
      }
      while (right > left && source[right - 1].trim().isEmpty) {
        right--;
      }
      if (left < right) {
        spans.add(
          _span(source, left, right, complete && stack.isEmpty && !pipe),
        );
      }
      start = end + 1;
      complete = true;
    }

    for (var i = lower; i < upper; i++) {
      final char = source[i];
      if (char == r'\') {
        i++;
        continue;
      }
      if (source.startsWith(disabledPrefix, i)) {
        final end = disabledEnd(source, i);
        if (end < 0) {
          complete = false;
          break;
        }
        i = end - 1;
        continue;
      }
      final literalEnd = PromptLiteralScanner.endAt(source, i, upper);
      if (literalEnd != null) {
        i = literalEnd - 1;
        continue;
      }
      if (source.startsWith('||', i)) {
        pipe = !pipe;
        i++;
        continue;
      }
      if (pipe) continue;
      final numeric = _numericOpening.matchAsPrefix(source, i);
      if (numeric != null &&
          (i == start ||
              source[i - 1].trim().isEmpty ||
              '{[,'.contains(source[i - 1]))) {
        if (!stack.contains('::')) stack.add('::');
        i = numeric.end - 1;
        continue;
      }
      if (source.startsWith('::', i) &&
          stack.isNotEmpty &&
          stack.last == '::') {
        stack.removeLast();
        i++;
        continue;
      }
      if ('{[('.contains(char)) stack.add(char);
      if ('}])'.contains(char)) {
        if (stack.isEmpty || '{[('.indexOf(stack.last) != '}])'.indexOf(char)) {
          complete = false;
        } else {
          stack.removeLast();
        }
      }
      if ((char == ',' || char == '\n') && stack.isEmpty) append(i);
    }
    append(upper);
    return spans;
  }

  static PromptEditSpan _span(
    String source,
    int start,
    int end,
    bool complete,
  ) {
    final raw = source.substring(start, end);
    if (!complete || raw.startsWith(disabledPrefix)) {
      return PromptEditSpan(start, end, raw, complete: complete);
    }
    var innerStart = start;
    var innerEnd = end;
    final numeric = _numericOpening.matchAsPrefix(source, start);
    if (numeric != null && raw.endsWith('::')) {
      innerStart = numeric.end;
      innerEnd -= 2;
    } else if ((raw.startsWith('{') && raw.endsWith('}')) ||
        (raw.startsWith('[') && raw.endsWith(']'))) {
      innerStart++;
      innerEnd--;
    } else if (raw.startsWith('negative(') && raw.endsWith(')')) {
      innerStart += 'negative('.length;
      innerEnd--;
    }
    if (innerStart == start || innerStart >= innerEnd) {
      return PromptEditSpan(start, end, raw);
    }
    final children = _parse(source, innerStart, innerEnd);
    if (children.any((child) => !child.complete)) {
      return PromptEditSpan(start, end, raw);
    }
    // Consecutive bracket shells describe one weight, not separate groups.
    // Keep numeric resets and real subgroups as distinct editing boundaries.
    if (children.length == 1 &&
        RegExp(r'^[\{\[]+$').hasMatch(raw.substring(0, innerStart - start)) &&
        RegExp(r'^[\{\[]+$').hasMatch(children.single.prefix)) {
      final child = children.single;
      return PromptEditSpan(
        start,
        end,
        raw,
        children: child.children,
        contentStart: child.editStart,
        contentEnd: child.editEnd,
      );
    }
    // A single weighted tag stays a single capsule; nested groups retain their
    // actual boundaries instead of distributing a group weight over its tags.
    if (children.length == 1 &&
        children.single.children.isEmpty &&
        !raw.startsWith('negative(') &&
        !children.single.disabled) {
      return PromptEditSpan(
        start,
        end,
        raw,
        contentStart: children.single.editStart,
        contentEnd: children.single.editEnd,
      );
    }
    return PromptEditSpan(
      start,
      end,
      raw,
      children: children,
      contentStart: innerStart,
      contentEnd: innerEnd,
    );
  }

  static PromptEditSpan? singleSelected(String source, int start, int end) {
    if (start < 0 || end > source.length || start >= end) return null;
    while (start < end && source[start].trim().isEmpty) {
      start++;
    }
    while (end > start && source[end - 1].trim().isEmpty) {
      end--;
    }
    for (final root in parse(source)) {
      for (final leaf in root.leaves) {
        if (leaf.complete &&
            ((start == leaf.start && end == leaf.end) ||
                (start == leaf.editStart && end == leaf.editEnd))) {
          return leaf;
        }
      }
    }
    return null;
  }

  /// Runs before any expansion so disabled aliases cannot execute.
  static String effectiveText(String source) {
    final markers = disabledRanges(source);
    if (markers.isEmpty) return source;
    final ranges = <(int, int)>[];
    bool excluded(PromptEditSpan span) =>
        span.disabled ||
        (span.children.isNotEmpty && span.children.every(excluded));
    void visit(List<PromptEditSpan> siblings) {
      for (var i = 0; i < siblings.length; i++) {
        if (!excluded(siblings[i])) {
          visit(siblings[i].children);
          continue;
        }
        final first = i;
        while (i + 1 < siblings.length && excluded(siblings[i + 1])) {
          i++;
        }
        final start = i + 1 == siblings.length && first > 0
            ? siblings[first - 1].end
            : siblings[first].start;
        final end = i + 1 < siblings.length
            ? siblings[i + 1].start
            : siblings[i].end;
        ranges.add((start, end));
      }
    }

    visit(parse(source));
    // Inline markers in natural-language or opaque fragments do not own the
    // surrounding text or delimiters; remove only the explicitly marked bytes.
    ranges.addAll(
      markers
          .where(
            (marker) => !ranges.any(
              (range) => range.$1 <= marker.$1 && range.$2 >= marker.$2,
            ),
          )
          .toList(),
    );
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    final result = StringBuffer();
    var cursor = 0;
    for (final range in ranges) {
      if (range.$1 > cursor) result.write(source.substring(cursor, range.$1));
      if (range.$2 > cursor) cursor = range.$2;
    }
    result.write(source.substring(cursor));
    return result.toString();
  }

  /// Formatting may transform active text, but must not rewrite the reversible
  /// payload of a disabled fragment, including an unfinished marker being typed.
  static String mapActiveText(
    String source,
    String Function(String) transform,
  ) {
    final result = StringBuffer();
    var cursor = 0;
    for (var i = 0; i < source.length; i++) {
      if (source[i] == r'\') {
        i++;
        continue;
      }
      if (!source.startsWith(disabledPrefix, i)) continue;
      final end = disabledEnd(source, i);
      result.write(transform(source.substring(cursor, i)));
      if (end < 0) {
        result.write(source.substring(i));
        return result.toString();
      }
      result.write(source.substring(i, end));
      cursor = end;
      i = end - 1;
    }
    result.write(transform(source.substring(cursor)));
    return result.toString();
  }

  static void requireEffective(String source, {required String field}) {
    if (effectiveText(source) != source) {
      throw StateError('Unprocessed disabled prompt fragment in $field');
    }
  }
}
