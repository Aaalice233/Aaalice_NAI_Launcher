import 'package:uuid/uuid.dart';

import '../models/tag_library/import_models.dart';
import '../models/tag_library/import_plan.dart';
import '../models/tag_library/tag_library_category.dart';
import '../models/tag_library/tag_library_entry.dart';

typedef _Draft<T> = ({
  T source,
  String sourceId,
  String sourceName,
  TagLibraryImportAction action,
  String? matchedId,
});

typedef _Target = ({String? id, bool reassigned});

/// 按每个分类与条目自身的冲突解决方案生成导入计划
class TagLibraryImportPlanner {
  const TagLibraryImportPlanner({this.newId = _uuidV4});

  final String Function() newId;

  static String _uuidV4() => const Uuid().v4();

  /// [conflicts] 为界面展示给用户的冲突，决定每项对应的现有数据
  TagLibraryImportPlan plan({
    required ImportPreview preview,
    required Set<String> selectedEntryIds,
    required Set<String> selectedCategoryIds,
    required List<ImportConflict> conflicts,
    required Map<String, ConflictResolution> conflictResolutions,
    required List<TagLibraryEntry> existingEntries,
    required List<TagLibraryCategory> existingCategories,
    required String renameSuffix,
  }) {
    final existingCategoryIds = existingCategories.map((c) => c.id).toSet();
    final existingEntryIds = existingEntries.map((e) => e.id).toSet();

    final categoryPlans = _planCategories(
      sources: preview.categories
          .where((c) => selectedCategoryIds.contains(c.id))
          .toList(),
      matchedIds: _matchedIds(
        conflicts.where((c) => c.isCategoryConflict),
        existingCategoryIds,
      ),
      conflictResolutions: conflictResolutions,
      existingIds: existingCategoryIds,
      renameSuffix: renameSuffix,
    );

    return TagLibraryImportPlan(
      preview: preview,
      categories: categoryPlans,
      entries: _planEntries(
        sources: preview.entries
            .where((e) => selectedEntryIds.contains(e.id))
            .toList(),
        matchedIds: _matchedIds(
          conflicts.where((c) => c.isEntryConflict),
          existingEntryIds,
        ),
        conflictResolutions: conflictResolutions,
        existingIds: existingEntryIds,
        categoryIdMapping: <String, String>{
          for (final item in categoryPlans)
            if (item.targetId != null) item.source.id: item.targetId!,
        },
        renameSuffix: renameSuffix,
      ),
    );
  }

  List<TagLibraryCategoryImportPlan> _planCategories({
    required List<TagLibraryCategory> sources,
    required Map<String, String> matchedIds,
    required Map<String, ConflictResolution> conflictResolutions,
    required Set<String> existingIds,
    required String renameSuffix,
  }) {
    final drafts = [
      for (final source in sources)
        _draft(
          source: source,
          sourceId: source.id,
          sourceName: source.name,
          matchedId: matchedIds[source.id],
          resolution: conflictResolutions[source.id],
        ),
    ];
    final targets = _assignTargets(drafts, existingIds);
    // 父级引用必须先于子级解析，包内顺序不保证父在子前
    final mapping = <String, String>{
      for (var i = 0; i < drafts.length; i++)
        if (targets[i].id != null) drafts[i].sourceId: targets[i].id!,
    };

    return [
      for (var i = 0; i < drafts.length; i++)
        TagLibraryCategoryImportPlan(
          source: drafts[i].source,
          action: drafts[i].action,
          targetId: targets[i].id,
          targetName: _targetName(drafts[i], renameSuffix),
          targetParentId: _mapped(mapping, drafts[i].source.parentId),
          replacedCategoryId: _replacedId(drafts[i]),
          reassignedId: targets[i].reassigned,
        ),
    ];
  }

  List<TagLibraryEntryImportPlan> _planEntries({
    required List<TagLibraryEntry> sources,
    required Map<String, String> matchedIds,
    required Map<String, ConflictResolution> conflictResolutions,
    required Set<String> existingIds,
    required Map<String, String> categoryIdMapping,
    required String renameSuffix,
  }) {
    final drafts = [
      for (final source in sources)
        _draft(
          source: source,
          sourceId: source.id,
          sourceName: source.name,
          matchedId: matchedIds[source.id],
          resolution: conflictResolutions[source.id],
        ),
    ];
    final targets = _assignTargets(drafts, existingIds);

    return [
      for (var i = 0; i < drafts.length; i++)
        TagLibraryEntryImportPlan(
          source: drafts[i].source,
          action: drafts[i].action,
          targetId: targets[i].id,
          targetName: _targetName(drafts[i], renameSuffix),
          targetCategoryId: _mapped(
            categoryIdMapping,
            drafts[i].source.categoryId,
          ),
          replacedEntryId: _replacedId(drafts[i]),
          reassignedId: targets[i].reassigned,
        ),
    ];
  }

  /// 先扣掉本次会被删除的本地 ID，再逐项占位，确保写入前目标身份互不冲突
  List<_Target> _assignTargets<T>(
    List<_Draft<T>> drafts,
    Set<String> existingIds,
  ) {
    final replacedIds = <String>{
      for (final draft in drafts)
        if (draft.action == TagLibraryImportAction.overwrite &&
            draft.matchedId != null)
          draft.matchedId!,
    };
    final taken = existingIds.difference(replacedIds);
    return [for (final draft in drafts) _assignTarget(draft, taken)];
  }

  _Target _assignTarget<T>(_Draft<T> draft, Set<String> taken) {
    if (draft.action == TagLibraryImportAction.skip) {
      return (id: draft.matchedId, reassigned: false);
    }
    final keepsSourceId = draft.action == TagLibraryImportAction.overwrite;
    if (keepsSourceId && taken.add(draft.sourceId)) {
      return (id: draft.sourceId, reassigned: false);
    }
    final generated = newId();
    taken.add(generated);
    return (id: generated, reassigned: keepsSourceId);
  }

  _Draft<T> _draft<T>({
    required T source,
    required String sourceId,
    required String sourceName,
    required String? matchedId,
    required ConflictResolution? resolution,
  }) => (
    source: source,
    sourceId: sourceId,
    sourceName: sourceName,
    action: switch (resolution) {
      ConflictResolution.skip => TagLibraryImportAction.skip,
      ConflictResolution.rename => TagLibraryImportAction.rename,
      ConflictResolution.overwrite when matchedId != null =>
        TagLibraryImportAction.overwrite,
      ConflictResolution.overwrite => TagLibraryImportAction.create,
      null => TagLibraryImportAction.create,
    },
    matchedId: matchedId,
  );

  /// 冲突记录来自选择文件时的快照，对应数据已被删除时视为无冲突
  Map<String, String> _matchedIds(
    Iterable<ImportConflict> conflicts,
    Set<String> existingIds,
  ) => <String, String>{
    for (final conflict in conflicts)
      if (existingIds.contains(conflict.existingId))
        conflict.importId: conflict.existingId,
  };

  String _targetName<T>(_Draft<T> draft, String suffix) =>
      draft.action == TagLibraryImportAction.rename
      ? '${draft.sourceName}$suffix'
      : draft.sourceName;

  String? _replacedId<T>(_Draft<T> draft) =>
      draft.action == TagLibraryImportAction.overwrite ? draft.matchedId : null;

  String? _mapped(Map<String, String> mapping, String? sourceId) =>
      sourceId == null ? null : mapping[sourceId];
}
