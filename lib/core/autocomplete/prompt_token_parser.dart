import '../utils/alias_parser.dart';
import '../utils/character_prompt_block_parser.dart';
import 'completion_models.dart';

class PromptTokenParser {
  const PromptTokenParser._();

  static final RegExp _weightPrefix = RegExp(r'^[\s\{\[\(]+');
  static final RegExp _weightSuffix = RegExp(r'[\s\}\]\)]+$');
  static final RegExp _weightNumberSuffix = RegExp(r'(?::\s*-?\d+(?:\.\d+)?)$');
  static final RegExp _artistCategoryPrefix = RegExp(
    r'^artist:',
    caseSensitive: false,
  );

  static CompletionQuery parse({
    required String text,
    required int cursorPosition,
    required int limit,
    required String locale,
    bool splitOnSpaces = false,
  }) {
    final cursor = cursorPosition.clamp(0, text.length);
    final syntax = CharacterPromptBlockParser.parse(text);
    final negativeBlock = syntax.blockContaining(cursor, contentOnly: true);
    if (syntax.hasNegativeBlock &&
        negativeBlock == null &&
        syntax.blockContaining(cursor) != null) {
      return CompletionQuery(
        fullText: text,
        cursorPosition: cursor,
        token: '',
        replacementRange: TextReplacementRange(start: cursor, end: cursor),
        existingTags: _existingTags(
          syntax,
          token: '',
          splitOnSpaces: splitOnSpaces,
        ),
        limit: limit.clamp(1, CompletionResultLimits.all),
        locale: locale,
      );
    }
    final (isTypingAlias, partialAlias, aliasStart) =
        AliasParser.detectPartialAlias(text, cursor);
    if (isTypingAlias) {
      var replacementEnd = cursor;
      final closingBracket = text.indexOf('>', cursor);
      final nextLineBreak = text.indexOf(RegExp(r'[\r\n]'), cursor);
      if (closingBracket >= 0 &&
          (nextLineBreak < 0 || closingBracket < nextLineBreak)) {
        replacementEnd = closingBracket + 1;
      }
      return CompletionQuery(
        fullText: text,
        cursorPosition: cursor,
        token: partialAlias.trim().toLowerCase(),
        replacementRange: TextReplacementRange(
          start: aliasStart,
          end: replacementEnd,
        ),
        existingTags: const {},
        limit: limit.clamp(1, CompletionResultLimits.all),
        locale: locale,
        kind: CompletionQueryKind.libraryAlias,
      );
    }

    final lowerBound = negativeBlock?.contentRange.start ?? 0;
    final upperBound = negativeBlock?.contentRange.end ?? text.length;
    var start = cursor.clamp(lowerBound, upperBound);
    var end = start;

    while (start > lowerBound &&
        !_isSeparator(text.codeUnitAt(start - 1), splitOnSpaces)) {
      start--;
    }
    while (end < upperBound &&
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

    var replacementStart = start + prefix.length;
    final replacementEnd = start + contentEnd;
    final categoryPrefix = _artistCategoryPrefix.firstMatch(
      text.substring(replacementStart, replacementEnd),
    );
    final categoryFilter = categoryPrefix == null ? null : TagCategory.artist;
    replacementStart += categoryPrefix?.end ?? 0;
    final token = text
        .substring(replacementStart, replacementEnd)
        .trim()
        .replaceAll(' ', '_')
        .toLowerCase();

    final existingTags = _existingTags(
      syntax,
      token: token,
      splitOnSpaces: splitOnSpaces,
    );

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
      categoryFilter: categoryFilter,
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
    if (parsed.kind == CompletionQueryKind.libraryAlias) return null;
    if (parsed.token.isEmpty) {
      final before = text
          .substring(0, parsed.replacementRange.start)
          .trimRight();
      if (!before.endsWith(',')) return null;
      final withoutComma = before.substring(0, before.length - 1);
      final previous = withoutComma.split(RegExp(r'[,\n]')).last;
      final normalized = _normalizeExistingTag(previous);
      if (normalized.length < 2) return null;
      return parsed.copyWith(relatedTag: normalized);
    }
    if (parsed.token.length < 2) return null;

    var insertionPosition = parsed.replacementRange.end;
    final syntax = CharacterPromptBlockParser.parse(text);
    final negativeBlock = syntax.blockContaining(
      parsed.cursorPosition,
      contentOnly: true,
    );
    final upperBound = negativeBlock?.contentRange.end ?? text.length;
    while (insertionPosition < upperBound &&
        !_isSeparator(text.codeUnitAt(insertionPosition), splitOnSpaces)) {
      insertionPosition++;
    }
    if (insertionPosition < upperBound &&
        text.codeUnitAt(insertionPosition) == 0x2c) {
      insertionPosition++;
      while (insertionPosition < upperBound &&
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

  /// Returns whether an edit changed the tag fragment at the caret.
  ///
  /// Structural edits around a tag (line breaks, commas, boundary whitespace,
  /// or weight delimiters) must not query an untouched neighboring tag.
  static bool editChangesActiveToken({
    required String previousText,
    required int previousCursorPosition,
    required String currentText,
    required int currentCursorPosition,
    bool splitOnSpaces = false,
  }) {
    if (previousText == currentText) return false;

    final previous = parse(
      text: previousText,
      cursorPosition: previousCursorPosition,
      limit: 1,
      locale: '',
      splitOnSpaces: splitOnSpaces,
    );
    final current = parse(
      text: currentText,
      cursorPosition: currentCursorPosition,
      limit: 1,
      locale: '',
      splitOnSpaces: splitOnSpaces,
    );
    if (current.kind == CompletionQueryKind.tag &&
        current.token.isEmpty &&
        current.categoryFilter == null) {
      return false;
    }

    if (previous.categoryFilter != current.categoryFilter) return true;

    var prefixLength = 0;
    final sharedLength = previousText.length < currentText.length
        ? previousText.length
        : currentText.length;
    while (prefixLength < sharedLength &&
        previousText.codeUnitAt(prefixLength) ==
            currentText.codeUnitAt(prefixLength)) {
      prefixLength++;
    }

    var suffixLength = 0;
    while (suffixLength < previousText.length - prefixLength &&
        suffixLength < currentText.length - prefixLength &&
        previousText.codeUnitAt(previousText.length - suffixLength - 1) ==
            currentText.codeUnitAt(currentText.length - suffixLength - 1)) {
      suffixLength++;
    }
    final previousChangeEnd = previousText.length - suffixLength;
    final currentChangeEnd = currentText.length - suffixLength;
    final removed = previousText.substring(prefixLength, previousChangeEnd);
    final inserted = currentText.substring(prefixLength, currentChangeEnd);
    final changedCodeUnits = [...removed.codeUnits, ...inserted.codeUnits];
    if (changedCodeUnits.every(
      (unit) => unit == 0x2c || unit == 0x0a || unit == 0x0d,
    )) {
      return false;
    }

    final sameActiveToken =
        previous.kind == current.kind &&
        previous.token == current.token &&
        previous.categoryFilter == current.categoryFilter;
    if (sameActiveToken) {
      return !_sameSemanticTags(previousText, currentText, splitOnSpaces);
    }

    final insertedTouchesCurrentToken =
        currentChangeEnd > prefixLength &&
        prefixLength < current.replacementRange.end &&
        currentChangeEnd > current.replacementRange.start;
    if (insertedTouchesCurrentToken) return true;

    final removedTouchesPreviousToken =
        prefixLength < previous.replacementRange.end &&
        previousChangeEnd > previous.replacementRange.start;
    if (!removedTouchesPreviousToken) return false;

    final removedWholePreviousToken =
        prefixLength <= previous.replacementRange.start &&
        previousChangeEnd >= previous.replacementRange.end;
    return !removedWholePreviousToken;
  }

  static ({String text, int cursorPosition}) apply({
    required String text,
    required CompletionQuery query,
    required String canonicalTag,
    required bool autoInsertComma,
    required bool replaceUnderscores,
  }) {
    final tag = query.kind == CompletionQueryKind.libraryAlias
        ? '<$canonicalTag>'
        : replaceUnderscores
        ? canonicalTag.replaceAll('_', ' ')
        : canonicalTag;
    final range = query.replacementRange;
    final before = text.substring(0, range.start);
    var after = text.substring(range.end);
    final parsedSyntax = CharacterPromptBlockParser.parse(text);
    final negativeBlock = parsedSyntax.blockContaining(
      range.start,
      contentOnly: true,
    );

    if (query.relatedTag != null && range.start == range.end) {
      final alreadySeparated =
          before.trimRight().endsWith(',') ||
          before.trimRight().endsWith('\n') ||
          before.trimRight().endsWith('\r');
      final prefix = before.isEmpty || alreadySeparated ? '' : ', ';
      final contentAfter = negativeBlock == null
          ? after
          : text.substring(range.end, negativeBlock.contentRange.end);
      final hasFollowingTag = contentAfter.trimLeft().isNotEmpty;
      final suffix = autoInsertComma || hasFollowingTag ? ', ' : '';
      final insertion = '$prefix$tag$suffix';
      final result = '$before$insertion$after';
      return (text: result, cursorPosition: before.length + insertion.length);
    }

    var insertion = tag;
    if (autoInsertComma) {
      final syntaxEnd = negativeBlock == null
          ? after.length
          : (negativeBlock.contentRange.end - range.end).clamp(0, after.length);
      final syntaxSuffix = RegExp(
        r'^(?::\s*-?\d+(?:\.\d+)?)?[\}\]\)]*',
      ).firstMatch(after.substring(0, syntaxEnd))!.group(0)!;
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

  static bool _sameSemanticTags(
    String previousText,
    String currentText,
    bool splitOnSpaces,
  ) {
    List<String> tags(String text) {
      final parsed = CharacterPromptBlockParser.parse(text);
      final separator = splitOnSpaces ? RegExp(r'[,\n\s]+') : RegExp(r'[,\n]');
      return _semanticText(parsed)
          .split(separator)
          .map(_normalizeExistingTag)
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false);
    }

    final previousTags = tags(previousText);
    final currentTags = tags(currentText);
    if (previousTags.length != currentTags.length) return false;
    for (var index = 0; index < previousTags.length; index++) {
      if (previousTags[index] != currentTags[index]) return false;
    }
    return true;
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
    value = value.replaceFirst(_artistCategoryPrefix, '');
    return value.trim().replaceAll(' ', '_').toLowerCase();
  }

  static Set<String> _existingTags(
    CharacterPromptBlockParseResult parsed, {
    required String token,
    required bool splitOnSpaces,
  }) {
    final tags = <String>{};
    final separator = splitOnSpaces ? RegExp(r'[,\n\s]+') : RegExp(r'[,\n]');
    for (final segment in _semanticText(parsed).split(separator)) {
      final normalized = _normalizeExistingTag(segment);
      if (normalized.isNotEmpty && normalized != token) tags.add(normalized);
    }
    return tags;
  }

  static String _semanticText(CharacterPromptBlockParseResult parsed) => [
    parsed.positivePrompt,
    parsed.negativePrompt,
  ].where((part) => part.isNotEmpty).join(', ');
}
