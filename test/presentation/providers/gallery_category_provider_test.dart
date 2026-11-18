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
import 'package:nai_launcher/data/services/gallery/gallery_image_files.dart';
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

  test('首次保存只访问父目录链，持久化失败能重试，已消失的文件夹不复建', () async {
    final repository = GalleryCategoryRepository(
      images: GalleryImageFiles(listDirectory: (d) => fail('保存不应枚举 ${d.path}')),
    );
    final cold = ProviderContainer(
      overrides: [
        galleryCategoryNotifierProvider.overrideWith(
          () => GalleryCategoryNotifier(repository: repository),
        ),
      ],
    );
    addTearDown(cold.dispose);
    final sidebar = cold.read(galleryCategoryNotifierProvider.notifier);
    final image = await File(
      p.join(galleryRoot.path, 'a', 'new', 'first.png'),
    ).create(recursive: true);
    final vanished = p.join(galleryRoot.path, 'gone', 'deleted.png');
    final requested = <String>[];
    int countIn(String folder) {
      requested.add(p.relative(folder, from: galleryRoot.path));
      return 1;
    }

    final tmp = await Directory(
      p.join(galleryRoot.path, '.gallery_categories.json.tmp'),
    ).create();
    await sidebar.updateForImagePaths([image.path, vanished], countIn);
    expect(
      cold.read(galleryCategoryNotifierProvider).error?.code,
      CategoryOperationErrorCode.syncFailed,
    );
    expect(requested, ['a', p.join('a', 'new')]);
    await tmp.delete();
    requested.clear();
    await sidebar.updateForImagePaths([image.path], countIn);
    expect(cold.read(galleryCategoryNotifierProvider).error, isNull);
    expect(requested, ['a', p.join('a', 'new')]);
    final disk = await repository.loadCategories(galleryRoot.path);
    expect(disk.firstWhere((c) => c.name == 'new').imageCount, 1);
    expect(disk.firstWhere((c) => c.id == 'a').imageCount, 1);
    expect(disk.any((c) => c.name == 'gone'), isFalse);
  });

  test('切换根目录后保存图片会保留新根的分类和排序', () async {
    final nextRoot = await Directory.systemTemp.createTemp('category_root_b_');
    addTearDown(() => nextRoot.delete(recursive: true));
    final repository = GalleryCategoryRepository.instance;
    final saved = [
      GalleryCategory.create(name: '委托', folderPath: p.join('作品', '委托')),
      GalleryCategory.create(name: '作品', folderPath: '作品', sortOrder: 17),
      GalleryCategory.create(name: '归档', folderPath: '归档', sortOrder: 3),
    ];
    final existing = [
      saved.first.copyWith(parentId: saved[1].id, sortOrder: 11),
      ...saved.skip(1),
    ];
    expect(await repository.saveCategories(nextRoot.path, existing), isTrue);
    final previousConfig = File(
      p.join(galleryRoot.path, '.gallery_categories.json'),
    );
    final originalContents = await previousConfig.readAsString();

    await Hive.box(
      StorageKeys.settingsBox,
    ).put(StorageKeys.imageSavePath, nextRoot.path);
    final image = await File(
      p.join(nextRoot.path, '2026-11-21', 'new.png'),
    ).create(recursive: true);
    await container
        .read(galleryCategoryNotifierProvider.notifier)
        .updateForImagePaths([image.path], (_) => 1);

    final persisted = await repository.loadCategories(nextRoot.path);
    expect(persisted.take(3), existing);
    expect(persisted.last.folderPath, '2026-11-21');
    expect(persisted.last.imageCount, 1);
    expect(await previousConfig.readAsString(), originalContents);
  });

  test('同步期间切换根目录仍向枚举时的根目录写入', () async {
    final nextRoot = await Directory.systemTemp.createTemp('category_root_b_');
    addTearDown(() => nextRoot.delete(recursive: true));
    final nextConfig = File(p.join(nextRoot.path, '.gallery_categories.json'));
    await nextConfig.writeAsString('[]');
    final repository = GalleryCategoryRepository(
      images: GalleryImageFiles(
        listDirectory: (dir) async* {
          if (p.equals(dir.path, galleryRoot.path)) {
            await Hive.box(
              StorageKeys.settingsBox,
            ).put(StorageKeys.imageSavePath, nextRoot.path);
          }
          yield* dir.list(followLinks: false);
        },
      ),
    );
    final scoped = ProviderContainer(
      overrides: [
        galleryCategoryNotifierProvider.overrideWith(
          () => GalleryCategoryNotifier(repository: repository),
        ),
      ],
    );
    addTearDown(scoped.dispose);
    await Directory(p.join(galleryRoot.path, 'new')).create();
    await scoped.read(galleryCategoryNotifierProvider.notifier).whenLoaded();

    final persisted = await repository.loadCategories(galleryRoot.path);
    expect(persisted.map((c) => c.folderPath), ['a', 'b', 'c', 'new']);
    expect(await nextConfig.readAsString(), '[]');
  });

  test('新根的分类配置无法解析时跳过写入，修好后可重试', () async {
    final nextRoot = await Directory.systemTemp.createTemp('category_root_b_');
    addTearDown(() => nextRoot.delete(recursive: true));
    final config = File(p.join(nextRoot.path, '.gallery_categories.json'));
    await config.writeAsString('{broken');
    await Hive.box(
      StorageKeys.settingsBox,
    ).put(StorageKeys.imageSavePath, nextRoot.path);
    final image = await File(
      p.join(nextRoot.path, 'new', 'x.png'),
    ).create(recursive: true);
    final sidebar = container.read(galleryCategoryNotifierProvider.notifier);

    await sidebar.updateForImagePaths([image.path], (_) => fail('分类未加载'));
    expect(
      container.read(galleryCategoryNotifierProvider).error?.code,
      CategoryOperationErrorCode.loadFailed,
    );
    expect(await config.readAsString(), '{broken');

    await config.writeAsString('[]');
    await sidebar.updateForImagePaths([image.path], (_) => 1);
    final persisted = await GalleryCategoryRepository.instance.loadCategories(
      nextRoot.path,
    );
    expect(persisted.single.folderPath, 'new');
  });

  test('隐藏设置无法解析时保留原文件和分类', () async {
    final config = File(
      p.join(galleryRoot.path, '.gallery_category_suppressed_paths.json'),
    );
    await config.writeAsString('{}');
    final sidebar = container.read(galleryCategoryNotifierProvider.notifier);

    expect(await sidebar.deleteCategory('a', deleteFolder: false), isFalse);
    expect(await config.readAsString(), '{}');
    expect(orderedCategoryIds(), ['a', 'b', 'c']);

    final image = await File(
      p.join(galleryRoot.path, 'new', 'x.png'),
    ).create(recursive: true);
    await sidebar.updateForImagePaths([image.path], (_) => fail('隐藏设置未加载'));
    expect(
      container.read(galleryCategoryNotifierProvider).error?.code,
      CategoryOperationErrorCode.syncFailed,
    );
    expect(orderedCategoryIds(), ['a', 'b', 'c']);
  });

  test('子目录暂时无法枚举时保留分类、隐藏项、选中范围和计数', () async {
    final root = galleryRoot.path;
    final work = GalleryCategory.create(
      name: '作品',
      folderPath: p.join('a', '作品'),
      parentId: 'a',
      sortOrder: 17,
    ).updateImageCount(2);
    final commission = GalleryCategory.create(
      name: '委托',
      folderPath: p.join(work.folderPath, '委托'),
      parentId: work.id,
      sortOrder: 11,
    ).updateImageCount(1);
    const hidden = 'a/作品/已隐藏';
    await File(
      p.join(root, commission.folderPath, 'x.png'),
    ).create(recursive: true);
    await File(p.join(root, hidden, 'hidden.png')).create(recursive: true);
    final suppressed = File(
      p.join(root, '.gallery_category_suppressed_paths.json'),
    );
    final contents = jsonEncode([hidden]);
    await suppressed.writeAsString(contents);

    var blocked = false;
    final repository = GalleryCategoryRepository(
      images: GalleryImageFiles(
        listDirectory: (dir) async* {
          if (blocked && p.equals(dir.path, p.join(root, work.folderPath))) {
            throw FileSystemException('cannot list', dir.path);
          }
          yield* dir.list(followLinks: false);
        },
      ),
    );
    expect(
      await repository.saveCategories(root, [
        ...container.read(galleryCategoryNotifierProvider).categories,
        work,
        commission,
      ]),
      isTrue,
    );
    final scoped = ProviderContainer(
      overrides: [
        galleryCategoryNotifierProvider.overrideWith(
          () => GalleryCategoryNotifier(repository: repository),
        ),
        localGalleryNotifierProvider.overrideWith(_GalleryScope.new),
      ],
    );
    addTearDown(scoped.dispose);
    final sidebar = scoped.read(galleryCategoryNotifierProvider.notifier);
    await sidebar.whenLoaded();
    sidebar.selectCategory(commission.id);
    await scoped
        .read(localGalleryNotifierProvider.notifier)
        .setSelectedCategory(
          commission.id,
          commission.folderPath,
          refreshFiles: true,
        );
    await File(p.join(root, 'a', 'new.png')).create();
    await File(p.join(root, 'b', 'sibling.png')).create();

    for (final inaccessible in [true, false]) {
      blocked = inaccessible;
      await sidebar.syncWithFileSystem();

      final persisted = await repository.loadCategories(root);
      expect(persisted.findById(work.id), work);
      expect(persisted.findById(commission.id), commission);
      expect(persisted.map((c) => c.name), isNot(contains('已隐藏')));
      expect(persisted.findById('a')?.imageCount, 3);
      expect(persisted.findById('b')?.imageCount, 1);
      expect(await suppressed.readAsString(), contents);
      expect(
        scoped.read(galleryCategoryNotifierProvider).selectedCategoryId,
        commission.id,
      );
      expect(
        scoped
            .read(localGalleryNotifierProvider)
            .filterCriteria
            .categoryFolderPath,
        commission.folderPath,
      );
    }
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
      final persisted = await GalleryCategoryRepository.instance.loadCategories(
        galleryRoot.path,
      );
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
      galleryRoot.path,
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
          .loadCategories(galleryRoot.path);

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
