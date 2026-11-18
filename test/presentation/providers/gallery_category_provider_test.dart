import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:path/path.dart' as p;

import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/gallery/gallery_category.dart';
import 'package:nai_launcher/data/models/gallery/gallery_tree_drop_slot.dart';
import 'package:nai_launcher/data/repositories/gallery_category_repository.dart';
import 'package:nai_launcher/presentation/providers/category_operation_error.dart';
import 'package:nai_launcher/presentation/providers/gallery_category_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';

class _GalleryScope extends LocalGalleryNotifier {
  @override
  LocalGalleryState build() => const LocalGalleryState();
  @override
  Future<void> refresh({bool scan = true}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory galleryRoot;
  late Directory hiveRoot;
  late ProviderContainer container;

  setUp(() async {
    galleryRoot = await Directory.systemTemp.createTemp(
      'gallery_category_provider_root_',
    );
    hiveRoot = await Directory.systemTemp.createTemp(
      'gallery_category_provider_hive_',
    );
    Hive.init(hiveRoot.path);
    await Hive.openBox(StorageKeys.settingsBox);
    await Hive.box(
      StorageKeys.settingsBox,
    ).put(StorageKeys.imageSavePath, galleryRoot.path);

    for (final name in ['a', 'b', 'c']) {
      await Directory(
        '${galleryRoot.path}${Platform.pathSeparator}$name',
      ).create();
    }
    final now = DateTime.utc(2026);
    final categories = [
      GalleryCategory(
        id: 'a',
        name: 'a',
        folderPath: 'a',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
      GalleryCategory(
        id: 'b',
        name: 'b',
        folderPath: 'b',
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      ),
      GalleryCategory(
        id: 'c',
        name: 'c',
        folderPath: 'c',
        sortOrder: 2,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    await File(
      '${galleryRoot.path}${Platform.pathSeparator}.gallery_categories.json',
    ).writeAsString(
      jsonEncode(categories.map((category) => category.toJson()).toList()),
    );

    container = ProviderContainer(
      overrides: [localGalleryNotifierProvider.overrideWith(_GalleryScope.new)],
    );
    await container.read(galleryCategoryNotifierProvider.notifier).whenLoaded();
  });

  tearDown(() async {
    container.dispose();
    await Hive.close();
    await hiveRoot.delete(recursive: true);
    await galleryRoot.delete(recursive: true);
  });

  List<String> orderedCategoryIds() {
    final categories = [
      ...container.read(galleryCategoryNotifierProvider).categories,
    ]..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    return categories.map((category) => category.id).toList();
  }

  test('父目录改名、移动、删除后选中子分类与图库范围一致', () async {
    final categories = container.read(galleryCategoryNotifierProvider.notifier);
    final child = (await categories.createCategory('child', parentId: 'a'))!;
    categories.selectCategory(child.id);
    final gallery = container.read(localGalleryNotifierProvider.notifier);
    await gallery.setSelectedCategory(
      child.id,
      child.folderPath,
      refreshFiles: true,
    );
    void check(GalleryCategory? selected, String? path) {
      expect(
        container.read(galleryCategoryNotifierProvider).selectedCategoryId,
        selected?.id,
      );
      final filter = container
          .read(localGalleryNotifierProvider)
          .filterCriteria;
      expect(filter.categoryId, selected?.id);
      expect(filter.categoryFolderPath, path);
    }

    await categories.renameCategory('a', 'renamed');
    check(child, p.join('renamed', 'child'));
    await categories.moveCategory('a', 'b');
    check(child, p.join('b', 'renamed', 'child'));
    await categories.deleteCategory('a', deleteFolder: false, recursive: true);
    check(null, null);
  });

  test('修改 foo 的后代路径不会改写 foobar', () {
    final original = container
        .read(galleryCategoryNotifierProvider)
        .categories
        .first;
    final changed = GalleryCategoryRepository.instance
        .updateDescendantPaths('foo', 'renamed', [
          original.copyWith(folderPath: p.join('foo', 'child')),
          original.copyWith(folderPath: p.join('foobar', 'child')),
        ]);
    expect(changed.map((c) => c.folderPath), [
      p.join('renamed', 'child'),
      p.join('foobar', 'child'),
    ]);
  });

  test(
    'before slot inserts the category immediately before the target',
    () async {
      final changed = await container
          .read(galleryCategoryNotifierProvider.notifier)
          .moveCategoryToSlot('c', 'b', GalleryTreeDropSlot.before);

      expect(changed, isTrue);
      expect(orderedCategoryIds(), ['a', 'c', 'b']);
    },
  );

  test(
    'after slot inserts the category immediately after the target',
    () async {
      final changed = await container
          .read(galleryCategoryNotifierProvider.notifier)
          .moveCategoryToSlot('a', 'b', GalleryTreeDropSlot.after);

      expect(changed, isTrue);
      expect(orderedCategoryIds(), ['b', 'a', 'c']);
    },
  );

  test(
    'manual move persists the displayed order without moving physical folders',
    () async {
      final changed = await container
          .read(galleryCategoryNotifierProvider.notifier)
          .moveCategoryToSlot(
            'a',
            'c',
            GalleryTreeDropSlot.after,
            displayOrder: {'c': 0, 'b': 1, 'a': 2},
          );
      expect(changed, isTrue);
      expect(orderedCategoryIds(), ['c', 'a', 'b']);
      final persisted = await GalleryCategoryRepository.instance
          .loadCategories();
      persisted.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      expect(persisted.map((c) => c.id), ['c', 'a', 'b']);
      for (final id in ['a', 'b', 'c']) {
        expect(await Directory('${galleryRoot.path}/$id').exists(), isTrue);
      }
    },
  );

  test('failed metadata save preserves the previous config file', () async {
    final configFile = File(
      '${galleryRoot.path}${Platform.pathSeparator}.gallery_categories.json',
    );
    final originalContents = await configFile.readAsString();
    await Directory('${configFile.path}.tmp').create();

    final saved = await GalleryCategoryRepository.instance.saveCategories(
      container
          .read(galleryCategoryNotifierProvider)
          .categories
          .reversed
          .toList(),
    );

    expect(saved, isFalse);
    expect(await configFile.readAsString(), originalContents);
  });

  test(
    'interrupted metadata replacement recovers the backup on load',
    () async {
      final configFile = File(
        '${galleryRoot.path}${Platform.pathSeparator}.gallery_categories.json',
      );
      final backupFile = File('${configFile.path}.bak');
      await configFile.rename(backupFile.path);

      final categories = await GalleryCategoryRepository.instance
          .loadCategories();

      expect(categories.map((category) => category.id), ['a', 'b', 'c']);
      expect(await configFile.exists(), isTrue);
      expect(await backupFile.exists(), isFalse);
    },
  );

  test('failed metadata save rolls a physical category move back', () async {
    final configFile = File(
      '${galleryRoot.path}${Platform.pathSeparator}.gallery_categories.json',
    );
    await configFile.delete();
    await Directory(configFile.path).create();

    final changed = await container
        .read(galleryCategoryNotifierProvider.notifier)
        .moveCategoryToSlot('c', 'b', GalleryTreeDropSlot.child);

    expect(changed, isFalse);
    expect(
      Directory('${galleryRoot.path}${Platform.pathSeparator}c').existsSync(),
      isTrue,
    );
    expect(
      Directory(
        '${galleryRoot.path}${Platform.pathSeparator}b'
        '${Platform.pathSeparator}c',
      ).existsSync(),
      isFalse,
    );
    final state = container.read(galleryCategoryNotifierProvider);
    expect(state.categories.findById('c')?.parentId, isNull);
    expect(state.error?.code, CategoryOperationErrorCode.moveFailed);
  });
}
