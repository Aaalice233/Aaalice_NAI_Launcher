import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../data/models/gallery/local_image_record.dart'
    show MetadataStatus;
import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../../data/services/image_metadata_service.dart';
import '../../utils/app_logger.dart';
import '../base_data_source.dart';
import '../data_source.dart'
    show DataSourceHealth, DataSourceType, HealthStatus;
import '../utils/lru_cache.dart';

/// 画廊图片记录
///
/// 数据库实体模型，用于 SQLite 存储。
/// 注意：与 [LocalImageRecord] 不同，此模型专注于数据库持久化。
class GalleryImageRecord {
  final int? id;
  final String filePath;
  final String fileName;
  final int fileSize;
  final int? width;
  final int? height;
  final double? aspectRatio;
  final DateTime modifiedAt;
  final DateTime createdAt;
  final DateTime indexedAt;
  final DateTime? lastScannedAt;
  final int dateYmd;
  final String? resolutionKey;
  final MetadataStatus metadataStatus;
  final bool isFavorite;
  final bool isDeleted;

  const GalleryImageRecord({
    this.id,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    this.width,
    this.height,
    this.aspectRatio,
    required this.modifiedAt,
    required this.createdAt,
    required this.indexedAt,
    this.lastScannedAt,
    required this.dateYmd,
    this.resolutionKey,
    this.metadataStatus = MetadataStatus.none,
    this.isFavorite = false,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'file_path': filePath,
        'file_name': fileName,
        'file_size': fileSize,
        'width': width,
        'height': height,
        'aspect_ratio': aspectRatio,
        'modified_at': modifiedAt.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
        'indexed_at': indexedAt.millisecondsSinceEpoch,
        'last_scanned_at': lastScannedAt?.millisecondsSinceEpoch,
        'date_ymd': dateYmd,
        'resolution_key': resolutionKey,
        'metadata_status': metadataStatus.index,
        'is_favorite': isFavorite ? 1 : 0,
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory GalleryImageRecord.fromMap(Map<String, dynamic> map) {
    return GalleryImageRecord(
      id: (map['id'] as num?)?.toInt(),
      filePath: map['file_path'] as String? ?? map['path'] as String? ?? '',
      fileName: map['file_name'] as String? ?? '',
      fileSize: (map['file_size'] as num?)?.toInt() ??
          (map['size'] as num?)?.toInt() ??
          0,
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      aspectRatio: (map['aspect_ratio'] as num?)?.toDouble(),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['modified_at'] as num?)?.toInt() ?? 0,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
      indexedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['indexed_at'] as num?)?.toInt() ?? 0,
      ),
      lastScannedAt: map['last_scanned_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['last_scanned_at'] as num).toInt())
          : null,
      dateYmd: (map['date_ymd'] as num?)?.toInt() ?? 0,
      resolutionKey: map['resolution_key'] as String?,
      metadataStatus:
          MetadataStatus.values[(map['metadata_status'] as num?)?.toInt() ?? 2],
      isFavorite: (map['is_favorite'] as num?)?.toInt() == 1,
      isDeleted: (map['is_deleted'] as num?)?.toInt() == 1,
    );
  }

  GalleryImageRecord copyWith({
    int? id,
    String? filePath,
    String? fileName,
    int? fileSize,
    int? width,
    int? height,
    double? aspectRatio,
    DateTime? modifiedAt,
    DateTime? createdAt,
    DateTime? indexedAt,
    DateTime? lastScannedAt,
    int? dateYmd,
    String? resolutionKey,
    MetadataStatus? metadataStatus,
    bool? isFavorite,
    bool? isDeleted,
  }) {
    return GalleryImageRecord(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      width: width ?? this.width,
      height: height ?? this.height,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      createdAt: createdAt ?? this.createdAt,
      indexedAt: indexedAt ?? this.indexedAt,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      dateYmd: dateYmd ?? this.dateYmd,
      resolutionKey: resolutionKey ?? this.resolutionKey,
      metadataStatus: metadataStatus ?? this.metadataStatus,
      isFavorite: isFavorite ?? this.isFavorite,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  String toString() {
    return 'GalleryImageRecord(id: $id, path: $filePath, name: $fileName, '
        'size: $fileSize, modifiedAt: $modifiedAt, metadataStatus: $metadataStatus, '
        'lastScannedAt: $lastScannedAt)';
  }
}

/// 画廊元数据记录
class GalleryMetadataRecord {
  final int imageId;
  final String prompt;
  final String negativePrompt;
  final int? seed;
  final String? sampler;
  final int? steps;
  final double? scale;
  final int? width;
  final int? height;
  final String? model;
  final bool smea;
  final bool smeaDyn;
  final String? noiseSchedule;
  final double? cfgRescale;
  final int? ucPreset;
  final bool qualityToggle;
  final bool isImg2Img;
  final double? strength;
  final double? noise;
  final String? software;
  final String? source;
  final String? version;
  final String? rawJson;
  final String fullPromptText;

  const GalleryMetadataRecord({
    required this.imageId,
    required this.prompt,
    this.negativePrompt = '',
    this.seed,
    this.sampler,
    this.steps,
    this.scale,
    this.width,
    this.height,
    this.model,
    this.smea = false,
    this.smeaDyn = false,
    this.noiseSchedule,
    this.cfgRescale,
    this.ucPreset,
    this.qualityToggle = false,
    this.isImg2Img = false,
    this.strength,
    this.noise,
    this.software,
    this.source,
    this.version,
    this.rawJson,
    required this.fullPromptText,
  });

  Map<String, dynamic> toMap() => {
        'image_id': imageId,
        'prompt': prompt,
        'negative_prompt': negativePrompt,
        'seed': seed,
        'sampler': sampler,
        'steps': steps,
        'cfg_scale': scale,
        'width': width,
        'height': height,
        'model': model,
        'smea': smea ? 1 : 0,
        'smea_dyn': smeaDyn ? 1 : 0,
        'noise_schedule': noiseSchedule,
        'cfg_rescale': cfgRescale,
        'uc_preset': ucPreset,
        'quality_toggle': qualityToggle ? 1 : 0,
        'is_img2img': isImg2Img ? 1 : 0,
        'strength': strength,
        'noise': noise,
        'software': software,
        'source': source,
        'version': version,
        'raw_json': rawJson,
        'full_prompt_text': fullPromptText,
      };

  factory GalleryMetadataRecord.fromMap(Map<String, dynamic> map) {
    return GalleryMetadataRecord(
      imageId: (map['image_id'] as num).toInt(),
      prompt: map['prompt'] as String? ?? '',
      negativePrompt: map['negative_prompt'] as String? ?? '',
      seed: map['seed'] as int?,
      sampler: map['sampler'] as String?,
      steps: map['steps'] as int?,
      scale: (map['cfg_scale'] as num?)?.toDouble(),
      width: map['width'] as int?,
      height: map['height'] as int?,
      model: map['model'] as String?,
      smea: (map['smea'] as num?)?.toInt() == 1,
      smeaDyn: (map['smea_dyn'] as num?)?.toInt() == 1,
      noiseSchedule: map['noise_schedule'] as String?,
      cfgRescale: (map['cfg_rescale'] as num?)?.toDouble(),
      ucPreset: map['uc_preset'] as int?,
      qualityToggle: (map['quality_toggle'] as num?)?.toInt() == 1,
      isImg2Img: (map['is_img2img'] as num?)?.toInt() == 1,
      strength: (map['strength'] as num?)?.toDouble(),
      noise: (map['noise'] as num?)?.toDouble(),
      software: map['software'] as String?,
      source: map['source'] as String?,
      version: map['version'] as String?,
      rawJson: map['raw_json'] as String?,
      fullPromptText: map['full_prompt_text'] as String? ?? '',
    );
  }

  factory GalleryMetadataRecord.fromNaiMetadata(
    int imageId,
    NaiImageMetadata metadata,
  ) {
    return GalleryMetadataRecord(
      imageId: imageId,
      prompt: metadata.prompt,
      negativePrompt: metadata.negativePrompt,
      seed: metadata.seed,
      sampler: metadata.sampler,
      steps: metadata.steps,
      scale: metadata.scale,
      width: metadata.width,
      height: metadata.height,
      model: metadata.model,
      smea: metadata.smea ?? false,
      smeaDyn: metadata.smeaDyn ?? false,
      noiseSchedule: metadata.noiseSchedule,
      cfgRescale: metadata.cfgRescale,
      ucPreset: metadata.ucPreset,
      qualityToggle: metadata.qualityToggle ?? false,
      isImg2Img: metadata.isImg2Img,
      strength: metadata.strength,
      noise: metadata.noise,
      software: metadata.software,
      source: metadata.source,
      version: metadata.version,
      rawJson: metadata.rawJson,
      fullPromptText: metadata.fullPrompt,
    );
  }
}

/// 画廊标签记录
class GalleryTagRecord {
  final String id;
  final String name;
  final String? category;
  final int usageCount;

  const GalleryTagRecord({
    required this.id,
    required this.name,
    this.category,
    this.usageCount = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'usage_count': usageCount,
      };

  factory GalleryTagRecord.fromMap(Map<String, dynamic> map) {
    return GalleryTagRecord(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String?,
      usageCount: (map['usage_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 扫描日志记录
class ScanLogRecord {
  final String id;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int totalFiles;
  final int processedFiles;
  final int newFiles;
  final int updatedFiles;
  final int failedFiles;
  final String? errorMessage;
  final String? scanPath;

  const ScanLogRecord({
    required this.id,
    required this.startedAt,
    this.completedAt,
    this.totalFiles = 0,
    this.processedFiles = 0,
    this.newFiles = 0,
    this.updatedFiles = 0,
    this.failedFiles = 0,
    this.errorMessage,
    this.scanPath,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'started_at': startedAt.millisecondsSinceEpoch,
        'completed_at': completedAt?.millisecondsSinceEpoch,
        'total_files': totalFiles,
        'processed_files': processedFiles,
        'new_files': newFiles,
        'updated_files': updatedFiles,
        'failed_files': failedFiles,
        'error_message': errorMessage,
        'scan_path': scanPath,
      };

  factory ScanLogRecord.fromMap(Map<String, dynamic> map) {
    return ScanLogRecord(
      id: map['id'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['started_at'] as num?)?.toInt() ?? 0,
      ),
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['completed_at'] as num).toInt(),
            )
          : null,
      totalFiles: (map['total_files'] as num?)?.toInt() ?? 0,
      processedFiles: (map['processed_files'] as num?)?.toInt() ?? 0,
      newFiles: (map['new_files'] as num?)?.toInt() ?? 0,
      updatedFiles: (map['updated_files'] as num?)?.toInt() ?? 0,
      failedFiles: (map['failed_files'] as num?)?.toInt() ?? 0,
      errorMessage: map['error_message'] as String?,
      scanPath: map['scan_path'] as String?,
    );
  }
}

/// 慢查询日志记录
class SlowQueryLog {
  final String operation;
  final int durationMs;
  final DateTime timestamp;
  final String? details;

  const SlowQueryLog({
    required this.operation,
    required this.durationMs,
    required this.timestamp,
    this.details,
  });
}

/// 查询缓存键
class _QueryCacheKey {
  final String queryType;
  final Map<String, dynamic> params;

  const _QueryCacheKey(this.queryType, this.params);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _QueryCacheKey &&
        other.queryType == queryType &&
        _mapEquals(other.params, params);
  }

  @override
  int get hashCode => Object.hash(queryType, _mapHash(params));

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static int _mapHash(Map<String, dynamic> map) {
    return Object.hashAll(map.entries.map((e) => Object.hash(e.key, e.value)));
  }
}

/// 画廊数据源
///
/// 管理本地图片画廊的数据存储和查询，支持图片元数据、标签、收藏和全文搜索。
class GalleryDataSource extends EnhancedBaseDataSource {
  static final GalleryDataSource _instance = GalleryDataSource._internal();
  factory GalleryDataSource() => _instance;
  GalleryDataSource._internal();

  static const int _maxImageCacheSize = 500;
  static const int _maxQueryCacheSize = 100;
  static const int _slowQueryThresholdMs = 500;

  static const String _imagesTable = 'gallery_images';
  static const String _metadataTable = 'gallery_metadata';
  static const String _favoritesTable = 'gallery_favorites';
  static const String _tagsTable = 'gallery_tags';
  static const String _imageTagsTable = 'gallery_image_tags';
  static const String _scanLogsTable = 'gallery_scan_logs';
  static const String _ftsIndexTable = 'gallery_fts_index';

  // LRU 缓存
  final LRUCache<int, GalleryImageRecord> _imageCache =
      LRUCache(maxSize: _maxImageCacheSize);
  final LRUCache<_QueryCacheKey, List<dynamic>> _queryCache =
      LRUCache(maxSize: _maxQueryCacheSize);
  final Set<int> _favoriteCache = <int>{};
  bool _favoritesLoaded = false;

  // 慢查询日志
  final List<SlowQueryLog> _slowQueryLogs = [];
  static const int _maxSlowQueryLogs = 100;

  @override
  String get name => 'gallery';

  @override
  DataSourceType get type => DataSourceType.gallery;

  @override
  Set<String> get dependencies => {};

  /// 清除所有缓存
  void clearCache() {
    _imageCache.clear();
    _queryCache.clear();
    _favoriteCache.clear();
    _favoritesLoaded = false;
    _slowQueryLogs.clear();
    AppLogger.i('Gallery cache cleared', 'GalleryDS');
  }

  /// 清除查询缓存
  void clearQueryCache() {
    _queryCache.clear();
    AppLogger.d('Gallery query cache cleared', 'GalleryDS');
  }

  /// 获取缓存统计
  Map<String, dynamic> getCacheStatistics() => {
        'imageCache': _imageCache.statistics,
        'queryCache': _queryCache.statistics,
        'favoriteCacheSize': _favoriteCache.length,
        'slowQueryCount': _slowQueryLogs.length,
      };

  /// 获取慢查询日志
  List<SlowQueryLog> getSlowQueryLogs() => List.unmodifiable(_slowQueryLogs);

  /// 记录慢查询
  void _logSlowQuery(String operation, int durationMs, {String? details}) {
    if (durationMs < _slowQueryThresholdMs) return;

    final log = SlowQueryLog(
      operation: operation,
      durationMs: durationMs,
      timestamp: DateTime.now(),
      details: details,
    );

    _slowQueryLogs.add(log);
    if (_slowQueryLogs.length > _maxSlowQueryLogs) {
      _slowQueryLogs.removeAt(0);
    }

    AppLogger.w('Slow query: $operation took ${durationMs}ms', 'GalleryDS');
  }

  /// 包装查询并记录性能
  Future<T> _trackQuery<T>(
    String operation,
    Future<T> Function() query, {
    String? details,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await query();
    } finally {
      stopwatch.stop();
      _logSlowQuery(operation, stopwatch.elapsedMilliseconds, details: details);
    }
  }

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

      AppLogger.i('Gallery tables initialized', 'GalleryDS');
    });
  }

  Future<void> _createImagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_imagesTable (
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
      ON $_imagesTable(modified_at DESC)
    ''');

    // 核心索引：按创建时间排序
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_created_at
      ON $_imagesTable(created_at DESC)
    ''');

    // 核心索引：按 ID 主键查询
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_id_deleted
      ON $_imagesTable(id) WHERE is_deleted = 0
    ''');

    // 核心索引：按日期分组
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_date_ymd
      ON $_imagesTable(date_ymd DESC) WHERE is_deleted = 0
    ''');

    // 核心索引：收藏过滤
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_favorite
      ON $_imagesTable(is_favorite, modified_at DESC) WHERE is_deleted = 0
    ''');

    // 核心索引：元数据状态过滤
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_metadata_status
      ON $_imagesTable(metadata_status) WHERE is_deleted = 0
    ''');

    // 核心索引：is_deleted 过滤（软删除）
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_is_deleted
      ON $_imagesTable(is_deleted, modified_at DESC)
    ''');

    // 核心索引：画廊扫描性能优化 - 文件路径
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_file_path
      ON $_imagesTable(file_path) WHERE is_deleted = 0
    ''');

    // 复合索引：多条件查询优化
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_images_composite
      ON $_imagesTable(is_deleted, is_favorite, modified_at DESC)
    ''');
  }

  Future<void> _createMetadataTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_metadataTable (
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
        FOREIGN KEY (image_id) REFERENCES $_imagesTable(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_metadata_model
      ON $_metadataTable(model) WHERE model IS NOT NULL AND model != ''
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_metadata_sampler
      ON $_metadataTable(sampler) WHERE sampler IS NOT NULL AND sampler != ''
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_metadata_seed
      ON $_metadataTable(seed)
    ''');

    // 新增索引：全文搜索优化
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_metadata_prompt
      ON $_metadataTable(prompt) WHERE prompt IS NOT NULL AND prompt != ''
    ''');
  }

  Future<void> _createFavoritesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_favoritesTable (
        image_id INTEGER PRIMARY KEY,
        favorited_at INTEGER NOT NULL,
        FOREIGN KEY (image_id) REFERENCES $_imagesTable(id) ON DELETE CASCADE
      )
    ''');

    // 新增索引：收藏时间排序
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_favorites_time
      ON $_favoritesTable(favorited_at DESC)
    ''');
  }

  Future<void> _createTagsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tagsTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        category TEXT,
        usage_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_tags_name
      ON $_tagsTable(name)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_tags_category
      ON $_tagsTable(category)
    ''');

    // 新增索引：使用频次排序
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_tags_usage
      ON $_tagsTable(usage_count DESC)
    ''');
  }

  Future<void> _createImageTagsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_imageTagsTable (
        image_id INTEGER NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (image_id, tag_id),
        FOREIGN KEY (image_id) REFERENCES $_imagesTable(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES $_tagsTable(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gallery_image_tags_tag_id
      ON $_imageTagsTable(tag_id)
    ''');
  }

  Future<void> _createScanLogsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_scanLogsTable (
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
      ON $_scanLogsTable(started_at DESC)
    ''');
  }

  Future<void> _createFtsIndexTable(Database db) async {
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS $_ftsIndexTable USING fts5(
        image_id UNINDEXED,
        prompt_text,
        tokenize = 'porter'
      )
    ''');
  }

  @override
  Future<DataSourceHealth> doCheckHealth() async {
    return await execute('doCheckHealth', (db) async {
      final tables = [
        _imagesTable,
        _metadataTable,
        _favoritesTable,
        _tagsTable,
        _imageTagsTable,
        _scanLogsTable,
        _ftsIndexTable,
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

      final imageCount = await _getTableCount(db, _imagesTable);
      final metadataCount = await _getTableCount(db, _metadataTable);
      final tagCount = await _getTableCount(db, _tagsTable);

      return DataSourceHealth(
        status: HealthStatus.healthy,
        message: 'Gallery data source is healthy',
        details: {
          'imageCount': imageCount,
          'metadataCount': metadataCount,
          'tagCount': tagCount,
          'imageCacheSize': _imageCache.size,
          'queryCacheSize': _queryCache.size,
          'cacheHitRate': {
            'image': _imageCache.hitRate,
            'query': _queryCache.hitRate,
          },
          'slowQueryCount': _slowQueryLogs.length,
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
    clearCache();
    AppLogger.i('Gallery data source cleared', 'GalleryDS');
  }

  @override
  Future<void> doRestore() async {
    clearCache();
    AppLogger.i('Gallery data source ready for restore', 'GalleryDS');
  }

  // ============================================================
  // 图片记录 CRUD 操作
  // ============================================================

  Future<int> upsertImage({
    required String filePath,
    required String fileName,
    required int fileSize,
    int? width,
    int? height,
    double? aspectRatio,
    required DateTime createdAt,
    required DateTime modifiedAt,
    String? resolutionKey,
    MetadataStatus? metadataStatus,
    bool? isFavorite,
    DateTime? lastScannedAt,
  }) async {
    return execute(
      'upsertImage',
      (db) async {
        final dateYmd = _formatDateYmd(modifiedAt);
        final now = DateTime.now();

        final existingResult = await db.rawQuery(
          'SELECT id FROM $_imagesTable WHERE file_path = ?',
          [filePath],
        );
        final existingId = existingResult.isNotEmpty
            ? (existingResult.first['id'] as num?)?.toInt()
            : null;

        if (existingId != null) {
          _imageCache.remove(existingId);
        }

        final map = {
          'file_path': filePath,
          'file_name': fileName,
          'file_size': fileSize,
          'width': width,
          'height': height,
          'aspect_ratio': aspectRatio,
          'created_at': createdAt.millisecondsSinceEpoch,
          'modified_at': modifiedAt.millisecondsSinceEpoch,
          'indexed_at': now.millisecondsSinceEpoch,
          'last_scanned_at': lastScannedAt?.millisecondsSinceEpoch,
          'date_ymd': dateYmd,
          'resolution_key': resolutionKey,
          'metadata_status': (metadataStatus ?? MetadataStatus.none).index,
          'is_favorite': (isFavorite ?? false) ? 1 : 0,
          'is_deleted': 0,
        };

        if (existingId != null) {
          map['id'] = existingId;
        }

        final id = await db.insert(
          _imagesTable,
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // 【优化】高频操作不记录，避免日志刷屏
        // AppLogger.d('Upserted image: $fileName (id=$id)', 'GalleryDS');
        return id;
      },
      timeout: const Duration(seconds: 30),
      maxRetries: 3,
    );
  }

  Future<int?> getImageIdByPath(String filePath) async {
    try {
      return await execute(
        'getImageIdByPath',
        (db) async {
          final result = await db.rawQuery(
            'SELECT id FROM $_imagesTable WHERE file_path = ? AND is_deleted = 0',
            [filePath],
          );

          if (result.isEmpty) return null;
          return (result.first['id'] as num?)?.toInt();
        },
        timeout: const Duration(seconds: 10),
        maxRetries: 3,
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get image ID by path: $filePath',
        e,
        stack,
        'GalleryDS',
      );
      return null;
    }
  }

  Future<void> updateFilePath(
    int imageId,
    String newPath, {
    String? newFileName,
  }) async {
    try {
      await execute(
        'updateFilePath',
        (db) async {
          final fileName = newFileName ?? newPath.split(Platform.pathSeparator).last;

          await db.update(
            _imagesTable,
            {
              'file_path': newPath,
              'file_name': fileName,
              'indexed_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [imageId],
          );

          _imageCache.remove(imageId);
        },
        timeout: const Duration(seconds: 10),
        maxRetries: 3,
      );

      AppLogger.d('Updated file path for image $imageId: $newPath', 'GalleryDS');
    } catch (e, stack) {
      AppLogger.e(
        'Failed to update file path for image $imageId: $newPath',
        e,
        stack,
        'GalleryDS',
      );
      rethrow;
    }
  }

  Future<Map<String, int?>> getImageIdsByPaths(List<String> filePaths) async {
    if (filePaths.isEmpty) return {};

    return _trackQuery(
      'getImageIdsByPaths',
      () async {
        try {
          final result = <String, int?>{};
          const batchSize = 900;
          final chunks = chunk(filePaths, batchSize);

          for (final chunk in chunks) {
            await execute(
              'getImageIdsByPaths',
              (db) async {
                final placeholders = List.filled(chunk.length, '?').join(',');

                final dbResult = await db.rawQuery(
                  '''
                  SELECT id, file_path FROM $_imagesTable
                  WHERE file_path IN ($placeholders) AND is_deleted = 0
                  ''',
                  chunk,
                );

                for (final row in dbResult) {
                  final path = row['file_path'] as String?;
                  if (path == null) continue;
                  final id = (row['id'] as num?)?.toInt();
                  result[path] = id;
                }
              },
              timeout: const Duration(seconds: 30),
              maxRetries: 3,
            );
          }

          for (final path in filePaths) {
            result.putIfAbsent(path, () => null);
          }

          return result;
        } catch (e, stack) {
          AppLogger.e(
            'Failed to get image IDs by paths: ${filePaths.length} paths',
            e,
            stack,
            'GalleryDS',
          );
          return {for (final path in filePaths) path: null};
        }
      },
      details: '${filePaths.length} paths',
    );
  }

  Future<GalleryImageRecord?> getImageById(int id) async {
    final cached = _imageCache.get(id);
    if (cached != null) {
      return cached;
    }

    try {
      return await execute(
        'getImageById',
        (db) async {
          final result = await db.rawQuery(
            '''
            SELECT * FROM $_imagesTable
            WHERE id = ? AND is_deleted = 0
            ''',
            [id],
          );

          if (result.isEmpty) return null;

          final record = GalleryImageRecord.fromMap(result.first);
          _imageCache.put(id, record);

          return record;
        },
        timeout: const Duration(seconds: 10),
        maxRetries: 3,
      );
    } catch (e, stack) {
      AppLogger.e('Failed to get image by ID: $id', e, stack, 'GalleryDS');
      return null;
    }
  }

  Future<List<GalleryImageRecord>> getImagesByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    final results = <GalleryImageRecord>[];
    final missingIds = <int>[];

    // 从缓存中获取
    for (final id in ids) {
      final cached = _imageCache.get(id);
      if (cached != null) {
        results.add(cached);
      } else {
        missingIds.add(id);
      }
    }

    return _trackQuery(
      'getImagesByIds',
      () async {
        // 批量查询缺失的 ID
        if (missingIds.isNotEmpty) {
          const batchSize = 900;
          final chunks = chunk(missingIds, batchSize);

          for (final batch in chunks) {
            await execute(
              'getImagesByIds.batch',
              (db) async {
                try {
                  final placeholders = List.filled(batch.length, '?').join(',');

                  final dbResults = await db.rawQuery(
                    '''
                    SELECT * FROM $_imagesTable
                    WHERE id IN ($placeholders) AND is_deleted = 0
                    ''',
                    batch,
                  );

                  for (final row in dbResults) {
                    final record = GalleryImageRecord.fromMap(row);
                    results.add(record);

                    if (record.id != null) {
                      _imageCache.put(record.id!, record);
                    }
                  }
                } catch (e, stack) {
                  AppLogger.e('Failed to get images by IDs', e, stack, 'GalleryDS');
                }
              },
              timeout: const Duration(seconds: 30),
              maxRetries: 3,
            );
          }
        }

        // 按原始顺序排序
        final idIndexMap = {for (var i = 0; i < ids.length; i++) ids[i]: i};
        results.sort((a, b) {
          final indexA = idIndexMap[a.id] ?? 0;
          final indexB = idIndexMap[b.id] ?? 0;
          return indexA.compareTo(indexB);
        });

        return results;
      },
      details: '${ids.length} IDs, ${missingIds.length} missing',
    );
  }

  Future<List<GalleryImageRecord>> queryImages({
    int limit = 50,
    int offset = 0,
    String orderBy = 'modified_at',
    bool descending = true,
  }) async {
    // 缓存键
    final cacheKey = _QueryCacheKey('queryImages', {
      'limit': limit,
      'offset': offset,
      'orderBy': orderBy,
      'descending': descending,
    });

    // 检查缓存
    final cached = _queryCache.get(cacheKey);
    if (cached != null) {
      return cached.cast<GalleryImageRecord>();
    }

    return _trackQuery(
      'queryImages',
      () async {
        return await execute('queryImages', (db) async {
          try {
            final validColumns = {
              'modified_at',
              'created_at',
              'indexed_at',
              'file_name',
              'file_size',
              'id',
            };
            final safeOrderBy =
                validColumns.contains(orderBy) ? orderBy : 'modified_at';
            final orderDirection = descending ? 'DESC' : 'ASC';

            final results = await db.rawQuery(
              '''
              SELECT * FROM $_imagesTable
              WHERE is_deleted = 0
              ORDER BY $safeOrderBy $orderDirection
              LIMIT ? OFFSET ?
              ''',
              [limit, offset],
            );

            final records = results.map((row) => GalleryImageRecord.fromMap(row)).toList();

            // 更新缓存
            _queryCache.put(cacheKey, records);

            return records;
          } catch (e, stack) {
            AppLogger.e('Failed to query images', e, stack, 'GalleryDS');
            return [];
          }
        });
      },
      details: 'limit=$limit, offset=$offset',
    );
  }

  Future<void> markAsDeleted(String filePath) async {
    await execute('markAsDeleted', (db) async {
      try {
        final result = await db.rawQuery(
          'SELECT id FROM $_imagesTable WHERE file_path = ?',
          [filePath],
        );

        if (result.isNotEmpty) {
          final id = (result.first['id'] as num?)?.toInt();
          if (id != null) {
            _imageCache.remove(id);
          }
        }

        await db.update(
          _imagesTable,
          {'is_deleted': 1},
          where: 'file_path = ?',
          whereArgs: [filePath],
        );

        // 清除相关查询缓存
        clearQueryCache();

        AppLogger.d('Marked as deleted: $filePath', 'GalleryDS');
      } catch (e, stack) {
        AppLogger.e(
          'Failed to mark as deleted: $filePath',
          e,
          stack,
          'GalleryDS',
        );
        rethrow;
      }
    });
  }

  /// 优化的批量 upsert 方法
  ///
  /// 解决 N+1 问题：使用预处理语句批量查询现有记录
  Future<List<int>> batchUpsertImages(
    List<GalleryImageRecord> records, {
    int batchSize = 50,
  }) async {
    if (records.isEmpty) return [];

    return _trackQuery(
      'batchUpsertImages',
      () async {
        final results = <int>[];
        final now = DateTime.now();

        // 按批次处理
        for (var i = 0; i < records.length; i += batchSize) {
          final end = (i + batchSize < records.length) ? i + batchSize : records.length;
          final batch = records.sublist(i, end);
          final batchIndex = i ~/ batchSize;

          final batchResults = await executeTransaction(
            'batchUpsertImages#batch$batchIndex',
            (txn) async {
              final batchIds = <int>[];

              // 1. 批量查询现有记录（一次查询）
              final filePaths = batch.map((r) => r.filePath).toList();
              final placeholders = List.filled(filePaths.length, '?').join(',');
              final existingResults = await txn.rawQuery(
                '''
                SELECT id, file_path FROM $_imagesTable
                WHERE file_path IN ($placeholders)
                ''',
                filePaths,
              );

              // 构建路径到 ID 的映射
              final pathToIdMap = <String, int>{};
              for (final row in existingResults) {
                final path = row['file_path'] as String?;
                final id = (row['id'] as num?)?.toInt();
                if (path != null && id != null) {
                  pathToIdMap[path] = id;
                }
              }

              // 2. 批量插入/更新
              for (final record in batch) {
                final dateYmd = _formatDateYmd(record.modifiedAt);
                final existingId = pathToIdMap[record.filePath];

                if (existingId != null) {
                  _imageCache.remove(existingId);
                }

                final map = {
                  'file_path': record.filePath,
                  'file_name': record.fileName,
                  'file_size': record.fileSize,
                  'width': record.width,
                  'height': record.height,
                  'aspect_ratio': record.aspectRatio,
                  'created_at': record.createdAt.millisecondsSinceEpoch,
                  'modified_at': record.modifiedAt.millisecondsSinceEpoch,
                  'indexed_at': now.millisecondsSinceEpoch,
                  'date_ymd': dateYmd,
                  'resolution_key': record.resolutionKey,
                  'metadata_status': record.metadataStatus.index,
                  'is_favorite': record.isFavorite ? 1 : 0,
                  'is_deleted': record.isDeleted ? 1 : 0,
                };

                if (existingId != null) {
                  map['id'] = existingId;
                }

                final id = await txn.insert(
                  _imagesTable,
                  map,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );

                batchIds.add(id);
              }

              return batchIds;
            },
            timeout: const Duration(seconds: 60),
          );

          results.addAll(batchResults);

          if (end < records.length) {
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }

        // 清除查询缓存
        clearQueryCache();

        AppLogger.i(
          'Batch upserted ${records.length} images in ${(records.length / batchSize).ceil()} batches',
          'GalleryDS',
        );

        return results;
      },
      details: '${records.length} records',
    );
  }

  Future<void> batchMarkAsDeleted(List<String> filePaths) async {
    if (filePaths.isEmpty) return;

    await execute('batchMarkAsDeleted', (db) async {
      try {
        await db.transaction((txn) async {
          final batch = txn.batch();

          for (final path in filePaths) {
            batch.update(
              _imagesTable,
              {'is_deleted': 1},
              where: 'file_path = ?',
              whereArgs: [path],
            );
          }

          await batch.commit(noResult: true);
        });

        // 更新缓存
        final pathToIdMap = await getImageIdsByPaths(filePaths);
        for (final entry in pathToIdMap.entries) {
          final id = entry.value;
          if (id != null) {
            _imageCache.remove(id);
          }
        }

        // 清除查询缓存
        clearQueryCache();

        AppLogger.d(
          'Batch marked as deleted: ${filePaths.length} files',
          'GalleryDS',
        );
      } catch (e, stack) {
        AppLogger.e('Failed to batch mark as deleted', e, stack, 'GalleryDS');
        rethrow;
      }
    });
  }

  Future<int> countImages({bool includeDeleted = false}) async {
    return await execute('countImages', (db) async {
      try {
        String sql = 'SELECT COUNT(*) as count FROM $_imagesTable';
        if (!includeDeleted) {
          sql += ' WHERE is_deleted = 0';
        }

        final result = await db.rawQuery(sql);
        return (result.first['count'] as num?)?.toInt() ?? 0;
      } catch (e, stack) {
        AppLogger.e('Failed to count images', e, stack, 'GalleryDS');
        return 0;
      }
    });
  }

  int _formatDateYmd(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  @override
  Future<void> doDispose() async {
    clearCache();
    AppLogger.i('Gallery data source disposed', 'GalleryDS');
  }

  // ============================================================
  // 元数据操作
  // ============================================================

  Future<void> upsertMetadata(int imageId, NaiImageMetadata metadata) async {
    try {
      final fullPromptText = _buildFullPromptText(metadata);

      await execute(
        'upsertMetadata',
        (db) async {
          await db.insert(
            _metadataTable,
            {
              'image_id': imageId,
              'prompt': metadata.prompt,
              'negative_prompt': metadata.negativePrompt,
              'seed': metadata.seed,
              'sampler': metadata.sampler,
              'steps': metadata.steps,
              'cfg_scale': metadata.scale,
              'width': metadata.width,
              'height': metadata.height,
              'model': metadata.model,
              'smea': metadata.smea == true ? 1 : 0,
              'smea_dyn': metadata.smeaDyn == true ? 1 : 0,
              'noise_schedule': metadata.noiseSchedule,
              'cfg_rescale': metadata.cfgRescale,
              'uc_preset': metadata.ucPreset,
              'quality_toggle': metadata.qualityToggle == true ? 1 : 0,
              'is_img2img': metadata.isImg2Img ? 1 : 0,
              'strength': metadata.strength,
              'noise': metadata.noise,
              'software': metadata.software,
              'source': metadata.source,
              'version': metadata.version,
              'raw_json': metadata.rawJson,
              'has_metadata': metadata.hasData ? 1 : 0,
              'full_prompt_text': fullPromptText,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        },
        timeout: const Duration(seconds: 30),
        maxRetries: 3,
      );

      await _updateFtsIndex(imageId, fullPromptText);

      // 【优化】高频操作不记录，避免日志刷屏
      // AppLogger.d('Upserted metadata for image: $imageId', 'GalleryDS');
    } catch (e, stack) {
      AppLogger.e('Failed to upsert metadata: $imageId', e, stack, 'GalleryDS');
      rethrow;
    }
  }

  String _buildFullPromptText(NaiImageMetadata metadata) {
    final buffer = StringBuffer();
    buffer.write(metadata.prompt);
    if (metadata.negativePrompt.isNotEmpty) {
      buffer.write(' ');
      buffer.write(metadata.negativePrompt);
    }
    for (final cp in metadata.characterPrompts) {
      if (cp.isNotEmpty) {
        buffer.write(' ');
        buffer.write(cp);
      }
    }
    return buffer.toString();
  }

  Future<void> _updateFtsIndex(int imageId, String promptText) async {
    await execute(
      '_updateFtsIndex',
      (db) async {
        try {
          await db.delete(
            _ftsIndexTable,
            where: 'image_id = ?',
            whereArgs: [imageId],
          );

          await db.insert(_ftsIndexTable, {
            'image_id': imageId,
            'prompt_text': promptText,
          });
        } catch (e) {
          AppLogger.w(
            'Failed to update FTS index for image $imageId: $e',
            'GalleryDS',
          );
        }
      },
      timeout: const Duration(seconds: 5),
      maxRetries: 1,
    );
  }

  Future<void> batchUpsertMetadata(
    List<MapEntry<int, NaiImageMetadata>> metadataList, {
    int batchSize = 50,
  }) async {
    if (metadataList.isEmpty) return;

    for (var i = 0; i < metadataList.length; i += batchSize) {
      final end = (i + batchSize < metadataList.length)
          ? i + batchSize
          : metadataList.length;
      final batch = metadataList.sublist(i, end);
      final batchIndex = i ~/ batchSize;

      await executeTransaction(
        'batchUpsertMetadata#batch$batchIndex',
        (txn) async {
          final ftsUpdates = <int, String>{};

          for (final entry in batch) {
            final imageId = entry.key;
            final metadata = entry.value;
            final fullPromptText = _buildFullPromptText(metadata);

            await txn.insert(
              _metadataTable,
              {
                'image_id': imageId,
                'prompt': metadata.prompt,
                'negative_prompt': metadata.negativePrompt,
                'seed': metadata.seed,
                'sampler': metadata.sampler,
                'steps': metadata.steps,
                'cfg_scale': metadata.scale,
                'width': metadata.width,
                'height': metadata.height,
                'model': metadata.model,
                'smea': metadata.smea == true ? 1 : 0,
                'smea_dyn': metadata.smeaDyn == true ? 1 : 0,
                'noise_schedule': metadata.noiseSchedule,
                'cfg_rescale': metadata.cfgRescale,
                'uc_preset': metadata.ucPreset,
                'quality_toggle': metadata.qualityToggle == true ? 1 : 0,
                'is_img2img': metadata.isImg2Img ? 1 : 0,
                'strength': metadata.strength,
                'noise': metadata.noise,
                'software': metadata.software,
                'source': metadata.source,
                'version': metadata.version,
                'raw_json': metadata.rawJson,
                'has_metadata': metadata.hasData ? 1 : 0,
                'full_prompt_text': fullPromptText,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            ftsUpdates[imageId] = fullPromptText;
          }

          await _batchUpdateFtsIndex(txn, ftsUpdates);
        },
        timeout: const Duration(seconds: 60),
      );

      if (end < metadataList.length) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    AppLogger.i(
      'Batch upserted ${metadataList.length} metadata in ${(metadataList.length / batchSize).ceil()} batches',
      'GalleryDS',
    );
  }

  Future<void> _batchUpdateFtsIndex(
    Transaction txn,
    Map<int, String> updates,
  ) async {
    if (updates.isEmpty) return;

    try {
      final placeholders = List.filled(updates.length, '?').join(',');
      await txn.rawDelete(
        'DELETE FROM $_ftsIndexTable WHERE image_id IN ($placeholders)',
        updates.keys.toList(),
      );

      final batch = txn.batch();
      for (final entry in updates.entries) {
        batch.insert(_ftsIndexTable, {
          'image_id': entry.key,
          'prompt_text': entry.value,
        });
      }
      await batch.commit(noResult: true);
    } catch (e) {
      AppLogger.w('Failed to batch update FTS index: $e', 'GalleryDS');
    }
  }

  Future<GalleryMetadataRecord?> getMetadataByImageId(int imageId) async {
    try {
      // 1. 先从 ImageMetadataService 获取（统一缓存）
      final imageRecord = await getImageById(imageId);
      if (imageRecord != null) {
        final metadata = await ImageMetadataService().getMetadata(imageRecord.filePath);
        if (metadata != null && metadata.hasData) {
          return GalleryMetadataRecord.fromNaiMetadata(imageId, metadata);
        }
      }

      // 2. 回退到数据库查询
      return await execute(
        'getMetadataByImageId',
        (db) async {
          final result = await db.rawQuery(
            '''
            SELECT * FROM $_metadataTable
            WHERE image_id = ?
            ''',
            [imageId],
          );

          if (result.isEmpty) return null;

          return GalleryMetadataRecord.fromMap(result.first);
        },
        timeout: const Duration(seconds: 10),
        maxRetries: 3,
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get metadata by image ID: $imageId',
        e,
        stack,
        'GalleryDS',
      );
      return null;
    }
  }

  Future<Map<int, GalleryMetadataRecord?>> getMetadataByImageIds(
    List<int> imageIds,
  ) async {
    if (imageIds.isEmpty) return {};

    return _trackQuery(
      'getMetadataByImageIds',
      () async {
        final results = <int, GalleryMetadataRecord?>{};

        try {
          // 直接从数据库批量查询
          const batchSize = 900;
          final chunks = chunk(imageIds, batchSize);

          for (final batch in chunks) {
            await execute(
              'getMetadataByImageIds',
              (db) async {
                final placeholders = List.filled(batch.length, '?').join(',');

                final dbResults = await db.rawQuery(
                  '''
                  SELECT * FROM $_metadataTable
                  WHERE image_id IN ($placeholders)
                  ''',
                  batch,
                );

                for (final id in batch) {
                  results[id] = null;
                }

                for (final row in dbResults) {
                  final record = GalleryMetadataRecord.fromMap(row);
                  results[record.imageId] = record;
                }
              },
              timeout: const Duration(seconds: 30),
              maxRetries: 3,
            );
          }
        } catch (e, stack) {
          AppLogger.e(
            'Failed to get metadata by image IDs: ${imageIds.length} IDs',
            e,
            stack,
            'GalleryDS',
          );
          for (final id in imageIds) {
            results.putIfAbsent(id, () => null);
          }
        }

        return results;
      },
      details: '${imageIds.length} IDs',
    );
  }

  // ============================================================
  // 收藏操作
  // ============================================================

  Future<bool> toggleFavorite(int imageId) async {
    return await execute(
      'toggleFavorite',
      (db) async {
        final exists = await db.rawQuery(
          'SELECT 1 FROM $_favoritesTable WHERE image_id = ?',
          [imageId],
        );

        final isCurrentlyFavorite = exists.isNotEmpty;

        if (isCurrentlyFavorite) {
          await db.delete(
            _favoritesTable,
            where: 'image_id = ?',
            whereArgs: [imageId],
          );
          _favoriteCache.remove(imageId);
          AppLogger.d('Removed favorite: $imageId', 'GalleryDS');
          return false;
        } else {
          await db.insert(_favoritesTable, {
            'image_id': imageId,
            'favorited_at': DateTime.now().millisecondsSinceEpoch,
          });
          _favoriteCache.add(imageId);
          AppLogger.d('Added favorite: $imageId', 'GalleryDS');
          return true;
        }
      },
      timeout: const Duration(seconds: 10),
      maxRetries: 3,
    );
  }

  Future<bool> isFavorite(int imageId) async {
    if (_favoritesLoaded) {
      return _favoriteCache.contains(imageId);
    }

    return await execute(
      'isFavorite',
      (db) async {
        final result = await db.rawQuery(
          'SELECT 1 FROM $_favoritesTable WHERE image_id = ?',
          [imageId],
        );
        return result.isNotEmpty;
      },
      timeout: const Duration(seconds: 5),
      maxRetries: 2,
    );
  }

  Future<void> loadFavoritesCache() async {
    if (_favoritesLoaded) return;

    await execute(
      'loadFavoritesCache',
      (db) async {
        final results = await db.rawQuery(
          'SELECT image_id FROM $_favoritesTable',
        );

        _favoriteCache.clear();
        for (final row in results) {
          final id = (row['image_id'] as num?)?.toInt();
          if (id != null) {
            _favoriteCache.add(id);
          }
        }

        _favoritesLoaded = true;
        AppLogger.i(
          'Loaded ${_favoriteCache.length} favorites into cache',
          'GalleryDS',
        );
      },
      timeout: const Duration(seconds: 15),
      maxRetries: 2,
    );
  }

  Future<int> getFavoriteCount() async {
    if (_favoritesLoaded) {
      return _favoriteCache.length;
    }

    return await execute(
      'getFavoriteCount',
      (db) async {
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $_favoritesTable',
        );
        return (result.first['count'] as num?)?.toInt() ?? 0;
      },
      timeout: const Duration(seconds: 10),
      maxRetries: 3,
    );
  }

  Future<List<int>> getFavoriteImageIds() async {
    await loadFavoritesCache();
    return _favoriteCache.toList();
  }

  Future<Map<int, bool>> getFavoritesByImageIds(List<int> imageIds) async {
    if (imageIds.isEmpty) return {};

    try {
      final favoritesMap = <int, bool>{
        for (final id in imageIds) id: false,
      };

      const batchSize = 900;
      final chunks = chunk(imageIds, batchSize);

      for (final chunk in chunks) {
        await execute(
          'getFavoritesByImageIds',
          (db) async {
            final placeholders = List.filled(chunk.length, '?').join(',');

            final result = await db.rawQuery(
              '''
              SELECT image_id FROM $_favoritesTable
              WHERE image_id IN ($placeholders)
              ''',
              chunk,
            );

            for (final row in result) {
              final id = (row['image_id'] as num?)?.toInt();
              if (id != null) {
                favoritesMap[id] = true;
              }
            }
          },
          timeout: const Duration(seconds: 30),
          maxRetries: 3,
        );
      }

      return favoritesMap;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get favorites by image IDs: ${imageIds.length} IDs',
        e,
        stack,
        'GalleryDS',
      );
      return {for (final id in imageIds) id: false};
    }
  }

  // ============================================================
  // FTS5 全文搜索
  // ============================================================

  Future<List<int>> searchFullText(String query, {int limit = 100}) async {
    if (query.trim().isEmpty) return [];

    // 缓存键
    final cacheKey = _QueryCacheKey('searchFullText', {
      'query': query.toLowerCase().trim(),
      'limit': limit,
    });

    // 检查缓存
    final cached = _queryCache.get(cacheKey);
    if (cached != null) {
      return cached.cast<int>();
    }

    return _trackQuery(
      'searchFullText',
      () async {
        try {
          String escapeFts5(String input) => input.replaceAll('"', '""');

          final searchQuery = query
              .split(RegExp(r'\s+'))
              .where((s) => s.isNotEmpty)
              .map((s) => '"${escapeFts5(s)}"*')
              .join(' OR ');

          final results = await execute(
            'searchFullText',
            (db) async {
              final dbResults = await db.rawQuery(
                '''
                SELECT image_id FROM $_ftsIndexTable
                WHERE $_ftsIndexTable MATCH ?
                ORDER BY rank
                LIMIT ?
                ''',
                [searchQuery, limit],
              );

              return dbResults
                  .map((row) => (row['image_id'] as num).toInt())
                  .toList();
            },
            timeout: const Duration(seconds: 10),
            maxRetries: 3,
          );

          // 更新缓存
          _queryCache.put(cacheKey, results);

          return results;
        } catch (e, stack) {
          AppLogger.e('Failed to search full text: $query', e, stack, 'GalleryDS');
          return [];
        }
      },
      details: 'query="$query"',
    );
  }

  /// 高级搜索 - 支持多条件组合查询
  Future<List<int>> advancedSearch({
    String? textQuery,
    DateTime? dateStart,
    DateTime? dateEnd,
    bool favoritesOnly = false,
    int? minWidth,
    int? minHeight,
    int? maxWidth,
    int? maxHeight,
    int? minFileSize,
    int? maxFileSize,
    List<String>? metadataStatuses,
    int limit = 100,
  }) async {
    // 缓存键
    final cacheKey = _QueryCacheKey('advancedSearch', {
      'textQuery': textQuery,
      'dateStart': dateStart?.millisecondsSinceEpoch,
      'dateEnd': dateEnd?.millisecondsSinceEpoch,
      'favoritesOnly': favoritesOnly,
      'minWidth': minWidth,
      'minHeight': minHeight,
      'maxWidth': maxWidth,
      'maxHeight': maxHeight,
      'minFileSize': minFileSize,
      'maxFileSize': maxFileSize,
      'metadataStatuses': metadataStatuses?.join(','),
      'limit': limit,
    });

    // 检查缓存
    final cached = _queryCache.get(cacheKey);
    if (cached != null) {
      return cached.cast<int>();
    }

    return _trackQuery(
      'advancedSearch',
      () async {
        return await execute('advancedSearch', (db) async {
          // 1. 全文搜索（如果有文本查询）
          List<int>? textSearchIds;
          if (textQuery != null && textQuery.trim().isNotEmpty) {
            textSearchIds = await searchFullText(textQuery, limit: limit * 2);
            if (textSearchIds.isEmpty) {
              return <int>[];
            }
          }

          // 2. 构建查询条件
          final conditions = <String>['i.is_deleted = 0'];
          final args = <dynamic>[];

          if (favoritesOnly) {
            conditions.add('f.image_id IS NOT NULL');
          }

          if (dateStart != null) {
            conditions.add('i.modified_at >= ?');
            args.add(dateStart.millisecondsSinceEpoch);
          }
          if (dateEnd != null) {
            conditions.add('i.modified_at <= ?');
            args.add(dateEnd.millisecondsSinceEpoch);
          }

          if (minWidth != null) {
            conditions.add('i.width >= ?');
            args.add(minWidth);
          }
          if (minHeight != null) {
            conditions.add('i.height >= ?');
            args.add(minHeight);
          }
          if (maxWidth != null) {
            conditions.add('i.width <= ?');
            args.add(maxWidth);
          }
          if (maxHeight != null) {
            conditions.add('i.height <= ?');
            args.add(maxHeight);
          }

          if (minFileSize != null) {
            conditions.add('i.file_size >= ?');
            args.add(minFileSize);
          }
          if (maxFileSize != null) {
            conditions.add('i.file_size <= ?');
            args.add(maxFileSize);
          }

          if (metadataStatuses != null && metadataStatuses.isNotEmpty) {
            final statusIndices = metadataStatuses
                .map((s) => MetadataStatus.values.indexWhere((v) => v.name == s))
                .where((i) => i >= 0)
                .toList();
            if (statusIndices.isNotEmpty) {
              final placeholders = List.filled(statusIndices.length, '?').join(',');
              conditions.add('i.metadata_status IN ($placeholders)');
              args.addAll(statusIndices);
            }
          }

          if (textSearchIds != null && textSearchIds.isNotEmpty) {
            final placeholders = List.filled(textSearchIds.length, '?').join(',');
            conditions.add('i.id IN ($placeholders)');
            args.addAll(textSearchIds);
          }

          final whereClause = conditions.join(' AND ');

          // 3. 执行查询
          final results = await db.rawQuery(
            '''
            SELECT i.id FROM $_imagesTable i
            ${favoritesOnly ? 'INNER JOIN $_favoritesTable f ON i.id = f.image_id' : 'LEFT JOIN $_favoritesTable f ON i.id = f.image_id'}
            WHERE $whereClause
            ORDER BY i.modified_at DESC
            LIMIT ?
            ''',
            [...args, limit],
          );

          final ids = results.map((row) => (row['id'] as num).toInt()).toList();

          // 更新缓存
          _queryCache.put(cacheKey, ids);

          return ids;
        });
      },
      details: 'text=${textQuery != null}, favorites=$favoritesOnly',
    );
  }

  // ============================================================
  // 标签操作
  // ============================================================

  Future<void> addTag(int imageId, String tagName) async {
    if (tagName.trim().isEmpty) return;

    final normalizedTag = tagName.trim();
    final tagId = _generateTagId(normalizedTag);

    return await execute('addTag', (db) async {
      await db.transaction((txn) async {
        await txn.insert(
          _tagsTable,
          {
            'id': tagId,
            'name': normalizedTag,
            'usage_count': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        await txn.insert(
          _imageTagsTable,
          {
            'image_id': imageId,
            'tag_id': tagId,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        await txn.rawUpdate(
          '''
          UPDATE $_tagsTable
          SET usage_count = (
            SELECT COUNT(*) FROM $_imageTagsTable WHERE tag_id = ?
          )
          WHERE id = ?
          ''',
          [tagId, tagId],
        );
      });

      AppLogger.d('Added tag "$normalizedTag" to image $imageId', 'GalleryDS');
    });
  }

  Future<void> removeTag(int imageId, String tagName) async {
    if (tagName.trim().isEmpty) return;

    final normalizedTag = tagName.trim();
    final tagId = _generateTagId(normalizedTag);

    return await execute('removeTag', (db) async {
      await db.transaction((txn) async {
        await txn.delete(
          _imageTagsTable,
          where: 'image_id = ? AND tag_id = ?',
          whereArgs: [imageId, tagId],
        );

        await txn.rawUpdate(
          '''
          UPDATE $_tagsTable
          SET usage_count = (
            SELECT COUNT(*) FROM $_imageTagsTable WHERE tag_id = ?
          )
          WHERE id = ?
          ''',
          [tagId, tagId],
        );
      });

      AppLogger.d(
        'Removed tag "$normalizedTag" from image $imageId',
        'GalleryDS',
      );
    });
  }

  Future<List<String>> getImageTags(int imageId) async {
    return await execute('getImageTags', (db) async {
      final results = await db.rawQuery(
        '''
        SELECT t.name
        FROM $_tagsTable t
        INNER JOIN $_imageTagsTable it ON t.id = it.tag_id
        WHERE it.image_id = ?
        ORDER BY t.name ASC
        ''',
        [imageId],
      );

      return results.map<String>((row) => row['name'] as String).toList();
    });
  }

  Future<Map<int, List<String>>> getTagsByImageIds(List<int> imageIds) async {
    if (imageIds.isEmpty) return {};

    try {
      final tagsMap = <int, List<String>>{
        for (final id in imageIds) id: const <String>[],
      };

      const batchSize = 900;
      final chunks = chunk(imageIds, batchSize);

      for (final chunk in chunks) {
        await execute(
          'getTagsByImageIds',
          (db) async {
            final placeholders = List.filled(chunk.length, '?').join(',');

            final results = await db.rawQuery(
              '''
              SELECT it.image_id, t.name
              FROM $_tagsTable t
              INNER JOIN $_imageTagsTable it ON t.id = it.tag_id
              WHERE it.image_id IN ($placeholders)
              ORDER BY t.name ASC
              ''',
              chunk,
            );

            for (final row in results) {
              final id = (row['image_id'] as num?)?.toInt();
              final tagName = row['name'] as String?;
              if (id != null && tagName != null) {
                tagsMap[id]!.add(tagName);
              }
            }
          },
          timeout: const Duration(seconds: 30),
          maxRetries: 3,
        );
      }

      return tagsMap;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get tags by image IDs: ${imageIds.length} IDs',
        e,
        stack,
        'GalleryDS',
      );
      return {for (final id in imageIds) id: <String>[] };
    }
  }

  Future<void> setImageTags(int imageId, List<String> tags) async {
    final normalizedTags =
        tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet().toList();

    return await execute('setImageTags', (db) async {
      await db.transaction((txn) async {
        final currentTagsResult = await txn.rawQuery(
          '''
          SELECT t.id
          FROM $_tagsTable t
          INNER JOIN $_imageTagsTable it ON t.id = it.tag_id
          WHERE it.image_id = ?
          ''',
          [imageId],
        );
        final oldTagIds =
            currentTagsResult.map((row) => row['id'] as String).toSet();

        await txn.delete(
          _imageTagsTable,
          where: 'image_id = ?',
          whereArgs: [imageId],
        );

        for (final tagName in normalizedTags) {
          final tagId = _generateTagId(tagName);

          await txn.insert(
            _tagsTable,
            {
              'id': tagId,
              'name': tagName,
              'usage_count': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );

          await txn.insert(
            _imageTagsTable,
            {
              'image_id': imageId,
              'tag_id': tagId,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        final allTagIds = <String>{...oldTagIds};
        for (final tagName in normalizedTags) {
          allTagIds.add(_generateTagId(tagName));
        }

        for (final tagId in allTagIds) {
          await txn.rawUpdate(
            '''
            UPDATE $_tagsTable
            SET usage_count = (
              SELECT COUNT(*) FROM $_imageTagsTable WHERE tag_id = ?
            )
            WHERE id = ?
            ''',
            [tagId, tagId],
          );
        }
      });

      AppLogger.d(
        'Set ${normalizedTags.length} tags for image $imageId',
        'GalleryDS',
      );
    });
  }

  String _generateTagId(String tagName) {
    return tagName.toLowerCase().trim();
  }

  // ============================================================
  // 统计查询
  // ============================================================

  Future<List<GalleryImageRecord>> getAllImages() async {
    return _trackQuery(
      'getAllImages',
      () async {
        try {
          return await execute(
            'getAllImages',
            (db) async {
              final results = await db.rawQuery(
                '''
                SELECT * FROM $_imagesTable
                WHERE is_deleted = 0
                ORDER BY modified_at DESC
                ''',
              );

              return results.map((row) => GalleryImageRecord.fromMap(row)).toList();
            },
            timeout: const Duration(seconds: 60),
            maxRetries: 3,
          );
        } catch (e, stack) {
          AppLogger.e('Failed to get all images', e, stack, 'GalleryDS');
          return [];
        }
      },
    );
  }

  Future<List<Map<String, dynamic>>> getModelDistribution() async {
    try {
      return await execute(
        'getModelDistribution',
        (db) async {
          final results = await db.rawQuery(
            '''
            SELECT
              model,
              COUNT(*) as count
            FROM $_metadataTable
            WHERE model IS NOT NULL AND model != ''
            GROUP BY model
            ORDER BY count DESC
            ''',
          );

          final total = results.fold<int>(
            0,
            (sum, row) => sum + (row['count'] as int),
          );

          return results.map((row) {
            final count = row['count'] as int;
            return {
              'model': row['model'] as String,
              'count': count,
              'percentage': total > 0 ? (count / total * 100) : 0.0,
            };
          }).toList();
        },
        timeout: const Duration(seconds: 30),
        maxRetries: 3,
      );
    } catch (e, stack) {
      AppLogger.e('Failed to get model distribution', e, stack, 'GalleryDS');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSamplerDistribution() async {
    try {
      return await execute(
        'getSamplerDistribution',
        (db) async {
          final results = await db.rawQuery(
            '''
            SELECT
              sampler,
              COUNT(*) as count
            FROM $_metadataTable
            WHERE sampler IS NOT NULL AND sampler != ''
            GROUP BY sampler
            ORDER BY count DESC
            ''',
          );

          final total = results.fold<int>(
            0,
            (sum, row) => sum + (row['count'] as int),
          );

          return results.map((row) {
            final count = row['count'] as int;
            return {
              'sampler': row['sampler'] as String,
              'count': count,
              'percentage': total > 0 ? (count / total * 100) : 0.0,
            };
          }).toList();
        },
        timeout: const Duration(seconds: 30),
        maxRetries: 3,
      );
    } catch (e, stack) {
      AppLogger.e('Failed to get sampler distribution', e, stack, 'GalleryDS');
      return [];
    }
  }

  /// 删除所有图片记录（保留文件）
  ///
  /// 用于深度清除画廊数据，强制下次重新扫描
  Future<void> deleteAllImages() async {
    try {
      await execute(
        'deleteAllImages',
        (db) async {
          // 先删除关联的元数据（外键约束）
          await db.delete(_metadataTable);
          // 删除收藏记录
          await db.delete(_favoritesTable);
          // 删除图片标签关联
          await db.delete(_imageTagsTable);
          // 最后删除图片记录
          final count = await db.delete(_imagesTable);
          AppLogger.i('Deleted $count image records', 'GalleryDS');
        },
        timeout: const Duration(seconds: 30),
        maxRetries: 2,
      );

      // 清除内存缓存
      clearCache();
    } catch (e, stack) {
      AppLogger.e('Failed to delete all images', e, stack, 'GalleryDS');
      rethrow;
    }
  }

  /// 删除所有元数据记录
  Future<void> deleteAllMetadata() async {
    try {
      await execute(
        'deleteAllMetadata',
        (db) async {
          final count = await db.delete(_metadataTable);
          AppLogger.i('Deleted $count metadata records', 'GalleryDS');
        },
        timeout: const Duration(seconds: 30),
        maxRetries: 2,
      );
    } catch (e, stack) {
      AppLogger.e('Failed to delete all metadata', e, stack, 'GalleryDS');
      rethrow;
    }
  }
}
