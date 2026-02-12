import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';
import '../utils/hive_storage_helper.dart';
import '../utils/vibe_library_path_helper.dart';

/// 数据迁移服务
///
/// 负责在应用启动时执行各类数据迁移：
/// - Hive 数据库：从 Documents 根目录 → %APPDATA%/NAI_Launcher/hive/
/// - Vibe 库：从 Documents/vibes/ → Documents/NAI_Launcher/vibes/
/// - 图片存储：从 Documents/nai_launcher/images/ → Documents/NAI_Launcher/images/
class DataMigrationService {
  /// 单例实例
  static final DataMigrationService instance = DataMigrationService._();

  DataMigrationService._();

  /// 迁移进度回调
  void Function(String stage, double progress)? onProgress;

  /// 本次进程内是否已执行过迁移
  bool _migratedThisSession = false;

  /// 本次进程内最近一次迁移结果
  MigrationResult? _lastResult;

  /// 执行所有数据迁移
  ///
  /// 返回迁移结果统计
  Future<MigrationResult> migrateAll() async {
    if (_migratedThisSession && _lastResult != null) {
      AppLogger.d('数据迁移已在本次启动执行，复用结果: $_lastResult', 'DataMigration');
      return _lastResult!;
    }

    final result = MigrationResult();

    try {
      AppLogger.i('开始数据迁移流程...', 'DataMigration');

      // 1. Hive 数据迁移
      onProgress?.call('迁移 Hive 数据', 0.05);
      final hivePath = await HiveStorageHelper.instance.getPath();
      await HiveStorageHelper.instance.migrateFromOldLocation(hivePath);
      onProgress?.call('Hive 数据迁移完成', 0.35);
      AppLogger.i('Hive 存储路径: $hivePath', 'DataMigration');
      result.hiveMigrated = true;

      // 2. Vibe 库迁移（触发路径初始化和迁移）
      onProgress?.call('迁移 Vibe 库数据', 0.4);
      final vibePath = await VibeLibraryPathHelper.instance.getPath();
      onProgress?.call('Vibe 库迁移完成', 0.65);
      AppLogger.i('Vibe 库路径: $vibePath', 'DataMigration');
      result.vibeMigrated = true;

      // 3. 图片存储迁移（触发路径初始化和迁移）
      onProgress?.call('迁移图片存储数据', 0.7);
      final imagePath = await _migrateImageStorage();
      onProgress?.call('图片存储迁移完成', 0.95);
      AppLogger.i('图片存储路径: $imagePath', 'DataMigration');
      result.imageMigrated = true;

      onProgress?.call('数据迁移完成', 1.0);
      AppLogger.i('数据迁移流程完成', 'DataMigration');

      _migratedThisSession = true;
      _lastResult = result;

      return result;
    } catch (e, stackTrace) {
      AppLogger.e('数据迁移失败: $e', 'DataMigration', stackTrace);
      result.error = e.toString();

      _migratedThisSession = true;
      _lastResult = result;

      return result;
    }
  }

  /// 迁移图片存储
  ///
  /// 从旧位置迁移到新位置：
  /// 旧：Documents/nai_launcher/images/
  /// 新：Documents/NAI_Launcher/images/
  Future<String> _migrateImageStorage() async {
    final appDir = await getApplicationDocumentsDirectory();
    final newPath = p.join(appDir.path, 'NAI_Launcher', 'images');
    final oldPath = p.join(appDir.path, 'nai_launcher', 'images');

    // 如果新路径已存在且有文件，不需要迁移
    final newDir = Directory(newPath);
    if (await newDir.exists()) {
      final files = await newDir.list().toList();
      if (files.isNotEmpty) {
        return newPath;
      }
    }

    // 检查旧位置是否存在
    final oldDir = Directory(oldPath);
    if (!await oldDir.exists()) {
      // 确保新目录存在
      if (!await newDir.exists()) {
        await newDir.create(recursive: true);
      }
      return newPath;
    }

    // 检查旧位置是否有文件
    final oldFiles = await oldDir.list().toList();
    if (oldFiles.isEmpty) {
      // 确保新目录存在
      if (!await newDir.exists()) {
        await newDir.create(recursive: true);
      }
      return newPath;
    }

    AppLogger.i('发现旧版本图片数据，开始迁移...', 'DataMigration');
    AppLogger.i('从: $oldPath', 'DataMigration');
    AppLogger.i('到: $newPath', 'DataMigration');

    // 确保新目录存在
    if (!await newDir.exists()) {
      await newDir.create(recursive: true);
    }

    // 迁移文件
    var migratedCount = 0;
    for (final entity in oldFiles) {
      try {
        final fileName = p.basename(entity.path);
        final newFilePath = p.join(newPath, fileName);

        if (entity is File) {
          await entity.copy(newFilePath);
          migratedCount++;
        } else if (entity is Directory) {
          // 递归复制子目录
          await _copyDirectory(entity, Directory(newFilePath));
          migratedCount++;
        }
      } catch (e) {
        AppLogger.e('迁移失败 ${entity.path}: $e', 'DataMigration');
      }
    }

    if (migratedCount > 0) {
      AppLogger.i('图片数据迁移完成: $migratedCount 个项目', 'DataMigration');
    }

    return newPath;
  }

  /// 递归复制目录
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }

  /// 清理旧位置的文件（谨慎使用）
  ///
  /// 仅在确认新位置数据完整且应用运行正常后调用
  Future<void> cleanupOldFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();

      // 清理 Documents 根目录下的 .hive 文件
      final hiveFiles = await _findHiveFiles(appDir.path);
      for (final file in hiveFiles) {
        try {
          await file.delete();
          AppLogger.i('已删除旧 Hive 文件: ${p.basename(file.path)}', 'DataMigration');
        } catch (e) {
          AppLogger.w('删除旧 Hive 文件失败: ${file.path}', 'DataMigration');
        }
      }

      // 清理 Documents/NAI_Launcher/hive/ 中的旧文件（如果当前使用的是 %APPDATA%）
      final appSupportDir = await getApplicationSupportDirectory();
      final currentHivePath = await HiveStorageHelper.instance.getPath();
      if (currentHivePath.startsWith(appSupportDir.path)) {
        // 当前使用的是 %APPDATA%，可以清理 Documents 中的旧文件
        final oldHivePath = p.join(appDir.path, 'NAI_Launcher', 'hive');
        final oldHiveDir = Directory(oldHivePath);
        if (await oldHiveDir.exists()) {
          AppLogger.i('旧 Hive 目录保留在: $oldHivePath（可手动删除）', 'DataMigration');
        }
      }

      // 清理旧图片目录
      final oldImagePath = p.join(appDir.path, 'nai_launcher', 'images');
      final oldImageDir = Directory(oldImagePath);
      if (await oldImageDir.exists()) {
        AppLogger.i('旧图片目录保留在: $oldImagePath（可手动删除）', 'DataMigration');
      }
    } catch (e) {
      AppLogger.e('清理旧文件失败: $e', 'DataMigration');
    }
  }

  /// 查找目录中的 Hive 文件
  Future<List<File>> _findHiveFiles(String dirPath) async {
    final files = <File>[];

    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        return files;
      }

      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.hive')) {
          files.add(entity);
        }
      }
    } catch (e) {
      AppLogger.e('查找 Hive 文件失败: $e', 'DataMigration');
    }

    return files;
  }

  /// 检查是否所有迁移都已完成
  ///
  /// 返回 true 表示所有数据都已在正确位置
  Future<bool> checkMigrationStatus() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();

      // 检查 Hive 数据位置
      final hivePath = await HiveStorageHelper.instance.getPath();
      final appSupportDir = await getApplicationSupportDirectory();
      final hiveInCorrectLocation = hivePath.startsWith(appSupportDir.path);

      // 检查是否有旧 Hive 文件需要迁移
      final oldHiveFiles = await _findHiveFiles(appDir.path);
      final hasOldHiveFiles = oldHiveFiles.isNotEmpty;

      return hiveInCorrectLocation && !hasOldHiveFiles;
    } catch (e) {
      AppLogger.e('检查迁移状态失败: $e', 'DataMigration');
      return false;
    }
  }
}

/// 迁移结果
class MigrationResult {
  /// Hive 数据是否已迁移/确认
  bool hiveMigrated = false;

  /// Vibe 库是否已迁移/确认
  bool vibeMigrated = false;

  /// 图片存储是否已迁移/确认
  bool imageMigrated = false;

  /// 错误信息（如果有）
  String? error;

  /// 是否全部成功
  bool get isSuccess => hiveMigrated && vibeMigrated && imageMigrated && error == null;

  @override
  String toString() {
    return 'MigrationResult(hive: $hiveMigrated, vibe: $vibeMigrated, image: $imageMigrated, error: $error)';
  }
}
