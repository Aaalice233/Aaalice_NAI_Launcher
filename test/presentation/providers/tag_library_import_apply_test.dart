import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/tag_library/import_models.dart';
import 'package:nai_launcher/data/models/tag_library/import_plan.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/data/services/tag_library_import_planner.dart';
import 'package:nai_launcher/data/services/tag_library_io_service.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

const _suffix = ' (导入)';
const _packagedBytes = <int>[0x89, 0x50, 0x4e, 0x47, 0x01];
const _localBytes = <int>[0x89, 0x50, 0x4e, 0x47, 0x02];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documents;
  late Directory workspace;
  late PathProviderPlatform previousPlatform;
  late TagLibraryIOService service;
  late int counter;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('tag-library-apply-');
    workspace = await Directory.systemTemp.createTemp('tag-library-pack-');
    previousPlatform = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _PathProvider(documents.path);
    service = TagLibraryIOService();
    counter = 0;
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPlatform;
    await documents.delete(recursive: true);
    await workspace.delete(recursive: true);
  });

  Directory thumbnailsRoot() =>
      Directory(p.join(documents.path, 'tag_library_thumbnails'));

  List<String> thumbnailNames() {
    final root = thumbnailsRoot();
    if (!root.existsSync()) return const [];
    return root.listSync().map((e) => p.basename(e.path)).toList()..sort();
  }

  File writeLocalThumbnail(String entryId, List<int> bytes) {
    final root = thumbnailsRoot()..createSync(recursive: true);
    return File(p.join(root.path, '$entryId.png'))..writeAsBytesSync(bytes);
  }

  Future<ProviderContainer> seeded({
    List<TagLibraryEntry> entries = const [],
    List<TagLibraryCategory> categories = const [],
  }) async {
    final storage = _MemoryStorage();
    await storage.setTagLibraryEntriesJson(
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
    await storage.setTagLibraryCategoriesJson(
      jsonEncode(categories.map((c) => c.toJson()).toList()),
    );
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    return container;
  }

  TagLibraryImportPlan planFor({
    required ProviderContainer container,
    required ImportPreview preview,
    required List<ImportConflict> conflicts,
    required Map<String, ConflictResolution> resolutions,
  }) {
    final state = container.read(tagLibraryPageNotifierProvider);
    return TagLibraryImportPlanner(newId: () => 'new-${++counter}').plan(
      preview: preview,
      selectedEntryIds: preview.entries.map((e) => e.id).toSet(),
      selectedCategoryIds: preview.categories.map((c) => c.id).toSet(),
      conflicts: conflicts,
      conflictResolutions: resolutions,
      existingEntries: state.entries,
      existingCategories: state.categories,
      renameSuffix: _suffix,
    );
  }

  test('混合批次只按各自方案改写对应条目', () async {
    final container = await seeded(
      entries: [
        _entry(id: 'local-a', name: '猫', content: '本地猫'),
        _entry(id: 'local-b', name: '狗', content: '本地狗'),
        _entry(id: 'local-c', name: '鸟', content: '本地鸟'),
      ],
    );
    final notifier = container.read(tagLibraryPageNotifierProvider.notifier);
    final preview = _preview(
      entries: [
        _entry(id: 'pkg-1', name: '猫', content: '包内猫'),
        _entry(id: 'pkg-2', name: '狗', content: '包内狗'),
        _entry(id: 'pkg-3', name: '鸟', content: '包内鸟'),
        _entry(id: 'pkg-4', name: '鱼', content: '包内鱼'),
      ],
    );

    final applied = await notifier.applyImportPlan(
      planFor(
        container: container,
        preview: preview,
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
      ),
    );

    final entries = container.read(tagLibraryPageNotifierProvider).entries;
    expect(applied.success, isTrue);
    expect(applied.appliedEntryIds, ['new-1', 'pkg-3', 'new-2']);
    expect(entries.map((e) => e.id), [
      'local-a',
      'local-b',
      'new-1',
      'pkg-3',
      'new-2',
    ]);
    expect(entries.map((e) => e.name), ['猫', '狗', '狗$_suffix', '鸟', '鱼']);
    expect(entries.map((e) => e.content), ['本地猫', '本地狗', '包内狗', '包内鸟', '包内鱼']);
    expect(entries.map((e) => e.sortOrder), [0, 1, 2, 3, 4]);
  });

  test('导入结果一次性持久化', () async {
    final storage = _MemoryStorage();
    await storage.setTagLibraryEntriesJson('[]');
    await storage.setTagLibraryCategoriesJson('[]');
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(tagLibraryPageNotifierProvider.notifier);
    final preview = _preview(
      categories: [_category(id: 'cat-1', name: '角色')],
      entries: [_entry(id: 'pkg-1', name: '猫', categoryId: 'cat-1')],
    );
    final writesBefore = storage.writeCount;

    await notifier.applyImportPlan(
      planFor(
        container: container,
        preview: preview,
        conflicts: const [],
        resolutions: const {},
      ),
    );

    final persisted =
        jsonDecode(storage.getTagLibraryEntriesJson()!) as List<dynamic>;
    expect(storage.writeCount - writesBefore, 2);
    expect(persisted.single['id'], 'new-2');
    expect(persisted.single['categoryId'], 'new-1');
  });

  test('覆盖分类会连带删除子分类并把现有条目移到根级', () async {
    final container = await seeded(
      categories: [
        _category(id: 'local-cat', name: '角色'),
        _category(id: 'local-child', name: '子', parentId: 'local-cat'),
      ],
      entries: [_entry(id: 'local-a', name: '猫', categoryId: 'local-child')],
    );
    final notifier = container.read(tagLibraryPageNotifierProvider.notifier);
    notifier.selectCategory('local-child');

    await notifier.applyImportPlan(
      planFor(
        container: container,
        preview: _preview(
          categories: [_category(id: 'pkg-cat', name: '角色')],
        ),
        conflicts: [
          _categoryConflict(importId: 'pkg-cat', existingId: 'local-cat'),
        ],
        resolutions: const {'pkg-cat': ConflictResolution.overwrite},
      ),
    );

    final state = container.read(tagLibraryPageNotifierProvider);
    expect(state.categories.map((c) => c.id), ['pkg-cat']);
    expect(state.entries.single.categoryId, isNull);
    expect(state.selectedCategoryId, isNull);
  });

  test('目标 ID 在应用时已被占用则只拒绝该项', () async {
    final container = await seeded(
      entries: [_entry(id: 'local-a', name: '猫', content: '本地猫')],
    );
    final notifier = container.read(tagLibraryPageNotifierProvider.notifier);
    final sources = [
      _entry(id: 'pkg-1', name: '猫', content: '包内猫'),
      _entry(id: 'pkg-2', name: '鱼', content: '包内鱼'),
    ];

    final applied = await notifier.applyImportPlan(
      TagLibraryImportPlan(
        preview: _preview(entries: sources),
        categories: const [],
        entries: [
          TagLibraryEntryImportPlan(
            source: sources.first,
            action: TagLibraryImportAction.create,
            targetId: 'local-a',
            targetName: '猫',
          ),
          TagLibraryEntryImportPlan(
            source: sources.last,
            action: TagLibraryImportAction.create,
            targetId: 'fresh',
            targetName: '鱼',
          ),
        ],
      ),
    );

    final entries = container.read(tagLibraryPageNotifierProvider).entries;
    expect(applied.success, isFalse);
    expect(applied.rejected.single.kind, TagLibraryImportItemKind.entry);
    expect(applied.rejected.single.sourceId, 'pkg-1');
    expect(applied.rejected.single.targetId, 'local-a');
    expect(entries.map((e) => e.id), ['local-a', 'fresh']);
    expect(entries.first.content, '本地猫');
  });

  group('预览图落盘', () {
    late File localThumbnail;
    late File package;
    late TagLibraryEntry localEntry;

    setUp(() async {
      localThumbnail = writeLocalThumbnail('local-a', _packagedBytes);
      localEntry = _entry(
        id: 'local-a',
        name: '猫',
        content: '本地猫',
        thumbnail: localThumbnail.path,
      );
      package = await service.exportLibrary(
        entries: [localEntry],
        categories: const [],
        includeThumbnails: true,
        outputPath: p.join(workspace.path, 'library.zip'),
      );
      localThumbnail.writeAsBytesSync(_localBytes);
    });

    test('覆盖时预览图写回同一条目并保留包内内容', () async {
      final container = await seeded(entries: [localEntry]);
      final notifier = container.read(tagLibraryPageNotifierProvider.notifier);
      final preview = await service.parseImportFile(package);
      final plan = planFor(
        container: container,
        preview: preview,
        conflicts: await service.detectConflicts(
          preview,
          container.read(tagLibraryPageNotifierProvider).entries,
          const [],
        ),
        resolutions: const {'local-a': ConflictResolution.overwrite},
      );

      final result = await service.executeImport(zipFile: package, plan: plan);
      await notifier.applyImportPlan(
        plan,
        importedEntries: result.updatedEntries,
      );

      final entry = container
          .read(tagLibraryPageNotifierProvider)
          .entries
          .single;
      expect(entry.id, 'local-a');
      expect(entry.thumbnail, p.join(thumbnailsRoot().path, 'local-a.png'));
      expect(File(entry.thumbnail!).readAsBytesSync(), _packagedBytes);
      expect(thumbnailNames(), ['local-a.png']);
    });

    test('重命名导入不会覆盖同 ID 本地条目的预览图', () async {
      final container = await seeded(entries: [localEntry]);
      final notifier = container.read(tagLibraryPageNotifierProvider.notifier);
      final preview = await service.parseImportFile(package);
      final plan = planFor(
        container: container,
        preview: preview,
        conflicts: await service.detectConflicts(
          preview,
          container.read(tagLibraryPageNotifierProvider).entries,
          const [],
        ),
        resolutions: const {'local-a': ConflictResolution.rename},
      );

      final result = await service.executeImport(zipFile: package, plan: plan);
      await notifier.applyImportPlan(
        plan,
        importedEntries: result.updatedEntries,
      );

      final entries = container.read(tagLibraryPageNotifierProvider).entries;
      expect(entries.map((e) => e.id), ['local-a', 'new-1']);
      expect(entries.first.thumbnail, localThumbnail.path);
      expect(localThumbnail.readAsBytesSync(), _localBytes);
      expect(
        entries.last.thumbnail,
        p.join(thumbnailsRoot().path, 'new-1.png'),
      );
      expect(File(entries.last.thumbnail!).readAsBytesSync(), _packagedBytes);
      expect(thumbnailNames(), ['local-a.png', 'new-1.png']);
    });
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
  String content = '1girl',
  String? categoryId,
  String? thumbnail,
}) => TagLibraryEntry(
  id: id,
  name: name,
  content: content,
  categoryId: categoryId,
  thumbnail: thumbnail,
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

class _MemoryStorage extends LocalStorageService {
  final Map<String, Object?> _values = {};
  int writeCount = 0;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (_values[key] ?? defaultValue) as T?;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    writeCount++;
    _values[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    _values.remove(key);
  }
}

class _PathProvider extends PathProviderPlatform {
  _PathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}
