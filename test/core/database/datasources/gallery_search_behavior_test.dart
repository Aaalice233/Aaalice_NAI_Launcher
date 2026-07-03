import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nai_launcher/core/database/connection_pool_holder.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';

void main() {
  group('Gallery Search Behavior', () {
    late GalleryDataSource dataSource;
    late String testDbPath;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await AppLogger.initialize(isTestEnvironment: true);

      final tempDir = Directory.systemTemp.createTempSync('gallery_search_');
      testDbPath = '${tempDir.path}/search_behavior.db';
    });

    tearDownAll(() async {
      await ConnectionPoolHolder.dispose();

      try {
        final dbFile = File(testDbPath);
        if (await dbFile.exists()) {
          await dbFile.delete();
        }

        final tempDir = Directory(testDbPath).parent;
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    setUp(() async {
      if (ConnectionPoolHolder.isInitialized) {
        await ConnectionPoolHolder.dispose();
      }

      final dbFile = File(testDbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      await ConnectionPoolHolder.initialize(
        dbPath: testDbPath,
        maxConnections: 2,
      );

      dataSource = GalleryDataSource();
      await dataSource.initialize();
    });

    tearDown(() async {
      await dataSource.dispose();
      await ConnectionPoolHolder.dispose();

      final dbFile = File(testDbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
    });

    test('should find images by file name even when metadata is absent',
        () async {
      final now = DateTime.now();
      final imageId = await dataSource.upsertImage(
        filePath: '/test/special_character_pose.png',
        fileName: 'special_character_pose.png',
        fileSize: 2048,
        createdAt: now,
        modifiedAt: now,
      );

      final result = await dataSource.advancedSearch(
        textQuery: 'special_character',
        limit: 10,
      );

      expect(result, contains(imageId));
    });

    test('should support prompt queries that use comma separators', () async {
      final now = DateTime.now();
      final imageId = await dataSource.upsertImage(
        filePath: '/test/comma_query.png',
        fileName: 'comma_query.png',
        fileSize: 1024,
        createdAt: now,
        modifiedAt: now,
      );

      await dataSource.upsertMetadata(
        imageId,
        const NaiImageMetadata(
          prompt: '1girl solo blue_eyes',
          negativePrompt: '',
          seed: 1,
        ),
      );

      final result = await dataSource.searchFullText('1girl,solo', limit: 10);

      expect(result, contains(imageId));
    });

    test(
        'should refresh cached search results after metadata indexing updates the same tag query',
        () async {
      final now = DateTime.now();
      final file = File('/test/cache_refresh.png');
      final imageId = await dataSource.upsertImage(
        filePath: file.path,
        fileName: 'cache_refresh.png',
        fileSize: 1024,
        createdAt: now,
        modifiedAt: now,
      );

      final filterService = GalleryFilterService(dataSource);

      final initialBareSearch = await filterService.applyFilters(
        [file],
        const FilterCriteria(searchQuery: 'shycocoa'),
      );

      expect(initialBareSearch.files, isEmpty);

      await dataSource.upsertMetadata(
        imageId,
        const NaiImageMetadata(
          prompt: 'artist:shycocoa, 1girl, solo',
          negativePrompt: '',
          seed: 1,
        ),
      );

      final prefixedSearch = await filterService.applyFilters(
        [file],
        const FilterCriteria(searchQuery: 'artist:shycocoa'),
      );
      final bareSearch = await filterService.applyFilters(
        [file],
        const FilterCriteria(searchQuery: 'shycocoa'),
      );

      expect(
          prefixedSearch.files.map((item) => item.path), contains(file.path),);
      expect(bareSearch.files.map((item) => item.path), contains(file.path));
      expect(bareSearch.files.length, equals(prefixedSearch.files.length));
    });

    test('should not truncate local gallery search results at 10000 items',
        () async {
      const totalImages = 10005;
      final now = DateTime.now();
      final imageRecords = List.generate(
        totalImages,
        (index) => GalleryImageRecord(
          filePath: '/test/search_limit_$index.png',
          fileName: 'search_limit_$index.png',
          fileSize: 1024 + index,
          createdAt: now,
          modifiedAt: now,
          indexedAt: now,
          dateYmd: 20260421,
        ),
      );

      final imageIds = await dataSource.batchUpsertImages(imageRecords);
      expect(imageIds.length, equals(totalImages));

      await dataSource.batchUpsertMetadata([
        for (var i = 0; i < imageIds.length; i++)
          MapEntry(
            imageIds[i],
            NaiImageMetadata(
              prompt: 'common search prompt $i',
              negativePrompt: '',
              seed: i,
            ),
          ),
      ]);

      final filterService = GalleryFilterService(dataSource);
      final result = await filterService.applyFilters(
        [
          for (final record in imageRecords) File(record.filePath),
        ],
        const FilterCriteria(searchQuery: 'common'),
      );

      expect(result.files.length, equals(totalImages));
    });
  });
}
