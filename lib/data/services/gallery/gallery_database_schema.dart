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

  /// 迁移：添加文件夹层级字段（版本 2 -> 3）
  static const List<String> migrateV2ToV3 = [
    // 添加排序字段
    'ALTER TABLE folders ADD COLUMN sort_order INTEGER DEFAULT 0',
    // 添加更新时间字段
    'ALTER TABLE folders ADD COLUMN updated_at INTEGER DEFAULT 0',
    // 添加文件夹描述字段
    'ALTER TABLE folders ADD COLUMN description TEXT',
    // 添加文件夹颜色标识字段
    'ALTER TABLE folders ADD COLUMN color INTEGER',
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
    'CREATE INDEX IF NOT EXISTS idx_metadata_image_id ON metadata(image_id)',
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
    'CREATE INDEX IF NOT EXISTS idx_folders_sort ON folders(sort_order)',
    'CREATE INDEX IF NOT EXISTS idx_folders_updated ON folders(updated_at DESC)',
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

  /// 文件夹层级查询语句

  /// 获取根级文件夹
  static const String selectRootFolders = '''
    SELECT * FROM folders
    WHERE parent_id IS NULL
    ORDER BY sort_order ASC, folder_name COLLATE NOCASE ASC
  ''';

  /// 获取指定父文件夹的子文件夹
  static const String selectChildFolders = '''
    SELECT * FROM folders
    WHERE parent_id = ?
    ORDER BY sort_order ASC, folder_name COLLATE NOCASE ASC
  ''';

  /// 获取文件夹及其所有后代（递归查询）
  static const String selectFolderDescendants = '''
    WITH RECURSIVE folder_tree AS (
      SELECT *, 0 as depth
      FROM folders
      WHERE id = ?
      UNION ALL
      SELECT f.*, ft.depth + 1
      FROM folders f
      INNER JOIN folder_tree ft ON f.parent_id = ft.id
    )
    SELECT * FROM folder_tree
    ORDER BY depth ASC, sort_order ASC
  ''';

  /// 获取文件夹路径（从指定文件夹到根）
  static const String selectFolderPath = '''
    WITH RECURSIVE folder_path AS (
      SELECT *, 0 as depth
      FROM folders
      WHERE id = ?
      UNION ALL
      SELECT f.*, fp.depth + 1
      FROM folders f
      INNER JOIN folder_path fp ON f.id = fp.parent_id
    )
    SELECT * FROM folder_path
    ORDER BY depth DESC
  ''';

  /// 更新文件夹路径（级联更新子文件夹路径）
  static const String updateFolderPathCascade = '''
    WITH RECURSIVE folder_tree AS (
      SELECT id, folder_path, ? || '/' || folder_name as new_path
      FROM folders
      WHERE id = ?
      UNION ALL
      SELECT f.id, f.folder_path,
             ft.new_path || '/' || f.folder_name
      FROM folders f
      INNER JOIN folder_tree ft ON f.parent_id = ft.id
    )
    UPDATE folders
    SET folder_path = (
      SELECT new_path FROM folder_tree WHERE folder_tree.id = folders.id
    ),
    updated_at = ?
    WHERE id IN (SELECT id FROM folder_tree)
  ''';

  /// 获取文件夹图片数量（仅直接包含）
  static const String countImagesInFolder = '''
    SELECT COUNT(*) FROM images
    WHERE file_path LIKE ? || '/%'
    AND file_path NOT LIKE ? || '/%/%'
  ''';

  /// 获取文件夹图片数量（递归包含子文件夹）
  static const String countImagesInFolderRecursive = '''
    SELECT COUNT(*) FROM images
    WHERE file_path LIKE ? || '/%'
  ''';

  /// 批量移动图片到新文件夹
  static const String updateImagesFolder = '''
    UPDATE images
    SET file_path = ? || '/' || file_name,
        modified_at = ?
    WHERE id IN (
      SELECT id FROM images
      WHERE file_path LIKE ? || '/%'
    )
  ''';

  /// 检查文件夹名称是否已存在（同一父级下）
  static const String checkFolderNameExists = '''
    SELECT COUNT(*) FROM folders
    WHERE parent_id IS ? AND folder_name = ? COLLATE NOCASE
  ''';

  /// 获取文件夹深度级别
  static const String selectFolderDepth = '''
    WITH RECURSIVE depth_calc AS (
      SELECT id, parent_id, 0 as depth
      FROM folders
      WHERE id = ?
      UNION ALL
      SELECT f.id, f.parent_id, dc.depth + 1
      FROM folders f
      INNER JOIN depth_calc dc ON f.id = dc.parent_id
    )
    SELECT MAX(depth) as depth_level FROM depth_calc
  ''';

  /// 更新文件夹图片数量统计
  static const String updateFolderImageCount = '''
    UPDATE folders
    SET image_count = ?,
        updated_at = ?
    WHERE id = ?
  ''';

  /// 获取所有需要更新计数的文件夹
  static const String selectFoldersNeedingCountUpdate = '''
    SELECT f.*, (
      SELECT COUNT(*) FROM images
      WHERE file_path LIKE f.folder_path || '/%'
    ) as actual_count
    FROM folders f
    WHERE f.image_count != actual_count
  ''';
}
