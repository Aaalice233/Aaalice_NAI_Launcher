import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

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
  final String id; // 图片ID (路径的hash)
  final String path; // 文件路径
  final int size; // 文件大小（字节）
  final DateTime modifiedAt; // 最后修改时间
  final DateTime createdAt; // 创建时间
  final DateTime indexedAt; // 索引时间
  final MetadataStatus metadataStatus; // 元数据状态
  final bool isFavorite; // 是否收藏

  const GalleryImageRecord({
    required this.id,
    required this.path,
    required this.size,
    required this.modifiedAt,
    required this.createdAt,
    required this.indexedAt,
    this.metadataStatus = MetadataStatus.none,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'path': path,
        'size': size,
        'modified_at': modifiedAt.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
        'indexed_at': indexedAt.millisecondsSinceEpoch,
        'metadata_status': metadataStatus.index,
        'is_favorite': isFavorite ? 1 : 0,
      };

  factory GalleryImageRecord.fromMap(Map<String, dynamic> map) {
    return GalleryImageRecord(
      id: map['id'] as String,
      path: map['path'] as String,
      size: (map['size'] as num?)?.toInt() ?? 0,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['modified_at'] as num?)?.toInt() ?? 0,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
      indexedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['indexed_at'] as num?)?.toInt() ?? 0,
      ),
      metadataStatus: MetadataStatus.values[
        (map['metadata_status'] as num?)?.toInt() ?? 2, // 默认 none
      ],
      isFavorite: (map['is_favorite'] as num?)?.toInt() == 1,
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
  final LRUCache<String, GalleryImageRecord> _imageCache =
      LRUCache(maxSize: _maxImageCacheSize);
  final LRUCache<String, GalleryMetadataRecord> _metadataCache =
      LRUCache(maxSize: _maxMetadataCacheSize);

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
      // 创建图片基础信息表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_imagesTable (
          id TEXT PRIMARY KEY,
          path TEXT NOT NULL UNIQUE,
          size INTEGER NOT NULL DEFAULT 0,
          modified_at INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          indexed_at INTEGER NOT NULL,
          metadata_status INTEGER NOT NULL DEFAULT 2,
          is_favorite INTEGER NOT NULL DEFAULT 0
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
          image_id TEXT PRIMARY KEY,
          prompt TEXT NOT NULL DEFAULT '',
          negative_prompt TEXT NOT NULL DEFAULT '',
          seed INTEGER,
          sampler TEXT,
          steps INTEGER,
          scale REAL,
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
          full_prompt_text TEXT NOT NULL DEFAULT '',
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
          image_id TEXT PRIMARY KEY,
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
          image_id TEXT NOT NULL,
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
          image_id,
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

  @override
  Future<void> doDispose() async {
    clearCache();
    AppLogger.i('Gallery data source disposed', 'GalleryDS');
  }
}
