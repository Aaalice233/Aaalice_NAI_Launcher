/// Recognizes opaque textual fragments without interpreting or rendering HTML.
/// Angle brackets that are not closed markup (for example `<3` and `a < b`)
/// remain ordinary characters rather than becoming prompt weight boundaries.
abstract final class PromptLiteralScanner {
  static final _elementName = RegExp(r'^<([A-Za-z][A-Za-z0-9:_-]*)(?:\s|/?>)');

  static int? endAt(String source, int start, int upper) {
    if (source[start] == '<') return _angleEnd(source, start, upper);
    final quote = source[start];
    if ((quote == '"' || quote == "'") &&
        (start == 0 ||
            source[start - 1].trim().isEmpty ||
            ',([{'.contains(source[start - 1]))) {
      return _quoteEnd(source, start, upper);
    }
    return null;
  }

  static int? _quoteEnd(String source, int start, int upper) {
    for (var i = start + 1; i < upper; i++) {
      if (source[i] == r'\') {
        i++;
        continue;
      }
      if (source[i] == source[start]) return i + 1;
    }
    return null;
  }

  static int? _openingEnd(String source, int start, int upper) {
    for (var i = start + 1; i < upper; i++) {
      if (source[i] == r'\') {
        i++;
        continue;
      }
      if (source[i] == '"' || source[i] == "'") {
        final end = _quoteEnd(source, i, upper);
        if (end == null) return null;
        i = end - 1;
      } else if (source[i] == '<' || source[i] == '\n') {
        return null;
      } else if (source[i] == '>') {
        return i + 1;
      }
    }
    return null;
  }

  static int? _angleEnd(String source, int start, int upper) {
    if (source.startsWith('<!--', start)) {
      final end = source.indexOf('-->', start + 4);
      return end >= 0 && end + 3 <= upper ? end + 3 : null;
    }
    final openingEnd = _openingEnd(source, start, upper);
    if (openingEnd == null) return null;
    final opening = source.substring(start, openingEnd);
    final name = _elementName.firstMatch(opening)?.group(1);
    if (name == null || opening.endsWith('/>')) return openingEnd;
    final closing = source.indexOf('</$name>', openingEnd);
    if (closing < 0 || closing >= upper) return openingEnd;
    var depth = 1;
    var cursor = openingEnd;
    // A matching closing element makes the entire block opaque, including
    // commas in its prose. A lone <name> is still a valid library reference.
    while (cursor < upper) {
      final next = source.indexOf('<', cursor);
      if (next < 0 || next >= upper) break;
      final end = _openingEnd(source, next, upper);
      if (end == null) {
        cursor = next + 1;
        continue;
      }
      final token = source.substring(next, end);
      if (token == '</$name>') {
        depth--;
        if (depth == 0) return end;
      } else if (_elementName.firstMatch(token)?.group(1) == name &&
          !token.endsWith('/>')) {
        depth++;
      }
      cursor = end;
    }
    return openingEnd;
  }
}
