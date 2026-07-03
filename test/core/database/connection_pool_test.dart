import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/connection_pool.dart';
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
    tempDir = await Directory.systemTemp.createTemp('connection_pool_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('closed pooled connections are replaced on release', () async {
    final pool = ConnectionPool(
      dbPath: p.join(tempDir.path, 'closed_replacement.db'),
      maxConnections: 1,
    );
    addTearDown(pool.dispose);

    await pool.initialize();
    final db = await pool.acquire();
    await db.close();

    await pool.release(db);
    await _waitForCondition(() => pool.availableCount == 1);

    expect(pool.availableCount, 1);
    final replacement = await pool.acquire();
    expect(replacement.isOpen, isTrue);
    await pool.release(replacement);
  });

  test(
    'release schedules closed connection replenishment outside release path',
    () async {
      var createCount = 0;
      final replacementStarted = Completer<void>();
      final replacementCompleter = Completer<Database>();
      final dbPath = p.join(tempDir.path, 'async_replenish.db');
      final pool = ConnectionPool(
        dbPath: dbPath,
        maxConnections: 1,
        connectionFactory: () async {
          createCount++;
          if (createCount == 1) {
            return databaseFactoryFfi.openDatabase(
              dbPath,
              options: OpenDatabaseOptions(singleInstance: false),
            );
          }
          replacementStarted.complete();
          return replacementCompleter.future;
        },
      );
      addTearDown(pool.dispose);

      await pool.initialize();
      final db = await pool.acquire();
      await db.close();

      await pool.release(db).timeout(const Duration(milliseconds: 100));
      await replacementStarted.future.timeout(const Duration(seconds: 1));

      expect(pool.availableCount, 0);
      expect(pool.inUseCount, 0);

      final replacement = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      replacementCompleter.complete(replacement);

      await _waitForCondition(() => pool.availableCount == 1);
    },
  );

  test('release absorbs asynchronous replenishment failures', () async {
    var createCount = 0;
    final dbPath = p.join(tempDir.path, 'failed_replenish.db');
    final pool = ConnectionPool(
      dbPath: dbPath,
      maxConnections: 1,
      connectionFactory: () async {
        createCount++;
        if (createCount == 1) {
          return databaseFactoryFfi.openDatabase(
            dbPath,
            options: OpenDatabaseOptions(singleInstance: false),
          );
        }
        throw StateError('replacement failed');
      },
    );
    addTearDown(pool.dispose);

    await pool.initialize();
    final db = await pool.acquire();
    await db.close();

    await expectLater(pool.release(db), completes);
    await _waitForCondition(() => createCount == 2);

    expect(pool.availableCount, 0);
    expect(pool.inUseCount, 0);
  });

  test(
    'release wakes a pending acquire without creating a temporary connection',
    () async {
      final pool = ConnectionPool(
        dbPath: p.join(tempDir.path, 'waiter_wakeup.db'),
        maxConnections: 1,
      );
      addTearDown(pool.dispose);

      await pool.initialize();
      final first = await pool.acquire();
      var completed = false;
      final pending = pool.acquire().then((db) {
        completed = true;
        return db;
      });

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(completed, isFalse);

      await pool.release(first);
      final second = await pending.timeout(const Duration(seconds: 1));

      expect(second.isOpen, isTrue);
      expect(pool.inUseCount, 1);
      await pool.release(second);
    },
  );

  test('dispose completes pending acquire with StateError', () async {
    final pool = ConnectionPool(
      dbPath: p.join(tempDir.path, 'dispose_waiter.db'),
      maxConnections: 1,
    );
    addTearDown(pool.dispose);

    await pool.initialize();
    final first = await pool.acquire();
    final pending = pool.acquire();

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await pool.dispose();

    await expectLater(pending, throwsA(isA<StateError>()));
    await pool.release(first);
  });

  test('connections set a sqlite busy timeout', () async {
    final pool = ConnectionPool(
      dbPath: p.join(tempDir.path, 'busy_timeout.db'),
      maxConnections: 1,
    );
    addTearDown(pool.dispose);

    await pool.initialize();
    final db = await pool.acquire();

    final rows = await db.rawQuery('PRAGMA busy_timeout');
    final timeout = rows.single.values.single;

    try {
      expect(timeout, 5000);
    } finally {
      await pool.release(db);
    }
  });
}

Future<void> _waitForCondition(bool Function() condition) async {
  for (var i = 0; i < 50; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('condition was not reached before timeout');
}
