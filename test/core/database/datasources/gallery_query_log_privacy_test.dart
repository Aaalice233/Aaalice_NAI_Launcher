import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/connection_pool_holder.dart';
import 'package:nai_launcher/core/database/datasources/gallery_tables.dart';

import '../../../helpers/gallery_database_sandbox.dart';
import '../../../helpers/log_capture.dart';

const _query = 'secret lighthouse keeper';

void main() {
  final sandbox = useGalleryDatabaseSandbox('gallery_query_log_privacy_');

  test('failed searches never quote the search text into the log', () async {
    final pool = ConnectionPoolHolder.instance;
    final db = await pool.acquire();
    try {
      await db.execute('''
        DROP TABLE ${GalleryTables.ftsIndex};
        ALTER TABLE ${GalleryTables.images} RENAME TO probe_images;
      ''');
    } finally {
      await pool.release(db);
    }

    final logs = await captureLogs(() async {
      final dataSource = sandbox.dataSource;
      expect(await dataSource.searchFullText(_query), isEmpty);
      expect(await dataSource.searchByFileName(_query), isEmpty);
      expect(await dataSource.searchByMetadataText(_query), isEmpty);
      expect(
        await dataSource.searchByDelimitedTextSegments([_query]),
        isEmpty,
      );
    });

    expect(logs.where((line) => line.contains('Failed to search')), hasLength(4));
    expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
  });
}
