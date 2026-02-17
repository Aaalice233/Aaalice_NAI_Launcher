import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/gallery/nai_image_metadata.dart';
import 'gallery_database_service.dart';

/// 迁移结果
class MigrationResult {
  bool alreadyMigrated = false;
  int metadataMigrated = 0;
  int favoritesMigrated = 0;
  int tagsMigrated = 0;
  List<String> errors = [];
  Duration duration = Duration.zero;

  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() {
    return 'MigrationResult(migrated: ${!alreadyMigrated}, '
        'metadata: $metadataMigrated, favorites: $favoritesMigrated, '
        'tags: $tagsMigrated, errors: ${errors.length})';
  }
}

/// 画廊数据迁移服务
///
/// 将现有Hive存储的数据迁移到SQLite
class GalleryMigrationService {
  final GalleryDatabaseService _db;

  /// 迁移状态标记键
  static const String _migrationCompleteKey = 'gallery_migration_complete';

  GalleryMigrationService({required GalleryDatabaseService db}) : _db = db;

  /// 单例实例
  static GalleryMigrationService? _instance;
  static GalleryMigrationService get instance {
    _instance ??= GalleryMigrationService(db: GalleryDatabaseService.instance);
    return _instance!;
  }

  /// 执行迁移（应用启动时自动调用）
  Future<MigrationResult> migrate() async {
    final stopwatch = Stopwatch()..start();
    final result = MigrationResult();

    // 检查是否已迁移
    if (await _checkMigrationStatus()) {
      result.alreadyMigrated = true;
      AppLogger.d('Migration already completed', 'GalleryMigrationService');
      return result;
    }

    AppLogger.i('Starting gallery data migration', 'GalleryMigrationService');

    try {
      // 迁移元数据缓存
      await _migrateMetadataCache(result);

      // 迁移收藏数据
      await _migrateFavorites(result);

      // 迁移标签数据
      await _migrateTags(result);

      // 标记迁移完成
      await _markMigrationComplete();

      AppLogger.i('Migration completed: $result', 'GalleryMigrationService');
    } catch (e, stack) {
      AppLogger.e('Migration failed', e, stack, 'GalleryMigrationService');
      result.errors.add(e.toString());
    }

    stopwatch.stop();
    result.duration = stopwatch.elapsed;

    return result;
  }

  /// 检查迁移状态
  Future<bool> _checkMigrationStatus() async {
    try {
      final settingsBox = Hive.box(StorageKeys.settingsBox);
      return settingsBox.get(_migrationCompleteKey, defaultValue: false) as bool;
    } catch (e) {
      return false;
    }
  }

  /// 标记迁移完成
  Future<void> _markMigrationComplete() async {
    try {
      final settingsBox = Hive.box(StorageKeys.settingsBox);
      await settingsBox.put(_migrationCompleteKey, true);
    } catch (e) {
      AppLogger.w('Failed to mark migration complete: $e', 'GalleryMigrationService');
    }
  }

  /// 迁移元数据缓存（Hive -> SQLite）
  Future<void> _migrateMetadataCache(MigrationResult result) async {
    try {
      final cacheBox = Hive.box(StorageKeys.localMetadataCacheBox);
      final keys = cacheBox.keys.toList();

      AppLogger.d('Migrating ${keys.length} metadata entries', 'GalleryMigrationService');

      for (final key in keys) {
        try {
          final filePath = key as String;
          final jsonStr = cacheBox.get(key) as String?;
          if (jsonStr == null) continue;

          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final metadata = NaiImageMetadata.fromJson(
            data['meta'] as Map<String, dynamic>,
          );

          // 查找对应的image_id
          final imageId = await _db.getImageIdByPath(filePath);
          if (imageId != null) {
            await _db.upsertMetadata(imageId, metadata);
            result.metadataMigrated++;
          }
        } catch (e) {
          // 单条记录迁移失败不影响整体
          result.errors.add('Metadata migration error for $key: $e');
        }
      }
    } catch (e) {
      result.errors.add('Metadata cache migration failed: $e');
    }
  }

  /// 迁移收藏数据
  Future<void> _migrateFavorites(MigrationResult result) async {
    try {
      if (!Hive.isBoxOpen(StorageKeys.localFavoritesBox)) {
        await Hive.openBox(StorageKeys.localFavoritesBox);
      }
      final favoritesBox = Hive.box(StorageKeys.localFavoritesBox);
      final keys = favoritesBox.keys.toList();

      AppLogger.d('Migrating ${keys.length} favorites', 'GalleryMigrationService');

      for (final key in keys) {
        try {
          final filePath = key as String;
          final isFavorite = favoritesBox.get(key);

          // 兼容不同的存储格式
          bool shouldMigrate = false;
          if (isFavorite is bool) {
            shouldMigrate = isFavorite;
          } else if (isFavorite == 1 || isFavorite == '1' || isFavorite == 'true') {
            shouldMigrate = true;
          }

          if (!shouldMigrate) continue;

          // 查找对应的image_id
          final imageId = await _db.getImageIdByPath(filePath);
          if (imageId != null) {
            // 检查是否已收藏，避免重复
            final alreadyFavorite = await _db.isFavorite(imageId);
            if (!alreadyFavorite) {
              await _db.toggleFavorite(imageId);
              result.favoritesMigrated++;
            }
          }
        } catch (e) {
          result.errors.add('Favorite migration error for $key: $e');
        }
      }
    } catch (e) {
      result.errors.add('Favorites migration failed: $e');
    }
  }

  /// 迁移标签数据
  Future<void> _migrateTags(MigrationResult result) async {
    try {
      if (!Hive.isBoxOpen(StorageKeys.tagsBox)) {
        await Hive.openBox(StorageKeys.tagsBox);
      }
      final tagsBox = Hive.box(StorageKeys.tagsBox);
      final keys = tagsBox.keys.toList();

      AppLogger.d('Migrating tags for ${keys.length} images', 'GalleryMigrationService');

      for (final key in keys) {
        try {
          final filePath = key as String;
          final tagsData = tagsBox.get(key);

          // 解析标签列表
          List<String> tags = [];
          if (tagsData is List) {
            tags = tagsData.cast<String>();
          } else if (tagsData is String) {
            try {
              final parsed = jsonDecode(tagsData);
              if (parsed is List) {
                tags = parsed.cast<String>();
              }
            } catch (_) {
              // 可能是逗号分隔的字符串
              tags = tagsData.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            }
          }

          if (tags.isEmpty) continue;

          // 查找对应的image_id
          final imageId = await _db.getImageIdByPath(filePath);
          if (imageId != null) {
            for (final tag in tags) {
              await _db.addTag(imageId, tag);
              result.tagsMigrated++;
            }
          }
        } catch (e) {
          result.errors.add('Tag migration error for $key: $e');
        }
      }
    } catch (e) {
      result.errors.add('Tags migration failed: $e');
    }
  }

  /// 重置迁移状态（用于测试）
  Future<void> resetMigration() async {
    try {
      final settingsBox = Hive.box(StorageKeys.settingsBox);
      await settingsBox.delete(_migrationCompleteKey);
      AppLogger.i('Migration status reset', 'GalleryMigrationService');
    } catch (e) {
      AppLogger.w('Failed to reset migration: $e', 'GalleryMigrationService');
    }
  }
}
