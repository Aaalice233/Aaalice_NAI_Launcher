import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';
import 'database_error_summary.dart';

/// [SingleMessageTransaction.applyAtomically] 结果中一条 rawQuery 的行。
List<Map<String, Object?>> batchQueryRows(Object? result) =>
    result! as List<Map<String, Object?>>;

// 池内连接共用 sqflite ffi 的同一个后台 isolate：事务跨消息持写锁时，别的连接的写语句
// 会在 isolate 里忙等满 busy_timeout，持锁方的 COMMIT 排在它后面进不来。
extension SingleMessageTransaction on Database {
  /// BEGIN、[build] 添加的语句与 COMMIT 作为同一条批处理消息执行，返回 [build] 各语句的结果。
  ///
  /// [readOnly] 只取读快照，不占写锁；[noResult] 与 sqflite 一致，返回空列表。
  Future<List<Object?>> applyAtomically(
    void Function(Batch batch) build, {
    bool readOnly = false,
    bool noResult = false,
  }) async {
    final batch = this.batch()
      ..execute(readOnly ? 'BEGIN DEFERRED' : 'BEGIN IMMEDIATE');
    build(batch);
    final statementCount = batch.length - 1;
    if (statementCount == 0) return const [];
    batch.execute('COMMIT');

    final List<Object?> results;
    try {
      results = await batch.apply(noResult: noResult);
    } catch (_) {
      await _rollbackInterruptedBatch();
      rethrow;
    }
    if (noResult) return const [];
    return results.sublist(1, statementCount + 1);
  }

  // 语句失败时事务停在这条连接上；BEGIN 本身失败或 SQLite 已自动回滚时则没有活动事务
  Future<void> _rollbackInterruptedBatch() async {
    try {
      await execute('ROLLBACK');
    } on DatabaseException catch (error) {
      if (error.toString().contains('no transaction is active')) return;
      AppLogger.w(
        'Rollback after failed batch failed: ${databaseErrorSummary(error)}',
        'Database',
      );
    }
  }
}
