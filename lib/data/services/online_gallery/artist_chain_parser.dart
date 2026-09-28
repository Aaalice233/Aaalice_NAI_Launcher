import '../../models/online_gallery/artist_chain.dart';

export '../../models/online_gallery/artist_chain.dart';

/// Extracts explicit `artist:` tags without inspecting any other metadata.
///
/// The parser intentionally accepts only tags at prompt-item boundaries. This
/// keeps prose such as "by famous artist" and "artist collaboration" out of
/// the result while preserving NovelAI brace, bracket and numeric weights.
class ArtistChainParser {
  const ArtistChainParser._();

  static final RegExp _numericWeight = RegExp(
    r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)\s*$',
  );
  static final RegExp _artistPrefix = RegExp(
    r'^artist\s*:\s*',
    caseSensitive: false,
  );
  static final RegExp _existingArtistConstraint = RegExp(
    r'(^|[\s,\n\r\{\[(:])artist\s*:',
    caseSensitive: false,
  );
  static final RegExp _lineBreaks = RegExp(r'\r\n?|\n');
  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _structuralSpacing = RegExp(r'\s*(::|[,{}\[\]])\s*');
  static final RegExp _artistPrefixSpacing = RegExp(
    r'artist\s*:\s*',
    caseSensitive: false,
  );
  static final RegExp _repeatedCommas = RegExp(r',+');
  static final RegExp _edgeCommas = RegExp(r'^,+|,+$');

  static ArtistChainExtraction parse(String? positivePrompt) {
    final prompt = positivePrompt ?? '';
    if (prompt.trim().isEmpty) return ArtistChainExtraction.empty;

    final parsed = _parseRange(prompt, 0, prompt.length);
    if (parsed.nodes.isEmpty) return ArtistChainExtraction.empty;

    final rawFragments = <String>[];
    final artistNames = <String>[];
    final seenNames = <String>{};
    for (final node in parsed.nodes) {
      rawFragments.addAll(node.rawFragments);
      for (final name in node.artistNames) {
        if (seenNames.add(name.toLowerCase())) artistNames.add(name);
      }
    }

    return ArtistChainExtraction(
      formattedText: parsed.nodes.map((node) => node.text).join(', '),
      rawFragments: List.unmodifiable(rawFragments),
      artistNames: List.unmodifiable(artistNames),
    );
  }

  /// Builds a conservative identity for suppressing repeated generations.
  ///
  /// Only casing and insignificant whitespace around Prompt syntax are
  /// normalized. Different positive Prompt content or different artist-chain
  /// weighting therefore remains independently visible.
  static String deduplicationKey(
    String positivePrompt,
    ArtistChainExtraction extraction,
  ) {
    final prompt = _normalizeIdentityText(positivePrompt);
    final chain = _normalizeIdentityText(extraction.formattedText);
    return '$prompt\u0000$chain';
  }

  static String _normalizeIdentityText(String value) {
    final collapsed = value
        .trim()
        .toLowerCase()
        .replaceAll(_lineBreaks, ',')
        .replaceAll(_whitespace, ' ');
    final normalizedArtists = collapsed.replaceAll(
      _artistPrefixSpacing,
      'artist:',
    );
    return normalizedArtists
        .replaceAllMapped(_structuralSpacing, (match) => match.group(1)!)
        .replaceAll(_repeatedCommas, ',')
        .replaceAll(_edgeCommas, '');
  }

  /// Adds the broad server-side candidate constraint without changing the
  /// caller's search field value. Exact matching still requires [parse].
  static String withArtistConstraint(String? promptQuery) {
    final query = (promptQuery ?? '').trim();
    if (_existingArtistConstraint.hasMatch(query)) return query;
    return query.isEmpty ? 'artist:' : '$query artist:';
  }

  static _ParsedSequence _parseRange(String source, int start, int end) {
    final nodes = <_ExtractedNode>[];
    final seenNodeText = <String>{};
    var cursor = start;

    void addNode(_ExtractedNode? node) {
      if (node == null || node.text.isEmpty || !seenNodeText.add(node.text)) {
        return;
      }
      nodes.add(node);
    }

    while (cursor < end) {
      cursor = _skipSeparatorsAndWhitespace(source, cursor, end);
      if (cursor >= end) break;

      final character = source[cursor];
      if (character == '}' || character == ']') {
        // Stray closing delimiters are malformed prompt syntax. They must be
        // consumed explicitly so the parser always makes forward progress.
        cursor++;
        continue;
      }
      if (character == '{' || character == '[') {
        final closingCharacter = character == '{' ? '}' : ']';
        final close = _findBalancedClose(
          source,
          cursor,
          end,
          character,
          closingCharacter,
        );
        if (close != null) {
          final inner = _parseRange(source, cursor + 1, close);
          if (inner.nodes.isNotEmpty) {
            addNode(
              _ExtractedNode.wrapper(character, closingCharacter, inner.nodes),
            );
          }
          cursor = close + 1;
          continue;
        }

        // An unmatched emphasis delimiter must not claim the rest of the
        // prompt. Degrade only the next safely delimited item.
        final safeEnd = _findItemEnd(source, cursor + 1, end);
        final degraded = _parseRange(source, cursor + 1, safeEnd);
        for (final node in degraded.nodes) {
          addNode(node);
        }
        cursor = safeEnd;
        continue;
      }

      final numericOpen = _readNumericWeightOpen(source, cursor, end);
      if (numericOpen != null) {
        final close = _findNumericWeightClose(
          source,
          numericOpen.contentStart,
          end,
        );
        if (close != null) {
          final inner = _parseRange(source, numericOpen.contentStart, close);
          if (inner.nodes.isNotEmpty) {
            addNode(
              _ExtractedNode.numericWeight(numericOpen.weight, inner.nodes),
            );
          }
          cursor = close + 2;
          continue;
        }

        // Preserve a safely parsed artist tag but drop the malformed weight.
        final safeEnd = _findItemEnd(source, numericOpen.contentStart, end);
        final degraded = _parseRange(source, numericOpen.contentStart, safeEnd);
        for (final node in degraded.nodes) {
          addNode(node);
        }
        cursor = safeEnd;
        continue;
      }

      final itemEnd = _findItemEnd(source, cursor, end);
      addNode(_parseArtistItem(source, cursor, itemEnd));
      cursor = itemEnd > cursor ? itemEnd : cursor + 1;
    }

    return _ParsedSequence(List.unmodifiable(nodes));
  }

  static _ExtractedNode? _parseArtistItem(String source, int start, int end) {
    var raw = source.substring(start, end).trim();
    while (raw.endsWith('::')) {
      raw = raw.substring(0, raw.length - 2).trimRight();
    }
    final prefix = _artistPrefix.firstMatch(raw);
    if (prefix == null) return null;

    final name = raw.substring(prefix.end).trim();
    if (name.isEmpty || name == ':' || name.contains('\n')) return null;

    return _ExtractedNode(
      text: 'artist:$name',
      rawFragments: <String>[raw],
      artistNames: <String>[name],
    );
  }

  static int _skipSeparatorsAndWhitespace(String source, int cursor, int end) {
    while (cursor < end) {
      final code = source.codeUnitAt(cursor);
      if (code == 44 || code == 10 || code == 13 || code == 32 || code == 9) {
        cursor++;
        continue;
      }
      break;
    }
    return cursor;
  }

  static int _findItemEnd(String source, int start, int end) {
    var cursor = start;
    while (cursor < end) {
      final character = source[cursor];
      if ((character == ',' || character == '\n' || character == '\r') &&
          !_isEscaped(source, cursor)) {
        return cursor;
      }
      if (character == '}' || character == ']') return cursor;
      cursor++;
    }
    return end;
  }

  static int? _findBalancedClose(
    String source,
    int openIndex,
    int end,
    String open,
    String close,
  ) {
    var depth = 1;
    for (var cursor = openIndex + 1; cursor < end; cursor++) {
      if (_isEscaped(source, cursor)) continue;
      if (source[cursor] == open) {
        depth++;
      } else if (source[cursor] == close && --depth == 0) {
        return cursor;
      }
    }
    return null;
  }

  static _NumericWeightOpen? _readNumericWeightOpen(
    String source,
    int start,
    int end,
  ) {
    final delimiter = source.indexOf('::', start);
    if (delimiter < 0 || delimiter >= end) return null;

    final candidate = source.substring(start, delimiter).trim();
    if (!_numericWeight.hasMatch(candidate)) return null;
    return _NumericWeightOpen(candidate, delimiter + 2);
  }

  static int? _findNumericWeightClose(
    String source,
    int contentStart,
    int end,
  ) {
    var depth = 1;
    var cursor = contentStart;
    while (cursor + 1 < end) {
      final delimiter = source.indexOf('::', cursor);
      if (delimiter < 0 || delimiter >= end) return null;

      final tokenStart = _findPreviousBoundary(source, delimiter, contentStart);
      final preceding = source.substring(tokenStart, delimiter).trim();
      if (_numericWeight.hasMatch(preceding)) {
        depth++;
      } else if (--depth == 0) {
        return delimiter;
      }
      cursor = delimiter + 2;
    }
    return null;
  }

  static int _findPreviousBoundary(String source, int before, int lowerBound) {
    var cursor = before - 1;
    while (cursor >= lowerBound) {
      final character = source[cursor];
      if (character == ',' ||
          character == '\n' ||
          character == '\r' ||
          character == '{' ||
          character == '[') {
        return cursor + 1;
      }
      cursor--;
    }
    return lowerBound;
  }

  static bool _isEscaped(String source, int index) {
    var slashes = 0;
    for (
      var cursor = index - 1;
      cursor >= 0 && source[cursor] == r'\';
      cursor--
    ) {
      slashes++;
    }
    return slashes.isOdd;
  }
}

class _ParsedSequence {
  const _ParsedSequence(this.nodes);

  final List<_ExtractedNode> nodes;
}

class _ExtractedNode {
  const _ExtractedNode({
    required this.text,
    required this.rawFragments,
    required this.artistNames,
  });

  factory _ExtractedNode.wrapper(
    String open,
    String close,
    List<_ExtractedNode> children,
  ) {
    return _ExtractedNode(
      text: '$open${children.map((child) => child.text).join(', ')}$close',
      rawFragments: List.unmodifiable(
        children.expand((child) => child.rawFragments),
      ),
      artistNames: List.unmodifiable(
        children.expand((child) => child.artistNames),
      ),
    );
  }

  factory _ExtractedNode.numericWeight(
    String weight,
    List<_ExtractedNode> children,
  ) {
    return _ExtractedNode(
      text: '$weight::${children.map((child) => child.text).join(', ')}::',
      rawFragments: List.unmodifiable(
        children.expand((child) => child.rawFragments),
      ),
      artistNames: List.unmodifiable(
        children.expand((child) => child.artistNames),
      ),
    );
  }

  final String text;
  final List<String> rawFragments;
  final List<String> artistNames;
}

class _NumericWeightOpen {
  const _NumericWeightOpen(this.weight, this.contentStart);

  final String weight;
  final int contentStart;
}
