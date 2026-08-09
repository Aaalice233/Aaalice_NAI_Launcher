import 'completion_models.dart';

class PromptTokenParser {
  const PromptTokenParser._();

  static final RegExp _weightPrefix = RegExp(r'^[\s\{\[\(]+');
  static final RegExp _weightSuffix = RegExp(r'[\s\}\]\)]+$');
  static final RegExp _weightNumberSuffix = RegExp(r'(?::\s*-?\d+(?:\.\d+)?)$');

  static CompletionQuery parse({
    required String text,
    required int cursorPosition,
    required int limit,
    required String locale,
    bool splitOnSpaces = false,
  }) {
    final cursor = cursorPosition.clamp(0, text.length);
    var start = cursor;
    var end = cursor;

    while (start > 0 &&
        !_isSeparator(text.codeUnitAt(start - 1), splitOnSpaces)) {
      start--;
    }
    while (end < text.length &&
        !_isSeparator(text.codeUnitAt(end), splitOnSpaces)) {
      end++;
    }

    final raw = text.substring(start, end);
    final prefix = _weightPrefix.firstMatch(raw)?.group(0) ?? '';
    final afterPrefix = raw.substring(prefix.length);
    final suffixMatch = _weightSuffix.firstMatch(afterPrefix);
    final suffixLength = suffixMatch?.group(0)?.length ?? 0;
    final withoutSuffixEnd = raw.length - suffixLength;
    final beforeSuffix = raw.substring(prefix.length, withoutSuffixEnd);
    final weightNumber = _weightNumberSuffix.firstMatch(beforeSuffix);
    final contentEnd = weightNumber == null
        ? withoutSuffixEnd
        : prefix.length + weightNumber.start;

    final replacementStart = start + prefix.length;
    final replacementEnd = start + contentEnd;
    final token = text
        .substring(replacementStart, replacementEnd)
        .trim()
        .replaceAll(' ', '_')
        .toLowerCase();

    final existingTags = <String>{};
    final tagSeparator = splitOnSpaces ? RegExp(r'[,\n\s]+') : RegExp(r'[,\n]');
    for (final segment in text.split(tagSeparator)) {
      final normalized = _normalizeExistingTag(segment);
      if (normalized.isNotEmpty && normalized != token) {
        existingTags.add(normalized);
      }
    }

    String? relatedTag;
    if (token.isEmpty) {
      final before = text.substring(0, start).trimRight();
      if (before.endsWith(',')) {
        final withoutComma = before.substring(0, before.length - 1);
        final previous = withoutComma.split(RegExp(r'[,\n]')).last;
        final normalized = _normalizeExistingTag(previous);
        if (normalized.length >= 2) relatedTag = normalized;
      }
    }

    return CompletionQuery(
      fullText: text,
      cursorPosition: cursor,
      token: token,
      replacementRange: TextReplacementRange(
        start: replacementStart,
        end: replacementEnd,
      ),
      existingTags: existingTags,
      limit: limit.clamp(1, CompletionResultLimits.all),
      locale: locale,
      relatedTag: relatedTag,
    );
  }

  /// Builds an insertion query for the complete tag under the caret.
  ///
  /// Unlike normal completion this never replaces the source tag. The result
  /// is inserted after its segment, or after the following comma when one is
  /// already present, so weighted NovelAI syntax remains untouched.
  static CompletionQuery? parseRelated({
    required String text,
    required int cursorPosition,
    required int limit,
    required String locale,
    bool splitOnSpaces = false,
  }) {
    final parsed = parse(
      text: text,
      cursorPosition: cursorPosition,
      limit: limit,
      locale: locale,
      splitOnSpaces: splitOnSpaces,
    );
    if (parsed.relatedTag != null) return parsed;
    if (parsed.token.length < 2) return null;

    var insertionPosition = parsed.replacementRange.end;
    while (insertionPosition < text.length &&
        !_isSeparator(text.codeUnitAt(insertionPosition), splitOnSpaces)) {
      insertionPosition++;
    }
    if (insertionPosition < text.length &&
        text.codeUnitAt(insertionPosition) == 0x2c) {
      insertionPosition++;
      while (insertionPosition < text.length &&
          (text.codeUnitAt(insertionPosition) == 0x20 ||
              text.codeUnitAt(insertionPosition) == 0x09)) {
        insertionPosition++;
      }
    }

    return CompletionQuery(
      fullText: text,
      cursorPosition: insertionPosition,
      token: '',
      replacementRange: TextReplacementRange(
        start: insertionPosition,
        end: insertionPosition,
      ),
      existingTags: {...parsed.existingTags, parsed.token},
      limit: parsed.limit,
      locale: parsed.locale,
      relatedTag: parsed.token,
    );
  }

  static ({String text, int cursorPosition}) apply({
    required String text,
    required CompletionQuery query,
    required String canonicalTag,
    required bool autoInsertComma,
    required bool replaceUnderscores,
  }) {
    final tag = replaceUnderscores
        ? canonicalTag.replaceAll('_', ' ')
        : canonicalTag;
    final range = query.replacementRange;
    final before = text.substring(0, range.start);
    var after = text.substring(range.end);

    if (query.relatedTag != null && range.start == range.end) {
      final alreadySeparated =
          before.trimRight().endsWith(',') ||
          before.trimRight().endsWith('\n') ||
          before.trimRight().endsWith('\r');
      final prefix = before.isEmpty || alreadySeparated ? '' : ', ';
      final hasFollowingTag = after.trimLeft().isNotEmpty;
      final suffix = autoInsertComma || hasFollowingTag ? ', ' : '';
      final insertion = '$prefix$tag$suffix';
      final result = '$before$insertion$after';
      return (text: result, cursorPosition: before.length + insertion.length);
    }

    var insertion = tag;
    if (autoInsertComma) {
      final syntaxSuffix = RegExp(
        r'^(?::\s*-?\d+(?:\.\d+)?)?[\}\]\)]*',
      ).firstMatch(after)!.group(0)!;
      final contentAfterSyntax = after.substring(syntaxSuffix.length);
      final existingComma = RegExp(r'^\s*,\s*').firstMatch(contentAfterSyntax);
      if (existingComma == null) {
        insertion = '$insertion$syntaxSuffix, ';
        after = contentAfterSyntax;
      } else {
        insertion = '$insertion$syntaxSuffix${existingComma.group(0)}';
        after = contentAfterSyntax.substring(existingComma.end);
      }
    }

    final result = '$before$insertion$after';
    return (text: result, cursorPosition: before.length + insertion.length);
  }

  static bool _isSeparator(int codeUnit, bool splitOnSpaces) =>
      codeUnit == 0x2c ||
      codeUnit == 0x0a ||
      codeUnit == 0x0d ||
      (splitOnSpaces && (codeUnit == 0x20 || codeUnit == 0x09));

  static String _normalizeExistingTag(String raw) {
    var value = raw.trim();
    value = value.replaceFirst(_weightPrefix, '');
    value = value.replaceFirst(_weightSuffix, '');
    value = value.replaceFirst(_weightNumberSuffix, '');
    return value.trim().replaceAll(' ', '_').toLowerCase();
  }
}
