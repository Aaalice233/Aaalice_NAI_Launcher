/// NovelAI V4+ plain-text multi-character prompt codec.
///
/// NovelAI defines a single `|` as a prompt-chunk separator: the first chunk
/// is the base prompt and each following chunk is one character prompt.
/// Pipes inside a `||a|b||` random-choice block are options, not separators.
class NaiMultiCharacterPromptCodec {
  const NaiMultiCharacterPromptCodec._();

  static const int maxCharacterCount = 6;
  static const int _pipe = 0x7c;

  static NaiMultiCharacterPrompt? tryDecode(String source) {
    var text = source.trim();
    if (text.startsWith('```') && text.endsWith('```')) {
      final closingFence = text.length - 3;
      final openingLineBreak = text.indexOf('\n');
      text = openingLineBreak >= 0 && openingLineBreak < closingFence
          ? text.substring(openingLineBreak + 1, closingFence).trim()
          : text.substring(3, closingFence).trim();
    }

    final chunks = _splitSinglePipes(text);
    if (chunks.length < 2 || chunks.length > maxCharacterCount + 1) {
      return null;
    }
    final normalized = chunks.map((chunk) => chunk.trim()).toList();
    if (normalized.skip(1).any((chunk) => chunk.isEmpty)) return null;
    return NaiMultiCharacterPrompt(
      basePrompt: normalized.first,
      characterPrompts: normalized.skip(1).toList(growable: false),
    );
  }

  static String encode({
    required String basePrompt,
    required Iterable<String> characterPrompts,
  }) => _encode(
    basePrompt: basePrompt,
    characterPrompts: characterPrompts,
    separator: '\n\n| ',
    maxCharacters: maxCharacterCount,
  );

  /// Keeps the same importable pipe contract on one line for clipboard export.
  static String encodeInline({
    required String basePrompt,
    required Iterable<String> characterPrompts,
  }) => _encode(
    basePrompt: basePrompt,
    characterPrompts: characterPrompts,
    separator: ' | ',
  );

  static String _encode({
    required String basePrompt,
    required Iterable<String> characterPrompts,
    required String separator,
    int? maxCharacters,
  }) {
    final base = basePrompt.trim();
    final availableCharacters = characterPrompts
        .map((prompt) => prompt.trim())
        .where((prompt) => prompt.isNotEmpty);
    final characters =
        (maxCharacters == null
                ? availableCharacters
                : availableCharacters.take(maxCharacters))
            .toList(growable: false);
    if (characters.isEmpty) return base;
    if (base.isEmpty) return '| ${characters.join(separator)}';
    return '$base$separator${characters.join(separator)}';
  }

  // Mirrors the web client: `||` fences pair up left to right like
  // `split('||')`, so an unclosed fence protects the rest of the text.
  static List<String> _splitSinglePipes(String text) {
    final chunks = <String>[];
    var start = 0;
    var index = 0;
    var inRandomBlock = false;
    while (index < text.length) {
      if (text.codeUnitAt(index) != _pipe) {
        index++;
        continue;
      }
      if (index + 1 < text.length && text.codeUnitAt(index + 1) == _pipe) {
        inRandomBlock = !inRandomBlock;
        index += 2;
        continue;
      }
      if (!inRandomBlock) {
        chunks.add(text.substring(start, index));
        start = index + 1;
      }
      index++;
    }
    chunks.add(text.substring(start));
    return chunks;
  }
}

class NaiMultiCharacterPrompt {
  const NaiMultiCharacterPrompt({
    required this.basePrompt,
    required this.characterPrompts,
  });

  final String basePrompt;
  final List<String> characterPrompts;
}
