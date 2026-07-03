import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/database/connection_pool_holder.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';
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
      await Hive.box(StorageKeys.settingsBox).put(
        StorageKeys.imageSavePath,
        galleryRoot.path,
      );

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
