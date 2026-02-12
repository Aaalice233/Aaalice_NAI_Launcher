import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/storage_keys.dart';
import 'app_logger.dart';

/// Hive 存储路径管理助手
///
/// 管理 Hive 数据库的存储路径，提供以下功能：
/// - 获取当前 Hive 存储路径（应用数据目录下的 hive 子目录）
/// - 初始化 Hive 并设置正确的存储路径
/// - 支持自定义路径（通过 settings box 设置）
/// - 数据迁移：从旧路径（Documents 根目录）迁移到新路径
class HiveStorageHelper {
  HiveStorageHelper._();

  static final HiveStorageHelper instance = HiveStorageHelper._();

  /// 默认子目录名称
  static const String _defaultSubDir = 'hive';

  /// Settings box 中的自定义路径键名
  static const String _customHivePathKey = 'hive_storage_path';

  /// 缓存的路径
  String? _cachedPath;

  /// 是否已完成初始化
  bool _initialized = false;

  /// 获取当前 Hive 存储路径
  ///
  /// 优先返回用户自定义路径，如果没有则返回默认路径
  /// 默认路径: {appSupportDir}/NAI_Launcher/hive/ (Windows: %APPDATA%/NAI_Launcher/hive/)
  Future<String> getPath() async {
    if (_cachedPath != null) {
      return _cachedPath!;
    }

    // 尝试获取自定义路径（在 Hive 初始化前，直接从文件系统读取）
    final customPath = await _getCustomPathFromFile();
    if (customPath != null && customPath.isNotEmpty) {
      _cachedPath = customPath;
      return customPath;
    }

    // 使用默认路径: %APPDATA%/NAI_Launcher/hive/ (更合适存放应用内部数据)
    final appSupportDir = await getApplicationSupportDirectory();
    final defaultPath = p.join(appSupportDir.path, 'NAI_Launcher', _defaultSubDir);
    _cachedPath = defaultPath;
    return defaultPath;
  }

  /// 从文件系统读取自定义路径（在 Hive 初始化前使用）
  Future<String?> _getCustomPathFromFile() async {
    try {
      // 检查旧位置的 settings.hive 文件
      final appDir = await getApplicationDocumentsDirectory();
      final oldSettingsPath = p.join(appDir.path, '${StorageKeys.settingsBox}.hive');
      final oldSettingsFile = File(oldSettingsPath);

      // 如果旧位置存在 settings.hive，说明还没有迁移，返回 null 使用默认路径
      if (await oldSettingsFile.exists()) {
        return null;
      }

      // 检查新位置的 settings.hive
      final newPath = p.join(appDir.path, 'NAI_Launcher', _defaultSubDir);
      final newSettingsPath = p.join(newPath, '${StorageKeys.settingsBox}.hive');
      final newSettingsFile = File(newSettingsPath);

      if (await newSettingsFile.exists()) {
        // 已经在新位置，检查是否有自定义路径设置
        // 这里需要 Hive 初始化后才能读取，暂时返回 null
        return null;
      }

      return null;
    } catch (e) {
      AppLogger.w('读取自定义路径失败: $e', 'HiveStorage');
      return null;
    }
  }

  /// 获取自定义路径（需要 Hive 已初始化）
  String? getCustomPath() {
    try {
      final box = Hive.box(StorageKeys.settingsBox);
      return box.get(_customHivePathKey) as String?;
    } catch (e) {
      return null;
    }
  }

  /// 设置自定义路径
  Future<void> setCustomPath(String? path) async {
    final box = Hive.box(StorageKeys.settingsBox);
    if (path != null && path.isNotEmpty) {
      await box.put(_customHivePathKey, path);
      AppLogger.i('Hive 存储路径已设置为: $path', 'HiveStorage');
    } else {
      await box.delete(_customHivePathKey);
      AppLogger.i('Hive 存储路径已重置为默认', 'HiveStorage');
    }
    _cachedPath = null; // 清除缓存
  }

  /// 初始化 Hive
  ///
  /// 1. 确定存储路径
  /// 2. 确保目录存在
  /// 3. 初始化 Hive
  ///
  /// 注意：数据迁移由 [DataMigrationService] 在预热阶段统一执行
  Future<void> init() async {
    if (_initialized) {
      return;
    }

    try {
      // 获取存储路径
      final storagePath = await getPath();
      AppLogger.i('Hive 存储路径: $storagePath', 'HiveStorage');

      // 确保目录存在
      final dir = Directory(storagePath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        AppLogger.i('创建 Hive 存储目录: $storagePath', 'HiveStorage');
      }

      // 注意：数据迁移由 DataMigrationService 在预热阶段统一执行
      // 这里只初始化 Hive，不执行迁移

      // 初始化 Hive
      Hive.init(storagePath);

      _initialized = true;
      AppLogger.i('Hive 初始化完成', 'HiveStorage');
    } catch (e, stackTrace) {
      AppLogger.e('Hive 初始化失败: $e', 'HiveStorage', stackTrace);
      // 降级：使用默认的 initFlutter
      await Hive.initFlutter();
      _initialized = true;
    }
  }

  /// 从旧位置迁移数据
  ///
  /// 旧位置 1：Documents 根目录下的 .hive 文件（最早的版本）
  /// 旧位置 2：Documents/NAI_Launcher/hive/（中间版本）
  /// 新位置：%APPDATA%/NAI_Launcher/hive/（当前版本，更合适存放应用内部数据）
  ///
  /// 由 [DataMigrationService] 在预热阶段调用
  Future<void> migrateFromOldLocation(String newPath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();

      // 检查所有可能的旧位置
      final oldLocations = [
        // 位置 1: Documents 根目录（最早版本）
        appDir.path,
        // 位置 2: Documents/NAI_Launcher/hive/（中间版本）
        p.join(appDir.path, 'NAI_Launcher', _defaultSubDir),
      ];

      final filesToMigrate = <String, File>{}; // 使用 Map 去重，保留最新版本

      for (final oldLocation in oldLocations) {
        if (oldLocation == newPath) continue; // 跳过新位置

        final oldFiles = await _findOldHiveFiles(oldLocation);
        for (final oldFile in oldFiles) {
          final fileName = p.basename(oldFile.path);
          // 如果同名文件已存在，保留修改时间更新的
          if (filesToMigrate.containsKey(fileName)) {
            final existingFile = filesToMigrate[fileName]!;
            final existingStat = existingFile.statSync();
            final newStat = oldFile.statSync();
            if (newStat.modified.isAfter(existingStat.modified)) {
              filesToMigrate[fileName] = oldFile;
              AppLogger.d('发现更新的版本: $fileName ($oldLocation)', 'HiveStorage');
            }
          } else {
            filesToMigrate[fileName] = oldFile;
          }
        }
      }

      if (filesToMigrate.isEmpty) {
        AppLogger.d('没有发现需要迁移的旧 Hive 文件', 'HiveStorage');
        return;
      }

      AppLogger.i('发现 ${filesToMigrate.length} 个旧 Hive 文件需要迁移', 'HiveStorage');

      // 确保新目录存在
      final newDir = Directory(newPath);
      if (!await newDir.exists()) {
        await newDir.create(recursive: true);
      }

      // 迁移文件
      var migratedCount = 0;
      for (final entry in filesToMigrate.entries) {
        final fileName = entry.key;
        final oldFile = entry.value;
        final newFilePath = p.join(newPath, fileName);
        final newFile = File(newFilePath);

        // 如果新位置已存在该文件，先判断是否为“新建占位文件”场景。
        // 场景：迁移前应用已先打开 box，导致新路径生成很小的新文件。
        // 为避免误判为“新文件更新”，当旧文件明显更大时，优先保留旧文件数据。
        if (await newFile.exists()) {
          final newFileStat = newFile.statSync();
          final oldFileStat = oldFile.statSync();

          final newSize = newFileStat.size;
          final oldSize = oldFileStat.size;
          final shouldPreferOldBySize = oldSize > 0 &&
              (newSize == 0 || (newSize <= 1024 && oldSize >= newSize * 4));

          if (!shouldPreferOldBySize &&
              newFileStat.modified.isAfter(oldFileStat.modified)) {
            AppLogger.d('新位置已存在更新的 $fileName，跳过迁移', 'HiveStorage');
            continue;
          }

          if (shouldPreferOldBySize) {
            AppLogger.w(
              '检测到新位置可能是占位文件（$fileName: new=$newSize, old=$oldSize），将使用旧文件覆盖',
              'HiveStorage',
            );
          }
        }

        try {
          if (await newFile.exists()) {
            await newFile.delete();
          }
          await oldFile.copy(newFilePath);
          migratedCount++;
          AppLogger.i('已迁移: $fileName', 'HiveStorage');
        } catch (e) {
          AppLogger.e('迁移失败 $fileName: $e', 'HiveStorage');
        }
      }

      if (migratedCount > 0) {
        AppLogger.i('Hive 数据迁移完成: $migratedCount 个文件', 'HiveStorage');
      }

      // 清理旧位置的已迁移文件（含 .hive/.lock/.crc）
      final cleanedCount = await _cleanupMigratedOldFiles(
        oldLocations: oldLocations,
        newPath: newPath,
        migratedHiveFileNames: filesToMigrate.keys.toSet(),
      );
      if (cleanedCount > 0) {
        AppLogger.i('旧位置清理完成: $cleanedCount 个文件', 'HiveStorage');
      }
    } catch (e, stackTrace) {
      AppLogger.e('迁移过程出错: $e', 'HiveStorage', stackTrace);
    }
  }

  /// 清理旧位置中已迁移的 Hive 文件
  ///
  /// 仅清理本次迁移识别到的目标文件，避免误删无关文件。
  Future<int> _cleanupMigratedOldFiles({
    required List<String> oldLocations,
    required String newPath,
    required Set<String> migratedHiveFileNames,
  }) async {
    var deletedCount = 0;

    for (final oldLocation in oldLocations) {
      if (oldLocation == newPath) continue;

      final oldFiles = await _findAllHiveRelatedFiles(oldLocation);
      for (final oldFile in oldFiles) {
        final fileName = p.basename(oldFile.path);
        final ext = p.extension(fileName).toLowerCase();

        final shouldDelete = switch (ext) {
          '.hive' => migratedHiveFileNames.contains(fileName),
          '.lock' || '.crc' => migratedHiveFileNames.contains(
              '${p.basenameWithoutExtension(fileName)}.hive',
            ),
          _ => false,
        };

        if (!shouldDelete) continue;

        // 对于 .hive 文件，要求新位置已存在同名文件；.lock/.crc 直接清理。
        if (ext == '.hive') {
          final newFilePath = p.join(newPath, fileName);
          final newFile = File(newFilePath);
          if (!await newFile.exists()) {
            AppLogger.w('跳过删除旧文件（新位置不存在）: $fileName', 'HiveStorage');
            continue;
          }
        }

        try {
          await oldFile.delete();
          deletedCount++;
        } catch (e) {
          AppLogger.w('删除旧文件失败 ${oldFile.path}: $e', 'HiveStorage');
        }
      }
    }

    return deletedCount;
  }

  /// 查找旧位置的 Hive 文件
  ///
  /// 返回 Documents 根目录下的所有 .hive 文件
  Future<List<File>> _findOldHiveFiles(String appDirPath) async {
    final files = <File>[];

    try {
      final dir = Directory(appDirPath);
      if (!await dir.exists()) {
        return files;
      }

      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.hive')) {
          files.add(entity);
        }
      }
    } catch (e) {
      AppLogger.e('查找旧 Hive 文件失败: $e', 'HiveStorage');
    }

    return files;
  }

  /// 获取所有 Hive 相关的文件（包括 .hive, .lock, .crc）
  Future<List<File>> _findAllHiveRelatedFiles(String appDirPath) async {
    final files = <File>[];
    final extensions = ['.hive', '.lock', '.crc'];

    try {
      final dir = Directory(appDirPath);
      if (!await dir.exists()) {
        return files;
      }

      await for (final entity in dir.list()) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (extensions.contains(ext)) {
            files.add(entity);
          }
        }
      }
    } catch (e) {
      AppLogger.e('查找 Hive 相关文件失败: $e', 'HiveStorage');
    }

    return files;
  }

  /// 清理旧位置的 Hive 文件（迁移成功后调用）
  ///
  /// ⚠️ 警告：此操作会删除旧位置的 Hive 文件，仅在确认迁移成功后调用
  Future<void> cleanupOldFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final newPath = await getPath();

      final newDir = Directory(newPath);
      if (!await newDir.exists()) {
        AppLogger.w('新位置不存在，取消清理', 'HiveStorage');
        return;
      }

      final oldLocations = [
        appDir.path,
        p.join(appDir.path, 'NAI_Launcher', _defaultSubDir),
      ];

      // 仅清理旧位置中有对应新 .hive 的文件（含 .lock/.crc）
      final newHiveFiles = await _findOldHiveFiles(newPath);
      final hiveNames = newHiveFiles.map((f) => p.basename(f.path)).toSet();
      final deletedCount = await _cleanupMigratedOldFiles(
        oldLocations: oldLocations,
        newPath: newPath,
        migratedHiveFileNames: hiveNames,
      );

      if (deletedCount > 0) {
        AppLogger.i('已清理 $deletedCount 个旧文件', 'HiveStorage');
      }
    } catch (e, stackTrace) {
      AppLogger.e('清理旧文件失败: $e', 'HiveStorage', stackTrace);
    }
  }

  /// 获取用于显示的存储路径
  String getDisplayPath() {
    final customPath = getCustomPath();
    if (customPath != null && customPath.isNotEmpty) {
      return customPath;
    }
    return '默认 (%APPDATA%/NAI_Launcher/hive/)';
  }

  /// 检查是否使用了自定义路径
  bool get hasCustomPath {
    final customPath = getCustomPath();
    return customPath != null && customPath.isNotEmpty;
  }

  /// 重置为默认路径
  Future<void> resetToDefault() async {
    await setCustomPath(null);
    _cachedPath = null;
    AppLogger.i('Hive 存储路径已重置为默认', 'HiveStorage');
  }

  /// 清除缓存
  void clearCache() {
    _cachedPath = null;
  }
}
