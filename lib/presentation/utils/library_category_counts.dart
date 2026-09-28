/// Count direct memberships once, then propagate them to their ancestors.
Map<String, int> libraryCategoryCounts(
  Map<String, String?> parentById,
  Iterable<String?> entryCategoryIds,
) {
  final direct = <String, int>{};
  for (final id in entryCategoryIds) {
    if (id != null && parentById.containsKey(id)) {
      direct.update(id, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  final counts = {for (final id in parentById.keys) id: 0};
  for (final entry in direct.entries) {
    final visited = <String>{};
    String? id = entry.key;
    while (id != null && parentById.containsKey(id)) {
      if (!visited.add(id)) {
        throw StateError('Category hierarchy contains a cycle');
      }
      counts[id] = counts[id]! + entry.value;
      id = parentById[id];
    }
  }
  return counts;
}
