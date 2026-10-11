import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/fixed_tag/fixed_tag_usage_record_store.dart';
import 'package:nai_launcher/data/services/gallery/local_gallery_repository.dart';
import 'package:nai_launcher/data/services/image_metadata_service.dart';
import 'package:nai_launcher/data/services/metadata/hash_calculator.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../../helpers/fixed_tag_usage_fixture.dart';

class _MockGalleryDataSource extends Mock implements GalleryDataSource {}

const _imageId = 11;

Map<String, dynamic>? _cachedMetadataJson(String hash) {
  final raw = ImageMetadataService().persistentBox?.get(hash);
  if (raw == null) return null;
  return jsonDecode(raw) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late _MockGalleryDataSource dataSource;
  late LocalGalleryRepository repository;

  setUpAll(() async {
    await AppLogger.initialize(
      isTestEnvironment: true,
      enableFileLogging: false,
    );
    registerFallbackValue(DateTime.utc(2026));
    registerFallbackValue(const NaiImageMetadata());
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('gallery-add-image-');
    Hive.init(directory.path);
    await ImageMetadataService().initialize();

    dataSource = _MockGalleryDataSource();
    when(
      () => dataSource.upsertImage(
        filePath: any(named: 'filePath'),
        fileName: any(named: 'fileName'),
        fileSize: any(named: 'fileSize'),
        width: any(named: 'width'),
        height: any(named: 'height'),
        aspectRatio: any(named: 'aspectRatio'),
        createdAt: any(named: 'createdAt'),
        modifiedAt: any(named: 'modifiedAt'),
        resolutionKey: any(named: 'resolutionKey'),
        lastScannedAt: any(named: 'lastScannedAt'),
        metadataStatus: any(named: 'metadataStatus'),
      ),
    ).thenAnswer((_) async => _imageId);
    when(
      () => dataSource.upsertMetadata(any(), any()),
    ).thenAnswer((_) async {});
    repository = LocalGalleryRepository(dataSource: dataSource);
  });

  tearDown(() async {
    await ImageMetadataService().clearCache();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<(File, String)> writeGalleryImage(String name, String prompt) async {
    final bytes = await novelAiPngBytes(prompt);
    final file = File('${directory.path}/$name');
    await file.writeAsBytes(bytes);
    return (file, FileHashCalculator().calculateFromBytes(bytes));
  }

  test('addImage keeps the recorded snapshot out of the cache', () async {
    final (file, hash) = await writeGalleryImage(
      'recorded.png',
      'from-store, gallery intake',
    );
    await FixedTagUsageRecordStore().record(
      contentHash: hash,
      snapshot: fixedTagUsageSnapshotOf('from-store'),
    );

    await repository.addImage(file);
    await pumpEventQueue();

    final cached = _cachedMetadataJson(hash);
    expect(cached, isNotNull);
    expect(cached!['fixedTagUsageData'], isNull);
    expect(cached['fixedPrefixTags'], isEmpty);
  });

  test('a record replaced after addImage takes effect right away', () async {
    final (file, hash) = await writeGalleryImage(
      'replaced.png',
      'from-store, gallery intake',
    );
    final store = FixedTagUsageRecordStore();
    await store.record(
      contentHash: hash,
      snapshot: fixedTagUsageSnapshotOf('from-store'),
    );
    await repository.addImage(file);

    final restored = fixedTagUsageSnapshotOf('from-cloud');
    await store.applySync(
      snapshots: {restored.fingerprint: restored.toJson()},
      usage: [
        FixedTagUsageRecord(
          contentHash: hash,
          fingerprint: restored.fingerprint,
          recordedAt: DateTime.utc(2026, 9, 22),
        ),
      ],
    );

    expect(
      (await ImageMetadataService().getMetadataImmediate(file.path))
          ?.fixedTagUsageSnapshot
          ?.entries
          .single
          .fixedTagId,
      'from-cloud',
    );

    await store.removeUsage(hash);

    expect(
      (await ImageMetadataService().getMetadataImmediate(
        file.path,
      ))?.fixedTagUsageData,
      isNull,
    );
  });

  test('a snapshot embedded in the png stays cached', () async {
    final bytes = embedFixedTagUsageSnapshot(
      await novelAiPngBytes('from-png, gallery intake'),
      fixedTagUsageSnapshotOf('from-png'),
    );
    final file = File('${directory.path}/embedded.png');
    await file.writeAsBytes(bytes);
    final hash = FileHashCalculator().calculateFromBytes(bytes);
    await FixedTagUsageRecordStore().record(
      contentHash: hash,
      snapshot: fixedTagUsageSnapshotOf('from-store'),
    );

    await repository.addImage(file);

    final cached = _cachedMetadataJson(hash);
    expect(
      NaiImageMetadata.fromJson(
        cached!,
      ).fixedTagUsageSnapshot?.entries.single.fixedTagId,
      'from-png',
    );
    expect(
      (await ImageMetadataService().getMetadataImmediate(file.path))
          ?.fixedTagUsageSnapshot
          ?.entries
          .single
          .fixedTagId,
      'from-png',
    );
  });

  test('caller supplied metadata never reaches the cache', () async {
    final bytes = await novelAiPngBytes('from-store, gallery intake');
    final file = File('${directory.path}/supplied.png');
    await file.writeAsBytes(bytes);
    final hash = FileHashCalculator().calculateFromBytes(bytes);
    await FixedTagUsageRecordStore().record(
      contentHash: hash,
      snapshot: fixedTagUsageSnapshotOf('from-store'),
    );
    final supplied = UnifiedMetadataParser.parseFromPng(
      bytes,
    ).metadata!.withFixedTagUsageData(
      fixedTagUsageSnapshotOf('from-caller').toJson(),
    );

    await repository.addImage(file, metadata: supplied);

    expect(_cachedMetadataJson(hash), isNull);
    expect(
      (await ImageMetadataService().getMetadataImmediate(file.path))
          ?.fixedTagUsageSnapshot
          ?.entries
          .single
          .fixedTagId,
      'from-store',
    );
  });

  test('addImage still indexes the mounted metadata', () async {
    final (file, hash) = await writeGalleryImage(
      'indexed.png',
      'from-store, gallery intake',
    );
    await FixedTagUsageRecordStore().record(
      contentHash: hash,
      snapshot: fixedTagUsageSnapshotOf('from-store'),
    );

    await repository.addImage(file);

    final imageFields = verify(
      () => dataSource.upsertImage(
        filePath: any(named: 'filePath'),
        fileName: any(named: 'fileName'),
        fileSize: any(named: 'fileSize'),
        width: captureAny(named: 'width'),
        height: captureAny(named: 'height'),
        aspectRatio: any(named: 'aspectRatio'),
        createdAt: any(named: 'createdAt'),
        modifiedAt: any(named: 'modifiedAt'),
        resolutionKey: captureAny(named: 'resolutionKey'),
        lastScannedAt: any(named: 'lastScannedAt'),
        metadataStatus: captureAny(named: 'metadataStatus'),
      ),
    ).captured;
    final indexed =
        verify(
              () => dataSource.upsertMetadata(_imageId, captureAny()),
            ).captured.single
            as NaiImageMetadata;

    expect(imageFields, [2, 2, '2x2', MetadataStatus.success]);
    expect(
      indexed.fixedTagUsageSnapshot?.entries.single.fixedTagId,
      'from-store',
    );
    expect(indexed.fixedPrefixTags, ['from-store']);
  });
}
