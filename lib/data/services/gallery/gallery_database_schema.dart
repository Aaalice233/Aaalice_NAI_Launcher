/// 画廊数据库Schema定义
///
/// 包含所有表结构、索引和触发器的SQL语句
class GalleryDatabaseSchema {
  GalleryDatabaseSchema._();

  /// 图片索引主表
  static const String createImagesTable = '''
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
      is_deleted INTEGER DEFAULT 0,
      date_ymd INTEGER,
      resolution_key TEXT
    )
  ''';

  /// 元数据表
  static const String createMetadataTable = '''
    CREATE TABLE IF NOT EXISTS metadata (
      image_id INTEGER PRIMARY KEY,
      prompt TEXT,
      negative_prompt TEXT,
      seed INTEGER,
      steps INTEGER,
      cfg_scale REAL,
      sampler TEXT,
      model TEXT,
      noise_schedule TEXT,
      smea INTEGER DEFAULT 0,
      smea_dyn INTEGER DEFAULT 0,
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
      has_metadata INTEGER DEFAULT 1,
      full_prompt_text TEXT,
      vibe_encoding TEXT,
      vibe_strength REAL,
      vibe_info_extracted REAL,
      vibe_source_type TEXT,
      has_vibe INTEGER DEFAULT 0,
      FOREIGN KEY (image_id) REFERENCES images(id) ON DELETE CASCADE
    )
  ''';

  /// 迁移：添加 Vibe 字段到元数据表（版本 1 -> 2）
  static const List<String> migrateV1ToV2 = [
    'ALTER TABLE metadata ADD COLUMN vibe_encoding TEXT',
    'ALTER TABLE metadata ADD COLUMN vibe_strength REAL',
    'ALTER TABLE metadata ADD COLUMN vibe_info_extracted REAL',
    'ALTER TABLE metadata ADD COLUMN vibe_source_type TEXT',
    'ALTER TABLE metadata ADD COLUMN has_vibe INTEGER DEFAULT 0',
  ];

  /// FTS5全文搜索虚拟表
  static const String createMetadataFtsTable = '''
    CREATE VIRTUAL TABLE IF NOT EXISTS metadata_fts USING fts5(
      prompt,
      negative_prompt,
      full_prompt_text,
      character_prompts,
      model,
      sampler,
      content=metadata,
      content_rowid=image_id,
      tokenize='unicode61'
    )
  ''';

  /// 收藏表
  static const String createFavoritesTable = '''
    CREATE TABLE IF NOT EXISTS favorites (
      image_id INTEGER PRIMARY KEY,
      favorited_at INTEGER NOT NULL,
      FOREIGN KEY (image_id) REFERENCES images(id) ON DELETE CASCADE
    )
  ''';

  /// 标签表
  static const String createTagsTable = '''
    CREATE TABLE IF NOT EXISTS tags (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tag_name TEXT NOT NULL UNIQUE COLLATE NOCASE
    )
  ''';

  /// 图片-标签关联表
  static const String createImageTagsTable = '''
    CREATE TABLE IF NOT EXISTS image_tags (
      image_id INTEGER NOT NULL,
      tag_id INTEGER NOT NULL,
      tagged_at INTEGER NOT NULL,
      PRIMARY KEY (image_id, tag_id),
      FOREIGN KEY (image_id) REFERENCES images(id) ON DELETE CASCADE,
      FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
    )
  ''';

  /// 文件夹表
  static const String createFoldersTable = '''
    CREATE TABLE IF NOT EXISTS folders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      folder_path TEXT NOT NULL UNIQUE,
      parent_id INTEGER,
      folder_name TEXT NOT NULL,
      depth_level INTEGER DEFAULT 0,
      image_count INTEGER DEFAULT 0,
      FOREIGN KEY (parent_id) REFERENCES folders(id) ON DELETE CASCADE
    )
  ''';

  /// 扫描历史表
  static const String createScanHistoryTable = '''
    CREATE TABLE IF NOT EXISTS scan_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      scan_type TEXT NOT NULL,
      root_path TEXT NOT NULL,
      files_scanned INTEGER NOT NULL,
      files_added INTEGER NOT NULL,
      files_updated INTEGER NOT NULL,
      files_deleted INTEGER NOT NULL,
      scan_duration_ms INTEGER NOT NULL,
      started_at INTEGER NOT NULL,
      completed_at INTEGER NOT NULL
    )
  ''';

  /// 索引定义
  static const List<String> createIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_images_modified_at ON images(modified_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_images_date_ymd ON images(date_ymd DESC)',
    'CREATE INDEX IF NOT EXISTS idx_images_file_hash ON images(file_hash)',
    'CREATE INDEX IF NOT EXISTS idx_images_resolution ON images(resolution_key)',
    'CREATE INDEX IF NOT EXISTS idx_images_is_deleted ON images(is_deleted)',
    'CREATE INDEX IF NOT EXISTS idx_metadata_model ON metadata(model)',
    'CREATE INDEX IF NOT EXISTS idx_metadata_sampler ON metadata(sampler)',
    'CREATE INDEX IF NOT EXISTS idx_metadata_steps ON metadata(steps)',
    'CREATE INDEX IF NOT EXISTS idx_metadata_cfg ON metadata(cfg_scale)',
    'CREATE INDEX IF NOT EXISTS idx_metadata_seed ON metadata(seed)',
    'CREATE INDEX IF NOT EXISTS idx_metadata_has_data ON metadata(has_metadata)',
    'CREATE INDEX IF NOT EXISTS idx_favorites_time ON favorites(favorited_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(tag_name COLLATE NOCASE)',
    'CREATE INDEX IF NOT EXISTS idx_image_tags_tag ON image_tags(tag_id)',
    'CREATE INDEX IF NOT EXISTS idx_folders_parent ON folders(parent_id)',
    'CREATE INDEX IF NOT EXISTS idx_folders_path ON folders(folder_path)',
  ];

  /// FTS5同步触发器
  static const List<String> createFtsTriggers = [
    // 插入时同步到FTS5
    '''
    CREATE TRIGGER IF NOT EXISTS metadata_fts_insert AFTER INSERT ON metadata
    BEGIN
      INSERT INTO metadata_fts(
        rowid, prompt, negative_prompt, full_prompt_text,
        character_prompts, model, sampler
      )
      VALUES (
        NEW.image_id, NEW.prompt, NEW.negative_prompt,
        NEW.full_prompt_text, NEW.character_prompts,
        NEW.model, NEW.sampler
      );
    END
    ''',
    // 更新时同步到FTS5
    '''
    CREATE TRIGGER IF NOT EXISTS metadata_fts_update AFTER UPDATE ON metadata
    BEGIN
      DELETE FROM metadata_fts WHERE rowid = OLD.image_id;
      INSERT INTO metadata_fts(
        rowid, prompt, negative_prompt, full_prompt_text,
        character_prompts, model, sampler
      )
      VALUES (
        NEW.image_id, NEW.prompt, NEW.negative_prompt,
        NEW.full_prompt_text, NEW.character_prompts,
        NEW.model, NEW.sampler
      );
    END
    ''',
    // 删除时同步到FTS5
    '''
    CREATE TRIGGER IF NOT EXISTS metadata_fts_delete AFTER DELETE ON metadata
    BEGIN
      DELETE FROM metadata_fts WHERE rowid = OLD.image_id;
    END
    ''',
  ];
}
