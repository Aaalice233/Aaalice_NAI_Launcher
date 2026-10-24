import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/connection_pool.dart';
import 'package:nai_launcher/core/database/single_message_transaction.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/log_capture.dart';

// 撞上一次跨消息写锁就要卡满连接池配置的 busy_timeout 5 秒
const _stallBudget = Duration(seconds: 2);

void main() {
  late Directory tempDir;
  late ConnectionPool pool;
  late Database writer;
  late Database other;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppLogger.initialize(isTestEnvironment: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('single_message_txn_');
    pool = ConnectionPool(
      dbPath: p.join(tempDir.path, 'probe.db'),
      maxConnections: 2,
    );
    await pool.initialize();
    writer = await pool.acquire();
    other = await pool.acquire();
    await writer.execute(
      'CREATE TABLE probe (id INTEGER PRIMARY KEY, value INTEGER '
      'CHECK (value >= 0))',
    );
  });

  tearDown(() async {
    await pool.release(writer);
    await pool.release(other);
    await pool.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<int> rowCount(Database db) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS count FROM probe');
    return rows.single['count']! as int;
  }

  group('applyAtomically', () {
    test('一次提交全部语句，只返回调用方语句的结果', () async {
      final results = await writer.applyAtomically((batch) {
        batch
          ..insert('probe', {'value': 1})
          ..insert('probe', {'value': 2})
          ..rawUpdate('UPDATE probe SET value = value + 10')
          ..rawQuery('SELECT value FROM probe ORDER BY value');
      });

      expect(results, hasLength(4));
      expect(results[0], 1);
      expect(results[1], 2);
      expect(results[2], 2);
      expect(batchQueryRows(results[3]), [
        {'value': 11},
        {'value': 12},
      ]);
      expect(await rowCount(other), 2);
    });

    test('noResult 照常提交并返回空列表', () async {
      final results = await writer.applyAtomically(
        (batch) => batch.insert('probe', {'value': 1}),
        noResult: true,
      );

      expect(results, isEmpty);
      expect(await rowCount(other), 1);
    });

    test('没有语句时不下发事务', () async {
      expect(await writer.applyAtomically((_) {}), isEmpty);
    });

    test('语句失败时整批回滚，连接上不残留事务和写锁', () async {
      final logs = await captureLogs(
        () => expectLater(
          writer.applyAtomically((batch) {
            batch
              ..insert('probe', {'value': 1})
              ..insert('probe', {'value': -1});
          }),
          throwsA(isA<DatabaseException>()),
        ),
      );

      expect(await rowCount(other), 0);
      expect(logs.where((line) => line.contains('Rollback')), isEmpty);

      final stopwatch = Stopwatch()..start();
      await other.insert('probe', {'value': 2});
      expect(stopwatch.elapsed, lessThan(_stallBudget));

      await writer.applyAtomically(
        (batch) => batch.insert('probe', {'value': 3}),
      );
      expect(await rowCount(other), 2);
    });

    test('BEGIN 本身拿不到写锁时原样抛出，回滚无事务可回不记日志', () async {
      await writer.execute('PRAGMA busy_timeout = 0');
      await other.execute('BEGIN IMMEDIATE');
      try {
        final logs = await captureLogs(
          () => expectLater(
            writer.applyAtomically(
              (batch) => batch.insert('probe', {'value': 1}),
            ),
            throwsA(
              isA<DatabaseException>().having(
                (error) => error.getResultCode(),
                'resultCode',
                5,
              ),
            ),
          ),
        );
        expect(logs.where((line) => line.contains('Rollback')), isEmpty);
      } finally {
        await other.execute('ROLLBACK');
      }

      expect(await rowCount(writer), 0);
    });

    test('readOnly 只取读快照，另一连接持有写锁时照样读', () async {
      await other.insert('probe', {'value': 7});
      await writer.execute('PRAGMA busy_timeout = 0');
      await other.execute('BEGIN IMMEDIATE');
      try {
        final results = await writer.applyAtomically(
          (batch) => batch.rawQuery('SELECT value FROM probe'),
          readOnly: true,
        );

        expect(batchQueryRows(results.single), [
          {'value': 7},
        ]);
      } finally {
        await other.execute('ROLLBACK');
      }
    });

    test('一条连接的批量写入不让另一条连接的单条写入忙等', () async {
      final stopwatch = Stopwatch()..start();
      await Future.wait([
        () async {
          for (var round = 0; round < 5; round++) {
            await writer.applyAtomically((batch) {
              for (var i = 0; i < 50; i++) {
                batch.insert('probe', {'value': i});
              }
            }, noResult: true);
          }
        }(),
        () async {
          for (var i = 0; i < 30; i++) {
            await other.insert('probe', {'value': i});
          }
        }(),
      ]);
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(_stallBudget));
      expect(await rowCount(other), 5 * 50 + 30);
    });
  });

  // 池内连接共用一个 isolate，跨消息事务与并发写入相撞就会卡满 busy_timeout；
  // 裸 batch.apply 不包事务，批内每条语句各自提交
  test('数据库层的事务与批处理只经 applyAtomically', () {
    final forbidden = RegExp(
      r'''\.transaction\(|executeTransaction|\.commit\(|\.apply\(|['"]BEGIN''',
    );
    final offenders = [
      for (final file
          in Directory('lib/core/database')
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))
              .where((file) => !file.path.endsWith('.g.dart'))
              .where(
                (file) =>
                    p.basename(file.path) != 'single_message_transaction.dart',
              ))
        for (final (index, line) in file.readAsLinesSync().indexed)
          if (forbidden.hasMatch(line)) '${file.path}:${index + 1}: $line',
    ];

    expect(offenders, isEmpty);
  });
}
