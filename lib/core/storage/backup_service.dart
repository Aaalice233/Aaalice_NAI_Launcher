import 'dart:io';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';

part 'backup_service.g.dart';

/// 备份数据版本，用于数据迁移
const int _backupVersion = 1;

/// 备份元数据
class BackupMetadata {
  /// 备份创建时间
  final DateTime createdAt;

  /// 备份版本
  final int version;

  /// 备份描述
  final String? description;

  /// 备份数据项数量
  final int itemCount;

  /// 应用版本（可选）
  final String? appVersion;

  const BackupMetadata({
    required this.createdAt,
    required this.version,
    required this.itemCount,
    this.description,
    this.appVersion,
  });

  /// 从JSON创建
  factory BackupMetadata.fromJson(Map<String, dynamic> json) {
    return BackupMetadata(
      createdAt: DateTime.parse(json['createdAt'] as String),
      version: json['version'] as int? ?? 1,
      itemCount: json['itemCount'] as int? ?? 0,
      description: json['description'] as String?,
      appVersion: json['appVersion'] as String?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'version': version,
      'itemCount': itemCount,
      'description': description,
      'appVersion': appVersion,
    };
  }
}

/// 备份数据容器
class BackupData {
  /// 备份元数据
  final BackupMetadata metadata;

  /// 设置数据
  final Map<String, dynamic> settings;

  /// 收藏数据
  final Map<String, dynamic> favorites;

  /// 标签数据
  final Map<String, dynamic> tags;

  /// 标签模板数据
  final Map<String, dynamic> tagTemplates;

  /// 标签收藏数据
  final Map<String, dynamic> tagFavorites;

  /// 生成历史数据
  final Map<String, dynamic> history;

  /// 复刻队列数据
  final Map<String, dynamic> replicationQueue;

  /// 本地元数据缓存
  final Map<String, dynamic> localMetadataCache;

  const BackupData({
    required this.metadata,
    required this.settings,
    required this.favorites,
    required this.tags,
    required this.tagTemplates,
    required this.tagFavorites,
    required this.history,
    required this.replicationQueue,
    required this.localMetadataCache,
  });

  /// 从JSON创建
  factory BackupData.fromJson(Map<String, dynamic> json) {
    return BackupData(
      metadata: BackupMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      settings: json['settings'] as Map<String, dynamic>? ?? {},
      favorites: json['favorites'] as Map<String, dynamic>? ?? {},
      tags: json['tags'] as Map<String, dynamic>? ?? {},
      tagTemplates: json['tagTemplates'] as Map<String, dynamic>? ?? {},
      tagFavorites: json['tagFavorites'] as Map<String, dynamic>? ?? {},
      history: json['history'] as Map<String, dynamic>? ?? {},
      replicationQueue: json['replicationQueue'] as Map<String, dynamic>? ?? {},
      localMetadataCache: json['localMetadataCache'] as Map<String, dynamic>? ?? {},
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'metadata': metadata.toJson(),
      'settings': settings,
      'favorites': favorites,
      'tags': tags,
      'tagTemplates': tagTemplates,
      'tagFavorites': tagFavorites,
      'history': history,
      'replicationQueue': replicationQueue,
      'localMetadataCache': localMetadataCache,
    };
  }
}

/// 备份结果
class BackupResult {
  /// 是否成功
  final bool success;

  /// 备份文件路径（成功时）
  final String? filePath;

  /// 错误信息（失败时）
  final String? error;

  /// 备份元数据
  final BackupMetadata? metadata;

  const BackupResult({
    required this.success,
    this.filePath,
    this.error,
    this.metadata,
  });

  /// 成功结果
  factory BackupResult.success(String filePath, BackupMetadata metadata) {
    return BackupResult(
      success: true,
      filePath: filePath,
      metadata: metadata,
    );
  }

  /// 失败结果
  factory BackupResult.failure(String error) {
    return BackupResult(
      success: false,
      error: error,
    );
  }
}

/// 恢复结果
class RestoreResult {
  /// 是否成功
  final bool success;

  /// 恢复的元数据
  final BackupMetadata? metadata;

  /// 错误信息（失败时）
  final String? error;

  /// 恢复的项数量
  final int restoredItems;

  const RestoreResult({
    required this.success,
    this.metadata,
    this.error,
    this.restoredItems = 0,
  });

  /// 成功结果
  factory RestoreResult.success(BackupMetadata metadata, int restoredItems) {
    return RestoreResult(
      success: true,
      metadata: metadata,
      restoredItems: restoredItems,
    );
  }

  /// 失败结果
  factory RestoreResult.failure(String error) {
    return RestoreResult(
      success: false,
      error: error,
    );
  }
}

/// 备份服务
///
/// 提供数据导出/导入功能，支持：
/// 1. 手动备份所有用户数据
/// 2. 从备份文件恢复数据
/// 3. 自动备份功能
/// 4. 备份文件管理
class BackupService {
  Box? _backupBox;

  /// 获取备份 Box（懒加载）
  Future<Box> _getBackupBox() async {
    _backupBox ??= await Hive.openBox(StorageKeys.appStateBox);
    return _backupBox!;
  }

  /// 获取设置 Box
  Box get _settingsBox => Hive.box(StorageKeys.settingsBox);

  /// 获取收藏 Box
  Box get _favoritesBox => Hive.box(StorageKeys.localFavoritesBox);

  /// 获取标签 Box
  Box get _tagsBox => Hive.box(StorageKeys.tagsBox);

  /// 获取标签模板 Box
  Box get _tagTemplatesBox => Hive.box(StorageKeys.tagTemplatesBox);

  /// 获取标签收藏 Box
  Box get _tagFavoritesBox => Hive.box(StorageKeys.tagFavoritesBox);

  /// 获取历史 Box
  Box get _historyBox => Hive.box(StorageKeys.historyBox);

  /// 获取复刻队列 Box
  Future<Box<String>> _getReplicationQueueBox() async {
    return await Hive.openBox<String>(StorageKeys.replicationQueueBox);
  }

  /// 获取本地元数据缓存 Box
  Box get _localMetadataCacheBox => Hive.box(StorageKeys.localMetadataCacheBox);

  /// 导出所有数据到备份文件
  ///
  /// [description] - 备份描述（可选）
  /// [customPath] - 自定义备份路径（可选，默认保存到下载目录）
  Future<BackupResult> exportBackup({
    String? description,
    String? customPath,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();

      // 1. 收集所有数据
      final settings = _collectBoxData(_settingsBox);
      final favorites = _collectBoxData(_favoritesBox);
      final tags = _collectBoxData(_tagsBox);
      final tagTemplates = _collectBoxData(_tagTemplatesBox);
      final tagFavorites = _collectBoxData(_tagFavoritesBox);
      final history = _collectBoxData(_historyBox);
      final localMetadataCache = _collectBoxData(_localMetadataCacheBox);

      // 复刻队列需要单独处理
      Map<String, dynamic> replicationQueue = {};
      try {
        final queueBox = await _getReplicationQueueBox();
        final queueData = queueBox.get(StorageKeys.replicationQueueData);
        if (queueData != null) {
          replicationQueue = {'data': queueData};
        }
        await queueBox.close();
      } catch (e) {
        AppLogger.w('Failed to collect replication queue data: $e', 'BackupService');
      }

      // 2. 计算项目数量
      int itemCount = 0;
      itemCount += settings.length;
      itemCount += favorites.length;
      itemCount += tags.length;
      itemCount += tagTemplates.length;
      itemCount += tagFavorites.length;
      itemCount += history.length;
      itemCount += replicationQueue.isNotEmpty ? 1 : 0;
      itemCount += localMetadataCache.length;

      // 3. 创建备份元数据
      final metadata = BackupMetadata(
        createdAt: DateTime.now(),
        version: _backupVersion,
        itemCount: itemCount,
        description: description,
      );

      // 4. 创建备份数据
      final backupData = BackupData(
        metadata: metadata,
        settings: settings,
        favorites: favorites,
        tags: tags,
        tagTemplates: tagTemplates,
        tagFavorites: tagFavorites,
        history: history,
        replicationQueue: replicationQueue,
        localMetadataCache: localMetadataCache,
      );

      // 5. 确定保存路径
      final String targetPath;
      if (customPath != null && customPath.isNotEmpty) {
        targetPath = customPath;
      } else {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir == null) {
          return BackupResult.failure('Failed to get downloads directory');
        }
        targetPath = downloadsDir.path;
      }

      // 6. 生成文件名
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'nai_launcher_backup_$timestamp.json';
      final filePath = '$targetPath${Platform.pathSeparator}$fileName';

      // 7. 写入文件
      final file = File(filePath);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(backupData.toJson()),
      );

      // 8. 记录备份元数据到本地
      await _recordBackupMetadata(metadata, filePath);

      stopwatch.stop();
      AppLogger.i(
        'Backup created: $fileName ($itemCount items) in ${stopwatch.elapsedMilliseconds}ms',
        'BackupService',
      );

      return BackupResult.success(filePath, metadata);
    } catch (e, stackTrace) {
      AppLogger.e('Failed to create backup', e, stackTrace, 'BackupService');
      return BackupResult.failure('Failed to create backup: $e');
    }
  }

  /// 从备份文件恢复数据
  ///
  /// [filePath] - 备份文件路径
  /// [mergeStrategy] - 合并策略（true=合并，false=覆盖）
  Future<RestoreResult> importBackup(
    String filePath, {
    bool mergeStrategy = false,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();

      // 1. 读取备份文件
      final file = File(filePath);
      if (!await file.exists()) {
        return RestoreResult.failure('Backup file not found: $filePath');
      }

      final jsonString = await file.readAsString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final backupData = BackupData.fromJson(json);

      // 2. 验证版本
      if (backupData.metadata.version > _backupVersion) {
        return RestoreResult.failure(
          'Backup version ${backupData.metadata.version} is newer than supported version $_backupVersion',
        );
      }

      // 3. 恢复数据
      int restoredItems = 0;

      // 恢复设置
      restoredItems += await _restoreBoxData(
        _settingsBox,
        backupData.settings,
        merge: mergeStrategy,
      );

      // 恢复收藏
      restoredItems += await _restoreBoxData(
        _favoritesBox,
        backupData.favorites,
        merge: mergeStrategy,
      );

      // 恢复标签
      restoredItems += await _restoreBoxData(
        _tagsBox,
        backupData.tags,
        merge: mergeStrategy,
      );

      // 恢复标签模板
      restoredItems += await _restoreBoxData(
        _tagTemplatesBox,
        backupData.tagTemplates,
        merge: mergeStrategy,
      );

      // 恢复标签收藏
      restoredItems += await _restoreBoxData(
        _tagFavoritesBox,
        backupData.tagFavorites,
        merge: mergeStrategy,
      );

      // 恢复历史
      restoredItems += await _restoreBoxData(
        _historyBox,
        backupData.history,
        merge: mergeStrategy,
      );

      // 恢复本地元数据缓存
      restoredItems += await _restoreBoxData(
        _localMetadataCacheBox,
        backupData.localMetadataCache,
        merge: mergeStrategy,
      );

      // 恢复复刻队列
      if (backupData.replicationQueue.isNotEmpty) {
        try {
          final queueBox = await _getReplicationQueueBox();
          final queueData = backupData.replicationQueue['data'] as String?;
          if (queueData != null) {
            await queueBox.put(StorageKeys.replicationQueueData, queueData);
            restoredItems++;
          }
          await queueBox.close();
        } catch (e) {
          AppLogger.w('Failed to restore replication queue: $e', 'BackupService');
        }
      }

      stopwatch.stop();
      AppLogger.i(
        'Backup restored: $restoredItems items in ${stopwatch.elapsedMilliseconds}ms',
        'BackupService',
      );

      return RestoreResult.success(backupData.metadata, restoredItems);
    } catch (e, stackTrace) {
      AppLogger.e('Failed to restore backup', e, stackTrace, 'BackupService');
      return RestoreResult.failure('Failed to restore backup: $e');
    }
  }

  /// 验证备份文件
  ///
  /// [filePath] - 备份文件路径
  /// 返回验证结果，包含元数据信息
  Future<BackupMetadata?> verifyBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final jsonString = await file.readAsString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final backupData = BackupData.fromJson(json);

      return backupData.metadata;
    } catch (e) {
      AppLogger.w('Failed to verify backup: $e', 'BackupService');
      return null;
    }
  }

  /// 创建自动备份
  ///
  /// [maxBackups] - 保留的最大备份数量（默认5个）
  Future<BackupResult> createAutoBackup({int maxBackups = 5}) async {
    try {
      // 1. 获取备份目录
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/nai_launcher/backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // 2. 创建备份
      final result = await exportBackup(
        description: 'Auto backup',
        customPath: backupDir.path,
      );

      if (!result.success) {
        return result;
      }

      // 3. 清理旧备份
      await _cleanupOldBackups(backupDir, maxBackups);

      // 4. 更新自动备份设置
      final box = await _getBackupBox();
      await box.put(StorageKeys.backupMetadata, {
        'lastAutoBackup': DateTime.now().toIso8601String(),
        'backupPath': result.filePath,
      });

      return result;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to create auto backup', e, stackTrace, 'BackupService');
      return BackupResult.failure('Failed to create auto backup: $e');
    }
  }

  /// 获取自动备份设置
  Future<Map<String, dynamic>> getAutoBackupSettings() async {
    try {
      final box = await _getBackupBox();
      final enabled = box.get(StorageKeys.autoBackupEnabled, defaultValue: false) as bool? ?? false;
      final interval = box.get(StorageKeys.autoBackupInterval, defaultValue: 24) as int? ?? 24;

      return {
        'enabled': enabled,
        'intervalHours': interval,
      };
    } catch (e) {
      return {
        'enabled': false,
        'intervalHours': 24,
      };
    }
  }

  /// 设置自动备份
  Future<void> setAutoBackup({
    required bool enabled,
    int intervalHours = 24,
  }) async {
    try {
      final box = await _getBackupBox();
      await box.put(StorageKeys.autoBackupEnabled, enabled);
      await box.put(StorageKeys.autoBackupInterval, intervalHours);

      AppLogger.i(
        'Auto backup ${enabled ? 'enabled' : 'disabled'} (interval: $intervalHours hours)',
        'BackupService',
      );
    } catch (e, stackTrace) {
      AppLogger.e('Failed to set auto backup', e, stackTrace, 'BackupService');
      rethrow;
    }
  }

  /// 检查是否需要自动备份
  Future<bool> shouldAutoBackup() async {
    try {
      final settings = await getAutoBackupSettings();
      if (!(settings['enabled'] as bool)) {
        return false;
      }

      final intervalHours = settings['intervalHours'] as int;
      final box = await _getBackupBox();
      final metadata = box.get(StorageKeys.backupMetadata) as Map<dynamic, dynamic>?;

      if (metadata == null) {
        return true;
      }

      final lastBackup = DateTime.tryParse(metadata['lastAutoBackup'] as String? ?? '');
      if (lastBackup == null) {
        return true;
      }

      final nextBackup = lastBackup.add(Duration(hours: intervalHours));
      return DateTime.now().isAfter(nextBackup);
    } catch (e) {
      return false;
    }
  }

  /// 获取备份历史列表
  Future<List<Map<String, dynamic>>> getBackupHistory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/nai_launcher/backups');

      if (!await backupDir.exists()) {
        return [];
      }

      final files = await backupDir
          .list()
          .where((entity) =>
              entity is File && entity.path.toLowerCase().endsWith('.json'))
          .cast<File>()
          .toList();

      // 按修改时间降序排序
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      final history = <Map<String, dynamic>>[];
      for (final file in files) {
        final metadata = await verifyBackup(file.path);
        if (metadata != null) {
          history.add({
            'filePath': file.path,
            'fileName': file.path.split(Platform.pathSeparator).last,
            'createdAt': metadata.createdAt.toIso8601String(),
            'itemCount': metadata.itemCount,
            'description': metadata.description,
            'size': await file.length(),
          });
        }
      }

      return history;
    } catch (e) {
      AppLogger.w('Failed to get backup history: $e', 'BackupService');
      return [];
    }
  }

  /// 删除备份文件
  Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        AppLogger.i('Backup deleted: $filePath', 'BackupService');
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to delete backup', e, stackTrace, 'BackupService');
      return false;
    }
  }

  /// 收集 Box 中的所有数据
  Map<String, dynamic> _collectBoxData(Box box) {
    final data = <String, dynamic>{};
    for (final key in box.keys) {
      try {
        final value = box.get(key);
        if (value != null) {
          data[key.toString()] = value;
        }
      } catch (e) {
        AppLogger.w('Failed to collect data for key: $key', 'BackupService');
      }
    }
    return data;
  }

  /// 恢复 Box 数据
  Future<int> _restoreBoxData(
    Box box,
    Map<String, dynamic> data, {
    required bool merge,
  }) async {
    int count = 0;

    if (!merge) {
      // 非合并模式：清空现有数据
      await box.clear();
    }

    for (final entry in data.entries) {
      try {
        await box.put(entry.key, entry.value);
        count++;
      } catch (e) {
        AppLogger.w('Failed to restore data for key: ${entry.key}', 'BackupService');
      }
    }

    return count;
  }

  /// 记录备份元数据到本地
  Future<void> _recordBackupMetadata(BackupMetadata metadata, String filePath) async {
    try {
      final box = await _getBackupBox();
      await box.put(StorageKeys.backupMetadata, {
        'lastBackup': metadata.createdAt.toIso8601String(),
        'backupPath': filePath,
        'itemCount': metadata.itemCount,
      });
    } catch (e) {
      AppLogger.w('Failed to record backup metadata: $e', 'BackupService');
    }
  }

  /// 清理旧备份文件
  Future<void> _cleanupOldBackups(Directory backupDir, int maxBackups) async {
    try {
      final files = await backupDir
          .list()
          .where((entity) =>
              entity is File && entity.path.toLowerCase().endsWith('.json'))
          .cast<File>()
          .toList();

      if (files.length <= maxBackups) {
        return;
      }

      // 按修改时间升序排序（旧的在前）
      files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

      // 删除多余的旧备份
      final toDelete = files.sublist(0, files.length - maxBackups);
      for (final file in toDelete) {
        await file.delete();
        AppLogger.d('Old backup deleted: ${file.path}', 'BackupService');
      }
    } catch (e) {
      AppLogger.w('Failed to cleanup old backups: $e', 'BackupService');
    }
  }

  /// 关闭存储
  Future<void> close() async {
    if (_backupBox != null && _backupBox!.isOpen) {
      await _backupBox!.close();
      _backupBox = null;
    }
  }
}

/// 备份服务 Provider
@riverpod
BackupService backupService(Ref ref) {
  return BackupService();
}
