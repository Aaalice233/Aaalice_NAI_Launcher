import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/cooccurrence_sqlite_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/log_capture.dart';

void main() {
  test('query failures never quote the prompt tag into the log', () async {
    sqfliteFfiInit();
    final repository = CooccurrenceSqliteRepository(databaseFactoryFfiNoIsolate);
    addTearDown(repository.close);
    await repository.replaceWith(
      await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath),
    );

    late List<Map<String, Object?>> related;
    final logs = await captureLogs(() async {
      related = await repository.queryRelatedTags(
        'lighthouse',
        limit: 5,
        minCount: 1,
      );
    });

    expect(related, isEmpty);
    expect(
      logs.where((line) => line.contains('Co-occurrence query failed')),
      hasLength(1),
    );
    expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
  });
}
