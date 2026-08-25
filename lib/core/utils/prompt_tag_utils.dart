abstract final class PromptTagUtils {
  /// Splits NovelAI prompts only at top-level separators. Commas inside
  /// emphasis wrappers and numeric weights remain part of the same tag.
  static List<String> splitTopLevel(String prompt) {
    if (prompt.trim().isEmpty) return const [];
    final tags = <String>[];
    final wrappers = <String>[];
    var tokenStart = 0;
    var numericWeightOpen = false;
    var escaped = false;

    void addTag(int end) {
      final tag = prompt.substring(tokenStart, end).trim();
      if (tag.isNotEmpty) tags.add(tag);
    }

    for (var index = 0; index < prompt.length; index++) {
      final character = prompt[index];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (character == r'\') {
        escaped = true;
        continue;
      }
      if (index + 1 < prompt.length &&
          character == ':' &&
          prompt[index + 1] == ':') {
        if (numericWeightOpen) {
          numericWeightOpen = false;
        } else {
          final prefix = prompt.substring(tokenStart, index).trimLeft();
          if (RegExp(
            r'^[\(\[\{]*\s*[+-]?(?:\d+(?:\.\d+)?|\.\d+)\s*$',
          ).hasMatch(prefix)) {
            numericWeightOpen = true;
          }
        }
        index++;
        continue;
      }

      final closing = switch (character) {
        '(' => ')',
        '[' => ']',
        '{' => '}',
        _ => null,
      };
      if (closing != null) {
        wrappers.add(closing);
        continue;
      }
      if (wrappers.isNotEmpty && character == wrappers.last) {
        wrappers.removeLast();
        continue;
      }
      if ((character == ',' || character == '，' || character == '\n') &&
          wrappers.isEmpty &&
          !numericWeightOpen) {
        addTag(index);
        tokenStart = index + 1;
      }
    }
    addTag(prompt.length);
    return List.unmodifiable(tags);
  }

  /// Produces individually actionable tags for display. Numeric weight groups
  /// keep their exact syntax in the prompt itself, but their inner tags are
  /// flattened here so one weighted group does not become a single giant chip.
  static List<String> splitForDisplay(String prompt) {
    final tags = <String>[];
    final numericWeight = RegExp(
      r'^[+-]?(?:\d+(?:\.\d+)?|\.\d+)\s*::([\s\S]*)::$',
    );
    for (final token in splitTopLevel(prompt)) {
      final match = numericWeight.firstMatch(token);
      if (match == null) {
        tags.add(token);
        continue;
      }
      final innerTags = splitTopLevel(match.group(1) ?? '');
      tags.addAll(innerTags.isEmpty ? [token] : innerTags);
    }
    return List.unmodifiable(tags);
  }

  /// Removes empty and repeated display tags while preserving the first
  /// occurrence and its original spelling.
  static List<String> uniqueForDisplay(Iterable<String> tags) {
    final seen = <String>{};
    return List.unmodifiable([
      for (final tag in tags)
        if (tag.trim().isNotEmpty && seen.add(tag.trim().toLowerCase()))
          tag.trim(),
    ]);
  }

  static List<String> parseForDisplay(String prompt) =>
      uniqueForDisplay(splitForDisplay(prompt));
}
