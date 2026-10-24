import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/connection_pool_holder.dart';
import 'package:nai_launcher/core/database/datasources/gallery_tables.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';

import '../../../helpers/gallery_database_sandbox.dart';
import '../../../helpers/log_capture.dart';

const _secret = 'secret lighthouse keeper';
const _metadata = NaiImageMetadata(
  prompt: _secret,
  negativePrompt: _secret,
  rawJson: '{"prompt":"$_secret"}',
);

void main() {
  final sandbox = useGalleryDatabaseSandbox('gallery_log_privacy_');

  test('failed metadata write never quotes the prompt into the log', () async {
    final logs = await captureLogs(
      () => expectLater(
        sandbox.dataSource.upsertMetadata(404, _metadata),
        throwsA(anything),
      ),
    );

    expect(logs.where((line) => line.contains('retrying')), isNotEmpty);
    expect(logs.where((line) => line.contains('upsert metadata')), hasLength(1));
    expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
  });

  test('failed FTS write never quotes the prompt into the log', () async {
    final imageId = await sandbox.dataSource.upsertImage(
      filePath: 'probe.png',
      fileName: 'probe.png',
      fileSize: 1,
      createdAt: DateTime(2026),
      modifiedAt: DateTime(2026),
    );
    final pool = ConnectionPoolHolder.instance;
    final db = await pool.acquire();
    try {
      await db.execute('''
        DROP TABLE ${GalleryTables.ftsIndex};
        CREATE TABLE ${GalleryTables.ftsIndex} (
          prompt_text TEXT CHECK (prompt_text IS NULL)
        );
      ''');
    } finally {
      await pool.release(db);
    }

    final logs = await captureLogs(() async {
      await sandbox.dataSource.upsertMetadata(imageId, _metadata);
      await sandbox.dataSource.batchUpsertMetadata([
        MapEntry(imageId, _metadata),
      ]);
    });

    expect(logs.where((line) => line.contains('FTS')), hasLength(2));
    expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
  });
}
