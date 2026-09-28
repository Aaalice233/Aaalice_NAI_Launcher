/// Source range in a character-library prompt.
class CharacterPromptSourceRange {
  const CharacterPromptSourceRange(this.start, this.end);

  final int start;
  final int end;

  bool contains(int offset, {bool includeEnd = false}) =>
      offset >= start && (includeEnd ? offset <= end : offset < end);
}

enum CharacterPromptBlockIssue { unclosedBlock, repeatedBlock, emptyBlock }

/// A complete top-level `negative(...)` block.
class CharacterNegativeBlock {
  const CharacterNegativeBlock({
    required this.range,
    required this.keywordRange,
    required this.openingBoundaryRange,
    required this.contentRange,
    required this.closingBoundaryRange,
  });

  final CharacterPromptSourceRange range;
  final CharacterPromptSourceRange keywordRange;
  final CharacterPromptSourceRange openingBoundaryRange;
  final CharacterPromptSourceRange contentRange;
  final CharacterPromptSourceRange closingBoundaryRange;
}

class CharacterPromptBlockParseResult {
  const CharacterPromptBlockParseResult({
    required this.source,
    required this.positivePrompt,
    required this.negativePrompt,
    required this.blocks,
    required this.issues,
  });

  final String source;
  final String positivePrompt;
  final String negativePrompt;
  final List<CharacterNegativeBlock> blocks;
  final Set<CharacterPromptBlockIssue> issues;

  bool get hasNegativeBlock => blocks.isNotEmpty;
  bool get isValid => issues.isEmpty;

  String mergeNegativePrompt(String existingPrompt) {
    final seen = <String>{};
    return [negativePrompt, existingPrompt]
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && seen.add(part))
        .join(', ');
  }

  CharacterNegativeBlock? blockContaining(
    int offset, {
    bool contentOnly = false,
  }) {
    for (final block in blocks) {
      final range = contentOnly ? block.contentRange : block.range;
      if (range.contains(offset, includeEnd: contentOnly)) return block;
    }
    return null;
  }
}

/// The single parser for the character-library `negative(...)` extension.
///
/// A block is reserved only at a top-level tag boundary. Parentheses escaped
/// with a backslash and parentheses inside the block are preserved as content.
abstract final class CharacterPromptBlockParser {
  static const _keyword = 'negative';

  /// Serializes separate character prompts back to the character-library
  /// extension without creating a second syntax representation.
  static String compose({
    required String positivePrompt,
    required String negativePrompt,
  }) {
    final parsedPositive = parse(positivePrompt.trim());
    final positive = parsedPositive.positivePrompt;
    final negative = parsedPositive.mergeNegativePrompt(negativePrompt);

    if (negative.isEmpty) return positive;
    if (positive.isEmpty) return '$_keyword($negative)';
    return '$positive, $_keyword($negative)';
  }

  static CharacterPromptBlockParseResult parse(String source) {
    if (source.isEmpty) {
      return const CharacterPromptBlockParseResult(
        source: '',
        positivePrompt: '',
        negativePrompt: '',
        blocks: [],
        issues: {},
      );
    }

    final blocks = <CharacterNegativeBlock>[];
    final issues = <CharacterPromptBlockIssue>{};
    var braceDepth = 0;
    var bracketDepth = 0;
    var parenDepth = 0;
    var index = 0;

    while (index < source.length) {
      if (_isEscaped(source, index)) {
        index++;
        continue;
      }

      if (braceDepth == 0 &&
          bracketDepth == 0 &&
          parenDepth == 0 &&
          _startsReservedBlock(source, index)) {
        final close = _findClosingParen(source, index + _keyword.length);
        if (close == null) {
          issues.add(CharacterPromptBlockIssue.unclosedBlock);
          index += _keyword.length + 1;
          continue;
        }
        if (!_hasClosingBoundary(source, close + 1)) {
          index++;
          continue;
        }

        final contentStart = index + _keyword.length + 1;
        final block = CharacterNegativeBlock(
          range: CharacterPromptSourceRange(index, close + 1),
          keywordRange: CharacterPromptSourceRange(
            index,
            index + _keyword.length,
          ),
          openingBoundaryRange: CharacterPromptSourceRange(
            index + _keyword.length,
            index + _keyword.length + 1,
          ),
          contentRange: CharacterPromptSourceRange(contentStart, close),
          closingBoundaryRange: CharacterPromptSourceRange(close, close + 1),
        );
        blocks.add(block);
        if (source.substring(contentStart, close).trim().isEmpty) {
          issues.add(CharacterPromptBlockIssue.emptyBlock);
        }
        index = close + 1;
        continue;
      }

      switch (source[index]) {
        case '{':
          braceDepth++;
        case '}':
          if (braceDepth > 0) braceDepth--;
        case '[':
          bracketDepth++;
        case ']':
          if (bracketDepth > 0) bracketDepth--;
        case '(':
          parenDepth++;
        case ')':
          if (parenDepth > 0) parenDepth--;
      }
      index++;
    }

    if (blocks.length > 1) {
      issues.add(CharacterPromptBlockIssue.repeatedBlock);
    }

    final negativeParts = blocks
        .map(
          (block) => source
              .substring(block.contentRange.start, block.contentRange.end)
              .trim(),
        )
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    return CharacterPromptBlockParseResult(
      source: source,
      positivePrompt: _removeBlocks(source, blocks),
      negativePrompt: negativeParts.join(', '),
      blocks: List.unmodifiable(blocks),
      issues: Set.unmodifiable(issues),
    );
  }

  static bool _startsReservedBlock(String source, int index) {
    final openingParen = index + _keyword.length;
    if (openingParen >= source.length ||
        !source.startsWith('$_keyword(', index)) {
      return false;
    }

    var previous = index - 1;
    while (previous >= 0 && _isHorizontalWhitespace(source[previous])) {
      previous--;
    }
    return previous < 0 ||
        source[previous] == ',' ||
        source[previous] == '\n' ||
        source[previous] == '\r';
  }

  static bool _hasClosingBoundary(String source, int index) {
    while (index < source.length && _isHorizontalWhitespace(source[index])) {
      index++;
    }
    return index == source.length ||
        source[index] == ',' ||
        source[index] == '\n' ||
        source[index] == '\r';
  }

  static int? _findClosingParen(String source, int openingParen) {
    var depth = 1;
    for (var index = openingParen + 1; index < source.length; index++) {
      if (_isEscaped(source, index)) continue;
      if (source[index] == '(') {
        depth++;
      } else if (source[index] == ')') {
        depth--;
        if (depth == 0) return index;
      }
    }
    return null;
  }

  static String _removeBlocks(
    String source,
    List<CharacterNegativeBlock> blocks,
  ) {
    if (blocks.isEmpty) return source;

    var result = source;
    for (final block in blocks.reversed) {
      var start = block.range.start;
      var end = block.range.end;

      while (start > 0 && _isHorizontalWhitespace(result[start - 1])) {
        start--;
      }
      if (start > 0 && result[start - 1] == ',') {
        start--;
      } else {
        while (end < result.length && _isHorizontalWhitespace(result[end])) {
          end++;
        }
        if (end < result.length && result[end] == ',') {
          end++;
          while (end < result.length && _isHorizontalWhitespace(result[end])) {
            end++;
          }
        }
      }
      result = result.replaceRange(start, end, '');
    }
    return result.trim();
  }

  static bool _isEscaped(String source, int index) {
    var backslashes = 0;
    for (
      var cursor = index - 1;
      cursor >= 0 && source[cursor] == r'\';
      cursor--
    ) {
      backslashes++;
    }
    return backslashes.isOdd;
  }

  static bool _isHorizontalWhitespace(String value) =>
      value == ' ' || value == '\t' || value == '\f' || value == '\u00a0';
}
