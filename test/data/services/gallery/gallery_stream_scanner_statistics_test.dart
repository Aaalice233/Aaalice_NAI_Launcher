import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nai_launcher/core/cache/gallery_cache_manager.dart';
import 'package:nai_launcher/core/database/connection_pool_holder.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/services/gallery/gallery_stream_scanner.dart';
import 'package:nai_launcher/data/services/metadata/isolate_metadata_service.dart';

void main() {
  final manager = GalleryCacheManager();
  late GalleryDataSource dataSource;
  late IsolateMetadataService metadataService;
  late GalleryStreamScanner scanner;
  late Directory tempDir;
  late Directory galleryDir;
  late int computeCount;
  late int invalidations;

  void countInvalidation() => invalidations++;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppLogger.initialize(isTestEnvironment: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'gallery_stream_scanner_statistics_',
    );
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

    computeCount = 0;
    invalidations = 0;
    manager.debugSetStatisticsComputerForTesting(() async {
      computeCount++;
      return CacheStatistics(
        l1MemorySize: 0,
        l1HitRate: 0,
        l1MemoryBytes: 0,
        l2HiveSize: 0,
        l2HitRate: 0,
        l2HiveBytes: 0,
        l3DatabaseImageCount: await dataSource.countImages(),
        l3DatabaseMetadataCount: 0,
        totalHitRate: 0,
        lastUpdated: DateTime(2026),
      );
    });
    manager.registerOnStatisticsInvalidated(countInvalidation);
  });

  tearDown(() async {
    manager.unregisterOnStatisticsInvalidated(countInvalidation);
    manager.debugSetStatisticsComputerForTesting(null);
    await scanner.dispose();
    metadataService.dispose();
    await dataSource.dispose();
    await Hive.close();
    await ConnectionPoolHolder.dispose();
    await _deleteDirectoryWithRetry(tempDir);
  });

  test('一轮扫描写入多个新文件后只失效一次，之后不再命中旧缓存', () async {
    expect((await manager.getStatistics()).l3DatabaseImageCount, 0);
    await manager.getStatistics();
    expect(computeCount, 1);

    // 尺寸不同：扫描器按“大小+修改时间”识别移动，同签名会被当成同一张图
    await _writePng(galleryDir, 'a.png', size: 2);
    await _writePng(galleryDir, 'b.png', size: 3);
    await scanner.startScanning(galleryDir);

    expect(invalidations, 1);
    final after = await manager.getStatistics();
    expect(computeCount, 2);
    expect(after.l3DatabaseImageCount, 2);

    await scanner.startScanning(galleryDir);

    expect(invalidations, 1);
  });

  test('扫描把消失的文件标记删除后失效一次', () async {
    for (final name in ['gone_a.png', 'gone_b.png']) {
      await dataSource.upsertImage(
        filePath: p.join(galleryDir.path, name),
        fileName: name,
        fileSize: 1,
        createdAt: DateTime(2026),
        modifiedAt: DateTime(2026),
      );
    }
    expect((await manager.getStatistics()).l3DatabaseImageCount, 2);

    await scanner.startScanning(galleryDir);

    expect(invalidations, 1);
    expect((await manager.getStatistics()).l3DatabaseImageCount, 0);
  });
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
