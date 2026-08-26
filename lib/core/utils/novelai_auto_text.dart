import '../constants/api_constants.dart';

/// Character prompt data used by NovelAI's automatic text-rendering pass.
class NovelAiAutoTextCharacter {
  const NovelAiAutoTextCharacter({
    required this.prompt,
    this.centerX = 0.5,
    this.centerY = 0.5,
    this.enabled = true,
  });

  final String prompt;
  final double centerX;
  final double centerY;
  final bool enabled;
}

/// Mirrors the NovelAI web client's V5 quote-to-`teXt:` transformation.
abstract final class NovelAiAutoText {
  static const String marker = 'teXt:';

  static final RegExp _generatedMarker = RegExp(
    r'(?:^|\s|[,.:\[\]{}、。])teXt:(?!:)',
  );
  static final RegExp _singleQuoteBoundary = RegExp(r'[\s,.]');
  static final RegExp _letterOrNumber = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static final RegExp _cjkCharacter = RegExp(
    r'[\u3000-\u303F\u3040-\u309F\u30A0-\u30FF'
    r'\uFF00-\uFF9F\u4E00-\u9FAF\u3400-\u4DBF]',
    unicode: true,
  );

  static const Map<String, String> _quotePairs = {
    '"': '"',
    '“': '”',
    '「': '」',
    "'": "'",
    '‘': '’',
  };

  /// Adds the generated text block to the first prompt-mix chunk.
  static String apply(
    String prompt, {
    List<NovelAiAutoTextCharacter> characters = const [],
    bool useCoords = false,
  }) {
    final block = buildBlock(
      prompt,
      characters: characters,
      useCoords: useCoords,
    );
    if (block == null) return prompt;

    final chunks = QualityTags.splitPromptMixChunks(prompt);
    final base = chunks.first.replaceFirst(RegExp(r'[\s,]+$'), '');
    chunks[0] = base.isEmpty ? block : '$base, $block';
    return chunks.join(QualityTags.promptMixSeparator);
  }

  /// Returns the exact block the web client would synthesize, if any.
  static String? buildBlock(
    String prompt, {
    List<NovelAiAutoTextCharacter> characters = const [],
    bool useCoords = false,
  }) {
    final enabledCharacters = characters
        .where((character) => character.enabled && character.prompt.isNotEmpty)
        .toList(growable: false);
    if (QualityTags.textRenderMarker.hasMatch(prompt) ||
        enabledCharacters.any(
          (character) =>
              QualityTags.textRenderMarker.hasMatch(character.prompt),
        )) {
      return null;
    }

    final chunks = QualityTags.splitPromptMixChunks(prompt);
    final quotedTexts = _collectQuotedTexts(
      chunks.first,
      enabledCharacters,
      useCoords: useCoords,
    );
    if (quotedTexts.isEmpty) return null;
    return '$marker ${quotedTexts.join('\n\n')}';
  }

  /// Removes a matching generated block when restoring a user-facing prompt.
  ///
  /// A manual `Text:` section or a `teXt:` block whose payload differs from the
  /// quoted strings is preserved verbatim.
  static String stripGeneratedBlock(
    String prompt, {
    List<NovelAiAutoTextCharacter> characters = const [],
    bool useCoords = false,
  }) {
    final chunks = QualityTags.splitPromptMixChunks(prompt);
    final stripped = chunks.map((chunk) {
      final match = _generatedMarker.firstMatch(chunk);
      if (match == null) return chunk;

      final prefix = chunk.substring(0, match.start);
      final expected = _collectQuotedTexts(
        prefix,
        characters,
        useCoords: useCoords,
      ).join('\n\n');
      final actual = chunk.substring(match.end).trim();
      if (actual != expected) return chunk;
      return prefix.replaceFirst(RegExp(r'[\s,]+$'), '');
    });
    return stripped.join(QualityTags.promptMixSeparator);
  }

  static List<String> _collectQuotedTexts(
    String basePrompt,
    List<NovelAiAutoTextCharacter> characters, {
    required bool useCoords,
  }) {
    final orderedCharacters = useCoords
        ? _sortCharactersByReadingOrder(characters)
        : characters;
    final groups = <List<String>>[
      _extractQuotedTexts(basePrompt),
      for (final character in orderedCharacters)
        _extractQuotedTexts(character.prompt),
    ];

    final combined = groups.expand((group) => group).join();
    final cjkCount = _cjkCharacter.allMatches(combined).length;
    if (cjkCount > 0 && cjkCount / combined.length > 0.3) {
      for (final group in groups) {
        group.setAll(0, group.reversed.toList(growable: false));
      }
    }
    return groups.expand((group) => group).toList(growable: false);
  }

  static List<String> _extractQuotedTexts(String prompt) {
    final result = <String>[];
    var cursor = 0;
    while (cursor < prompt.length) {
      final opening = prompt[cursor];
      final closing = _quotePairs[opening];
      final acceptsOpening =
          closing != null &&
          (opening != "'" || _isSingleQuoteBoundary(prompt, cursor - 1));
      if (!acceptsOpening) {
        cursor++;
        continue;
      }

      final apostropheStyle = closing == "'" || closing == '’';
      var end = cursor + 1;
      while (end < prompt.length &&
          (prompt[end] != closing ||
              (apostropheStyle && _isLetterOrNumber(prompt, end + 1)))) {
        end++;
      }
      if (end >= prompt.length) {
        cursor++;
        continue;
      }

      final value = prompt.substring(cursor + 1, end).trim();
      if (value.isNotEmpty) result.add(value);
      cursor = end + 1;
    }
    return result;
  }

  static bool _isSingleQuoteBoundary(String text, int index) {
    if (index < 0 || index >= text.length) return true;
    return _singleQuoteBoundary.hasMatch(text[index]);
  }

  static bool _isLetterOrNumber(String text, int index) {
    if (index < 0 || index >= text.length) return false;
    return _letterOrNumber.hasMatch(text[index]);
  }

  static List<NovelAiAutoTextCharacter> _sortCharactersByReadingOrder(
    List<NovelAiAutoTextCharacter> characters,
  ) {
    final byY = _stableSort(
      characters,
      (left, right) => left.centerY.compareTo(right.centerY),
    );
    return _splitRows(byY)
        .expand(
          (row) => _stableSort(
            row,
            (left, right) => left.centerX.compareTo(right.centerX),
          ),
        )
        .toList(growable: false);
  }

  static List<List<NovelAiAutoTextCharacter>> _splitRows(
    List<NovelAiAutoTextCharacter> characters,
  ) {
    if (characters.length <= 1) return [characters];

    final totalSpan = characters.last.centerY - characters.first.centerY;
    var splitIndex = 1;
    var largestGap = -1.0;
    for (var index = 1; index < characters.length; index++) {
      final gap = characters[index].centerY - characters[index - 1].centerY;
      if (gap > largestGap) {
        largestGap = gap;
        splitIndex = index;
      }
    }
    if (totalSpan <= 0.15 && largestGap <= 0.1) return [characters];

    return [
      ..._splitRows(characters.sublist(0, splitIndex)),
      ..._splitRows(characters.sublist(splitIndex)),
    ];
  }

  static List<T> _stableSort<T>(
    List<T> values,
    int Function(T left, T right) compare,
  ) {
    final indexed = <({int index, T value})>[
      for (var index = 0; index < values.length; index++)
        (index: index, value: values[index]),
    ];
    indexed.sort((left, right) {
      final result = compare(left.value, right.value);
      return result != 0 ? result : left.index.compareTo(right.index);
    });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }
}
