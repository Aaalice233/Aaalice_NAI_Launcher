/// NovelAI V4+ plain-text multi-character prompt codec.
///
/// NovelAI defines a single `|` as a prompt-chunk separator: the first chunk
/// is the base prompt and each following chunk is one character prompt.
class NaiMultiCharacterPromptCodec {
  const NaiMultiCharacterPromptCodec._();

  static const int maxCharacterCount = 6;

  static NaiMultiCharacterPrompt? tryDecode(String source) {
    var text = source.trim();
    if (text.startsWith('```') && text.endsWith('```')) {
      text = text.substring(3, text.length - 3).trim();
      final firstLineBreak = text.indexOf('\n');
      if (firstLineBreak >= 0) {
        final fenceLanguage = text.substring(0, firstLineBreak).trim();
        if (RegExp(r'^[a-zA-Z0-9_-]{1,20}$').hasMatch(fenceLanguage)) {
          text = text.substring(firstLineBreak + 1).trim();
        }
      }
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
  }) {
    final base = basePrompt.trim();
    final characters = characterPrompts
        .map((prompt) => prompt.trim())
        .where((prompt) => prompt.isNotEmpty)
        .take(maxCharacterCount)
        .toList(growable: false);
    if (characters.isEmpty) return base;
    final buffer = StringBuffer(base);
    for (final character in characters) {
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write('| $character');
    }
    return buffer.toString();
  }

  static List<String> _splitSinglePipes(String text) {
    final chunks = <String>[];
    var start = 0;
    var index = 0;
    while (index < text.length) {
      if (text.codeUnitAt(index) != 0x7c) {
        index++;
        continue;
      }
      var end = index + 1;
      while (end < text.length && text.codeUnitAt(end) == 0x7c) {
        end++;
      }
      if (end - index == 1) {
        chunks.add(text.substring(start, index));
        start = end;
      }
      index = end;
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
