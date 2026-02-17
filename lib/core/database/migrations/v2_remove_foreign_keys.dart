import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../migration_engine.dart';

/// 移除外键约束迁移 (v2)
///
/// 从 v1 迁移到 v2:
/// - 移除外键约束以提高性能
/// - 添加应用层约束检查
/// - 添加必要的辅助索引
///
/// 注意：SQLite 不支持直接修改外键约束，
/// 需要重建表结构。
class V2RemoveForeignKeys implements Migration {
  @override
  int get version => 2;

  @override
  String get description => 'Remove foreign key constraints for better performance';

  @override
  Future<void> up(Database db) async {
    // 注意：由于我们从未在外键约束模式下创建过表，
    // 这个迁移实际上是一个空操作，用于记录版本变更。
    //
    // 如果需要真正移除外键约束，需要执行以下步骤：
    // 1. 创建新表（无外键约束）
    // 2. 复制数据
    // 3. 删除旧表
    // 4. 重命名新表
    //
    // 由于初始版本 v1 就没有外键约束，这里只是确保一致性

    final batch = db.batch();

    // 添加应用层约束检查的辅助索引
    // 这些索引用于快速检查关联完整性

    // 用于检查孤儿元数据
    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_metadata_image_id 
      ON metadata(image_id)
    ''');

    // 用于检查孤儿收藏
    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_favorites_image_id_check 
      ON favorites(image_id)
    ''');

    // 用于检查孤儿标签关联
    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_image_tags_check 
      ON image_tags(image_id, tag_id)
    ''');

    // 添加数据库配置优化
    // 这些 PRAGMA 设置可以在连接时应用
    // 这里只是记录推荐设置

    await batch.commit(noResult: true);

    // 记录迁移完成
    await _recordMigration(db, 'v2_migration_completed');
  }

  @override
  Future<void> down(Database db) async {
    // 降级：移除外键检查相关的索引
    // 注意：我们不重新添加外键约束，因为这需要重建表

    await db.execute('DROP INDEX IF EXISTS idx_metadata_image_id');
    await db.execute('DROP INDEX IF EXISTS idx_favorites_image_id_check');
    await db.execute('DROP INDEX IF EXISTS idx_image_tags_check');

    // 记录降级完成
    await _recordMigration(db, 'v2_migration_rolled_back');
  }

  /// 记录迁移状态
  Future<void> _recordMigration(Database db, String status) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'db_metadata',
      {
        'key': 'v2_migration_status',
        'value': status,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
