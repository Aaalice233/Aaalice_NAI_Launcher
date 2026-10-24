import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/database/connection_pool_holder.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/database/datasources/gallery_tables.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 当前用例的临时目录与已初始化的图库数据源。
final class GalleryDatabaseSandbox {
  static const _rejectMetadataTrigger = 'test_reject_gallery_metadata';

  late Directory root;
  late GalleryDataSource dataSource;

  /// 元数据表在 SQLite 层拒绝写入，直到 [allowMetadataWrites]。
  Future<void> rejectMetadataWrites() => _execute('''
    CREATE TRIGGER $_rejectMetadataTrigger
    BEFORE INSERT ON ${GalleryTables.metadata}
    BEGIN
      SELECT RAISE(ABORT, 'metadata write rejected');
    END
  ''');

  Future<void> allowMetadataWrites() =>
      _execute('DROP TRIGGER IF EXISTS $_rejectMetadataTrigger');

  Future<void> _execute(String sql) async {
    final pool = ConnectionPoolHolder.instance;
    final db = await pool.acquire();
    try {
      await db.execute(sql);
    } finally {
      await pool.release(db);
    }
  }
}

/// 每个用例在独立临时目录里准备 SQLite 图库、Hive 与连接池，结束后释放并删除目录。
///
/// 用例自己的 tearDown 先于这里执行，扫描器等依赖数据源的对象应在其中释放。
GalleryDatabaseSandbox useGalleryDatabaseSandbox(String prefix) {
  final sandbox = GalleryDatabaseSandbox();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppLogger.initialize(isTestEnvironment: true);
  });

  setUp(() async {
    sandbox.root = await Directory.systemTemp.createTemp(prefix);
    final hivePath = p.join(sandbox.root.path, 'hive');
    await Directory(hivePath).create(recursive: true);
    Hive.init(hivePath);
    await ConnectionPoolHolder.initialize(
      dbPath: p.join(sandbox.root.path, 'gallery.db'),
      maxConnections: 2,
    );
    sandbox.dataSource = GalleryDataSource();
    await sandbox.dataSource.initialize();
  });

  tearDown(() async {
    await Hive.close();
    await sandbox.dataSource.dispose();
    await ConnectionPoolHolder.dispose();
    await _deleteWithRetry(sandbox.root);
  });

  return sandbox;
}

// Windows 上 SQLite 与 Hive 句柄可能晚一点才释放，删不掉时稍后重试
Future<void> _deleteWithRetry(Directory directory) async {
  for (var attempt = 1; attempt <= 5; attempt++) {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
      return;
    } on PathAccessException {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
