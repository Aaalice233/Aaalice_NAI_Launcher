import 'dart:async';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';

import '../../core/cache/thumbnail_cache_service.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../models/gallery/generation_record.dart';
import 'thumbnail_generation_queue.dart';

/// 缩略图迁移服务
///
/// 检测并批量为已有图片生成缺失的缩略图。
/// 使用后台队列处理，避免阻塞 UI。
class ThumbnailMigrationService {
  /// 迁移状态存储键
  static const String _migrationCompletedKey = 'thumbnail_migration_completed';

  /// 最后检查时间键
  static const String _lastCheckTimeKey = 'thumbnail_migration_last_check';

  /// 单例
  static final ThumbnailMigrationService _instance =
      ThumbnailMigrationService._();
  factory ThumbnailMigrationService() => _instance;
  ThumbnailMigrationService._();

  /// 缩略图缓存服务
  ThumbnailCacheService? _thumbnailService;

  /// 缩略图生成队列
  ThumbnailGenerationQueue? _thumbnailQueue;

  /// 是否正在处理中
  bool _isProcessing = false;

  /// 初始化服务
  ///
  /// [thumbnailService] 缩略图缓存服务实例
  /// [thumbnailQueue] 缩略图生成队列实例
  void init({
    ThumbnailCacheService? thumbnailService,
    ThumbnailGenerationQueue? thumbnailQueue,
  }) {
    _thumbnailService = thumbnailService;
    _thumbnailQueue = thumbnailQueue ?? ThumbnailGenerationQueue.instance;

    if (_thumbnailService != null) {
      _thumbnailQueue?.init(_thumbnailService!);
    }

    AppLogger.i('ThumbnailMigrationService initialized', 'ThumbnailMigration');
  }

  /// 执行迁移
  ///
  /// 检测所有画廊记录，为缺失缩略图的图片生成缩略图。
  /// 使用后台队列批量处理，不阻塞 UI。
  ///
  /// 返回迁移结果：[成功标志, 需要生成的数量, 已加入队列的数量]
  Future<(bool, int, int)> migrate() async {
    if (_isProcessing) {
      AppLogger.w('Migration already in progress', 'ThumbnailMigration');
      return (false, 0, 0);
    }

    if (_thumbnailQueue == null) {
      AppLogger.w('Thumbnail queue not initialized', 'ThumbnailMigration');
      return (false, 0, 0);
    }

    _isProcessing = true;
    AppLogger.i('Starting thumbnail migration...', 'ThumbnailMigration');

    try {
      // 1. 打开画廊 Box
      final galleryBox = await Hive.openBox<GenerationRecord>(
        StorageKeys.galleryBox,
      );

      if (galleryBox.isEmpty) {
        AppLogger.i('Gallery is empty, nothing to migrate', 'ThumbnailMigration');
        await galleryBox.close();
        _isProcessing = false;
        return (true, 0, 0);
      }

      // 2. 收集需要生成缩略图的图片路径
      final missingThumbnailPaths = <String>[];
      int totalRecords = 0;
      int recordsWithFilePath = 0;

      for (final record in galleryBox.values) {
        totalRecords++;

        // 跳过没有文件路径的记录
        if (record.filePath == null || record.filePath!.isEmpty) {
          continue;
        }
        recordsWithFilePath++;

        // 检查缩略图是否存在
        final hasThumbnail = record.thumbnailPath != null &&
            record.thumbnailPath!.isNotEmpty;

        if (!hasThumbnail) {
          // 再检查缩略图文件是否实际存在
          final thumbnailPath = _thumbnailService?.thumbnailExists(
            record.filePath!,
          );
          if (thumbnailPath != true) {
            missingThumbnailPaths.add(record.filePath!);
          }
        }
      }

      await galleryBox.close();

      AppLogger.i(
        'Thumbnail migration check: $totalRecords total, '
        '$recordsWithFilePath with file, ${missingThumbnailPaths.length} missing thumbnails',
        'ThumbnailMigration',
      );

      // 3. 如果没有缺失的缩略图，直接返回成功
      if (missingThumbnailPaths.isEmpty) {
        await _markCompleted();
        _isProcessing = false;
        return (true, 0, 0);
      }

      // 4. 将任务加入批量生成队列
      final batchId = await _thumbnailQueue!.enqueueBatch(
        missingThumbnailPaths,
        description: 'Migration batch',
        priority: 10, // 较低优先级，不干扰用户操作
      );

      AppLogger.i(
        'Enqueued ${missingThumbnailPaths.length} thumbnails for generation '
        '(batch: $batchId)',
        'ThumbnailMigration',
      );

      // 5. 监听批次进度，完成后更新记录
      _listenToBatchProgress(batchId, missingThumbnailPaths);

      // 6. 更新最后检查时间
      await _updateLastCheckTime();

      return (true, missingThumbnailPaths.length, missingThumbnailPaths.length);
    } catch (e, stack) {
      AppLogger.e(
        'Thumbnail migration failed: $e',
        e,
        stack,
        'ThumbnailMigration',
      );
      return (false, 0, 0);
    } finally {
      _isProcessing = false;
    }
  }

  /// 监听批次进度，完成后更新记录
  void _listenToBatchProgress(String batchId, List<String> originalPaths) {
    // 使用进度流监听
    StreamSubscription<ThumbnailGenerationBatch>? subscription;
    bool isCompleted = false;

    subscription = _thumbnailQueue!.progressStream.listen((batch) {
      if (batch.id == batchId && batch.isCompleted) {
        isCompleted = true;
        AppLogger.i(
          'Migration batch completed: ${batch.completedCount} success, '
          '${batch.failedCount} failed',
          'ThumbnailMigration',
        );

        // 更新记录中的缩略图路径
        _updateRecordsWithThumbnails(originalPaths);

        // 标记迁移完成
        _markCompleted();

        // 完成后取消订阅
        subscription?.cancel();
      }
    });

    // 30分钟后自动取消监听（防止内存泄漏）
    Future.delayed(const Duration(minutes: 30), () {
      // 超时前检查是否已完成，避免不必要的取消操作
      if (!isCompleted) {
        AppLogger.w(
          'Migration batch $batchId timeout after 30 minutes, cancelling subscription',
          'ThumbnailMigration',
        );
        subscription?.cancel();
      }
    });
  }

  /// 更新记录的缩略图路径
  Future<void> _updateRecordsWithThumbnails(List<String> originalPaths) async {
    try {
      final galleryBox = await Hive.openBox<GenerationRecord>(
        StorageKeys.galleryBox,
      );

      int updatedCount = 0;
      for (final originalPath in originalPaths) {
        // 查找对应的记录
        GenerationRecord? targetRecord;
        String? recordId;

        for (final record in galleryBox.values) {
          if (record.filePath == originalPath) {
            targetRecord = record;
            recordId = record.id;
            break;
          }
        }

        if (targetRecord != null && recordId != null) {
          // 检查缩略图是否已生成
          final thumbnailPath = _thumbnailService?.getThumbnailPath(
            originalPath,
          );

          if (thumbnailPath != null) {
            // 更新记录的缩略图路径
            final updatedRecord = targetRecord.copyWith(
              thumbnailPath: thumbnailPath,
            );
            await galleryBox.put(recordId, updatedRecord);
            updatedCount++;
          }
        }
      }

      await galleryBox.close();

      AppLogger.i(
        'Updated $updatedCount records with thumbnail paths',
        'ThumbnailMigration',
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to update records with thumbnails: $e',
        e,
        stack,
        'ThumbnailMigration',
      );
    }
  }

  /// 快速检查是否有缺失的缩略图
  ///
  /// 不执行实际生成，仅返回是否需要迁移
  Future<bool> needsMigration() async {
    try {
      final settingsBox = await Hive.openBox(StorageKeys.settingsBox);
      final isCompleted = settingsBox.get(_migrationCompletedKey) == true;

      if (isCompleted) {
        return false;
      }

      // 检查画廊是否有记录
      final galleryBox = await Hive.openBox<GenerationRecord>(
        StorageKeys.galleryBox,
      );

      if (galleryBox.isEmpty) {
        await galleryBox.close();
        await _markCompleted();
        return false;
      }

      // 抽样检查前 10 条记录
      int checkedCount = 0;
      int missingCount = 0;

      for (final record in galleryBox.values) {
        if (checkedCount >= 10) break;

        if (record.filePath != null && record.filePath!.isNotEmpty) {
          checkedCount++;

          // 检查记录中是否已有缩略图路径
          if (record.thumbnailPath == null || record.thumbnailPath!.isEmpty) {
            missingCount++;
          }
        }
      }

      await galleryBox.close();

      // 如果抽样中超过一半缺失，认为需要迁移
      return missingCount > checkedCount / 2;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to check migration status: $e',
        e,
        stack,
        'ThumbnailMigration',
      );
      return false;
    }
  }

  /// 检查是否已完成迁移
  Future<bool> isMigrated() async {
    try {
      final settingsBox = await Hive.openBox(StorageKeys.settingsBox);
      return settingsBox.get(_migrationCompletedKey) == true;
    } catch (e) {
      return false;
    }
  }

  /// 标记迁移已完成
  Future<void> _markCompleted() async {
    try {
      final settingsBox = await Hive.openBox(StorageKeys.settingsBox);
      await settingsBox.put(_migrationCompletedKey, true);
      AppLogger.i('Thumbnail migration marked as completed', 'ThumbnailMigration');
    } catch (e, stack) {
      AppLogger.e(
        'Failed to mark migration as completed: $e',
        e,
        stack,
        'ThumbnailMigration',
      );
    }
  }

  /// 更新最后检查时间
  Future<void> _updateLastCheckTime() async {
    try {
      final settingsBox = await Hive.openBox(StorageKeys.settingsBox);
      await settingsBox.put(_lastCheckTimeKey, DateTime.now().toIso8601String());
    } catch (e) {
      // 忽略错误
    }
  }

  /// 重置迁移状态（用于重新触发）
  Future<void> resetMigrationStatus() async {
    try {
      final settingsBox = await Hive.openBox(StorageKeys.settingsBox);
      await settingsBox.delete(_migrationCompletedKey);
      await settingsBox.delete(_lastCheckTimeKey);
      AppLogger.i('Thumbnail migration status reset', 'ThumbnailMigration');
    } catch (e, stack) {
      AppLogger.e(
        'Failed to reset migration status: $e',
        e,
        stack,
        'ThumbnailMigration',
      );
    }
  }

  /// 获取迁移统计信息
  Future<Map<String, dynamic>> getStats() async {
    try {
      final settingsBox = await Hive.openBox(StorageKeys.settingsBox);
      final isCompleted = settingsBox.get(_migrationCompletedKey) == true;
      final lastCheckStr = settingsBox.get(_lastCheckTimeKey) as String?;

      // 获取队列统计
      final queueStats = _thumbnailQueue?.getStats();

      return {
        'isCompleted': isCompleted,
        'lastCheckTime': lastCheckStr != null
            ? DateTime.tryParse(lastCheckStr)?.toIso8601String()
            : null,
        'isProcessing': _isProcessing,
        'queueStats': queueStats,
      };
    } catch (e) {
      return {
        'isCompleted': false,
        'lastCheckTime': null,
        'isProcessing': _isProcessing,
        'queueStats': null,
      };
    }
  }

  /// 强制重新生成所有缩略图
  ///
  /// 用于修复损坏的缩略图或更新缩略图格式
  Future<(bool, int)> regenerateAllThumbnails() async {
    if (_thumbnailQueue == null) {
      return (false, 0);
    }

    try {
      // 打开画廊 Box
      final galleryBox = await Hive.openBox<GenerationRecord>(
        StorageKeys.galleryBox,
      );

      if (galleryBox.isEmpty) {
        await galleryBox.close();
        return (true, 0);
      }

      // 收集所有有文件路径的图片
      final allPaths = <String>[];
      for (final record in galleryBox.values) {
        if (record.filePath != null && record.filePath!.isNotEmpty) {
          allPaths.add(record.filePath!);

          // 删除现有缩略图
          if (record.thumbnailPath != null) {
            try {
              final thumbFile = File(record.thumbnailPath!);
              if (await thumbFile.exists()) {
                await thumbFile.delete();
              }
            } catch (e) {
              // 忽略删除错误
            }
          }
        }
      }

      await galleryBox.close();

      // 清除迁移标记
      await resetMigrationStatus();

      // 重新生成
      final batchId = await _thumbnailQueue!.enqueueBatch(
        allPaths,
        description: 'Regenerate all thumbnails',
        priority: 5,
      );

      AppLogger.i(
        'Enqueued ${allPaths.length} thumbnails for regeneration (batch: $batchId)',
        'ThumbnailMigration',
      );

      return (true, allPaths.length);
    } catch (e, stack) {
      AppLogger.e(
        'Failed to regenerate thumbnails: $e',
        e,
        stack,
        'ThumbnailMigration',
      );
      return (false, 0);
    }
  }
}
