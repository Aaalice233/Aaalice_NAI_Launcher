import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../utils/app_logger.dart';
import '../data_source.dart' show DataSourceHealth, HealthStatus;
import 'gallery_database_gateway.dart';
import 'gallery_store_context.dart';
import 'gallery_tables.dart';

class GallerySchema {
  GallerySchema({required this.gateway, required this.context});

  final GalleryDatabaseGateway gateway;
  final GalleryStoreContext context;

  Future<void> initialize() async {
    return await gateway.execute('doInitialize', (db) async {
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
      CREATE TABLE IF NOT EXISTS ${GalleryTables.images} (
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
      ON ${GalleryTables.images}(modified_at DESC)
    ''');

    // 核心索引：按创建时间排序
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_created_at
      ON ${GalleryTables.images}(created_at DESC)
    ''');

    // 核心索引：按 ID 主键查询
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_id_deleted
      ON ${GalleryTables.images}(id) WHERE is_deleted = 0
    ''');

    // 核心索引：按日期分组
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_date_ymd
      ON ${GalleryTables.images}(date_ymd DESC) WHERE is_deleted = 0
    ''');

    // 核心索引：收藏过滤
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_favorite
      ON ${GalleryTables.images}(is_favorite, modified_at DESC) WHERE is_deleted = 0
    ''');

    // 核心索引：元数据状态过滤
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_metadata_status
      ON ${GalleryTables.images}(metadata_status) WHERE is_deleted = 0
    ''');

    // 核心索引：is_deleted 过滤（软删除）
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_is_deleted
      ON ${GalleryTables.images}(is_deleted, modified_at DESC)
    ''');

    // 核心索引：画廊扫描性能优化 - 文件路径
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_file_path
      ON ${GalleryTables.images}(file_path) WHERE is_deleted = 0
    ''');

    // 复合索引：多条件查询优化
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_composite
      ON ${GalleryTables.images}(is_deleted, is_favorite, modified_at DESC)
    ''');
  }

  /// 迁移：添加 last_scanned_at 列（如果缺失）
  Future<void> _migrateAddLastScannedAt(Database db) async {
    try {
      // 检查列是否存在
      final tableInfo = await db.rawQuery(
        'PRAGMA table_info(${GalleryTables.images})',
      );
      final hasColumn = tableInfo.any(
        (col) => col['name'] == 'last_scanned_at',
      );

      if (!hasColumn) {
        AppLogger.i(
          '[Migration] Adding last_scanned_at column to ${GalleryTables.images}',
          'GalleryDS',
        );
        await db.execute(
          'ALTER TABLE ${GalleryTables.images} ADD COLUMN last_scanned_at INTEGER',
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
      CREATE TABLE IF NOT EXISTS ${GalleryTables.metadata} (
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
        FOREIGN KEY (image_id) REFERENCES ${GalleryTables.images}(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_metadata_model
      ON ${GalleryTables.metadata}(model) WHERE model IS NOT NULL AND model != ''
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_metadata_sampler
      ON ${GalleryTables.metadata}(sampler) WHERE sampler IS NOT NULL AND sampler != ''
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_metadata_seed
      ON ${GalleryTables.metadata}(seed)
    ''');

    // 新增索引：全文搜索优化
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_metadata_prompt
      ON ${GalleryTables.metadata}(prompt) WHERE prompt IS NOT NULL AND prompt != ''
    ''');
  }

  Future<void> _createFavoritesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${GalleryTables.favorites} (
        image_id INTEGER PRIMARY KEY,
        favorited_at INTEGER NOT NULL,
        FOREIGN KEY (image_id) REFERENCES ${GalleryTables.images}(id) ON DELETE CASCADE
      )
    ''');

    // 新增索引：收藏时间排序
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_favorites_time
      ON ${GalleryTables.favorites}(favorited_at DESC)
    ''');
  }

  Future<void> _createTagsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${GalleryTables.tags} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        category TEXT,
        usage_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_tags_name
      ON ${GalleryTables.tags}(name)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_tags_category
      ON ${GalleryTables.tags}(category)
    ''');

    // 新增索引：使用频次排序
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_tags_usage
      ON ${GalleryTables.tags}(usage_count DESC)
    ''');
  }

  Future<void> _createImageTagsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${GalleryTables.imageTags} (
        image_id INTEGER NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (image_id, tag_id),
        FOREIGN KEY (image_id) REFERENCES ${GalleryTables.images}(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES ${GalleryTables.tags}(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_image_tags_tag_id
      ON ${GalleryTables.imageTags}(tag_id)
    ''');
  }

  Future<void> _createScanLogsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${GalleryTables.scanLogs} (
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
      ON ${GalleryTables.scanLogs}(started_at DESC)
    ''');
  }

  Future<void> _createFtsIndexTable(Database db) async {
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS ${GalleryTables.ftsIndex} USING fts5(
        image_id UNINDEXED,
        prompt_text,
        tokenize = 'porter'
      )
    ''');
  }

  Future<DataSourceHealth> checkHealth() async {
    return await gateway.execute('doCheckHealth', (db) async {
      final tables = [
        GalleryTables.images,
        GalleryTables.metadata,
        GalleryTables.favorites,
        GalleryTables.tags,
        GalleryTables.imageTags,
        GalleryTables.scanLogs,
        GalleryTables.ftsIndex,
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

      final imageCount = await _getTableCount(db, GalleryTables.images);
      final metadataCount = await _getTableCount(db, GalleryTables.metadata);
      final tagCount = await _getTableCount(db, GalleryTables.tags);

      return DataSourceHealth(
        status: HealthStatus.healthy,
        message: 'Gallery data source is healthy',
        details: {
          'imageCount': imageCount,
          'metadataCount': metadataCount,
          'tagCount': tagCount,
          'imageCacheSize': context.imageCacheSize,
          'queryCacheSize': context.queryCacheSize,
          'cacheHitRate': {
            'image': context.imageCacheHitRate,
            'query': context.queryCacheHitRate,
          },
          'slowQueryCount': context.slowQueryCount,
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

  Future<void> clear() async {
    context.clearCache();
    AppLogger.i('Gallery data source cleared', 'GalleryDS');
  }

  Future<void> restore() async {
    context.clearCache();
    AppLogger.i('Gallery data source ready for restore', 'GalleryDS');
  }
}
