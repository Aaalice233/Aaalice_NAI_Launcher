import '../models/prompt/diy_category_references.dart';

/// Runtime context shared across one `RandomPreset` generation.
///
/// The context is intentionally mutable and scoped to one generation call. It
/// lets category, dependency, visibility, branch, variable replacement, and
/// post-process rules observe tags selected earlier in the same generation.
class RandomPresetGenerationContext {
  RandomPresetGenerationContext({
    DateTime? generationTime,
    this.characterCount = 1,
    this.characterGender,
    Map<String, List<String>>? categoryTags,
    Map<String, String>? variables,
  })  : generationTime = generationTime ?? DateTime.now(),
        categoryTags = categoryTags ?? <String, List<String>>{},
        variables = variables ?? <String, String>{} {
    this.variables.putIfAbsent(
      characterCountReference,
      () => '$characterCount',
    );
    if (characterGender != null) {
      this.variables[characterGenderVariable] = characterGender!;
    }
  }

  final DateTime generationTime;
  final int characterCount;
  final String? characterGender;
  final Map<String, List<String>> categoryTags;
  final Map<String, String> variables;

  Map<String, List<String>> get tagContext => categoryTags;

  void addCategoryTags(
    String categoryKey,
    List<String> tags, {
    String? categoryId,
  }) {
    if (tags.isEmpty) return;
    _append(categoryKey, tags);
    if (categoryId != null && categoryId != categoryKey) {
      _append(categoryId, tags);
    }
    variables[categoryKey] = tags.join(', ');
    if (categoryId != null) {
      variables[categoryId] = tags.join(', ');
    }
  }

  void addVariable(String key, String value) {
    variables[key] = value;
  }

  void reconcileProcessedTags({
    required List<String> originalTags,
    required List<String> processedTags,
  }) {
    final removedTags = List<String>.from(originalTags);
    for (final tag in processedTags) {
      removedTags.remove(tag);
    }
    if (removedTags.isEmpty) return;

    final removedSet = removedTags.toSet();
    for (final entry in categoryTags.entries) {
      entry.value.removeWhere(removedSet.contains);
      variables[entry.key] = entry.value.join(', ');
    }
  }

  int countFor(String key) {
    if (key == characterCountReference) return characterCount;
    return categoryTags[key]?.length ?? 0;
  }

  List<String> valuesFor(String key) {
    if (key == characterCountReference) return ['$characterCount'];
    return categoryTags[key] ?? const [];
  }

  String firstValueFor(String key) {
    if (key == characterCountReference) return '$characterCount';
    final values = categoryTags[key];
    return variables[key] ??
        (values == null || values.isEmpty ? '' : values.first);
  }

  RandomPresetGenerationContext forCharacter(String gender) {
    return RandomPresetGenerationContext(
      generationTime: generationTime,
      characterCount: characterCount,
      characterGender: gender,
      categoryTags: {
        for (final entry in categoryTags.entries)
          entry.key: List<String>.from(entry.value),
      },
      variables: Map<String, String>.from(variables),
    );
  }

  void _append(String key, List<String> tags) {
    categoryTags.putIfAbsent(key, () => <String>[]).addAll(tags);
  }
}
