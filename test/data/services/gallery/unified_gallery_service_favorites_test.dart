import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nai_launcher/core/cache/gallery_cache_manager.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/database/connection_pool_holder.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/database/datasources/gallery_tables.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';
import 'package:nai_launcher/data/services/gallery/gallery_image_files.dart';
import 'package:nai_launcher/data/repositories/gallery_category_repository.dart';
import 'package:nai_launcher/presentation/providers/gallery_category_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:nai_launcher/data/services/gallery/unified_gallery_service.dart';

void main() {
  group('LocalGalleryService favorites', () {
    late Directory tempDir;
    late Directory galleryRoot;
    late GalleryDataSource dataSource;
    late LocalGalleryServiceImpl service;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await AppLogger.initialize(isTestEnvironment: true);
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'nai_launcher_gallery_service_favorites_',
      );
      galleryRoot = Directory(p.join(tempDir.path, 'gallery'));
      await galleryRoot.create(recursive: true);

      Hive.init(p.join(tempDir.path, 'hive'));
      await Hive.openBox(StorageKeys.settingsBox);
      await Hive.box(
        StorageKeys.settingsBox,
      ).put(StorageKeys.imageSavePath, galleryRoot.path);

      await ConnectionPoolHolder.initialize(
        dbPath: p.join(tempDir.path, 'gallery.db'),
        maxConnections: 2,
      );

      dataSource = GalleryDataSource();
      await dataSource.initialize();
      service = LocalGalleryServiceImpl(
        dataSource: dataSource,
        filterService: GalleryFilterService(dataSource),
      );
    });

    tearDown(() async {
      // initialize() starts a tiny background scan; let it release sqlite locks.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await service.dispose();
      await dataSource.dispose();
      await ConnectionPoolHolder.dispose();
      await Hive.close();

      if (await tempDir.exists()) {
        await _deleteDirectoryWithRetry(tempDir);
      }
    });

    Future<File> indexFile(String name, {bool onDisk = true}) async {
      final file = File(p.join(galleryRoot.path, name));
      if (onDisk) await file.writeAsBytes([1]);
      await dataSource.upsertImage(
        filePath: file.path,
        fileName: name,
        fileSize: 1,
        createdAt: DateTime(2026),
        modifiedAt: DateTime(2026),
        metadataStatus: MetadataStatus.success,
      );
      return file;
    }

    Future<Map<String, int>> deletionFlags() =>
        dataSource.execute('readDeletionFlags', (db) async {
          final rows = await db.query(
            GalleryTables.images,
            columns: ['file_name', 'is_deleted'],
          );
          return {
            for (final row in rows)
              row['file_name'] as String: row['is_deleted'] as int,
          };
        });

    test('真实图库删除标记已删文件和仅存索引行，保留相邻图片', () async {
      final target = await indexFile('target.png');
      final keep = await indexFile('keep.png');
      await service.initialize();
      final missing = await indexFile('missing.png', onDisk: false);
      await target.delete();
      expect(await deletionFlags(), {
        'target.png': 0,
        'missing.png': 0,
        'keep.png': 0,
      });
      expect(
        await service.removeDeletedImagesImmediately([
          target.path,
          missing.path,
          keep.path,
        ]),
        1,
      );
      expect(await deletionFlags(), {
        'target.png': 1,
        'missing.png': 1,
        'keep.png': 0,
      });
      expect(service.totalCount, 1);
      expect((await service.getPage(0)).map((record) => record.path), [
        keep.path,
      ]);
    });

    test('SQLite 删除回滚不失效统计，重试提交后监听者读到新总数', () async {
      final file = await indexFile('target.png');
      await service.initialize();
      await file.delete();
      await dataSource.execute(
        'rejectDeletion',
        (db) => db.execute(
          "CREATE TRIGGER reject_deletion BEFORE UPDATE OF is_deleted ON ${GalleryTables.images} "
          "BEGIN SELECT RAISE(ABORT, 'reject deletion'); END",
        ),
      );
      final counts = <Future<int>>[];
      void onInvalidated() => counts.add(dataSource.countImages());
      final cache = GalleryCacheManager()
        ..registerOnStatisticsInvalidated(onInvalidated);
      try {
        await expectLater(
          service.removeDeletedImagesImmediately([file.path]),
          throwsException,
        );
        expect(counts, isEmpty);
        expect((await deletionFlags())['target.png'], 0);
        await dataSource.execute(
          'allowDeletion',
          (db) => db.execute('DROP TRIGGER reject_deletion'),
        );
        await service.removeDeletedImagesImmediately([file.path]);
        expect(await Future.wait(counts), [0]);
      } finally {
        cache.unregisterOnStatisticsInvalidated(onInvalidated);
      }
    });

    test('concurrent initialize calls share the same operation', () async {
      final image = File(p.join(galleryRoot.path, 'concurrent.png'));
      await image.writeAsBytes(<int>[137, 80, 78, 71]);

      final first = service.initialize();
      final concurrent = service.initialize();

      expect(identical(first, concurrent), isTrue);
      expect((await concurrent).map((file) => file.path), contains(image.path));
      expect(service.isInitialized, isTrue);
    });

    test('跨日保存、并发批量、重复通知与删除仅更新路径上的侧栏文件夹且可读回', () async {
      final enumerated = <String>[];
      final repository = GalleryCategoryRepository(
        images: GalleryImageFiles(
          listDirectory: (dir) {
            enumerated.add(p.relative(dir.path, from: galleryRoot.path));
            return dir.list(followLinks: false);
          },
        ),
      );
      Future<File> save(String path) =>
          File(p.join(galleryRoot.path, path)).create(recursive: true);
      await save('2026-11-17/old.png');
      await save('2026-11-17/sub/nested.png');
      final container = ProviderContainer(
        overrides: [
          galleryServiceProvider.overrideWith(
            () => GalleryService(createService: () => service),
          ),
          galleryCategoryNotifierProvider.overrideWith(
            () => GalleryCategoryNotifier(repository: repository),
          ),
        ],
      );
      addTearDown(container.dispose);
      final gallery = container.read(localGalleryNotifierProvider.notifier);
      final sidebar = container.read(galleryCategoryNotifierProvider.notifier);
      await gallery.initialize();
      await sidebar.whenLoaded();
      Map<String, int> counts() => {
        for (final c
            in container.read(galleryCategoryNotifierProvider).categories)
          c.folderPath.replaceAll('\\', '/'): c.imageCount,
      };
      expect(counts()['2026-11-17'], 2);
      expect(enumerated.toSet().length, enumerated.length);
      enumerated.clear();
      final first = await save('2026-11-18/one.png');
      await gallery.addNewlySavedImages([first.path]);
      expect(counts()['2026-11-18'], 1);
      final second = await save('2026-11-18/two.png');
      await gallery.addNewlySavedImages([second.path]);
      await gallery.addNewlySavedImages([first.path, second.path]);
      expect(counts()['2026-11-18'], 2);
      final sub = await save('2026-11-18/sub/a.png');
      final sub2 = await save('2026-11-18/sub/b.png');
      final third = await save('2026-11-18/three.png');
      await Future.wait([
        gallery.addNewlySavedImages([sub.path, sub2.path]),
        gallery.addNewlySavedImages([third.path]),
      ]);
      expect(counts()['2026-11-18'], 5);
      expect(counts()['2026-11-18/sub'], 2);
      await sub.delete();
      await gallery.removeDeletedImages([sub.path]);
      expect(counts()['2026-11-18'], 4);
      expect(counts()['2026-11-18/sub'], 1);
      final suppressed = container
          .read(galleryCategoryNotifierProvider)
          .categories
          .firstWhere(
            (c) => c.name == 'sub' && c.folderPath.startsWith('2026-11-18'),
          );
      await sidebar.deleteCategory(suppressed.id, deleteFolder: false);
      final underSuppressed = await save('2026-11-18/sub/deeper/new.png');
      await gallery.addNewlySavedImages([underSuppressed.path]);
      expect(
        counts().keys.where((k) => k.startsWith('2026-11-18/sub')),
        isEmpty,
      );
      expect(counts()['2026-11-18'], 5);
      final hidden = await save('2026-11-18/.private/new.png');
      await sidebar.updateForImagePaths([
        hidden.path,
      ], (_) => fail('隐藏目录不参与侧栏计数'));
      await sidebar.updateForImagePaths([
        p.join(tempDir.path, 'outside.png'),
        p.join(galleryRoot.path, 'at-root.png'),
      ], (_) => fail('根级和图库外文件不触发分类计数'));
      expect(enumerated, isEmpty);
      expect(counts()['2026-11-17'], 2);
      final fromDisk = await GalleryCategoryRepository().loadCategories(
        galleryRoot.path,
      );
      expect({
        for (final c in fromDisk)
          c.folderPath.replaceAll('\\', '/'): c.imageCount,
      }, counts());
      await sidebar.syncWithFileSystem();
      expect(enumerated.toSet().length, enumerated.length);
      expect(counts()['2026-11-18'], 5);
    });

    test(
      'toggles the scanned gallery record when history uses mixed separators',
      () async {
        if (!Platform.isWindows) {
          markTestSkipped('Windows separator regression');
          return;
        }

        final file = File(p.join(galleryRoot.path, 'already_scanned.png'));
        await file.writeAsBytes(<int>[137, 80, 78, 71]);
        final scannedPath = file.path;
        final visibleImageId = await dataSource.upsertImage(
          filePath: scannedPath,
          fileName: p.basename(scannedPath),
          fileSize: await file.length(),
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        );
        await service.initialize();

        final historyPath = scannedPath.replaceAll(r'\', '/');
        final isFavorite = await service.toggleFavorite(historyPath);

        expect(isFavorite, isTrue);
        expect(await dataSource.isFavorite(visibleImageId), isTrue);

        final records = await service.getPage(0);
        expect(records.single.path, scannedPath);
        expect(records.single.isFavorite, isTrue);
      },
    );

    test(
      'indexes a newly saved history image before applying favorite filters',
      () async {
        await service.initialize();
        final file = File(p.join(galleryRoot.path, 'saved_from_history.png'));
        await file.writeAsBytes(<int>[137, 80, 78, 71]);

        final isFavorite = await service.toggleFavorite(file.path);
        await service.setShowFavoritesOnly(true);

        final favorites = await service.getPage(0);
        expect(isFavorite, isTrue);
        expect(favorites, hasLength(1));
        expect(favorites.single.path, file.path);
        expect(favorites.single.isFavorite, isTrue);
      },
    );

    test(
      'counts favorites without changing the active favorites filter',
      () async {
        final favoriteFile = File(p.join(galleryRoot.path, 'favorite.png'));
        final otherFile = File(p.join(galleryRoot.path, 'ordinary.png'));
        await favoriteFile.writeAsBytes(<int>[137, 80, 78, 71]);
        await otherFile.writeAsBytes(<int>[137, 80, 78, 71]);

        await service.initialize();
        expect(await service.toggleFavorite(favoriteFile.path), isTrue);
        await service.setShowFavoritesOnly(true);

        final beforeCount = service.filteredCount;
        final beforeRecords = await service.getPage(0);
        expect(beforeCount, 1);
        expect(beforeRecords.map((record) => record.path), [favoriteFile.path]);

        final count = await service.getFavoriteCount();

        expect(count, 1);
        expect(service.currentFilter.showFavoritesOnly, isTrue);
        expect(service.filteredCount, beforeCount);

        final afterRecords = await service.getPage(0);
        expect(afterRecords.map((record) => record.path), [favoriteFile.path]);
      },
    );

    test('queries favorite image records directly in modified order', () async {
      final olderFile = File(p.join(galleryRoot.path, 'older.png'));
      final newerFile = File(p.join(galleryRoot.path, 'newer.png'));
      final ordinaryFile = File(p.join(galleryRoot.path, 'ordinary.png'));
      await olderFile.writeAsBytes(<int>[137, 80, 78, 71]);
      await newerFile.writeAsBytes(<int>[137, 80, 78, 71]);
      await ordinaryFile.writeAsBytes(<int>[137, 80, 78, 71]);

      final olderId = await dataSource.upsertImage(
        filePath: olderFile.path,
        fileName: p.basename(olderFile.path),
        fileSize: await olderFile.length(),
        createdAt: DateTime(2026),
        modifiedAt: DateTime(2026),
      );
      final newerId = await dataSource.upsertImage(
        filePath: newerFile.path,
        fileName: p.basename(newerFile.path),
        fileSize: await newerFile.length(),
        createdAt: DateTime(2026, 1, 2),
        modifiedAt: DateTime(2026, 1, 2),
      );
      await dataSource.upsertImage(
        filePath: ordinaryFile.path,
        fileName: p.basename(ordinaryFile.path),
        fileSize: await ordinaryFile.length(),
        createdAt: DateTime(2026, 1, 3),
        modifiedAt: DateTime(2026, 1, 3),
      );
      expect(await dataSource.toggleFavorite(olderId), isTrue);
      expect(await dataSource.toggleFavorite(newerId), isTrue);

      final favorites = await dataSource.queryFavoriteImages(limit: 10);

      expect(favorites.map((record) => record.filePath), [
        newerFile.path,
        olderFile.path,
      ]);
    });

    test(
      'counts only favorites that are still visible in the local gallery root',
      () async {
        final visibleFile = File(p.join(galleryRoot.path, 'visible.png'));
        await visibleFile.writeAsBytes(<int>[137, 80, 78, 71]);

        final outsideDir = Directory(p.join(tempDir.path, 'outside'));
        await outsideDir.create();
        final outsideFile = File(p.join(outsideDir.path, 'outside.png'));
        await outsideFile.writeAsBytes(<int>[137, 80, 78, 71]);

        await service.initialize();
        expect(await service.toggleFavorite(visibleFile.path), isTrue);

        final outsideId = await dataSource.upsertImage(
          filePath: outsideFile.path,
          fileName: p.basename(outsideFile.path),
          fileSize: await outsideFile.length(),
          createdAt: DateTime(2026),
          modifiedAt: DateTime(2026),
        );
        expect(await dataSource.toggleFavorite(outsideId), isTrue);

        expect(await service.getFavoriteCount(), 1);
      },
    );

    test(
      'independent query pages and searches the complete gallery without changing the active view',
      () async {
        final newest = File(p.join(galleryRoot.path, 'newest.png'));
        final middle = File(p.join(galleryRoot.path, 'middle.png'));
        final archived = File(p.join(galleryRoot.path, 'archived-needle.png'));
        for (final file in [newest, middle, archived]) {
          await file.writeAsBytes(<int>[137, 80, 78, 71]);
        }
        await newest.setLastModified(DateTime(2026, 3));
        await middle.setLastModified(DateTime(2026, 2));
        await archived.setLastModified(DateTime(2026, 1));
        for (final file in [newest, middle, archived]) {
          final stat = await file.stat();
          await dataSource.upsertImage(
            filePath: file.path,
            fileName: p.basename(file.path),
            fileSize: stat.size,
            createdAt: stat.modified,
            modifiedAt: stat.modified,
          );
        }

        await service.initialize();
        await service.setSearchQuery('newest');
        final activePageBefore = await service.getPage(0);

        final historicalPage = await service.queryPage(page: 2, pageSize: 1);
        final searchPage = await service.queryPage(
          page: 0,
          pageSize: 10,
          criteria: const FilterCriteria(searchQuery: 'needle'),
        );

        expect(historicalPage.records.map((record) => record.path), [
          archived.path,
        ]);
        expect(historicalPage.totalCount, 3);
        expect(historicalPage.hasMore, isFalse);
        expect(searchPage.records.map((record) => record.path), [
          archived.path,
        ]);
        expect(searchPage.totalCount, 1);
        expect(await service.getImageIdByPath(archived.path), isNotNull);
        expect(service.currentFilter.searchQuery, 'newest');
        expect(
          (await service.getPage(0)).map((record) => record.path),
          activePageBefore.map((record) => record.path),
        );
      },
    );
  });
}

Future<void> _deleteDirectoryWithRetry(Directory directory) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      return;
    } on FileSystemException {
      if (attempt == 9) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
