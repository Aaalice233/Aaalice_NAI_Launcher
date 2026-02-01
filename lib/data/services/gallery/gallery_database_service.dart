import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/gallery/local_image_record.dart';
import '../../models/gallery/nai_image_metadata.dart';
import 'gallery_database_schema.dart';

/// 画廊数据库服务
///
/// 使用SQLite存储图片索引和元数据，支持FTS5全文搜索
class GalleryDatabaseService {
  static const String _dbName = 'nai_gallery.db';
  static const int _dbVersion = 1;

  Database? _db;
  bool _initialized = false;

  /// 单例实例
  static final GalleryDatabaseService instance = GalleryDatabaseService._();

  GalleryDatabaseService._();

  /// 获取数据库实例
  Database get database {
    if (_db == null || !_db!.isOpen) {
      throw StateError('Database not initialized. Call init() first.');
    }
    return _db!;
  }

  /// 是否已初始化
  bool get isInitialized => _initialized;

  /// 初始化数据库
  Future<void> init() async {
    if (_initialized && _db != null && _db!.isOpen) return;

    // 初始化FFI（桌面端支持）
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dbPath = await _getDatabasePath();
    _db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );

    _initialized = true;
  }

  /// 获取数据库路径
  Future<String> _getDatabasePath() async {
    final appDir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(appDir.path, 'database'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    return p.join(dbDir.path, _dbName);
  }

  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 创建核心表
    batch.execute(GalleryDatabaseSchema.createImagesTable);
    batch.execute(GalleryDatabaseSchema.createMetadataTable);
    batch.execute(GalleryDatabaseSchema.createFavoritesTable);
    batch.execute(GalleryDatabaseSchema.createTagsTable);
    batch.execute(GalleryDatabaseSchema.createImageTagsTable);
    batch.execute(GalleryDatabaseSchema.createFoldersTable);
    batch.execute(GalleryDatabaseSchema.createScanHistoryTable);

    // 创建FTS5虚拟表
    batch.execute(GalleryDatabaseSchema.createMetadataFtsTable);

    // 创建索引
    for (final index in GalleryDatabaseSchema.createIndexes) {
      batch.execute(index);
    }

    // 创建FTS5触发器
    for (final trigger in GalleryDatabaseSchema.createFtsTriggers) {
      batch.execute(trigger);
    }

    await batch.commit(noResult: true);
  }

  /// 升级数据库
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 预留升级逻辑
  }

  /// 关闭数据库
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
      _initialized = false;
    }
  }

  // ============================================================
  // 图片记录操作
  // ============================================================

  /// 插入或更新图片记录
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
  }) async {
    final dateYmd = _formatDateYmd(modifiedAt);

    return await database.insert(
      'images',
      {
        'file_path': filePath,
        'file_name': fileName,
        'file_size': fileSize,
        'file_hash': fileHash,
        'width': width,
        'height': height,
        'aspect_ratio': aspectRatio,
        'created_at': createdAt.millisecondsSinceEpoch,
        'modified_at': modifiedAt.millisecondsSinceEpoch,
        'indexed_at': DateTime.now().millisecondsSinceEpoch,
        'date_ymd': dateYmd,
        'resolution_key': resolutionKey,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 批量插入图片记录（使用事务）
  Future<void> batchInsertImages(List<Map<String, dynamic>> images) async {
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final image in images) {
        batch.insert(
          'images',
          image,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// 根据路径获取图片ID
  Future<int?> getImageIdByPath(String filePath) async {
    final result = await database.query(
      'images',
      columns: ['id'],
      where: 'file_path = ?',
      whereArgs: [filePath],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first['id'] as int;
  }

  /// 获取所有文件路径和哈希映射（用于增量扫描）
  Future<Map<String, String?>> getAllFileHashes() async {
    final results = await database.query(
      'images',
      columns: ['file_path', 'file_hash'],
      where: 'is_deleted = 0',
    );

    return {
      for (final row in results)
        row['file_path'] as String: row['file_hash'] as String?,
    };
  }

  /// 标记图片为已删除（软删除）
  Future<void> markAsDeleted(String filePath) async {
    await database.update(
      'images',
      {'is_deleted': 1},
      where: 'file_path = ?',
      whereArgs: [filePath],
    );
  }

  /// 批量标记为已删除
  Future<void> batchMarkAsDeleted(List<String> filePaths) async {
    if (filePaths.isEmpty) return;

    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final path in filePaths) {
        batch.update(
          'images',
          {'is_deleted': 1},
          where: 'file_path = ?',
          whereArgs: [path],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// 根据ID查询单张图片
  Future<Map<String, dynamic>?> getImageById(int imageId) async {
    final results = await queryImagesByIds([imageId]);
    return results.isNotEmpty ? results.first : null;
  }

  /// 根据ID列表查询图片
  Future<List<Map<String, dynamic>>> queryImagesByIds(List<int> imageIds) async {
    if (imageIds.isEmpty) return [];

    // 构建IN子句的参数占位符
    final placeholders = List.filled(imageIds.length, '?').join(',');
    final args = imageIds.cast<dynamic>();

    final sql = '''
      SELECT 
        i.id,
        i.file_path,
        i.file_name,
        i.file_size,
        i.file_hash,
        i.width,
        i.height,
        i.aspect_ratio,
        i.created_at,
        i.modified_at,
        i.date_ymd,
        i.resolution_key,
        m.prompt,
        m.negative_prompt,
        m.seed,
        m.steps,
        m.cfg_scale,
        m.sampler,
        m.model,
        m.smea,
        m.smea_dyn,
        m.noise_schedule,
        m.cfg_rescale,
        m.character_prompts,
        m.character_negative_prompts,
        m.raw_json,
        m.has_metadata,
        (f.image_id IS NOT NULL) AS is_favorite
      FROM images i
      LEFT JOIN metadata m ON i.id = m.image_id
      LEFT JOIN favorites f ON i.id = f.image_id
      WHERE i.id IN ($placeholders) AND i.is_deleted = 0
      ORDER BY i.modified_at DESC
    ''';

    return await database.rawQuery(sql, args);
  }

  /// 查询图片总数
  Future<int> countImages({bool includeDeleted = false}) async {
    final where = includeDeleted ? null : 'is_deleted = 0';
    final result = await database.rawQuery(
      'SELECT COUNT(*) as count FROM images ${where != null ? "WHERE $where" : ""}',
    );
    return result.first['count'] as int? ?? 0;
  }

  /// 查询图片（分页）
  Future<List<Map<String, dynamic>>> queryImages({
    int limit = 50,
    int offset = 0,
    String orderBy = 'modified_at DESC',
    bool favoritesOnly = false,
    List<String>? tags,
    DateTime? dateStart,
    DateTime? dateEnd,
    String? model,
    String? sampler,
    int? minSteps,
    int? maxSteps,
    double? minCfg,
    double? maxCfg,
    String? resolution,
    String? folderId,
  }) async {
    final conditions = <String>['i.is_deleted = 0'];
    final args = <dynamic>[];

    // 收藏过滤
    if (favoritesOnly) {
      conditions.add('f.image_id IS NOT NULL');
    }

    // 日期范围过滤
    if (dateStart != null) {
      conditions.add('i.modified_at >= ?');
      args.add(dateStart.millisecondsSinceEpoch);
    }
    if (dateEnd != null) {
      conditions.add('i.modified_at <= ?');
      args.add(dateEnd.millisecondsSinceEpoch);
    }

    // 元数据过滤
    if (model != null) {
      conditions.add('m.model = ?');
      args.add(model);
    }
    if (sampler != null) {
      conditions.add('m.sampler = ?');
      args.add(sampler);
    }
    if (minSteps != null) {
      conditions.add('m.steps >= ?');
      args.add(minSteps);
    }
    if (maxSteps != null) {
      conditions.add('m.steps <= ?');
      args.add(maxSteps);
    }
    if (minCfg != null) {
      conditions.add('m.cfg_scale >= ?');
      args.add(minCfg);
    }
    if (maxCfg != null) {
      conditions.add('m.cfg_scale <= ?');
      args.add(maxCfg);
    }
    if (resolution != null) {
      conditions.add('i.resolution_key = ?');
      args.add(resolution);
    }

    final whereClause = conditions.join(' AND ');

    final sql = '''
      SELECT 
        i.id,
        i.file_path,
        i.file_name,
        i.file_size,
        i.file_hash,
        i.width,
        i.height,
        i.aspect_ratio,
        i.created_at,
        i.modified_at,
        i.date_ymd,
        i.resolution_key,
        m.prompt,
        m.negative_prompt,
        m.seed,
        m.steps,
        m.cfg_scale,
        m.sampler,
        m.model,
        m.smea,
        m.smea_dyn,
        m.noise_schedule,
        m.cfg_rescale,
        m.character_prompts,
        m.character_negative_prompts,
        m.raw_json,
        m.has_metadata,
        (f.image_id IS NOT NULL) AS is_favorite
      FROM images i
      LEFT JOIN metadata m ON i.id = m.image_id
      LEFT JOIN favorites f ON i.id = f.image_id
      WHERE $whereClause
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
    ''';

    args.addAll([limit, offset]);

    return await database.rawQuery(sql, args);
  }

  // ============================================================
  // 元数据操作
  // ============================================================

  /// 插入或更新元数据
  Future<void> upsertMetadata(int imageId, NaiImageMetadata metadata) async {
    final fullPromptText = _buildFullPromptText(metadata);

    await database.insert(
      'metadata',
      {
        'image_id': imageId,
        'prompt': metadata.prompt,
        'negative_prompt': metadata.negativePrompt,
        'seed': metadata.seed,
        'steps': metadata.steps,
        'cfg_scale': metadata.scale,
        'sampler': metadata.sampler,
        'model': metadata.model,
        'noise_schedule': metadata.noiseSchedule,
        'smea': metadata.smea == true ? 1 : 0,
        'smea_dyn': metadata.smeaDyn == true ? 1 : 0,
        'cfg_rescale': metadata.cfgRescale,
        'quality_toggle': metadata.qualityToggle == true ? 1 : 0,
        'uc_preset': metadata.ucPreset,
        'is_img2img': metadata.isImg2Img ? 1 : 0,
        'strength': metadata.strength,
        'noise': metadata.noise,
        'software': metadata.software,
        'version': metadata.version,
        'source': metadata.source,
        'character_prompts': jsonEncode(metadata.characterPrompts),
        'character_negative_prompts':
            jsonEncode(metadata.characterNegativePrompts),
        'raw_json': metadata.rawJson,
        'has_metadata': metadata.hasData ? 1 : 0,
        'full_prompt_text': fullPromptText,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 构建完整提示词文本（用于FTS5搜索）
  String _buildFullPromptText(NaiImageMetadata metadata) {
    final buffer = StringBuffer();
    buffer.write(metadata.prompt);
    if (metadata.negativePrompt.isNotEmpty) {
      buffer.write(' ');
      buffer.write(metadata.negativePrompt);
    }
    for (final cp in metadata.characterPrompts) {
      buffer.write(' ');
      buffer.write(cp);
    }
    return buffer.toString();
  }

  // ============================================================
  // FTS5全文搜索
  // ============================================================

  /// 全文搜索图片
  Future<List<int>> searchFullText(String query, {int limit = 100}) async {
    if (query.trim().isEmpty) return [];

    // 处理搜索词，添加通配符支持
    final searchQuery = query
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => '"$s"*')
        .join(' OR ');

    final results = await database.rawQuery(
      '''
      SELECT rowid FROM metadata_fts 
      WHERE metadata_fts MATCH ? 
      ORDER BY rank 
      LIMIT ?
      ''',
      [searchQuery, limit],
    );

    return results.map((row) => row['rowid'] as int).toList();
  }

  // ============================================================
  // 收藏操作
  // ============================================================

  /// 切换收藏状态
  Future<bool> toggleFavorite(int imageId) async {
    final exists = await database.query(
      'favorites',
      where: 'image_id = ?',
      whereArgs: [imageId],
      limit: 1,
    );

    if (exists.isEmpty) {
      await database.insert('favorites', {
        'image_id': imageId,
        'favorited_at': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    } else {
      await database.delete(
        'favorites',
        where: 'image_id = ?',
        whereArgs: [imageId],
      );
      return false;
    }
  }

  /// 检查是否已收藏
  Future<bool> isFavorite(int imageId) async {
    final result = await database.query(
      'favorites',
      where: 'image_id = ?',
      whereArgs: [imageId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// 获取收藏数量
  Future<int> getFavoriteCount() async {
    final result = await database.rawQuery(
      'SELECT COUNT(*) as count FROM favorites',
    );
    return result.first['count'] as int? ?? 0;
  }

  // ============================================================
  // 标签操作
  // ============================================================

  /// 添加标签到图片
  Future<void> addTag(int imageId, String tagName) async {
    await database.transaction((txn) async {
      // 插入或获取标签
      await txn.insert(
        'tags',
        {'tag_name': tagName},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      final tagResult = await txn.query(
        'tags',
        where: 'tag_name = ?',
        whereArgs: [tagName],
        limit: 1,
      );

      if (tagResult.isNotEmpty) {
        final tagId = tagResult.first['id'] as int;
        await txn.insert(
          'image_tags',
          {
            'image_id': imageId,
            'tag_id': tagId,
            'tagged_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  /// 从图片移除标签
  Future<void> removeTag(int imageId, String tagName) async {
    await database.rawDelete(
      '''
      DELETE FROM image_tags 
      WHERE image_id = ? AND tag_id IN (
        SELECT id FROM tags WHERE tag_name = ?
      )
      ''',
      [imageId, tagName],
    );
  }

  /// 获取图片的所有标签
  Future<List<String>> getImageTags(int imageId) async {
    final results = await database.rawQuery(
      '''
      SELECT t.tag_name 
      FROM tags t
      INNER JOIN image_tags it ON t.id = it.tag_id
      WHERE it.image_id = ?
      ORDER BY it.tagged_at DESC
      ''',
      [imageId],
    );

    return results.map((row) => row['tag_name'] as String).toList();
  }

  /// 获取所有标签
  Future<List<Map<String, dynamic>>> getAllTags() async {
    return await database.rawQuery(
      '''
      SELECT t.id, t.tag_name, COUNT(it.image_id) as image_count
      FROM tags t
      LEFT JOIN image_tags it ON t.id = it.tag_id
      GROUP BY t.id
      ORDER BY image_count DESC
      ''',
    );
  }

  // ============================================================
  // 统计数据
  // ============================================================

  /// 获取画廊统计信息
  Future<Map<String, dynamic>> getStatistics() async {
    final totalImages = await countImages();
    final favoriteCount = await getFavoriteCount();

    final sizeResult = await database.rawQuery(
      'SELECT SUM(file_size) as total_size FROM images WHERE is_deleted = 0',
    );
    final totalSize = sizeResult.first['total_size'] as int? ?? 0;

    final metadataResult = await database.rawQuery(
      '''
      SELECT COUNT(*) as count FROM metadata m
      INNER JOIN images i ON m.image_id = i.id
      WHERE i.is_deleted = 0 AND m.has_metadata = 1
      ''',
    );
    final imagesWithMetadata = metadataResult.first['count'] as int? ?? 0;

    return {
      'total_images': totalImages,
      'favorite_count': favoriteCount,
      'total_size_bytes': totalSize,
      'images_with_metadata': imagesWithMetadata,
    };
  }

  /// 获取模型分布统计
  Future<List<Map<String, dynamic>>> getModelDistribution() async {
    return await database.rawQuery(
      '''
      SELECT m.model, COUNT(*) as count
      FROM metadata m
      INNER JOIN images i ON m.image_id = i.id
      WHERE i.is_deleted = 0 AND m.model IS NOT NULL
      GROUP BY m.model
      ORDER BY count DESC
      LIMIT 20
      ''',
    );
  }

  /// 获取采样器分布统计
  Future<List<Map<String, dynamic>>> getSamplerDistribution() async {
    return await database.rawQuery(
      '''
      SELECT m.sampler, COUNT(*) as count
      FROM metadata m
      INNER JOIN images i ON m.image_id = i.id
      WHERE i.is_deleted = 0 AND m.sampler IS NOT NULL
      GROUP BY m.sampler
      ORDER BY count DESC
      ''',
    );
  }

  /// 获取分辨率分布统计
  Future<List<Map<String, dynamic>>> getResolutionDistribution() async {
    return await database.rawQuery(
      '''
      SELECT resolution_key, COUNT(*) as count
      FROM images
      WHERE is_deleted = 0 AND resolution_key IS NOT NULL
      GROUP BY resolution_key
      ORDER BY count DESC
      LIMIT 20
      ''',
    );
  }

  // ============================================================
  // 扫描历史
  // ============================================================

  /// 记录扫描历史
  Future<void> insertScanHistory({
    required String scanType,
    required String rootPath,
    required int filesScanned,
    required int filesAdded,
    required int filesUpdated,
    required int filesDeleted,
    required int scanDurationMs,
    required DateTime startedAt,
    required DateTime completedAt,
  }) async {
    await database.insert('scan_history', {
      'scan_type': scanType,
      'root_path': rootPath,
      'files_scanned': filesScanned,
      'files_added': filesAdded,
      'files_updated': filesUpdated,
      'files_deleted': filesDeleted,
      'scan_duration_ms': scanDurationMs,
      'started_at': startedAt.millisecondsSinceEpoch,
      'completed_at': completedAt.millisecondsSinceEpoch,
    });
  }

  /// 获取最后一次扫描记录
  Future<Map<String, dynamic>?> getLastScanHistory() async {
    final results = await database.query(
      'scan_history',
      orderBy: 'completed_at DESC',
      limit: 1,
    );
    return results.isEmpty ? null : results.first;
  }

  // ============================================================
  // 工具方法
  // ============================================================

  /// 格式化日期为YYYYMMDD整数
  int _formatDateYmd(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  /// 将数据库记录转换为LocalImageRecord
  LocalImageRecord mapToLocalImageRecord(Map<String, dynamic> row) {
    final metadata = row['has_metadata'] == 1
        ? NaiImageMetadata(
            prompt: row['prompt'] as String? ?? '',
            negativePrompt: row['negative_prompt'] as String? ?? '',
            seed: row['seed'] as int?,
            sampler: row['sampler'] as String?,
            steps: row['steps'] as int?,
            scale: row['cfg_scale'] as double?,
            width: row['width'] as int?,
            height: row['height'] as int?,
            model: row['model'] as String?,
            smea: row['smea'] == 1,
            smeaDyn: row['smea_dyn'] == 1,
            noiseSchedule: row['noise_schedule'] as String?,
            cfgRescale: row['cfg_rescale'] as double?,
            characterPrompts: _parseJsonList(row['character_prompts']),
            characterNegativePrompts:
                _parseJsonList(row['character_negative_prompts']),
            rawJson: row['raw_json'] as String?,
          )
        : null;

    return LocalImageRecord(
      path: row['file_path'] as String,
      size: row['file_size'] as int,
      modifiedAt:
          DateTime.fromMillisecondsSinceEpoch(row['modified_at'] as int),
      metadata: metadata,
      metadataStatus:
          metadata != null ? MetadataStatus.success : MetadataStatus.none,
      isFavorite: row['is_favorite'] == 1,
    );
  }

  /// 解析JSON列表
  List<String> _parseJsonList(dynamic value) {
    if (value == null) return [];
    if (value is String) {
      try {
        final list = jsonDecode(value) as List;
        return list.cast<String>();
      } catch (_) {
        return [];
      }
    }
    return [];
  }
}
