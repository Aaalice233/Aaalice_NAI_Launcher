part of 'gallery_data_source.dart';

mixin GalleryDataSourceSchema on EnhancedBaseDataSource {
  @override
  Future<void> doInitialize() async {
    return await execute('doInitialize', (db) async {
      await _createImagesTable(db);
      await _createMetadataTable(db);
      await _createFavoritesTable(db);
      await _createTagsTable(db);
      await _createImageTagsTable(db);
      await _createScanLogsTable(db);
      await _createFtsIndexTable(db);

      // 迁移：添加 last_scanned_at 列（如果缺失）
      await _migrateAddLastScannedAt(db);

      AppLogger.i('Gallery tables initialized', 'GalleryDS');
    });
  }

  Future<void> _createImagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${GalleryDataSource._imagesTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_path TEXT NOT NULL UNIQUE,
        file_name TEXT NOT NULL,
        file_size INTEGER NOT NULL DEFAULT 0,
        width INTEGER,
        height INTEGER,
        aspect_ratio REAL,
        modified_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        indexed_at INTEGER NOT NULL,
        last_scanned_at INTEGER,
        date_ymd INTEGER NOT NULL DEFAULT 0,
        resolution_key TEXT,
        metadata_status INTEGER NOT NULL DEFAULT 2,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 核心索引：按修改时间排序（主查询）
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_modified_at
      ON ${GalleryDataSource._imagesTable}(modified_at DESC)
    ''');

    // 核心索引：按创建时间排序
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_created_at
      ON ${GalleryDataSource._imagesTable}(created_at DESC)
    ''');

    // 核心索引：按 ID 主键查询
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_id_deleted
      ON ${GalleryDataSource._imagesTable}(id) WHERE is_deleted = 0
    ''');

    // 核心索引：按日期分组
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_date_ymd
      ON ${GalleryDataSource._imagesTable}(date_ymd DESC) WHERE is_deleted = 0
    ''');

    // 核心索引：收藏过滤
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_favorite
      ON ${GalleryDataSource._imagesTable}(is_favorite, modified_at DESC) WHERE is_deleted = 0
    ''');

    // 核心索引：元数据状态过滤
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_metadata_status
      ON ${GalleryDataSource._imagesTable}(metadata_status) WHERE is_deleted = 0
    ''');

    // 核心索引：is_deleted 过滤（软删除）
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_is_deleted
      ON ${GalleryDataSource._imagesTable}(is_deleted, modified_at DESC)
    ''');

    // 核心索引：画廊扫描性能优化 - 文件路径
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_file_path
      ON ${GalleryDataSource._imagesTable}(file_path) WHERE is_deleted = 0
    ''');

    // 复合索引：多条件查询优化
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_composite
      ON ${GalleryDataSource._imagesTable}(is_deleted, is_favorite, modified_at DESC)
    ''');
  }

  /// 迁移：添加 last_scanned_at 列（如果缺失）
  Future<void> _migrateAddLastScannedAt(Database db) async {
    try {
      // 检查列是否存在
      final tableInfo = await db.rawQuery(
        'PRAGMA table_info(${GalleryDataSource._imagesTable})',
      );
      final hasColumn = tableInfo.any(
        (col) => col['name'] == 'last_scanned_at',
      );

      if (!hasColumn) {
        AppLogger.i(
          '[Migration] Adding last_scanned_at column to ${GalleryDataSource._imagesTable}',
          'GalleryDS',
        );
        await db.execute(
          'ALTER TABLE ${GalleryDataSource._imagesTable} ADD COLUMN last_scanned_at INTEGER',
        );
        AppLogger.i(
          '[Migration] last_scanned_at column added successfully',
          'GalleryDS',
        );
      } else {
        AppLogger.d(
          '[Migration] last_scanned_at column already exists',
          'GalleryDS',
        );
      }
    } catch (e, stack) {
      AppLogger.e(
        '[Migration] Failed to add last_scanned_at column',
        e,
        stack,
        'GalleryDS',
      );
      // 迁移失败不应该阻止应用启动
    }
  }

  Future<void> _createMetadataTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${GalleryDataSource._metadataTable} (
        image_id INTEGER PRIMARY KEY,
        prompt TEXT NOT NULL DEFAULT '',
        negative_prompt TEXT NOT NULL DEFAULT '',
        seed INTEGER,
        sampler TEXT,
        steps INTEGER,
        cfg_scale REAL,
        width INTEGER,
        height INTEGER,
        model TEXT,
        smea INTEGER NOT NULL DEFAULT 0,
        smea_dyn INTEGER NOT NULL DEFAULT 0,
        noise_schedule TEXT,
        cfg_rescale REAL,
        uc_preset INTEGER,
        quality_toggle INTEGER NOT NULL DEFAULT 0,
        is_img2img INTEGER NOT NULL DEFAULT 0,
        strength REAL,
        noise REAL,
        software TEXT,
        source TEXT,
        version TEXT,
        raw_json TEXT,
        has_metadata INTEGER NOT NULL DEFAULT 0,
        full_prompt_text TEXT NOT NULL DEFAULT '',
        vibe_encoding TEXT,
        vibe_strength REAL,
        vibe_info_extracted REAL,
        vibe_source_type TEXT,
        has_vibe INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (image_id) REFERENCES ${GalleryDataSource._imagesTable}(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_metadata_model
      ON ${GalleryDataSource._metadataTable}(model) WHERE model IS NOT NULL AND model != ''
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_metadata_sampler
      ON ${GalleryDataSource._metadataTable}(sampler) WHERE sampler IS NOT NULL AND sampler != ''
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_metadata_seed
      ON ${GalleryDataSource._metadataTable}(seed)
    ''');

    // 新增索引：全文搜索优化
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_metadata_prompt
      ON ${GalleryDataSource._metadataTable}(prompt) WHERE prompt IS NOT NULL AND prompt != ''
    ''');
  }

  Future<void> _createFavoritesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${GalleryDataSource._favoritesTable} (
        image_id INTEGER PRIMARY KEY,
        favorited_at INTEGER NOT NULL,
        FOREIGN KEY (image_id) REFERENCES ${GalleryDataSource._imagesTable}(id) ON DELETE CASCADE
      )
    ''');

    // 新增索引：收藏时间排序
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_favorites_time
      ON ${GalleryDataSource._favoritesTable}(favorited_at DESC)
    ''');
  }

  Future<void> _createTagsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${GalleryDataSource._tagsTable} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        category TEXT,
        usage_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_tags_name
      ON ${GalleryDataSource._tagsTable}(name)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_tags_category
      ON ${GalleryDataSource._tagsTable}(category)
    ''');

    // 新增索引：使用频次排序
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_tags_usage
      ON ${GalleryDataSource._tagsTable}(usage_count DESC)
    ''');
  }

  Future<void> _createImageTagsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${GalleryDataSource._imageTagsTable} (
        image_id INTEGER NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (image_id, tag_id),
        FOREIGN KEY (image_id) REFERENCES ${GalleryDataSource._imagesTable}(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES ${GalleryDataSource._tagsTable}(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_image_tags_tag_id
      ON ${GalleryDataSource._imageTagsTable}(tag_id)
    ''');
  }

  Future<void> _createScanLogsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${GalleryDataSource._scanLogsTable} (
        id TEXT PRIMARY KEY,
        started_at INTEGER NOT NULL,
        completed_at INTEGER,
        total_files INTEGER NOT NULL DEFAULT 0,
        processed_files INTEGER NOT NULL DEFAULT 0,
        new_files INTEGER NOT NULL DEFAULT 0,
        updated_files INTEGER NOT NULL DEFAULT 0,
        failed_files INTEGER NOT NULL DEFAULT 0,
        error_message TEXT,
        scan_path TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_scan_logs_started_at
      ON ${GalleryDataSource._scanLogsTable}(started_at DESC)
    ''');
  }

  Future<void> _createFtsIndexTable(Database db) async {
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS ${GalleryDataSource._ftsIndexTable} USING fts5(
        image_id UNINDEXED,
        prompt_text,
        tokenize = 'porter'
      )
    ''');
  }

  @override
  Future<DataSourceHealth> doCheckHealth() async {
    return await execute('doCheckHealth', (db) async {
      final source = this as GalleryDataSource;
      final tables = [
        GalleryDataSource._imagesTable,
        GalleryDataSource._metadataTable,
        GalleryDataSource._favoritesTable,
        GalleryDataSource._tagsTable,
        GalleryDataSource._imageTagsTable,
        GalleryDataSource._scanLogsTable,
        GalleryDataSource._ftsIndexTable,
      ];

      final missingTables = <String>[];

      for (final table in tables) {
        final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );
        if (result.isEmpty) {
          missingTables.add(table);
        }
      }

      if (missingTables.isNotEmpty) {
        return DataSourceHealth(
          status: HealthStatus.corrupted,
          message: 'Missing tables: ${missingTables.join(', ')}',
          details: {'missingTables': missingTables},
          timestamp: DateTime.now(),
        );
      }

      for (final table in tables) {
        await db.rawQuery('SELECT 1 FROM $table LIMIT 1');
      }

      final imageCount = await _getTableCount(
        db,
        GalleryDataSource._imagesTable,
      );
      final metadataCount = await _getTableCount(
        db,
        GalleryDataSource._metadataTable,
      );
      final tagCount = await _getTableCount(db, GalleryDataSource._tagsTable);

      return DataSourceHealth(
        status: HealthStatus.healthy,
        message: 'Gallery data source is healthy',
        details: {
          'imageCount': imageCount,
          'metadataCount': metadataCount,
          'tagCount': tagCount,
          'imageCacheSize': source._imageCache.size,
          'queryCacheSize': source._queryCache.size,
          'cacheHitRate': {
            'image': source._imageCache.hitRate,
            'query': source._queryCache.hitRate,
          },
          'slowQueryCount': source._slowQueryLogs.length,
        },
        timestamp: DateTime.now(),
      );
    });
  }

  Future<int> _getTableCount(dynamic db, String tableName) async {
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName',
      );
      return (result.first['count'] as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<void> doClear() async {
    (this as GalleryDataSource).clearCache();
    AppLogger.i('Gallery data source cleared', 'GalleryDS');
  }

  @override
  Future<void> doRestore() async {
    (this as GalleryDataSource).clearCache();
    AppLogger.i('Gallery data source ready for restore', 'GalleryDS');
  }
}
