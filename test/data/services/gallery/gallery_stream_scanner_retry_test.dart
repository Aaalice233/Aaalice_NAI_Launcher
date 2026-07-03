import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nai_launcher/core/database/connection_pool_holder.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/services/gallery/gallery_stream_scanner.dart'
    show ExistingFileCacheEntry, GalleryStreamScanner, buildRetryPriorityPaths;
import 'package:nai_launcher/data/services/image_metadata_service.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

void main() {
  group('GalleryStreamScanner retryMissingMetadata', () {
    late GalleryDataSource dataSource;
    late Directory tempDir;
    late String testDbPath;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await AppLogger.initialize(isTestEnvironment: true);
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'gallery_stream_scanner_retry_',
      );
      testDbPath = p.join(tempDir.path, 'gallery_retry.db');
      final hivePath = p.join(tempDir.path, 'hive');
      await Directory(hivePath).create(recursive: true);
      Hive.init(hivePath);

      await ConnectionPoolHolder.initialize(
        dbPath: testDbPath,
        maxConnections: 2,
      );

      dataSource = GalleryDataSource();
      await dataSource.initialize();
      await ImageMetadataService().initialize();
      GalleryStreamScanner.resetInstance();
    });

    tearDown(() async {
      GalleryStreamScanner.resetInstance();
      await Hive.close();
      await dataSource.dispose();
      await ConnectionPoolHolder.dispose();

      if (await tempDir.exists()) {
        await _deleteDirectoryWithRetry(tempDir);
      }
    });

    test('should skip stale none records during default incremental scan',
        () async {
      final file = await _createWrappedNovelAiPng(
        tempDir,
        'stale_skip.png',
        prompt: 'artist:shycocoa, 1girl, solo',
      );

      final imageId = await _seedStaleNoneRecord(dataSource, file);
      final scanner = GalleryStreamScanner(dataSource: dataSource);

      await scanner.startScanning(tempDir);

      final imageRecord = await dataSource.getImageById(imageId);
      final metadata =
          (await dataSource.getMetadataByImageIds([imageId]))[imageId];
      final results = await dataSource.advancedSearch(
        textQuery: 'shycocoa',
        limit: 10,
      );

      expect(imageRecord, isNotNull);
      expect(imageRecord!.metadataStatus, MetadataStatus.none);
      expect(metadata, isNull);
      expect(results, isNot(contains(imageId)));
    });

    test('should retry stale none records when retryMissingMetadata is enabled',
        () async {
      final file = await _createWrappedNovelAiPng(
        tempDir,
        'stale_retry.png',
        prompt: 'artist:shycocoa, 1girl, solo',
      );

      final imageId = await _seedStaleNoneRecord(dataSource, file);
      final scanner = GalleryStreamScanner(dataSource: dataSource);

      await scanner.startScanning(
        tempDir,
        retryMissingMetadata: true,
      );

      final imageRecord = await dataSource.getImageById(imageId);
      final metadata =
          (await dataSource.getMetadataByImageIds([imageId]))[imageId];
      final results = await dataSource.advancedSearch(
        textQuery: 'shycocoa',
        limit: 10,
      );

      expect(imageRecord, isNotNull);
      expect(imageRecord!.metadataStatus, MetadataStatus.success);
      expect(metadata, isNotNull);
      expect(metadata!.prompt, contains('artist:shycocoa'));
      expect(results, contains(imageId));
    });

    test(
        'should mark stale none records as failed when retry finds no metadata',
        () async {
      final file = File(p.join(tempDir.path, 'stale_failed.png'));
      await file.writeAsBytes(_buildBasePngBytes());

      final imageId = await _seedStaleNoneRecord(dataSource, file);
      final scanner = GalleryStreamScanner(dataSource: dataSource);

      await scanner.startScanning(
        tempDir,
        retryMissingMetadata: true,
      );

      final imageRecord = await dataSource.getImageById(imageId);
      final metadata =
          (await dataSource.getMetadataByImageIds([imageId]))[imageId];

      expect(imageRecord, isNotNull);
      expect(imageRecord!.metadataStatus, MetadataStatus.failed);
      expect(metadata, isNull);
    });

    test('should prioritize missing metadata records before normal scan order',
        () async {
      final oldNoneTime = DateTime(2026, 1, 1);
      final newNoneTime = DateTime(2026, 2, 1);
      final failedTime = DateTime(2026, 3, 1);

      final entries = <String, ExistingFileCacheEntry>{
        '/gallery/success.png': (
          1,
          1,
          1,
          MetadataStatus.success,
          DateTime(2026, 4, 1),
        ),
        '/gallery/new_none.png': (
          1,
          1,
          2,
          MetadataStatus.none,
          newNoneTime,
        ),
        '/gallery/old_none.png': (
          1,
          1,
          3,
          MetadataStatus.none,
          oldNoneTime,
        ),
        '/gallery/failed.png': (
          1,
          1,
          4,
          MetadataStatus.failed,
          failedTime,
        ),
      };

      expect(
        buildRetryPriorityPaths(
          entries,
          retryMissingMetadata: true,
          retryFailedMetadata: false,
        ),
        ['/gallery/old_none.png', '/gallery/new_none.png'],
      );

      expect(
        buildRetryPriorityPaths(
          entries,
          retryMissingMetadata: false,
          retryFailedMetadata: true,
        ),
        ['/gallery/failed.png'],
      );

      expect(
        buildRetryPriorityPaths(
          entries,
          retryMissingMetadata: true,
          retryFailedMetadata: true,
        ),
        [
          '/gallery/old_none.png',
          '/gallery/new_none.png',
          '/gallery/failed.png',
        ],
      );
    });
  });
}

Future<int> _seedStaleNoneRecord(
  GalleryDataSource dataSource,
  File file,
) async {
  final stat = await file.stat();
  return dataSource.upsertImage(
    filePath: file.path,
    fileName: file.uri.pathSegments.last,
    fileSize: stat.size,
    createdAt: stat.modified,
    modifiedAt: stat.modified,
    metadataStatus: MetadataStatus.none,
    lastScannedAt: DateTime.now(),
  );
}

Future<File> _createWrappedNovelAiPng(
  Directory dir,
  String fileName, {
  required String prompt,
}) async {
  final innerComment = jsonEncode({
    'prompt': prompt,
    'uc': 'lowres, blurry',
    'seed': 42,
    'sampler': 'k_euler',
    'steps': 28,
    'scale': 6.5,
    'width': 64,
    'height': 64,
    'version': 1,
  });

  final outerComment = jsonEncode({
    'Description': prompt,
    'Software': 'NovelAI',
    'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
    'Comment': innerComment,
  });

  var bytes = _buildBasePngBytes();
  bytes = UnifiedMetadataParser.embedTextChunkOnly(
    bytes,
    'Title',
    'NovelAI generated image',
  );
  bytes = UnifiedMetadataParser.embedTextChunkOnly(
    bytes,
    'Description',
    prompt,
  );
  bytes = UnifiedMetadataParser.embedTextChunkOnly(
    bytes,
    'Software',
    'NovelAI',
  );
  bytes = UnifiedMetadataParser.embedTextChunkOnly(
    bytes,
    'Source',
    'NovelAI Diffusion V4.5 4BDE2A90',
  );
  bytes = UnifiedMetadataParser.embedTextChunkOnly(
    bytes,
    'Comment',
    outerComment,
  );

  final file = File(p.join(dir.path, fileName));
  await file.writeAsBytes(bytes);
  return file;
}

Uint8List _buildBasePngBytes() {
  final image = img.Image(width: 4, height: 4);
  img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));
  return Uint8List.fromList(img.encodePng(image));
}

Future<void> _deleteDirectoryWithRetry(
  Directory dir, {
  int maxAttempts = 5,
}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await dir.delete(recursive: true);
      return;
    } on PathAccessException {
      if (attempt == maxAttempts) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
