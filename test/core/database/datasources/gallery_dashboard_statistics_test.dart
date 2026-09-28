import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/connection_pool_holder.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDirectory;
  late GalleryDataSource dataSource;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppLogger.initialize(isTestEnvironment: true);
  });

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'gallery_dashboard_statistics_',
    );
    await ConnectionPoolHolder.initialize(
      dbPath: '${tempDirectory.path}/gallery.db',
      maxConnections: 2,
    );
    dataSource = GalleryDataSource();
    await dataSource.initialize();
  });

  tearDown(() async {
    await dataSource.dispose();
    await ConnectionPoolHolder.dispose();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'aggregates active images without materializing large metadata',
    () async {
      final monday = DateTime(2026, 7, 27, 10, 15);
      final tuesday = DateTime(2026, 7, 28, 15, 30);
      final wednesday = DateTime(2026, 7, 29, 20, 45);
      final largeMetadata = List.filled(512 * 1024, 'x').join();

      final firstId = await dataSource.upsertImage(
        filePath: '/test/first.png',
        fileName: 'first.png',
        fileSize: 512 * 1024,
        width: 512,
        height: 768,
        createdAt: monday,
        modifiedAt: monday,
      );
      await dataSource.upsertMetadata(
        firstId,
        NaiImageMetadata(
          prompt: 'first',
          negativePrompt: '',
          sampler: 'k_euler',
          width: 512,
          height: 768,
          model: 'model-a',
          rawJson: largeMetadata,
        ),
      );
      await dataSource.toggleFavorite(firstId);
      await dataSource.setImageTags(firstId, const ['landscape']);

      final secondId = await dataSource.upsertImage(
        filePath: '/test/second.png',
        fileName: 'second.png',
        fileSize: 1536 * 1024,
        width: 1024,
        height: 1024,
        createdAt: tuesday,
        modifiedAt: tuesday,
      );
      await dataSource.upsertMetadata(
        secondId,
        const NaiImageMetadata(
          prompt: 'second',
          negativePrompt: '',
          sampler: 'k_euler_ancestral',
          width: 1024,
          height: 1024,
          model: 'model-a',
        ),
      );

      await dataSource.upsertImage(
        filePath: '/test/third.png',
        fileName: 'third.png',
        fileSize: 12 * 1024 * 1024,
        createdAt: wednesday,
        modifiedAt: wednesday,
      );

      final deletedId = await dataSource.upsertImage(
        filePath: '/test/deleted.png',
        fileName: 'deleted.png',
        fileSize: 64 * 1024 * 1024,
        width: 2048,
        height: 2048,
        createdAt: monday,
        modifiedAt: monday,
      );
      await dataSource.upsertMetadata(
        deletedId,
        const NaiImageMetadata(
          prompt: 'deleted',
          negativePrompt: '',
          sampler: 'ddim',
          width: 2048,
          height: 2048,
          model: 'deleted-model',
        ),
      );
      await dataSource.markAsDeleted('/test/deleted.png');

      final snapshot = await dataSource.getDashboardStatistics();

      expect(snapshot.totalImages, 3);
      expect(snapshot.totalSizeBytes, 14 * 1024 * 1024);
      expect(snapshot.favoriteCount, 1);
      expect(snapshot.taggedImageCount, 1);
      expect(snapshot.imagesWithMetadata, 2);
      expect(snapshot.resolutionCounts, {'512x768': 1, '1024x1024': 1});
      expect(snapshot.modelCounts, {'model-a': 2});
      expect(snapshot.samplerCounts, {'k_euler': 1, 'k_euler_ancestral': 1});
      expect(snapshot.sizeCounts, {'< 1 MB': 1, '1-2 MB': 1, '> 10 MB': 1});
      expect(snapshot.tagCounts, {'landscape': 1});
      expect(snapshot.dailyCounts, {20260727: 1, 20260728: 1, 20260729: 1});
      expect(snapshot.hourlyCounts, {10: 1, 15: 1, 20: 1});
      expect(snapshot.weekdayCounts, {
        DateTime.monday: 1,
        DateTime.tuesday: 1,
        DateTime.wednesday: 1,
      });
    },
  );
}
