import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/gallery/gallery_category.dart';
import 'package:nai_launcher/data/repositories/gallery_category_repository.dart';

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
      category,
      [category],
      deleteFolder: false,
    );
    expect(deleted, isTrue);

    final syncedCategories = await repository.syncWithFileSystem(const []);

    expect(syncedCategories, isEmpty);
    expect(await folder.exists(), isTrue);
  });
}
