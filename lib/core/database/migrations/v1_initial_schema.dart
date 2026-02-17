import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../migration_engine.dart';

/// 初始数据库结构迁移 (v1)
///
/// 创建所有核心表：
/// - images: 图片基础信息
/// - metadata: 图片元数据
/// - favorites: 收藏记录
/// - tags: 标签表
/// - image_tags: 图片-标签关联
/// - folders: 文件夹
/// - scan_history: 扫描历史
/// - metadata_fts: FTS5 全文搜索虚拟表
/// - db_metadata: 数据库元数据
class V1InitialSchema implements Migration {
  @override
  int get version => 1;

  @override
  String get description => 'Initial database schema';

  @override
  Future<void> up(Database db) async {
    final batch = db.batch();

    // 创建图片基础表
    batch.execute('''
      CREATE TABLE IF NOT EXISTS images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_path TEXT NOT NULL UNIQUE,
        file_name TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        file_hash TEXT,
        width INTEGER,
        height INTEGER,
        aspect_ratio REAL,
        created_at INTEGER NOT NULL,
        modified_at INTEGER NOT NULL,
        indexed_at INTEGER NOT NULL,
        date_ymd INTEGER NOT NULL,
        resolution_key TEXT,
        is_deleted INTEGER DEFAULT 0,
        folder_id INTEGER
      )
    ''');

    // 创建元数据表
    batch.execute('''
      CREATE TABLE IF NOT EXISTS metadata (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_id INTEGER NOT NULL UNIQUE,
        prompt TEXT,
        negative_prompt TEXT,
        seed INTEGER,
        steps INTEGER,
        cfg_scale REAL,
        sampler TEXT,
        model TEXT,
        smea INTEGER DEFAULT 0,
        smea_dyn INTEGER DEFAULT 0,
        noise_schedule TEXT,
        cfg_rescale REAL,
        quality_toggle INTEGER DEFAULT 0,
        uc_preset INTEGER,
        is_img2img INTEGER DEFAULT 0,
        strength REAL,
        noise REAL,
        software TEXT,
        version TEXT,
        source TEXT,
        character_prompts TEXT,
        character_negative_prompts TEXT,
        raw_json TEXT,
        has_metadata INTEGER DEFAULT 0,
        full_prompt_text TEXT,
        vibe_encoding TEXT,
        vibe_strength REAL,
        vibe_info_extracted REAL,
        vibe_source_type TEXT,
        has_vibe INTEGER DEFAULT 0
      )
    ''');

    // 创建收藏表
    batch.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_id INTEGER NOT NULL UNIQUE,
        favorited_at INTEGER NOT NULL
      )
    ''');

    // 创建标签表
    batch.execute('''
      CREATE TABLE IF NOT EXISTS tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tag_name TEXT NOT NULL UNIQUE
      )
    ''');

    // 创建图片-标签关联表
    batch.execute('''
      CREATE TABLE IF NOT EXISTS image_tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        tagged_at INTEGER NOT NULL
      )
    ''');

    // 创建文件夹表
    batch.execute('''
      CREATE TABLE IF NOT EXISTS folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        path TEXT NOT NULL UNIQUE,
        parent_id INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');

    // 创建扫描历史表
    batch.execute('''
      CREATE TABLE IF NOT EXISTS scan_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scan_type TEXT NOT NULL,
        root_path TEXT NOT NULL,
        files_scanned INTEGER DEFAULT 0,
        files_added INTEGER DEFAULT 0,
        files_updated INTEGER DEFAULT 0,
        files_deleted INTEGER DEFAULT 0,
        scan_duration_ms INTEGER DEFAULT 0,
        started_at INTEGER NOT NULL,
        completed_at INTEGER NOT NULL
      )
    ''');

    // 创建 FTS5 虚拟表（全文搜索）
    batch.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS metadata_fts USING fts5(
        full_prompt_text,
        content='metadata',
        content_rowid='id'
      )
    ''');

    // 创建数据库元数据表
    batch.execute('''
      CREATE TABLE IF NOT EXISTS db_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 创建索引
    _createIndexes(batch);

    // 创建 FTS5 触发器
    _createFtsTriggers(batch);

    await batch.commit(noResult: true);
  }

  @override
  Future<void> down(Database db) async {
    // 删除 FTS5 表（先删触发器）
    await db.execute('DROP TABLE IF EXISTS metadata_fts');

    // 删除其他表
    await db.execute('DROP TABLE IF EXISTS image_tags');
    await db.execute('DROP TABLE IF EXISTS tags');
    await db.execute('DROP TABLE IF EXISTS favorites');
    await db.execute('DROP TABLE IF EXISTS metadata');
    await db.execute('DROP TABLE IF EXISTS scan_history');
    await db.execute('DROP TABLE IF EXISTS folders');
    await db.execute('DROP TABLE IF EXISTS images');
    await db.execute('DROP TABLE IF EXISTS db_metadata');
  }

  /// 创建索引
  void _createIndexes(Batch batch) {
    // images 表索引
    batch.execute('CREATE INDEX IF NOT EXISTS idx_images_modified ON images(modified_at DESC)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_images_created ON images(created_at DESC)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_images_date_ymd ON images(date_ymd DESC)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_images_resolution ON images(resolution_key)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_images_deleted ON images(is_deleted)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_images_folder ON images(folder_id)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_images_hash ON images(file_hash)');

    // metadata 表索引
    batch.execute('CREATE INDEX IF NOT EXISTS idx_metadata_model ON metadata(model)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_metadata_sampler ON metadata(sampler)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_metadata_seed ON metadata(seed)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_metadata_has_vibe ON metadata(has_vibe)');

    // favorites 表索引
    batch.execute('CREATE INDEX IF NOT EXISTS idx_favorites_image ON favorites(image_id)');

    // image_tags 表索引
    batch.execute('CREATE INDEX IF NOT EXISTS idx_image_tags_image ON image_tags(image_id)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_image_tags_tag ON image_tags(tag_id)');

    // folders 表索引
    batch.execute('CREATE INDEX IF NOT EXISTS idx_folders_parent ON folders(parent_id)');
  }

  /// 创建 FTS5 触发器
  void _createFtsTriggers(Batch batch) {
    // 插入时同步到 FTS5
    batch.execute('''
      CREATE TRIGGER IF NOT EXISTS metadata_fts_insert
      AFTER INSERT ON metadata
      BEGIN
        INSERT INTO metadata_fts(rowid, full_prompt_text)
        VALUES (new.id, new.full_prompt_text);
      END
    ''');

    // 更新时同步到 FTS5
    batch.execute('''
      CREATE TRIGGER IF NOT EXISTS metadata_fts_update
      AFTER UPDATE ON metadata
      BEGIN
        UPDATE metadata_fts
        SET full_prompt_text = new.full_prompt_text
        WHERE rowid = old.id;
      END
    ''');

    // 删除时同步到 FTS5
    batch.execute('''
      CREATE TRIGGER IF NOT EXISTS metadata_fts_delete
      AFTER DELETE ON metadata
      BEGIN
        DELETE FROM metadata_fts WHERE rowid = old.id;
      END
    ''');
  }
}
