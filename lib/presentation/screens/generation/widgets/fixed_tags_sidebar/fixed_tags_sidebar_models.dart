import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../../../data/models/tag_library/tag_library_category.dart';
import 'fixed_tags_sidebar_layout.dart';

enum FixedTagAddAction { positive, negative, libraryPositive, libraryNegative }

class FixedTagLinkDragPayload {
  const FixedTagLinkDragPayload(this.positiveEntryId);

  final String positiveEntryId;
}

class FixedTagLinkDragPreview {
  const FixedTagLinkDragPreview({
    required this.start,
    required this.end,
    required this.isDetaching,
  });

  final Offset start;
  final Offset end;
  final bool isDetaching;
}

class FixedTagSection {
  const FixedTagSection({
    required this.id,
    required this.name,
    required this.entries,
    required this.color,
  });

  final String id;
  final String name;
  final List<FixedTagEntry> entries;
  final Color color;
}

Color fixedTagCategoryColor(BuildContext context, String? categoryId) {
  if (categoryId == null) return Theme.of(context).colorScheme.outline;
  final hash = categoryId.codeUnits.fold<int>(
    0,
    (previous, codeUnit) => (previous * 31 + codeUnit) & 0x7fffffff,
  );
  return HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.58, 0.55).toColor();
}

List<FixedTagSection> buildFixedTagSections(
  BuildContext context,
  List<FixedTagEntry> sourceEntries,
  List<TagLibraryCategory> categories,
) {
  final categoriesById = {
    for (final category in categories) category.id: category,
  };
  final grouped = <String?, List<FixedTagEntry>>{};
  for (final entry in sourceEntries) {
    grouped.putIfAbsent(entry.categoryId, () => []).add(entry);
  }
  final sections = <FixedTagSection>[];
  for (final category in categories.sortedByOrder()) {
    final entries = grouped[category.id] ?? const <FixedTagEntry>[];
    if (entries.isEmpty) continue;
    sections.add(
      FixedTagSection(
        id: category.id,
        name: category.displayName,
        entries: entries,
        color: fixedTagCategoryColor(context, category.id),
      ),
    );
  }

  final unknownCategoryIds = grouped.keys.where(
    (id) => id != null && !categoriesById.containsKey(id),
  );
  for (final categoryId in unknownCategoryIds) {
    final entries = grouped[categoryId] ?? const <FixedTagEntry>[];
    if (entries.isEmpty) continue;
    sections.add(
      FixedTagSection(
        id: categoryId!,
        name: context.l10n.fixedTags_unknownCategory,
        entries: entries,
        color: fixedTagCategoryColor(context, categoryId),
      ),
    );
  }

  final uncategorized = grouped[null] ?? const <FixedTagEntry>[];
  if (uncategorized.isNotEmpty) {
    sections.add(
      FixedTagSection(
        id: uncategorizedSectionId,
        name: context.l10n.fixedTags_uncategorized,
        entries: uncategorized,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
  return sections;
}
