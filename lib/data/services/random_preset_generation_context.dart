import '../models/prompt/diy_category_references.dart';

/// 一次预设生成内共享的可变上下文，让后续规则能看到本轮先选出的标签与变量
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

  /// 源的结果数：类别为已选标签数，角色数量为人数，其他变量有取值时为 1
  int countFor(String key) {
    if (key == characterCountReference) return characterCount;
    return valuesFor(key).length;
  }

  /// 源的结果：类别为已选标签，角色数量为人数，其他变量为本轮的取值
  List<String> valuesFor(String key) {
    if (key == characterCountReference) return ['$characterCount'];
    final tags = categoryTags[key];
    if (tags != null) return tags;
    final value = variables[key];
    return value == null || value.isEmpty ? const [] : [value];
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
