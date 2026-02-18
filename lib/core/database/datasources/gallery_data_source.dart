import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../utils/app_logger.dart';
import '../connection_pool_holder.dart';
import '../data_source.dart';

/// 通用 LRU 缓存实现
///
/// 使用 LinkedHashMap 实现 LRU 缓存，限制最大条目数。
/// 当缓存满时，自动移除最久未使用的条目。
class LRUCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap();

  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;

  LRUCache({required this.maxSize});

  /// 获取缓存值
  ///
  /// 如果找到，将条目移到末尾（标记为最近使用）
  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value;
      _hitCount++;
      return value;
    }
    _missCount++;
    return null;
  }

  /// 设置缓存值
  ///
  /// 如果缓存已满，先移除最旧的条目
  void put(K key, V value) {
    _cache.remove(key);

    if (_cache.length >= maxSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
      _evictionCount++;
    }

    _cache[key] = value;
  }

  /// 检查是否包含键
  bool containsKey(K key) => _cache.containsKey(key);

  /// 获取当前大小
  int get size => _cache.length;

  /// 检查是否为空
  bool get isEmpty => _cache.isEmpty;

  /// 检查是否已满
  bool get isFull => _cache.length >= maxSize;

  /// 清除所有缓存
  void clear() {
    _cache.clear();
    _hitCount = 0;
    _missCount = 0;
    _evictionCount = 0;
  }

  /// 移除特定键
  bool remove(K key) => _cache.remove(key) != null;

  /// 获取命中率
  double get hitRate {
    final total = _hitCount + _missCount;
    return total == 0 ? 0.0 : _hitCount / total;
  }

  /// 获取统计信息
  Map<String, dynamic> get statistics => {
        'size': _cache.length,
        'maxSize': maxSize,
        'hitCount': _hitCount,
        'missCount': _missCount,
        'evictionCount': _evictionCount,
        'hitRate': hitRate,
      };
}

/// 元数据解析状态
enum MetadataStatus {
  success, // 解析成功
  failed, // 解析失败
  none, // 未解析
}

/// 画廊图片记录
///
/// 表示本地图片文件的基本信息和元数据
class GalleryImageRecord {
  final int? id; // 图片ID (SQLite自增主键)
  final String filePath; // 文件路径
  final String fileName; // 文件名称
  final int fileSize; // 文件大小（字节）
  final String? fileHash; // 文件哈希
  final int? width; // 图片宽度
  final int? height; // 图片高度
  final double? aspectRatio; // 宽高比
  final DateTime modifiedAt; // 最后修改时间
  final DateTime createdAt; // 创建时间
  final DateTime indexedAt; // 索引时间
  final int dateYmd; // 日期YYYYMMDD格式
  final String? resolutionKey; // 分辨率键
  final MetadataStatus metadataStatus; // 元数据状态
  final bool isFavorite; // 是否收藏
  final bool isDeleted; // 是否已删除（软删除）

  const GalleryImageRecord({
    this.id,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    this.fileHash,
    this.width,
    this.height,
    this.aspectRatio,
    required this.modifiedAt,
    required this.createdAt,
    required this.indexedAt,
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
        'file_hash': fileHash,
        'width': width,
        'height': height,
        'aspect_ratio': aspectRatio,
        'modified_at': modifiedAt.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
        'indexed_at': indexedAt.millisecondsSinceEpoch,
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
      fileSize: (map['file_size'] as num?)?.toInt() ?? (map['size'] as num?)?.toInt() ?? 0,
      fileHash: map['file_hash'] as String?,
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
      dateYmd: (map['date_ymd'] as num?)?.toInt() ?? 0,
      resolutionKey: map['resolution_key'] as String?,
      metadataStatus: MetadataStatus.values[
        (map['metadata_status'] as num?)?.toInt() ?? 2, // 默认 none
      ],
      isFavorite: (map['is_favorite'] as num?)?.toInt() == 1,
      isDeleted: (map['is_deleted'] as num?)?.toInt() == 1,
    );
  }

  GalleryImageRecord copyWith({
    int? id,
    String? filePath,
    String? fileName,
    int? fileSize,
    String? fileHash,
    int? width,
    int? height,
    double? aspectRatio,
    DateTime? modifiedAt,
    DateTime? createdAt,
    DateTime? indexedAt,
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
      fileHash: fileHash ?? this.fileHash,
      width: width ?? this.width,
      height: height ?? this.height,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      createdAt: createdAt ?? this.createdAt,
      indexedAt: indexedAt ?? this.indexedAt,
      dateYmd: dateYmd ?? this.dateYmd,
      resolutionKey: resolutionKey ?? this.resolutionKey,
      metadataStatus: metadataStatus ?? this.metadataStatus,
      isFavorite: isFavorite ?? this.isFavorite,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

/// 画廊元数据记录
///
/// 存储图片的 NAI 生成元数据
class GalleryMetadataRecord {
  final String imageId; // 关联的图片ID
  final String prompt; // 正向提示词
  final String negativePrompt; // 负向提示词
  final int? seed; // 随机种子
  final String? sampler; // 采样器
  final int? steps; // 采样步数
  final double? scale; // CFG Scale
  final int? width; // 图片宽度
  final int? height; // 图片高度
  final String? model; // 模型名称
  final bool smea; // SMEA 开关
  final bool smeaDyn; // SMEA DYN 开关
  final String? noiseSchedule; // 噪声计划
  final double? cfgRescale; // CFG Rescale
  final int? ucPreset; // UC 预设
  final bool qualityToggle; // 质量标签开关
  final bool isImg2Img; // 是否为 img2img
  final double? strength; // img2img 强度
  final double? noise; // img2img 噪声
  final String? software; // 软件名称
  final String? source; // 模型来源
  final String? version; // 版本信息
  final String? rawJson; // 原始 JSON 字符串
  final String fullPromptText; // 用于 FTS5 搜索的完整提示词文本

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
        'scale': scale,
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
      imageId: map['image_id'] as String,
      prompt: map['prompt'] as String? ?? '',
      negativePrompt: map['negative_prompt'] as String? ?? '',
      seed: map['seed'] as int?,
      sampler: map['sampler'] as String?,
      steps: map['steps'] as int?,
      scale: (map['scale'] as num?)?.toDouble(),
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

  /// 从 NaiImageMetadata 构造
  factory GalleryMetadataRecord.fromNaiMetadata(
    String imageId,
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
  final String id; // 标签ID
  final String name; // 标签名称
  final String? category; // 标签分类
  final int usageCount; // 使用次数

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
  final String id; // 日志ID
  final DateTime startedAt; // 开始时间
  final DateTime? completedAt; // 完成时间
  final int totalFiles; // 总文件数
  final int processedFiles; // 处理文件数
  final int newFiles; // 新增文件数
  final int updatedFiles; // 更新文件数
  final int failedFiles; // 失败文件数
  final String? errorMessage; // 错误信息
  final String? scanPath; // 扫描路径

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

/// 画廊数据源
///
/// 管理本地图片画廊的数据存储和查询。
/// 支持图片元数据、标签、收藏和全文搜索。
class GalleryDataSource extends BaseDataSource {
  static const int _maxImageCacheSize = 500;
  static const int _maxMetadataCacheSize = 200;

  // 表名常量
  static const String _imagesTable = 'gallery_images';
  static const String _metadataTable = 'gallery_metadata';
  static const String _favoritesTable = 'gallery_favorites';
  static const String _tagsTable = 'gallery_tags';
  static const String _imageTagsTable = 'gallery_image_tags';
  static const String _scanLogsTable = 'gallery_scan_logs';
  static const String _ftsIndexTable = 'gallery_fts_index';

  // 缓存
  final LRUCache<int, GalleryImageRecord> _imageCache =
      LRUCache(maxSize: _maxImageCacheSize);
  final LRUCache<int, GalleryMetadataRecord> _metadataCache =
      LRUCache(maxSize: _maxMetadataCacheSize);

  // 收藏缓存
  final Set<int> _favoriteCache = <int>{};
  bool _favoritesLoaded = false;

  @override
  String get name => 'gallery';

  @override
  DataSourceType get type => DataSourceType.gallery;

  @override
  Set<String> get dependencies => {}; // 无依赖

  /// 获取数据库连接
  Future<dynamic> _acquireDb() async {
    var retryCount = 0;
    const maxRetries = 10;

    while (retryCount < maxRetries) {
      try {
        if (!ConnectionPoolHolder.isInitialized) {
          throw StateError('Connection pool not initialized');
        }
        final db = await ConnectionPoolHolder.instance.acquire();

        // 验证连接是否真正可用
        try {
          await db.rawQuery('SELECT 1');
          return db;
        } catch (e) {
          AppLogger.w(
            'Acquired connection is invalid, releasing and retrying...',
            'GalleryDS',
          );
          try {
            await ConnectionPoolHolder.instance.release(db);
          } catch (_) {
            // 忽略释放错误
          }
          throw StateError('Database connection invalid');
        }
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        final isDbClosed = errorStr.contains('database_closed') ||
            errorStr.contains('not initialized') ||
            errorStr.contains('connection invalid');
        if (isDbClosed && retryCount < maxRetries - 1) {
          retryCount++;
          AppLogger.w(
            'Database connection not ready, retrying ($retryCount/$maxRetries)...',
            'GalleryDS',
          );
          await Future.delayed(
            Duration(milliseconds: 100 * (1 << (retryCount - 1))),
          );
        } else {
          rethrow;
        }
      }
    }

    throw StateError(
        'Failed to acquire database connection after $maxRetries retries');
  }

  /// 释放数据库连接
  Future<void> _releaseDb(dynamic db) async {
    await ConnectionPoolHolder.instance.release(db);
  }

  /// 清除缓存
  void clearCache() {
    _imageCache.clear();
    _metadataCache.clear();
    _favoriteCache.clear();
    _favoritesLoaded = false;
    AppLogger.i('Gallery cache cleared', 'GalleryDS');
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStatistics() => {
        'imageCache': _imageCache.statistics,
        'metadataCache': _metadataCache.statistics,
      };

  @override
  Future<void> doInitialize() async {
    final db = await _acquireDb();

    try {
      // 创建图片基础信息表（兼容旧数据库结构）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_imagesTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          file_path TEXT NOT NULL UNIQUE,
          file_name TEXT NOT NULL,
          file_size INTEGER NOT NULL DEFAULT 0,
          file_hash TEXT,
          width INTEGER,
          height INTEGER,
          aspect_ratio REAL,
          modified_at INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          indexed_at INTEGER NOT NULL,
          date_ymd INTEGER NOT NULL DEFAULT 0,
          resolution_key TEXT,
          metadata_status INTEGER NOT NULL DEFAULT 2,
          is_favorite INTEGER NOT NULL DEFAULT 0,
          is_deleted INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // 创建图片表索引
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_gallery_images_modified_at
        ON $_imagesTable(modified_at DESC)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_gallery_images_created_at
        ON $_imagesTable(created_at DESC)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_gallery_images_favorite
        ON $_imagesTable(is_favorite)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_gallery_images_metadata_status
        ON $_imagesTable(metadata_status)
      ''');

      // 创建元数据表
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

      // 创建元数据表索引
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_gallery_metadata_model
        ON $_metadataTable(model)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_gallery_metadata_sampler
        ON $_metadataTable(sampler)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_gallery_metadata_seed
        ON $_metadataTable(seed)
      ''');

      // 创建收藏表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_favoritesTable (
          image_id INTEGER PRIMARY KEY,
          favorited_at INTEGER NOT NULL,
          FOREIGN KEY (image_id) REFERENCES $_imagesTable(id) ON DELETE CASCADE
        )
      ''');

      // 创建标签表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tagsTable (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          category TEXT,
          usage_count INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // 创建标签表索引
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_gallery_tags_name
        ON $_tagsTable(name)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_gallery_tags_category
        ON $_tagsTable(category)
      ''');

      // 创建图片-标签关联表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_imageTagsTable (
          image_id INTEGER NOT NULL,
          tag_id TEXT NOT NULL,
          PRIMARY KEY (image_id, tag_id),
          FOREIGN KEY (image_id) REFERENCES $_imagesTable(id) ON DELETE CASCADE,
          FOREIGN KEY (tag_id) REFERENCES $_tagsTable(id) ON DELETE CASCADE
        )
      ''');

      // 创建图片标签关联表索引
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_gallery_image_tags_tag_id
        ON $_imageTagsTable(tag_id)
      ''');

      // 创建扫描日志表
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

      // 创建扫描日志表索引
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_gallery_scan_logs_started_at
        ON $_scanLogsTable(started_at DESC)
      ''');

      // 创建 FTS5 虚拟表用于全文搜索
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS $_ftsIndexTable USING fts5(
          image_id UNINDEXED,
          prompt_text,
          tokenize = 'porter'
        )
      ''');

      AppLogger.i('Gallery tables initialized', 'GalleryDS');
    } catch (e, stack) {
      AppLogger.e(
        'Failed to initialize gallery tables',
        e,
        stack,
        'GalleryDS',
      );
      rethrow;
    } finally {
      await _releaseDb(db);
    }
  }

  @override
  Future<DataSourceHealth> doCheckHealth() async {
    final db = await _acquireDb();

    try {
      // 检查所有表是否存在
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

      // 尝试查询每个表
      for (final table in tables) {
        await db.rawQuery('SELECT 1 FROM $table LIMIT 1');
      }

      // 获取统计信息
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
          'metadataCacheSize': _metadataCache.size,
          'cacheHitRate': {
            'image': _imageCache.hitRate,
            'metadata': _metadataCache.hitRate,
          },
        },
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return DataSourceHealth(
        status: HealthStatus.corrupted,
        message: 'Health check failed: $e',
        details: {'error': e.toString()},
        timestamp: DateTime.now(),
      );
    } finally {
      await _releaseDb(db);
    }
  }

  /// 获取表记录数
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

  /// 插入或更新图片记录
  ///
  /// 使用 INSERT OR REPLACE 语义，如果存在相同 file_path 的记录则更新
  /// 返回插入/更新后的图片ID
  Future<int> upsertImage({
    required String filePath,
    required String fileName,
    required int fileSize,
    String? fileHash,
    int? width,
    int? height,
    double? aspectRatio,
    required DateTime createdAt,
    required DateTime modifiedAt,
    String? resolutionKey,
    MetadataStatus? metadataStatus,
    bool? isFavorite,
  }) async {
    final db = await _acquireDb();

    try {
      final dateYmd = _formatDateYmd(modifiedAt);
      final now = DateTime.now();

      // 首先尝试获取现有记录的ID（如果存在）
      final existingResult = await db.rawQuery(
        'SELECT id FROM $_imagesTable WHERE file_path = ?',
        [filePath],
      );
      final existingId = existingResult.isNotEmpty
          ? (existingResult.first['id'] as num?)?.toInt()
          : null;

      // 如果存在，清除缓存
      if (existingId != null) {
        _imageCache.remove(existingId);
      }

      final map = {
        'file_path': filePath,
        'file_name': fileName,
        'file_size': fileSize,
        'file_hash': fileHash,
        'width': width,
        'height': height,
        'aspect_ratio': aspectRatio,
        'created_at': createdAt.millisecondsSinceEpoch,
        'modified_at': modifiedAt.millisecondsSinceEpoch,
        'indexed_at': now.millisecondsSinceEpoch,
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

      AppLogger.d('Upserted image: $fileName (id=$id)', 'GalleryDS');
      return id;
    } catch (e, stack) {
      AppLogger.e('Failed to upsert image: $filePath', e, stack, 'GalleryDS');
      rethrow;
    } finally {
      await _releaseDb(db);
    }
  }

  /// 根据文件路径获取图片ID
  ///
  /// 如果找不到记录，返回 null
  Future<int?> getImageIdByPath(String filePath) async {
    final db = await _acquireDb();

    try {
      final result = await db.rawQuery(
        'SELECT id FROM $_imagesTable WHERE file_path = ? AND is_deleted = 0',
        [filePath],
      );

      if (result.isEmpty) return null;
      return (result.first['id'] as num?)?.toInt();
    } catch (e, stack) {
      AppLogger.e('Failed to get image ID by path: $filePath', e, stack, 'GalleryDS');
      return null;
    } finally {
      await _releaseDb(db);
    }
  }

  /// 根据ID获取图片记录
  ///
  /// 使用 LRU 缓存，优先从缓存获取
  Future<GalleryImageRecord?> getImageById(int id) async {
    // 先从缓存获取
    final cached = _imageCache.get(id);
    if (cached != null) {
      return cached;
    }

    final db = await _acquireDb();

    try {
      final result = await db.rawQuery(
        '''
        SELECT * FROM $_imagesTable
        WHERE id = ? AND is_deleted = 0
        ''',
        [id],
      );

      if (result.isEmpty) return null;

      final record = GalleryImageRecord.fromMap(result.first);

      // 存入缓存
      _imageCache.put(id, record);

      return record;
    } catch (e, stack) {
      AppLogger.e('Failed to get image by ID: $id', e, stack, 'GalleryDS');
      return null;
    } finally {
      await _releaseDb(db);
    }
  }

  /// 根据ID列表批量获取图片记录
  ///
  /// 优先从缓存获取，缺失的从数据库查询
  Future<List<GalleryImageRecord>> getImagesByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    final results = <GalleryImageRecord>[];
    final missingIds = <int>[];

    // 先从缓存获取
    for (final id in ids) {
      final cached = _imageCache.get(id);
      if (cached != null) {
        results.add(cached);
      } else {
        missingIds.add(id);
      }
    }

    // 从数据库查询缺失的记录
    if (missingIds.isNotEmpty) {
      final db = await _acquireDb();

      try {
        // 构建 IN 子句的占位符
        final placeholders = List.filled(missingIds.length, '?').join(',');

        final dbResults = await db.rawQuery(
          '''
          SELECT * FROM $_imagesTable
          WHERE id IN ($placeholders) AND is_deleted = 0
          ''',
          missingIds,
        );

        for (final row in dbResults) {
          final record = GalleryImageRecord.fromMap(row);
          results.add(record);

          // 存入缓存
          if (record.id != null) {
            _imageCache.put(record.id!, record);
          }
        }
      } catch (e, stack) {
        AppLogger.e('Failed to get images by IDs', e, stack, 'GalleryDS');
      } finally {
        await _releaseDb(db);
      }
    }

    // 按照原始ID顺序排序结果
    final idIndexMap = {for (var i = 0; i < ids.length; i++) ids[i]: i};
    results.sort((a, b) {
      final indexA = idIndexMap[a.id] ?? 0;
      final indexB = idIndexMap[b.id] ?? 0;
      return indexA.compareTo(indexB);
    });

    return results;
  }

  /// 获取所有文件路径和哈希映射
  ///
  /// 用于增量扫描，只返回未删除的记录
  Future<Map<String, String?>> getAllFileHashes() async {
    final db = await _acquireDb();

    try {
      final results = await db.rawQuery(
        '''
        SELECT file_path, file_hash FROM $_imagesTable
        WHERE is_deleted = 0
        ''',
      );

      return {
        for (final row in results)
          row['file_path'] as String: row['file_hash'] as String?,
      };
    } catch (e, stack) {
      AppLogger.e('Failed to get all file hashes', e, stack, 'GalleryDS');
      return {};
    } finally {
      await _releaseDb(db);
    }
  }

  /// 分页查询图片记录
  ///
  /// [limit] 每页数量
  /// [offset] 偏移量
  /// [orderBy] 排序字段，可选值: 'modified_at', 'created_at', 'indexed_at', 'file_name'
  /// [descending] 是否降序
  Future<List<GalleryImageRecord>> queryImages({
    int limit = 50,
    int offset = 0,
    String orderBy = 'modified_at',
    bool descending = true,
  }) async {
    final db = await _acquireDb();

    try {
      // 验证排序字段，防止SQL注入
      final validColumns = {
        'modified_at',
        'created_at',
        'indexed_at',
        'file_name',
        'file_size',
        'id',
      };
      final safeOrderBy = validColumns.contains(orderBy) ? orderBy : 'modified_at';
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

      return results.map((row) => GalleryImageRecord.fromMap(row)).toList();
    } catch (e, stack) {
      AppLogger.e('Failed to query images', e, stack, 'GalleryDS');
      return [];
    } finally {
      await _releaseDb(db);
    }
  }

  /// 标记图片为已删除（软删除）
  ///
  /// [filePath] 文件路径
  Future<void> markAsDeleted(String filePath) async {
    final db = await _acquireDb();

    try {
      // 先获取ID以清除缓存
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

      AppLogger.d('Marked as deleted: $filePath', 'GalleryDS');
    } catch (e, stack) {
      AppLogger.e('Failed to mark as deleted: $filePath', e, stack, 'GalleryDS');
      rethrow;
    } finally {
      await _releaseDb(db);
    }
  }

  /// 批量标记图片为已删除（软删除）
  ///
  /// 使用事务批量处理
  Future<void> batchMarkAsDeleted(List<String> filePaths) async {
    if (filePaths.isEmpty) return;

    final db = await _acquireDb();

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

      // 清除相关缓存
      for (final path in filePaths) {
        final result = await db.rawQuery(
          'SELECT id FROM $_imagesTable WHERE file_path = ?',
          [path],
        );
        if (result.isNotEmpty) {
          final id = (result.first['id'] as num?)?.toInt();
          if (id != null) {
            _imageCache.remove(id);
          }
        }
      }

      AppLogger.d('Batch marked as deleted: ${filePaths.length} files', 'GalleryDS');
    } catch (e, stack) {
      AppLogger.e('Failed to batch mark as deleted', e, stack, 'GalleryDS');
      rethrow;
    } finally {
      await _releaseDb(db);
    }
  }

  /// 统计图片数量
  ///
  /// [includeDeleted] 是否包含已删除的图片
  Future<int> countImages({bool includeDeleted = false}) async {
    final db = await _acquireDb();

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
    } finally {
      await _releaseDb(db);
    }
  }

  /// 格式化日期为YYYYMMDD整数
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

  /// 插入或更新元数据
  ///
  /// [imageId] 图片ID
  /// [metadata] NAI 图片元数据
  ///
  /// 使用 INSERT OR REPLACE 语义，如果存在则更新。
  /// 插入后清除元数据缓存并更新 FTS5 索引。
  Future<void> upsertMetadata(int imageId, NaiImageMetadata metadata) async {
    final db = await _acquireDb();

    try {
      final fullPromptText = _buildFullPromptText(metadata);

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

      // 清除该图片的元数据缓存
      _metadataCache.remove(imageId);

      // 更新 FTS5 索引
      await _updateFtsIndex(imageId, fullPromptText);

      AppLogger.d('Upserted metadata for image: $imageId', 'GalleryDS');
    } catch (e, stack) {
      AppLogger.e('Failed to upsert metadata: $imageId', e, stack, 'GalleryDS');
      rethrow;
    } finally {
      await _releaseDb(db);
    }
  }

  /// 构建完整提示词文本（用于 FTS5 搜索）
  ///
  /// 合并 prompt, negativePrompt, characterPrompts
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

  /// 更新 FTS5 索引
  Future<void> _updateFtsIndex(int imageId, String promptText) async {
    final db = await _acquireDb();

    try {
      // 先删除旧索引
      await db.delete(
        _ftsIndexTable,
        where: 'image_id = ?',
        whereArgs: [imageId],
      );

      // 插入新索引
      await db.insert(_ftsIndexTable, {
        'image_id': imageId,
        'prompt_text': promptText,
      });
    } catch (e, stack) {
      AppLogger.w('Failed to update FTS index for image $imageId: $e', 'GalleryDS');
      // FTS 更新失败不应影响主流程
    } finally {
      await _releaseDb(db);
    }
  }

  /// 根据图片ID获取元数据
  ///
  /// 先检查 _metadataCache，数据库查询后写入缓存
  Future<GalleryMetadataRecord?> getMetadataByImageId(int imageId) async {
    // 先检查缓存
    final cached = _metadataCache.get(imageId);
    if (cached != null) {
      return cached;
    }

    final db = await _acquireDb();

    try {
      final result = await db.rawQuery(
        '''
        SELECT * FROM $_metadataTable
        WHERE image_id = ?
        ''',
        [imageId],
      );

      if (result.isEmpty) return null;

      final record = GalleryMetadataRecord.fromMap(result.first);

      // 写入缓存
      _metadataCache.put(imageId, record);

      return record;
    } catch (e, stack) {
      AppLogger.e('Failed to get metadata by image ID: $imageId', e, stack, 'GalleryDS');
      return null;
    } finally {
      await _releaseDb(db);
    }
  }

  // ============================================================
  // 收藏操作
  // ============================================================

  /// 切换收藏状态
  ///
  /// [imageId] 图片ID
  ///
  /// 如果存在则删除，不存在则插入。
  /// 更新 _favoriteCache，返回新的收藏状态（true=已收藏，false=未收藏）
  Future<bool> toggleFavorite(int imageId) async {
    final db = await _acquireDb();

    try {
      // 检查是否已收藏
      final exists = await db.rawQuery(
        'SELECT 1 FROM $_favoritesTable WHERE image_id = ?',
        [imageId],
      );

      final isCurrentlyFavorite = exists.isNotEmpty;

      if (isCurrentlyFavorite) {
        // 取消收藏
        await db.delete(
          _favoritesTable,
          where: 'image_id = ?',
          whereArgs: [imageId],
        );
        _favoriteCache.remove(imageId);
        AppLogger.d('Removed favorite: $imageId', 'GalleryDS');
        return false;
      } else {
        // 添加收藏
        await db.insert(_favoritesTable, {
          'image_id': imageId,
          'favorited_at': DateTime.now().millisecondsSinceEpoch,
        });
        _favoriteCache.add(imageId);
        AppLogger.d('Added favorite: $imageId', 'GalleryDS');
        return true;
      }
    } catch (e, stack) {
      AppLogger.e('Failed to toggle favorite: $imageId', e, stack, 'GalleryDS');
      rethrow;
    } finally {
      await _releaseDb(db);
    }
  }

  /// 检查是否已收藏
  ///
  /// [imageId] 图片ID
  ///
  /// 优先使用 _favoriteCache，如果缓存未加载则查询数据库
  Future<bool> isFavorite(int imageId) async {
    // 优先使用缓存
    if (_favoritesLoaded) {
      return _favoriteCache.contains(imageId);
    }

    // 缓存未加载，查询数据库
    final db = await _acquireDb();

    try {
      final result = await db.rawQuery(
        'SELECT 1 FROM $_favoritesTable WHERE image_id = ?',
        [imageId],
      );
      return result.isNotEmpty;
    } catch (e, stack) {
      AppLogger.e('Failed to check favorite status: $imageId', e, stack, 'GalleryDS');
      return false;
    } finally {
      await _releaseDb(db);
    }
  }

  /// 加载所有收藏到缓存
  ///
  /// 一次性加载所有收藏ID到 _favoriteCache，设置 _favoritesLoaded = true
  Future<void> loadFavoritesCache() async {
    if (_favoritesLoaded) return;

    final db = await _acquireDb();

    try {
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
      AppLogger.i('Loaded ${_favoriteCache.length} favorites into cache', 'GalleryDS');
    } catch (e, stack) {
      AppLogger.e('Failed to load favorites cache', e, stack, 'GalleryDS');
    } finally {
      await _releaseDb(db);
    }
  }

  /// 获取收藏数量
  ///
  /// 如果缓存已加载，直接返回缓存大小；否则查询数据库
  Future<int> getFavoriteCount() async {
    // 如果缓存已加载，直接返回
    if (_favoritesLoaded) {
      return _favoriteCache.length;
    }

    final db = await _acquireDb();

    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_favoritesTable',
      );
      return (result.first['count'] as num?)?.toInt() ?? 0;
    } catch (e, stack) {
      AppLogger.e('Failed to get favorite count', e, stack, 'GalleryDS');
      return 0;
    } finally {
      await _releaseDb(db);
    }
  }

  /// 获取所有收藏的图片ID
  ///
  /// 先调用 loadFavoritesCache 确保缓存已加载
  Future<List<int>> getFavoriteImageIds() async {
    await loadFavoritesCache();
    return _favoriteCache.toList();
  }
}
