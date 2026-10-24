import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../utils/app_logger.dart';
import '../database_error_summary.dart';
import 'gallery_database_gateway.dart';
import 'gallery_tables.dart';

/// 提示词全文索引：rowid 即图片 id，内容派生自 gallery_metadata.full_prompt_text。
///
/// 本类从不开事务：所有连接共用一个 sqflite isolate，
/// 事务跨消息持有写锁时，其他连接的写入会在 isolate 里干等满 busy_timeout。
class GalleryFtsIndex {
  GalleryFtsIndex({required this.gateway});

  final GalleryDatabaseGateway gateway;

  // 每批约 0.1～0.3 秒，期间其他数据库操作在 isolate 里排队
  static const _rebuildBatchSize = 500;
  static const _rebuildBatchPause = Duration(milliseconds: 50);

  bool _rebuildPending = false;
  bool _stopRequested = false;
  Future<void>? _rebuild;

  /// 建表；遇到旧版索引就删掉，并登记由 [resumePendingRebuild] 从元数据回填。
  Future<void> prepare() async {
    _rebuildPending = await gateway.execute(
      'prepareFtsIndex',
      (db) async {
        await db.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS ${GalleryTables.ftsIndex} USING fts5(
            prompt_text,
            tokenize = 'porter'
          )
        ''');
        if (await _tableExists(db, GalleryTables.legacyFtsIndex)) {
          await _retireLegacyIndex(db);
        }
        return _tableExists(db, GalleryTables.ftsRebuild);
      },
      // 删旧表要读遍它的全部页，大图库冷盘上要数秒
      timeout: const Duration(minutes: 2),
      maxRetries: 1,
    );
  }

  // 先登记游标再删旧表：中途退出时旧表仍在，下次启动重走一遍
  Future<void> _retireLegacyIndex(Database db) async {
    AppLogger.i(
      '[Migration] Dropping legacy FTS index, prompts will be reindexed '
          'in background',
      'GalleryDS',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${GalleryTables.ftsRebuild} (
        id INTEGER PRIMARY KEY CHECK (id = 0),
        next_image_id INTEGER NOT NULL
      )
    ''');
    // 旧表在说明新索引没建完，或降级期间旧版本只写了旧表，都要从头回填
    await db.execute(
      'INSERT OR REPLACE INTO ${GalleryTables.ftsRebuild} '
      '(id, next_image_id) VALUES (0, 0)',
    );
    await db.execute('DROP TABLE ${GalleryTables.legacyFtsIndex}');
  }

  /// 按 rowid 覆盖这些图片的索引行，不扫描其他行。
  Future<void> replaceRows(
    DatabaseExecutor executor,
    Map<int, String> promptTexts,
  ) async {
    if (promptTexts.isEmpty) return;

    final batch = executor.batch();
    for (final MapEntry(key: imageId, value: promptText)
        in promptTexts.entries) {
      batch.rawInsert(
        'INSERT OR REPLACE INTO ${GalleryTables.ftsIndex} '
        '(rowid, prompt_text) VALUES (?, ?)',
        [imageId, promptText],
      );
    }
    // apply 不另开事务，整批在一条消息里执行完
    await batch.apply(noResult: true);
  }

  /// 按相关度返回匹配 [matchExpression] 的图片 id。
  Future<List<int>> matchImageIds(
    DatabaseExecutor executor,
    String matchExpression, {
    required int limit,
  }) async {
    final rows = await executor.rawQuery(
      '''
      SELECT rowid AS image_id FROM ${GalleryTables.ftsIndex}
      WHERE ${GalleryTables.ftsIndex} MATCH ?
      ORDER BY rank
      LIMIT ?
      ''',
      [matchExpression, limit],
    );
    return [for (final row in rows) (row['image_id'] as num).toInt()];
  }

  /// 有待回填时在后台分批执行；回填期间搜索只少掉尚未回填的行。
  Future<void> resumePendingRebuild() {
    if (!_rebuildPending) return Future<void>.value();
    return _rebuild ??= _runRebuild().whenComplete(() => _rebuild = null);
  }

  /// 当前回填结束（完成、中断或失败）后完成；没有回填时立即完成。
  Future<void> whenRebuildSettled() => _rebuild ?? Future<void>.value();

  /// 停在当前批次之后，未回填的部分下次启动接着做。
  Future<void> stopRebuild() async {
    _stopRequested = true;
    await _rebuild;
  }

  Future<void> _runRebuild() async {
    _stopRequested = false;
    final stopwatch = Stopwatch()..start();
    var indexedRows = 0;
    try {
      while (!_stopRequested) {
        final batchRows = await gateway.execute(
          'rebuildFtsIndex',
          _rebuildNextBatch,
          timeout: const Duration(seconds: 30),
        );
        if (batchRows == null) {
          _rebuildPending = false;
          AppLogger.i(
            'FTS index rebuilt from metadata: $indexedRows rows in '
                '${stopwatch.elapsedMilliseconds}ms',
            'GalleryDS',
          );
          return;
        }
        indexedRows += batchRows;
        await Future<void>.delayed(_rebuildBatchPause);
      }
    } catch (e) {
      AppLogger.w(
        'FTS index rebuild paused after $indexedRows rows, resumes on next '
            'launch: ${databaseErrorSummary(e)}',
        'GalleryDS',
      );
    }
  }

  /// 回填下一批并推进游标，返回本批行数；已全部回填时删除游标表并返回 null。
  ///
  /// 覆盖是幂等的：游标没来得及推进就退出，下次重做这一批即可。
  Future<int?> _rebuildNextBatch(Database db) async {
    final cursor = await _readRebuildCursor(db);
    final range = cursor == null ? null : await _nextRebuildRange(db, cursor);
    if (cursor == null || range == null) {
      await db.execute('DROP TABLE ${GalleryTables.ftsRebuild}');
      return null;
    }

    // 单条语句读写原子完成；并发写入总是先写元数据再写索引，最终索引等于最新元数据
    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO ${GalleryTables.ftsIndex} (rowid, prompt_text)
      SELECT image_id, full_prompt_text FROM ${GalleryTables.metadata}
      WHERE image_id > ? AND image_id <= ?
      ''',
      [cursor, range.lastImageId],
    );
    await db.rawUpdate(
      'UPDATE ${GalleryTables.ftsRebuild} SET next_image_id = ? WHERE id = 0',
      [range.lastImageId],
    );
    return range.rowCount;
  }

  Future<int?> _readRebuildCursor(Database db) async {
    final rows = await db.rawQuery(
      'SELECT next_image_id FROM ${GalleryTables.ftsRebuild} WHERE id = 0',
    );
    return rows.isEmpty ? null : (rows.first['next_image_id'] as num).toInt();
  }

  Future<({int lastImageId, int rowCount})?> _nextRebuildRange(
    Database db,
    int cursor,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT max(image_id) AS last_image_id, count(*) AS row_count FROM (
        SELECT image_id FROM ${GalleryTables.metadata}
        WHERE image_id > ?
        ORDER BY image_id
        LIMIT ?
      )
      ''',
      [cursor, _rebuildBatchSize],
    );
    final lastImageId = (rows.first['last_image_id'] as num?)?.toInt();
    if (lastImageId == null) return null;
    return (
      lastImageId: lastImageId,
      rowCount: (rows.first['row_count'] as num).toInt(),
    );
  }

  Future<bool> _tableExists(DatabaseExecutor executor, String table) async {
    final rows = await executor.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    return rows.isNotEmpty;
  }
}
