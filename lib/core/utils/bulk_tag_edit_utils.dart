String canonicalBulkTagKey(String tag) => tag.trim().toLowerCase();

List<String> parseBulkTagInput(Iterable<String> input) {
  final tagsByKey = <String, String>{};
  for (final item in input) {
    for (final part in item.split(RegExp(r'[,，\r\n]+'))) {
      final tag = part.trim();
      if (tag.isEmpty) continue;
      tagsByKey.putIfAbsent(canonicalBulkTagKey(tag), () => tag);
    }
  }
  return tagsByKey.values.toList(growable: false);
}

List<String> applyBulkTagChanges(
  Iterable<String> currentTags, {
  required Iterable<String> tagsToAdd,
  required Iterable<String> tagsToRemove,
}) {
  final removedKeys = tagsToRemove.map(canonicalBulkTagKey).toSet();
  final resultByKey = <String, String>{};

  for (final tag in currentTags) {
    final normalized = tag.trim();
    final key = canonicalBulkTagKey(normalized);
    if (normalized.isNotEmpty && !removedKeys.contains(key)) {
      resultByKey.putIfAbsent(key, () => normalized);
    }
  }
  for (final tag in tagsToAdd) {
    final normalized = tag.trim();
    final key = canonicalBulkTagKey(normalized);
    if (normalized.isNotEmpty && !removedKeys.contains(key)) {
      resultByKey.putIfAbsent(key, () => normalized);
    }
  }

  return resultByKey.values.toList(growable: false);
}
