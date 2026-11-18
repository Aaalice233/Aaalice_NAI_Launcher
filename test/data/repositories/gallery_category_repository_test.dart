import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/data/models/gallery/gallery_category.dart';
import 'package:nai_launcher/data/repositories/gallery_category_repository.dart';
import 'package:nai_launcher/data/services/gallery/local_gallery_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory hiveTempDir;
  late Directory galleryRoot;
  late GalleryCategoryRepository repository;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    hiveTempDir = await Directory.systemTemp.createTemp(
      'nai_launcher_gallery_category_hive_',
    );
    galleryRoot = await Directory.systemTemp.createTemp(
      'nai_launcher_gallery_category_root_',
    );
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
    await Hive.box(StorageKeys.settingsBox).put(
      StorageKeys.imageSavePath,
      galleryRoot.path,
    );
    repository = GalleryCategoryRepository.instance;
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
    if (await galleryRoot.exists()) {
      await galleryRoot.delete(recursive: true);
    }
  });

  test('grid and category counts admit the same root-relative images', () async {
    final root = p.join(galleryRoot.path, 'cache', 'temp', 'gallery');
    await Hive.box(StorageKeys.settingsBox).put(StorageKeys.imageSavePath, root);
    const visible = [
      'top/root.PNG', 'top/temp/a.jpg', 'top/cache/b.JPEG',
      'top/thumbs/c.webp', 'top/.portrait.png',
    ];
    for (final path in [
      ...visible, 'top/.thumbs/old.png', 'top/deep/.private/hidden.png',
      'top/readme.txt',
    ]) {
      await File(p.join(root, path)).create(recursive: true);
    }
    final grid = LocalGalleryRepository(dataSource: GalleryDataSource());
    final files = await grid.findGalleryFiles();
    expect(files.map((f) => p.relative(f.path, from: root)),
        unorderedEquals(visible.map(p.normalize)));
    final category = GalleryCategory.create(name: 'top', folderPath: 'top');
    expect(await repository.countImagesInCategory(category), files.length);
    final hidden = GalleryCategory.create(name: '.thumbs', folderPath: 'top/.thumbs');
    expect(await repository.countImagesInCategory(hidden), 0);
  });

  test('sync does not recreate a category deleted while keeping its folder',
      () async {
    final folder =
        Directory('${galleryRoot.path}${Platform.pathSeparator}keep');
    await folder.create();

    final category = GalleryCategory.create(
      name: 'keep',
      folderPath: 'keep',
    );

    final deleted = await repository.deleteCategory(
      galleryRoot.path,
      category,
      [category],
      deleteFolder: false,
    );
    expect(deleted, isTrue);

    final syncedCategories = await repository.syncWithFileSystem(
      galleryRoot.path,
      const [],
    );

    expect(syncedCategories, isEmpty);
    expect(await folder.exists(), isTrue);
  });

  test('new category folder matches the name Windows keeps on disk', () async {
    final category = await repository.createCategory(
      rootPath: galleryRoot.path,
      name: 'summer\ntrip. ',
    );

    expect(category?.folderPath, 'summer trip');
    expect(
      await Directory(
        '${galleryRoot.path}${Platform.pathSeparator}summer trip',
      ).exists(),
      isTrue,
    );
  });
}
