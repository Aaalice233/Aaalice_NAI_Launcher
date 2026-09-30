import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nai_launcher/core/database/connection_pool_holder.dart';
import 'package:nai_launcher/core/database/database_manager.dart';
import 'package:nai_launcher/core/database/database_providers.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/models/gallery/gallery_statistics.dart';
import 'package:nai_launcher/data/services/gallery/gallery_stream_scanner.dart';
import 'package:nai_launcher/data/services/metadata/isolate_metadata_service.dart';
import 'package:nai_launcher/data/services/statistics_cache_service.dart';
import 'package:nai_launcher/presentation/screens/statistics/statistics_state.dart';

class _MockDatabaseManager extends Mock implements DatabaseManager {}

class _MockStatisticsCacheService extends Mock
    implements StatisticsCacheService {}

void main() {
  late GalleryDataSource dataSource;
  late IsolateMetadataService metadataService;
  late GalleryStreamScanner scanner;
  late Directory tempDir;
  late Directory galleryDir;
  late ProviderContainer container;

  int totalImages() =>
      container.read(statisticsNotifierProvider).statistics!.totalImages;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppLogger.initialize(isTestEnvironment: true);
    registerFallbackValue(
      GalleryStatistics(
        totalImages: 0,
        totalSizeBytes: 0,
        averageFileSizeBytes: 0,
        calculatedAt: DateTime(2026),
      ),
    );
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('statistics_scan_refresh_');
    galleryDir = await Directory(p.join(tempDir.path, 'gallery')).create();
    final hivePath = p.join(tempDir.path, 'hive');
    await Directory(hivePath).create(recursive: true);
    Hive.init(hivePath);
    await ConnectionPoolHolder.initialize(
      dbPath: p.join(tempDir.path, 'gallery.db'),
      maxConnections: 2,
    );
    dataSource = GalleryDataSource();
    await dataSource.initialize();
    metadataService = IsolateMetadataService.forTesting();
    scanner = GalleryStreamScanner.forTesting(
      dataSource: dataSource,
      metadataService: metadataService,
    );

    final databaseManager = _MockDatabaseManager();
    when(
      () => databaseManager.getDataSource<GalleryDataSource>('gallery'),
    ).thenReturn(dataSource);
    final statisticsCache = _MockStatisticsCacheService();
    when(statisticsCache.getCache).thenReturn(null);
    when(() => statisticsCache.isCacheValid(any())).thenReturn(false);
    when(
      () => statisticsCache.saveCache(any(), any()),
    ).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        databaseManagerProvider.overrideWith((ref) async => databaseManager),
        statisticsCacheServiceProvider.overrideWithValue(statisticsCache),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await scanner.dispose();
    metadataService.dispose();
    await dataSource.dispose();
    await Hive.close();
    await ConnectionPoolHolder.dispose();
    await _deleteDirectoryWithRetry(tempDir);
  });

  // One test on purpose: ScanStateManager is a process-wide singleton whose
  // Hive box would outlive the per-test Hive.close() between two tests.
  test(
    'scans refresh the open statistics and leave closed ones stale',
    () async {
      final notifier = container.read(statisticsNotifierProvider.notifier);
      await notifier.whenLoaded();
      expect(totalImages(), 0);

      // Page closed: the scan is only remembered.
      await _writePng(galleryDir, 'a.png', size: 2);
      await scanner.startScanning(galleryDir);
      await Future<void>.delayed(StatisticsNotifier.galleryChangeDebounce * 2);
      expect(totalImages(), 0);
      await notifier.whenLoaded();
      expect(totalImages(), 1);

      // Page open: the scan refreshes by itself after the debounce.
      final page = container.listen(statisticsNotifierProvider, (_, _) {});
      addTearDown(page.close);
      await _writePng(galleryDir, 'b.png', size: 3);
      await scanner.startScanning(galleryDir);
      expect(totalImages(), 1, reason: 'the reload waits out the debounce');
      await _waitUntil(() => totalImages() == 2);
    },
  );
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition not met in time');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<void> _writePng(Directory dir, String name, {required int size}) async {
  final image = img.Image(width: size, height: size);
  await File(p.join(dir.path, name)).writeAsBytes(img.encodePng(image));
}

Future<void> _deleteDirectoryWithRetry(Directory dir) async {
  for (var attempt = 1; attempt <= 5; attempt++) {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
      return;
    } on PathAccessException {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
