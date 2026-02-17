import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../models/gallery/generation_record.dart';

/// 画廊迁移服务
///
/// 安全地将数据从旧的 JSON 字符串格式迁移到新的 Hive 对象格式。
/// 包含严格的数量校验，确保零数据丢失。
class GalleryMigrationService {
  /// 旧存储键
  static const String _oldRecordsKey = 'generation_records';

  /// 新 Box 名称
  static const String _newBoxName = StorageKeys.galleryBox;

  /// 单例
  static final GalleryMigrationService _instance = GalleryMigrationService._();
  factory GalleryMigrationService() => _instance;
  GalleryMigrationService._();

  /// 执行迁移
  ///
  /// 返回迁移结果：[成功标志, 迁移记录数, 错误信息(如果有)]
  Future<(bool, int, String?)> migrate() async {
    AppLogger.i('Starting gallery migration...', 'GalleryMigration');

    try {
      // 1. 检查是否已经迁移过
      final newBox = await Hive.openBox(_newBoxName);
      if (newBox.isNotEmpty) {
        AppLogger.w(
          'Migration already completed, skipping',
          'GalleryMigration',
        );
        await newBox.close();
        return (true, newBox.length, null);
      }

      // 2. 读取旧数据
      final oldBox = Hive.box(StorageKeys.galleryBox);
      final oldData = oldBox.get(_oldRecordsKey);

      if (oldData == null) {
        AppLogger.i(
          'No old data found, nothing to migrate',
          'GalleryMigration',
        );
        await newBox.close();
        return (true, 0, null);
      }

      // 3. 解析旧 JSON 数据
      List<dynamic> oldList;
      if (oldData is String) {
        oldList = jsonDecode(oldData) as List<dynamic>;
      } else if (oldData is List) {
        oldList = oldData;
      } else {
        return (false, 0, 'Invalid old data format: ${oldData.runtimeType}');
      }

      final oldCount = oldList.length;
      AppLogger.i('Found $oldCount records to migrate', 'GalleryMigration');

      // 4. 迁移到新格式
      int migratedCount = 0;
      for (final item in oldList) {
        try {
          if (item is Map<String, dynamic>) {
            final record = GenerationRecord.fromJson(item);
            await newBox.put(record.id, record);
            migratedCount++;
          }
        } catch (e, stack) {
          AppLogger.e(
            'Failed to migrate record: $e',
            e,
            stack,
            'GalleryMigration',
          );
        }
      }

      await newBox.close();

      // 5. 安全校验
      if (migratedCount != oldCount) {
        AppLogger.e(
          'Migration count mismatch: old=$oldCount, new=$migratedCount',
          null,
          null,
          'GalleryMigration',
        );
        // 不删除旧数据，保留作为备份
        return (
          false,
          migratedCount,
          'Count mismatch: $oldCount -> $migratedCount'
        );
      }

      // 6. 迁移成功，删除旧数据
      AppLogger.i(
        'Migration successful, deleting old data',
        'GalleryMigration',
      );
      await oldBox.delete(_oldRecordsKey);

      return (true, migratedCount, null);
    } catch (e, stack) {
      AppLogger.e('Migration failed: $e', e, stack, 'GalleryMigration');
      return (false, 0, e.toString());
    }
  }

  /// 检查迁移状态
  Future<bool> isMigrated() async {
    try {
      final newBox = await Hive.openBox(_newBoxName);
      final isMigrated = newBox.isNotEmpty;
      await newBox.close();
      return isMigrated;
    } catch (e) {
      return false;
    }
  }

  /// 获取迁移后的记录数量
  Future<int> getMigratedCount() async {
    try {
      final newBox = await Hive.openBox(_newBoxName);
      final count = newBox.length;
      await newBox.close();
      return count;
    } catch (e) {
      return 0;
    }
  }

  /// 回滚迁移（如果需要）
  Future<void> rollback() async {
    try {
      final newBox = await Hive.openBox(_newBoxName);
      await newBox.clear();
      await newBox.close();
      AppLogger.i('Migration rolled back', 'GalleryMigration');
    } catch (e, stack) {
      AppLogger.e(
        'Failed to rollback migration: $e',
        e,
        stack,
        'GalleryMigration',
      );
    }
  }
}
