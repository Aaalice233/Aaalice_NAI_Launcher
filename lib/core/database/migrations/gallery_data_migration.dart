import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/services/sqflite_bootstrap_service.dart';
import '../../../data/models/gallery/nai_image_metadata.dart';
import '../datasources/gallery_data_source.dart';

/// 迁移结果类
///
/// 记录数据迁移的详细结果和统计信息
class MigrationResult {
  /// 迁移是否成功
  bool success = false;

  /// 迁移的图片数量
  int imagesMigrated = 0;

  /// 迁移的元数据数量
  int metadataMigrated = 0;

  /// 迁移的收藏数量
  int favoritesMigrated = 0;

  /// 迁移的标签数量
  int tagsMigrated = 0;

  /// 迁移的图片-标签关联数量
  int imageTagsMigrated = 0;

  /// 错误信息（如果失败）
  String? error;

  @override
  String toString() {
    return 'MigrationResult(success: $success, images: $imagesMigrated, '
        'metadata: $metadataMigrated, favorites: $favoritesMigrated, '
        'tags: $tagsMigrated, imageTags: $imageTagsMigrated, error: $error)';
  }
}

/// 标签迁移结果
///
/// 记录标签迁移的映射关系
class TagMigrationResult {
  /// 旧标签ID到新标签ID的映射
  final Map<int, String> tagIdMapping = {};

  /// 旧标签名称到新标签ID的映射
  final Map<String, String> tagNameMapping = {};

  /// 添加映射关系
  void addMapping(int oldId, String newId, String tagName) {
    tagIdMapping[oldId] = newId;
    tagNameMapping[tagName.toLowerCase()] = newId;
  }

  /// 根据旧ID获取新ID
  String? getNewIdByOldId(int oldId) => tagIdMapping[oldId];

  /// 根据标签名称获取新ID
  String? getNewIdByName(String tagName) => tagNameMapping[tagName.toLowerCase()];
}

/// 画廊数据迁移工具类
///
/// 负责将旧版画廊数据库（nai_gallery.db）的数据迁移到新的统一数据库架构。
/// 支持迁移图片、元数据、收藏和标签数据。
class GalleryDataMigration {
  GalleryDataMigration._();

  /// 旧数据库名称
  static const String _oldDbName = 'nai_gallery.db';

  /// 旧数据库实例
  static Database? _oldDb;

  /// 标签迁移结果缓存
  static final TagMigrationResult _tagMigrationResult = TagMigrationResult();

  /// 旧图片ID到新图片ID的映射
  static final Map<int, int> _imageIdMapping = {};

  /// 检查是否需要迁移
  ///
  /// 检查旧数据库文件是否存在且包含数据
  static Future<bool> needsMigration() async {
    try {
      final oldDbPath = await _getOldDatabasePath();
      final oldDbFile = File(oldDbPath);

      if (!await oldDbFile.exists()) {
        AppLogger.i('Old database not found, no migration needed', 'GalleryMigration');
        return false;
      }

      // 检查数据库是否包含数据
      final db = await _openOldDatabase();
      try {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM images');
        final count = (result.first['count'] as num?)?.toInt() ?? 0;

        if (count == 0) {
          AppLogger.i('Old database is empty, no migration needed', 'GalleryMigration');
          return false;
        }

        AppLogger.i('Old database found with $count images, migration needed', 'GalleryMigration');
        return true;
      } finally {
        await _closeOldDatabase();
      }
    } catch (e, stack) {
      AppLogger.e('Failed to check migration need', e, stack, 'GalleryMigration');
      return false;
    }
  }

  /// 执行数据迁移
  ///
  /// [dataSource] 目标数据源
  /// 返回迁移结果
  static Future<MigrationResult> migrate(GalleryDataSource dataSource) async {
    final result = MigrationResult();

    try {
      AppLogger.i('Starting gallery data migration...', 'GalleryMigration');

      // 打开旧数据库
      _oldDb = await _openOldDatabase();

      // 执行各项迁移
      await _migrateImages(dataSource, result);
      await _migrateMetadata(dataSource, result);
      await _migrateFavorites(dataSource, result);
      await _migrateTags(dataSource, result);

      // 关闭旧数据库
      await _closeOldDatabase();

      // 删除旧数据库文件
      await _deleteOldDatabase();

      result.success = true;
      AppLogger.i('Gallery data migration completed: $result', 'GalleryMigration');
    } catch (e, stack) {
      result.success = false;
      result.error = e.toString();
      AppLogger.e('Gallery data migration failed', e, stack, 'GalleryMigration');

      // 确保关闭旧数据库
      await _closeOldDatabase();
    }

    return result;
  }

  /// 获取旧数据库路径
  static Future<String> _getOldDatabasePath() async {
    final appDir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(appDir.path, 'database'));
    return p.join(dbDir.path, _oldDbName);
  }

  /// 打开旧数据库
  static Future<Database> _openOldDatabase() async {
    if (_oldDb != null && _oldDb!.isOpen) {
      return _oldDb!;
    }

    // 初始化 FFI
    await SqfliteBootstrapService.instance.ensureInitialized();

    final dbPath = await _getOldDatabasePath();
    _oldDb = await databaseFactoryFfi.openDatabase(dbPath);

    AppLogger.i('Opened old database: $dbPath', 'GalleryMigration');
    return _oldDb!;
  }

  /// 关闭旧数据库
  static Future<void> _closeOldDatabase() async {
    if (_oldDb != null && _oldDb!.isOpen) {
      await _oldDb!.close();
      _oldDb = null;
      AppLogger.i('Closed old database', 'GalleryMigration');
    }
  }

  /// 删除旧数据库文件
  static Future<void> _deleteOldDatabase() async {
    try {
      final dbPath = await _getOldDatabasePath();
      final dbFile = File(dbPath);

      if (await dbFile.exists()) {
        await dbFile.delete();
        AppLogger.i('Deleted old database file: $dbPath', 'GalleryMigration');
      }

      // 同时删除相关的 journal 文件
      final journalFile = File('$dbPath-journal');
      if (await journalFile.exists()) {
        await journalFile.delete();
      }

      final walFile = File('$dbPath-wal');
      if (await walFile.exists()) {
        await walFile.delete();
      }
    } catch (e) {
      AppLogger.w('Failed to delete old database: $e', 'GalleryMigration');
    }
  }

  /// 迁移图片数据
  static Future<void> _migrateImages(
    GalleryDataSource dataSource,
    MigrationResult result,
  ) async {
    try {
      final db = await _openOldDatabase();

      // 查询所有未删除的图片
      final images = await db.rawQuery('''
        SELECT * FROM images
        WHERE is_deleted = 0 OR is_deleted IS NULL
        ORDER BY id
      ''');

      AppLogger.i('Found ${images.length} images to migrate', 'GalleryMigration');

      int successCount = 0;
      int failCount = 0;

      for (final image in images) {
        try {
          final oldId = image['id'] as int;
          final filePath = image['file_path'] as String;
          final fileName = image['file_name'] as String;
          final fileSize = (image['file_size'] as num?)?.toInt() ?? 0;
          final fileHash = image['file_hash'] as String?;
          final width = (image['width'] as num?)?.toInt();
          final height = (image['height'] as num?)?.toInt();
          final aspectRatio = (image['aspect_ratio'] as num?)?.toDouble();
          final createdAt = _parseDateTime(image['created_at']);
          final modifiedAt = _parseDateTime(image['modified_at']);
          final resolutionKey = image['resolution_key'] as String?;

          // 插入到新数据源
          final newId = await dataSource.upsertImage(
            filePath: filePath,
            fileName: fileName,
            fileSize: fileSize,
            fileHash: fileHash,
            width: width,
            height: height,
            aspectRatio: aspectRatio,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            resolutionKey: resolutionKey,
            metadataStatus: MetadataStatus.none,
            isFavorite: false, // 将在收藏迁移时更新
          );

          // 记录ID映射
          _imageIdMapping[oldId] = newId;
          successCount++;
        } catch (e) {
          failCount++;
          AppLogger.w('Failed to migrate image: $e', 'GalleryMigration');
          // 单条失败不影响整体
        }
      }

      result.imagesMigrated = successCount;
      AppLogger.i(
        'Migrated $successCount images ($failCount failed)',
        'GalleryMigration',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to migrate images', e, stack, 'GalleryMigration');
      rethrow;
    }
  }

  /// 迁移元数据
  static Future<void> _migrateMetadata(
    GalleryDataSource dataSource,
    MigrationResult result,
  ) async {
    try {
      final db = await _openOldDatabase();

      // 查询所有元数据
      final metadataList = await db.rawQuery('''
        SELECT * FROM metadata
        WHERE has_metadata = 1
        ORDER BY image_id
      ''');

      AppLogger.i('Found ${metadataList.length} metadata records to migrate', 'GalleryMigration');

      int successCount = 0;
      int failCount = 0;

      for (final metadata in metadataList) {
        try {
          final oldImageId = metadata['image_id'] as int;
          final newImageId = _imageIdMapping[oldImageId];

          if (newImageId == null) {
            AppLogger.w('Image ID mapping not found for: $oldImageId', 'GalleryMigration');
            continue;
          }

          // 构建 NaiImageMetadata
          final naiMetadata = NaiImageMetadata(
            prompt: metadata['prompt'] as String? ?? '',
            negativePrompt: metadata['negative_prompt'] as String? ?? '',
            seed: (metadata['seed'] as num?)?.toInt(),
            sampler: metadata['sampler'] as String?,
            steps: (metadata['steps'] as num?)?.toInt(),
            scale: (metadata['cfg_scale'] as num?)?.toDouble(),
            width: (metadata['width'] as num?)?.toInt(),
            height: (metadata['height'] as num?)?.toInt(),
            model: metadata['model'] as String?,
            smea: metadata['smea'] == 1,
            smeaDyn: metadata['smea_dyn'] == 1,
            noiseSchedule: metadata['noise_schedule'] as String?,
            cfgRescale: (metadata['cfg_rescale'] as num?)?.toDouble(),
            ucPreset: (metadata['uc_preset'] as num?)?.toInt(),
            qualityToggle: metadata['quality_toggle'] == 1,
            isImg2Img: metadata['is_img2img'] == 1,
            strength: (metadata['strength'] as num?)?.toDouble(),
            noise: (metadata['noise'] as num?)?.toDouble(),
            software: metadata['software'] as String?,
            source: metadata['source'] as String?,
            version: metadata['version']?.toString(),
            characterPrompts: _parseJsonList(metadata['character_prompts']),
            characterNegativePrompts: _parseJsonList(metadata['character_negative_prompts']),
            rawJson: metadata['raw_json'] as String?,
          );

          // 插入到新数据源
          await dataSource.upsertMetadata(newImageId, naiMetadata);
          successCount++;
        } catch (e) {
          failCount++;
          AppLogger.w('Failed to migrate metadata: $e', 'GalleryMigration');
          // 单条失败不影响整体
        }
      }

      result.metadataMigrated = successCount;
      AppLogger.i(
        'Migrated $successCount metadata records ($failCount failed)',
        'GalleryMigration',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to migrate metadata', e, stack, 'GalleryMigration');
      rethrow;
    }
  }

  /// 迁移收藏数据
  static Future<void> _migrateFavorites(
    GalleryDataSource dataSource,
    MigrationResult result,
  ) async {
    try {
      final db = await _openOldDatabase();

      // 查询所有收藏
      final favorites = await db.rawQuery('''
        SELECT f.*, i.file_path
        FROM favorites f
        INNER JOIN images i ON f.image_id = i.id
        ORDER BY f.image_id
      ''');

      AppLogger.i('Found ${favorites.length} favorites to migrate', 'GalleryMigration');

      int successCount = 0;
      int failCount = 0;

      for (final favorite in favorites) {
        try {
          final oldImageId = favorite['image_id'] as int;
          final newImageId = _imageIdMapping[oldImageId];

          if (newImageId == null) {
            // 尝试通过文件路径查找
            final filePath = favorite['file_path'] as String?;
            if (filePath != null) {
              final foundId = await dataSource.getImageIdByPath(filePath);
              if (foundId != null) {
                await dataSource.toggleFavorite(foundId);
                successCount++;
                continue;
              }
            }
            AppLogger.w('Favorite image not found for old ID: $oldImageId', 'GalleryMigration');
            continue;
          }

          // 切换收藏状态（默认是未收藏，切换后变为收藏）
          await dataSource.toggleFavorite(newImageId);
          successCount++;
        } catch (e) {
          failCount++;
          AppLogger.w('Failed to migrate favorite: $e', 'GalleryMigration');
          // 单条失败不影响整体
        }
      }

      result.favoritesMigrated = successCount;
      AppLogger.i(
        'Migrated $successCount favorites ($failCount failed)',
        'GalleryMigration',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to migrate favorites', e, stack, 'GalleryMigration');
      rethrow;
    }
  }

  /// 迁移标签数据
  static Future<void> _migrateTags(
    GalleryDataSource dataSource,
    MigrationResult result,
  ) async {
    try {
      final db = await _openOldDatabase();

      // 首先迁移所有标签
      final tags = await db.rawQuery('''
        SELECT * FROM tags
        ORDER BY id
      ''');

      AppLogger.i('Found ${tags.length} tags to migrate', 'GalleryMigration');

      // 清空之前的映射
      _tagMigrationResult.tagIdMapping.clear();
      _tagMigrationResult.tagNameMapping.clear();

      // 第一步：建立标签映射（新系统使用小写标签名作为ID）
      for (final tag in tags) {
        try {
          final oldId = tag['id'] as int;
          final tagName = tag['tag_name'] as String;

          // 新系统使用小写标签名作为ID
          final newId = tagName.toLowerCase().trim();

          // 记录映射
          _tagMigrationResult.addMapping(oldId, newId, tagName);
        } catch (e) {
          AppLogger.w('Failed to map tag: $e', 'GalleryMigration');
          // 单条失败不影响整体
        }
      }

      result.tagsMigrated = _tagMigrationResult.tagIdMapping.length;
      AppLogger.i(
        'Mapped ${_tagMigrationResult.tagIdMapping.length} tags',
        'GalleryMigration',
      );

      // 第二步：迁移图片-标签关联
      final imageTags = await db.rawQuery('''
        SELECT * FROM image_tags
        ORDER BY image_id, tag_id
      ''');

      AppLogger.i('Found ${imageTags.length} image-tag associations to migrate', 'GalleryMigration');

      int successCount = 0;
      int failCount = 0;

      for (final imageTag in imageTags) {
        try {
          final oldImageId = imageTag['image_id'] as int;
          final oldTagId = imageTag['tag_id'] as int;

          final newImageId = _imageIdMapping[oldImageId];
          final newTagId = _tagMigrationResult.getNewIdByOldId(oldTagId);

          if (newImageId == null) {
            AppLogger.w('Image ID mapping not found for: $oldImageId', 'GalleryMigration');
            continue;
          }

          if (newTagId == null) {
            AppLogger.w('Tag ID mapping not found for: $oldTagId', 'GalleryMigration');
            continue;
          }

          // 添加标签到图片（使用标签名称，addTag 会自动创建标签）
          await dataSource.addTag(newImageId, newTagId);
          successCount++;
        } catch (e) {
          failCount++;
          AppLogger.w('Failed to migrate image-tag association: $e', 'GalleryMigration');
          // 单条失败不影响整体
        }
      }

      result.imageTagsMigrated = successCount;
      AppLogger.i(
        'Migrated $successCount image-tag associations ($failCount failed)',
        'GalleryMigration',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to migrate tags', e, stack, 'GalleryMigration');
      rethrow;
    }
  }

  /// 解析日期时间
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }

    return DateTime.now();
  }

  /// 解析 JSON 列表
  static List<String> _parseJsonList(dynamic value) {
    if (value == null) return [];

    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.cast<String>();
        }
      } catch (_) {
        // 解析失败返回空列表
      }
    }

    return [];
  }
}
