import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/import_models.dart';
import 'package:nai_launcher/data/models/tag_library/import_plan.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/data/services/tag_library_import_planner.dart';

const _suffix = ' (导入)';

void main() {
  late int counter;

  setUp(() => counter = 0);

  TagLibraryImportPlanner planner() =>
      TagLibraryImportPlanner(newId: () => 'new-${++counter}');

  TagLibraryImportPlan run({
    List<TagLibraryEntry> entries = const [],
    List<TagLibraryCategory> categories = const [],
    List<ImportConflict> conflicts = const [],
    Map<String, ConflictResolution> resolutions = const {},
    List<TagLibraryEntry> existingEntries = const [],
    List<TagLibraryCategory> existingCategories = const [],
    Set<String>? selectedEntryIds,
    Set<String>? selectedCategoryIds,
  }) => planner().plan(
    preview: _preview(entries: entries, categories: categories),
    selectedEntryIds: selectedEntryIds ?? entries.map((e) => e.id).toSet(),
    selectedCategoryIds:
        selectedCategoryIds ?? categories.map((c) => c.id).toSet(),
    conflicts: conflicts,
    conflictResolutions: resolutions,
    existingEntries: existingEntries,
    existingCategories: existingCategories,
    renameSuffix: _suffix,
  );

  group('逐条动作', () {
    test('同一批次内跳过、重命名、覆盖与新建互不影响', () {
      final plan = run(
        entries: [
          _entry(id: 'pkg-1', name: '猫'),
          _entry(id: 'pkg-2', name: '狗'),
          _entry(id: 'pkg-3', name: '鸟'),
          _entry(id: 'pkg-4', name: '鱼'),
        ],
        conflicts: [
          _entryConflict(importId: 'pkg-1', existingId: 'local-a'),
          _entryConflict(importId: 'pkg-2', existingId: 'local-b'),
          _entryConflict(importId: 'pkg-3', existingId: 'local-c'),
        ],
        resolutions: const {
          'pkg-1': ConflictResolution.skip,
          'pkg-2': ConflictResolution.rename,
          'pkg-3': ConflictResolution.overwrite,
        },
        existingEntries: [
          _entry(id: 'local-a', name: '猫'),
          _entry(id: 'local-b', name: '狗'),
          _entry(id: 'local-c', name: '鸟'),
        ],
      );

      final byId = {for (final item in plan.entries) item.source.id: item};
      expect(byId['pkg-1']!.action, TagLibraryImportAction.skip);
      expect(byId['pkg-1']!.isApplied, isFalse);
      expect(byId['pkg-1']!.targetId, 'local-a');

      expect(byId['pkg-2']!.action, TagLibraryImportAction.rename);
      expect(byId['pkg-2']!.targetId, 'new-1');
      expect(byId['pkg-2']!.targetName, '狗$_suffix');
      expect(byId['pkg-2']!.replacedEntryId, isNull);

      expect(byId['pkg-3']!.action, TagLibraryImportAction.overwrite);
      expect(byId['pkg-3']!.targetId, 'pkg-3');
      expect(byId['pkg-3']!.targetName, '鸟');
      expect(byId['pkg-3']!.replacedEntryId, 'local-c');

      expect(byId['pkg-4']!.action, TagLibraryImportAction.create);
      expect(byId['pkg-4']!.targetId, 'new-2');
      expect(byId['pkg-4']!.targetName, '鱼');

      expect(plan.skippedCount, 1);
      expect(plan.renamedCount, 1);
      expect(plan.overwrittenCount, 1);
      expect(plan.importedEntryCount, 3);
    });

    test('未选中的条目与分类不进入计划', () {
      final plan = run(
        entries: [
          _entry(id: 'pkg-1', name: '猫'),
          _entry(id: 'pkg-2', name: '狗'),
        ],
        categories: [_category(id: 'cat-1', name: '角色')],
        selectedEntryIds: {'pkg-2'},
        selectedCategoryIds: const {},
      );

      expect(plan.entries.map((e) => e.source.id), ['pkg-2']);
      expect(plan.categories, isEmpty);
      expect(plan.categoryIdMapping, isEmpty);
    });

    test('冲突指向的本地数据已被删除时按新建处理', () {
      final plan = run(
        entries: [_entry(id: 'pkg-1', name: '猫')],
        conflicts: [_entryConflict(importId: 'pkg-1', existingId: 'gone')],
        resolutions: const {'pkg-1': ConflictResolution.overwrite},
      );

      expect(plan.entries.single.action, TagLibraryImportAction.create);
      expect(plan.entries.single.targetId, 'new-1');
      expect(plan.entries.single.replacedEntryId, isNull);
    });
  });

  group('目标 ID', () {
    test('覆盖自己的导出包时沿用包内 ID', () {
      final plan = run(
        entries: [_entry(id: 'shared', name: '猫')],
        conflicts: [_entryConflict(importId: 'shared', existingId: 'shared')],
        resolutions: const {'shared': ConflictResolution.overwrite},
        existingEntries: [_entry(id: 'shared', name: '猫')],
      );

      expect(plan.entries.single.targetId, 'shared');
      expect(plan.entries.single.replacedEntryId, 'shared');
      expect(plan.entries.single.reassignedId, isFalse);
    });

    test('重命名即使包内 ID 与本地相同也改用新 ID', () {
      final plan = run(
        entries: [_entry(id: 'shared', name: '猫')],
        conflicts: [_entryConflict(importId: 'shared', existingId: 'shared')],
        resolutions: const {'shared': ConflictResolution.rename},
        existingEntries: [_entry(id: 'shared', name: '猫')],
      );

      expect(plan.entries.single.targetId, 'new-1');
      expect(plan.entries.single.targetName, '猫$_suffix');
      expect(plan.entries.single.replacedEntryId, isNull);
    });

    test('包内 ID 被本次保留的其他本地条目占用时改用新 ID', () {
      final plan = run(
        entries: [_entry(id: 'shared', name: '乙')],
        conflicts: [_entryConflict(importId: 'shared', existingId: 'local-y')],
        resolutions: const {'shared': ConflictResolution.overwrite},
        existingEntries: [
          _entry(id: 'shared', name: '甲'),
          _entry(id: 'local-y', name: '乙'),
        ],
      );

      expect(plan.entries.single.targetId, 'new-1');
      expect(plan.entries.single.reassignedId, isTrue);
      expect(plan.entries.single.replacedEntryId, 'local-y');
    });

    test('分类沿用同一套 ID 规则', () {
      final plan = run(
        categories: [
          _category(id: 'shared', name: '角色'),
          _category(id: 'pkg-cat', name: '场景'),
        ],
        conflicts: [
          _categoryConflict(importId: 'shared', existingId: 'shared'),
          _categoryConflict(importId: 'pkg-cat', existingId: 'local-cat'),
        ],
        resolutions: const {
          'shared': ConflictResolution.overwrite,
          'pkg-cat': ConflictResolution.rename,
        },
        existingCategories: [
          _category(id: 'shared', name: '角色'),
          _category(id: 'local-cat', name: '场景'),
        ],
      );

      expect(plan.categories.first.targetId, 'shared');
      expect(plan.categories.first.replacedCategoryId, 'shared');
      expect(plan.categories.last.targetId, 'new-1');
      expect(plan.categories.last.targetName, '场景$_suffix');
      expect(plan.overwrittenCount, 1);
      expect(plan.renamedCount, 1);
      expect(plan.importedCategoryCount, 1);
    });
  });

  group('引用映射', () {
    test('子分类先于父分类出现也能解析父级', () {
      final plan = run(
        categories: [
          _category(id: 'c-child', name: '子', parentId: 'c-parent'),
          _category(id: 'c-parent', name: '父'),
        ],
        entries: [_entry(id: 'e-1', name: '词', categoryId: 'c-child')],
      );

      expect(plan.categories.first.targetId, 'new-1');
      expect(plan.categories.first.targetParentId, 'new-2');
      expect(plan.categories.last.targetParentId, isNull);
      expect(plan.entries.single.targetCategoryId, 'new-1');
      expect(plan.categoryIdMapping, {'c-child': 'new-1', 'c-parent': 'new-2'});
    });

    test('跳过的分类映射到现有同名分类供条目引用', () {
      final plan = run(
        categories: [_category(id: 'pkg-cat', name: '角色')],
        entries: [_entry(id: 'e-1', name: '词', categoryId: 'pkg-cat')],
        conflicts: [
          _categoryConflict(importId: 'pkg-cat', existingId: 'local-cat'),
        ],
        resolutions: const {'pkg-cat': ConflictResolution.skip},
        existingCategories: [_category(id: 'local-cat', name: '角色')],
      );

      expect(plan.categories.single.isApplied, isFalse);
      expect(plan.categoryIdMapping, {'pkg-cat': 'local-cat'});
      expect(plan.entries.single.targetCategoryId, 'local-cat');
    });

    test('父分类未被选中时子分类落到根级', () {
      final plan = run(
        categories: [
          _category(id: 'c-parent', name: '父'),
          _category(id: 'c-child', name: '子', parentId: 'c-parent'),
        ],
        entries: [_entry(id: 'e-1', name: '词', categoryId: 'c-parent')],
        selectedCategoryIds: {'c-child'},
      );

      expect(plan.categories.single.source.id, 'c-child');
      expect(plan.categories.single.targetParentId, isNull);
      expect(plan.entries.single.targetCategoryId, isNull);
    });

    test('分类与条目的冲突记录互不串用', () {
      final plan = run(
        categories: [_category(id: 'same', name: '角色')],
        entries: [_entry(id: 'same', name: '角色')],
        conflicts: [_entryConflict(importId: 'same', existingId: 'local-e')],
        resolutions: const {'same': ConflictResolution.overwrite},
        existingEntries: [_entry(id: 'local-e', name: '角色')],
      );

      expect(plan.categories.single.action, TagLibraryImportAction.create);
      expect(plan.categories.single.replacedCategoryId, isNull);
      expect(plan.entries.single.action, TagLibraryImportAction.overwrite);
      expect(plan.entries.single.replacedEntryId, 'local-e');
    });
  });

  test('缩略图目标使用条目自己的目标 ID', () {
    final plan = run(
      entries: [
        _entry(id: 'pkg-1', name: '猫'),
        _entry(id: 'pkg-2', name: '狗'),
      ],
      conflicts: [_entryConflict(importId: 'pkg-2', existingId: 'local-b')],
      resolutions: const {'pkg-2': ConflictResolution.skip},
      existingEntries: [_entry(id: 'local-b', name: '狗')],
    );

    expect(plan.entries.first.thumbnailEntryId, 'new-1');
    expect(plan.entries.last.thumbnailEntryId, isNull);
  });
}

ImportPreview _preview({
  List<TagLibraryEntry> entries = const [],
  List<TagLibraryCategory> categories = const [],
}) => ImportPreview(
  version: '1.0',
  exportDate: DateTime.utc(2026),
  entries: entries,
  categories: categories,
);

TagLibraryEntry _entry({
  required String id,
  required String name,
  String? categoryId,
}) => TagLibraryEntry(
  id: id,
  name: name,
  content: '1girl',
  categoryId: categoryId,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

TagLibraryCategory _category({
  required String id,
  required String name,
  String? parentId,
}) => TagLibraryCategory(
  id: id,
  name: name,
  parentId: parentId,
  createdAt: DateTime.utc(2026),
);

ImportConflict _entryConflict({
  required String importId,
  required String existingId,
}) => ImportConflict(
  type: ConflictType.entry,
  importName: importId,
  importId: importId,
  existingId: existingId,
);

ImportConflict _categoryConflict({
  required String importId,
  required String existingId,
}) => ImportConflict(
  type: ConflictType.category,
  importName: importId,
  importId: importId,
  existingId: existingId,
);
