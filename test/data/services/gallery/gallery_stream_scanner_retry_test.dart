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
    show
        ExistingFileCacheEntry,
        GalleryStreamScanner,
        StreamScanStats,
        buildRetryPriorityPaths;
import 'package:nai_launcher/data/services/gallery/local_gallery_repository.dart';
import 'package:nai_launcher/data/services/image_metadata_service.dart';
import 'package:nai_launcher/data/services/metadata/isolate_metadata_service.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../../helpers/webp_metadata_fixture.dart';

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
      IsolateMetadataService.instance.dispose();
      GalleryStreamScanner.resetInstance();
    });

    tearDown(() async {
      GalleryStreamScanner.resetInstance();
      IsolateMetadataService.instance.dispose();
      await Hive.close();
      await dataSource.dispose();
      await ConnectionPoolHolder.dispose();

      if (await tempDir.exists()) {
        await _deleteDirectoryWithRetry(tempDir);
      }
    });

    test(
      'retry scan indexes NovelAI tags from stale unparsed records',
      () async {
        final file = await _createWrappedNovelAiPng(
          tempDir,
          'evil_neuro_sama.png',
          prompt: '1girl, evil_neuro-sama, solo',
        );

        final imageId = await _seedStaleNoneRecord(dataSource, file);
        final scanner = GalleryStreamScanner.instance(dataSource: dataSource);

        await scanner.startScanning(tempDir, retryMissingMetadata: true);

        final imageRecord = await dataSource.getImageById(imageId);
        final metadata = (await dataSource.getMetadataByImageIds([
          imageId,
        ]))[imageId];

        expect(imageRecord, isNotNull);
        expect(imageRecord!.metadataStatus, MetadataStatus.success);
        expect(metadata?.prompt, contains('evil_neuro-sama'));
        for (final query in const [
          'evil_neuro-sama',
          'EVIL_NEURO-SAMA',
          'evil neuro-sama',
          'evil-neuro-sama',
        ]) {
          final results = await dataSource.advancedSearch(
            textQuery: query,
            limit: 10,
          );
          expect(results, contains(imageId), reason: 'query=$query');
        }
      },
    );

    test('immediate gallery add parses and indexes NovelAI tags', () async {
      final file = await _createWrappedNovelAiPng(
        tempDir,
        'immediate_add.png',
        prompt: '1girl, evil_neuro-sama, solo',
      );
      final repository = LocalGalleryRepository(dataSource: dataSource);

      await repository.addImage(file);

      final imageId = await dataSource.getImageIdByPath(file.path);
      expect(imageId, isNotNull);
      final imageRecord = await dataSource.getImageById(imageId!);
      final metadata = (await dataSource.getMetadataByImageIds([
        imageId,
      ]))[imageId];
      final results = await dataSource.advancedSearch(
        textQuery: 'evil_neuro-sama',
        limit: 10,
      );

      expect(imageRecord?.metadataStatus, MetadataStatus.success);
      expect(metadata?.prompt, contains('evil_neuro-sama'));
      expect(results, contains(imageId));
    });

    test('can explicitly skip stale unparsed records', () async {
      final file = await _createWrappedNovelAiPng(
        tempDir,
        'stale_skip.png',
        prompt: 'artist:shycocoa, 1girl, solo',
      );

      final imageId = await _seedStaleNoneRecord(dataSource, file);
      final scanner = GalleryStreamScanner.instance(dataSource: dataSource);

      await scanner.startScanning(tempDir, retryMissingMetadata: false);

      final imageRecord = await dataSource.getImageById(imageId);
      final metadata = (await dataSource.getMetadataByImageIds([
        imageId,
      ]))[imageId];
      final results = await dataSource.advancedSearch(
        textQuery: 'shycocoa',
        limit: 10,
      );

      expect(imageRecord?.metadataStatus, MetadataStatus.none);
      expect(metadata, isNull);
      expect(results, isNot(contains(imageId)));
    });

    test(
      'should mark stale none records as failed when retry finds no metadata',
      () async {
        final file = File(p.join(tempDir.path, 'stale_failed.png'));
        await file.writeAsBytes(_buildBasePngBytes());

        final imageId = await _seedStaleNoneRecord(dataSource, file);
        final scanner = GalleryStreamScanner.instance(dataSource: dataSource);

        await scanner.startScanning(tempDir, retryMissingMetadata: true);

        final imageRecord = await dataSource.getImageById(imageId);
        final metadata = (await dataSource.getMetadataByImageIds([
          imageId,
        ]))[imageId];

        expect(imageRecord, isNotNull);
        expect(imageRecord!.metadataStatus, MetadataStatus.failed);
        expect(metadata, isNull);
      },
    );

    test(
      'should prioritize missing metadata records before normal scan order',
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
          '/gallery/new_none.png': (1, 1, 2, MetadataStatus.none, newNoneTime),
          '/gallery/old_none.png': (1, 1, 3, MetadataStatus.none, oldNoneTime),
          '/gallery/failed.png': (1, 1, 4, MetadataStatus.failed, failedTime),
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

        expect(
          buildRetryPriorityPaths(
            {
              '/gallery/transient.png': (
                1,
                1,
                5,
                MetadataStatus.transientFailure,
                DateTime(2026, 5, 1),
              ),
            },
            retryMissingMetadata: false,
            retryFailedMetadata: false,
          ),
          ['/gallery/transient.png'],
        );
      },
    );

    test(
      'ordinary scans retry metadata after a temporary worker outage',
      () async {
        final file = await _createWrappedNovelAiPng(
          tempDir,
          'transient_worker.png',
          prompt: 'artist:retryable, 1girl',
        );
        var startupCalls = 0;
        final metadataService = IsolateMetadataService.forTesting(
          workerInitializer: (_, initializeWorker) async {
            startupCalls++;
            if (startupCalls == 1) {
              throw StateError('temporary spawn failure');
            }
            await initializeWorker();
          },
        );
        addTearDown(metadataService.dispose);
        final scanner = GalleryStreamScanner.forTesting(
          dataSource: dataSource,
          metadataService: metadataService,
        );
        addTearDown(scanner.dispose);

        await scanner.startScanning(tempDir);
        final imageId = await dataSource.getImageIdByPath(file.path);
        expect(imageId, isNotNull);
        final storedImageId = imageId!;
        var imageRecord = await dataSource.getImageById(storedImageId);
        expect(imageRecord?.metadataStatus, MetadataStatus.transientFailure);

        await scanner.startScanning(tempDir);
        imageRecord = await dataSource.getImageById(storedImageId);
        final metadata = (await dataSource.getMetadataByImageIds([
          storedImageId,
        ]))[storedImageId];

        expect(imageRecord?.metadataStatus, MetadataStatus.success);
        expect(metadata?.prompt, contains('artist:retryable'));
      },
    );

    test('scanner indexes NovelAI metadata from WebP', () async {
      final file = File(p.join(tempDir.path, 'metadata.webp'));
      await file.writeAsBytes(
        buildNovelAiWebpFixture(
          comment: const {
            'prompt': 'scanner-webp-prompt',
            'uc': 'lowres',
            'width': 832,
            'height': 1216,
            'seed': 42,
            'steps': 28,
            'scale': 5.0,
            'sampler': 'k_euler',
          },
        ),
      );
      final scanner = GalleryStreamScanner.instance(dataSource: dataSource);

      await scanner.startScanning(tempDir, fileSnapshot: [file]);

      final imageId = await dataSource.getImageIdByPath(file.path);
      expect(imageId, isNotNull);
      final storedImageId = imageId!;
      final image = await dataSource.getImageById(storedImageId);
      final metadata = (await dataSource.getMetadataByImageIds([
        storedImageId,
      ]))[storedImageId];
      expect(image?.metadataStatus, MetadataStatus.success);
      expect(metadata?.prompt, 'scanner-webp-prompt');
    });

    test(
      'file-system changes cannot change a running snapshot total',
      () async {
        final first = await _createWrappedNovelAiPng(
          tempDir,
          'snapshot_a.png',
          prompt: 'snapshot-a',
        );
        final deleted = await _createWrappedNovelAiPng(
          tempDir,
          'snapshot_b.png',
          prompt: 'snapshot-b',
        );
        final added = File(p.join(tempDir.path, 'snapshot_added.png'));
        final callerOwnedSnapshot = <File>[first, deleted];
        final observedStats = <StreamScanStats>[];
        final scanner = GalleryStreamScanner.instance(dataSource: dataSource);

        await scanner.startScanning(
          tempDir,
          fileSnapshot: callerOwnedSnapshot,
          onFileProcessed: (_, stats) {
            observedStats.add(stats);
            if (observedStats.length == 1) {
              callerOwnedSnapshot
                ..clear()
                ..add(added);
              deleted.deleteSync();
              added.writeAsBytesSync(_buildBasePngBytes());
            }
          },
        );

        expect(observedStats, hasLength(2));
        expect(
          observedStats.every((stats) => stats.totalDiscovered == 2),
          isTrue,
        );
        expect(observedStats.last.processed + observedStats.last.skipped, 2);
        expect(observedStats.last.progress, 1);
        expect(observedStats.every((stats) => stats.progress <= 1), isTrue);
        expect(await dataSource.getImageIdByPath(added.path), isNull);
      },
    );

    test('priority paths outside the snapshot are never injected', () async {
      final included = await _createWrappedNovelAiPng(
        tempDir,
        'snapshot_included.png',
        prompt: 'included',
      );
      final externalDir = await Directory.systemTemp.createTemp(
        'gallery_priority_external_',
      );
      addTearDown(() => _deleteDirectoryWithRetry(externalDir));
      final external = await _createWrappedNovelAiPng(
        externalDir,
        'external_retry.png',
        prompt: 'external',
      );
      await external.setLastModified(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      final externalId = await _seedStaleNoneRecord(dataSource, external);
      final processedPaths = <String>[];
      final scanner = GalleryStreamScanner.instance(dataSource: dataSource);

      await scanner.startScanning(
        tempDir,
        retryMissingMetadata: true,
        fileSnapshot: [included],
        onFileProcessed: (result, stats) {
          processedPaths.add(result.path);
          expect(stats.totalDiscovered, 1);
          expect(stats.progress, lessThanOrEqualTo(1));
        },
      );

      expect(processedPaths, [p.absolute(included.path)]);
      final externalRecord = await dataSource.getImageById(externalId);
      expect(externalRecord?.metadataStatus, MetadataStatus.none);
    });

    test('snapshot and scanning share the gallery file policy', () async {
      final cacheDir = Directory(p.join(tempDir.path, 'cache'));
      await cacheDir.create();
      final excluded = await _createWrappedNovelAiPng(
        cacheDir,
        'excluded_retry.png',
        prompt: 'excluded',
      );
      final included = await _createWrappedNovelAiPng(
        tempDir,
        'included.png',
        prompt: 'included',
      );
      await excluded.setLastModified(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      await _seedStaleNoneRecord(dataSource, excluded);

      final scanner = GalleryStreamScanner.instance(dataSource: dataSource);
      final progressValues = <double>[];
      final subscription = scanner.statsStream.listen(
        (stats) => progressValues.add(stats.progress),
      );
      addTearDown(subscription.cancel);

      await scanner.startScanning(
        tempDir,
        retryMissingMetadata: true,
        fileSnapshot: [included],
      );

      expect(await dataSource.getImageIdByPath(included.path), isNotNull);
      final excludedId = await dataSource.getImageIdByPath(excluded.path);
      final excludedRecord = await dataSource.getImageById(excludedId!);
      expect(excludedRecord?.metadataStatus, MetadataStatus.none);
      expect(progressValues, isNotEmpty);
      expect(
        progressValues.reduce((a, b) => a > b ? a : b),
        lessThanOrEqualTo(1),
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
