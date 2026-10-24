import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';

import '../../../helpers/gallery_database_sandbox.dart';

const _path = 'gallery/probe.png';
const _metadata = NaiImageMetadata(
  prompt: '1girl, lighthouse keeper',
  width: 832,
  height: 1216,
);

void main() {
  final sandbox = useGalleryDatabaseSandbox('gallery_upsert_with_metadata_');
  final scannedAt = DateTime(2026, 10, 24, 12);

  Future<int> write({
    NaiImageMetadata? metadata = _metadata,
    MetadataStatus statusWithoutMetadata = MetadataStatus.failed,
  }) {
    return sandbox.dataSource.upsertImageWithMetadata(
      filePath: _path,
      fileName: 'probe.png',
      fileSize: 1,
      createdAt: DateTime(2026),
      modifiedAt: DateTime(2026),
      metadata: metadata,
      statusWithoutMetadata: statusWithoutMetadata,
      lastScannedAt: scannedAt,
    );
  }

  Future<GalleryMetadataRecord?> storedMetadata(int imageId) async =>
      (await sandbox.dataSource.getMetadataByImageIds([imageId]))[imageId];

  test('marks the row success once its metadata is stored', () async {
    final imageId = await write();

    final image = await sandbox.dataSource.getImageById(imageId);
    expect(image?.metadataStatus, MetadataStatus.success);
    expect(image?.lastScannedAt, scannedAt);
    expect(image?.width, 832);
    expect(image?.height, 1216);
    expect(image?.aspectRatio, closeTo(832 / 1216, 1e-9));
    expect(image?.resolutionKey, '832x1216');
    expect((await storedMetadata(imageId))?.prompt, _metadata.prompt);
    expect(await sandbox.dataSource.advancedSearch(textQuery: 'lighthouse'), [
      imageId,
    ]);
  });

  test('a rejected metadata write leaves the row retryable', () async {
    await sandbox.rejectMetadataWrites();

    await expectLater(write(), throwsA(anything));

    final imageId = await sandbox.dataSource.getImageIdByPath(_path);
    expect(imageId, isNotNull);
    final image = await sandbox.dataSource.getImageById(imageId!);
    expect(image?.metadataStatus, MetadataStatus.transientFailure);
    expect(image?.lastScannedAt, scannedAt);
    expect(await storedMetadata(imageId), isNull);
  });

  test('rewriting after a rejected write completes the same row', () async {
    await sandbox.rejectMetadataWrites();
    await expectLater(write(), throwsA(anything));
    final failedId = await sandbox.dataSource.getImageIdByPath(_path);
    await sandbox.allowMetadataWrites();

    final imageId = await write();

    expect(imageId, failedId);
    final image = await sandbox.dataSource.getImageById(imageId);
    expect(image?.metadataStatus, MetadataStatus.success);
    expect((await storedMetadata(imageId))?.prompt, _metadata.prompt);
  });

  test('records the caller status when there is no metadata', () async {
    for (final metadata in const [null, NaiImageMetadata(width: 64)]) {
      final imageId = await write(
        metadata: metadata,
        statusWithoutMetadata: MetadataStatus.transientFailure,
      );

      final image = await sandbox.dataSource.getImageById(imageId);
      expect(image?.metadataStatus, MetadataStatus.transientFailure);
      expect(image?.width, metadata?.width);
      expect(await storedMetadata(imageId), isNull);
    }
  });

  test('refuses to claim success without metadata', () async {
    await expectLater(
      write(metadata: null, statusWithoutMetadata: MetadataStatus.success),
      throwsArgumentError,
    );

    expect(await sandbox.dataSource.getImageIdByPath(_path), isNull);
  });
}
