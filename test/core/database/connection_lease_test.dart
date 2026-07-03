import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/connection_lease.dart';
import 'package:nai_launcher/core/database/connection_pool_holder.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppLogger.initialize(isTestEnvironment: true);
  });

  setUp(() async {
    if (ConnectionPoolHolder.isInitialized) {
      await ConnectionPoolHolder.dispose();
    }
    tempDir = await Directory.systemTemp.createTemp('connection_lease_test_');
  });

  tearDown(() async {
    if (ConnectionPoolHolder.isInitialized) {
      await ConnectionPoolHolder.dispose();
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'dispose returns lease to the pool that issued it after holder reset',
    () async {
      final oldPool = await ConnectionPoolHolder.initialize(
        dbPath: p.join(tempDir.path, 'old.db'),
        maxConnections: 1,
      );

      final lease = await acquireLease(operationId: 'lease-reset-release-test');
      expect(oldPool.inUseCount, 1);

      await ConnectionPoolHolder.reset(
        dbPath: p.join(tempDir.path, 'new.db'),
        maxConnections: 1,
      );

      try {
        expect(oldPool.inUseCount, 1);

        await lease.dispose();

        expect(oldPool.inUseCount, 0);
      } finally {
        if (oldPool.inUseCount > 0) {
          await oldPool.release(lease.connection);
        }
      }
    },
  );

  test(
    'execute treats database is closed errors as invalid connections',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        p.join(tempDir.path, 'lease_error.db'),
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(() async {
        if (db.isOpen) {
          await db.close();
        }
      });

      final lease = ConnectionLease(
        connection: db,
        poolVersion: ConnectionPoolHolder.version,
        releaseConnection: (_) async {},
      );

      await expectLater(
        lease.execute<void>((_) async {
          throw StateError('database is closed');
        }, validateBefore: false),
        throwsA(isA<ConnectionInvalidException>()),
      );
      expect(lease.isValid, isFalse);
    },
  );
}
