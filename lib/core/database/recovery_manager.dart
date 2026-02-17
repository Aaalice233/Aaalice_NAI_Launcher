import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../services/sqflite_bootstrap_service.dart';
import '../utils/app_logger.dart';
import 'connection_pool.dart';

/// 恢复操作结果
class RecoveryResult {
  final bool success;
  final String message;
  final Map<String, dynamic> details;

  const RecoveryResult({
    required this.success,
    required this.message,
    this.details = const {},
  });

  factory RecoveryResult.success(String message, [Map<String, dynamic>? details]) {
    return RecoveryResult(
      success: true,
      message: message,
      details: details ?? const {},
    );
  }

  factory RecoveryResult.failure(String message, [Map<String, dynamic>? details]) {
    return RecoveryResult(
      success: false,
      message: message,
      details: details ?? const {},
    );
  }
}

/// 数据库恢复管理器
///
/// 提供自动损坏恢复功能：
/// - rebuild(): 从重建数据库
/// - restoreFromPrebuilt(): 从 bundled assets 恢复
/// - autoRecover(): 自动选择最佳恢复策略
class RecoveryManager {
  RecoveryManager._();

  static final RecoveryManager _instance = RecoveryManager._();

  /// 获取单例实例
  static RecoveryManager get instance => _instance;

  static const String _prebuiltDbAsset = 'assets/database/nai_gallery.db';
  static const String _backupSuffix = '.backup';
  static const String _corruptedSuffix = '.corrupted';

  String? _dbPath;

  /// 初始化恢复管理器
  Future<void> initialize(String dbPath) async {
    _dbPath = dbPath;
    AppLogger.i('RecoveryManager initialized', 'RecoveryManager');
  }

  /// 自动恢复数据库
  ///
  /// 按优先级尝试恢复策略：
  /// 1. 尝试从备份恢复
  /// 2. 尝试从预构建数据库恢复
  /// 3. 重建数据库
  ///
  /// 返回：恢复结果
  Future<RecoveryResult> autoRecover() async {
    if (_dbPath == null) {
      return RecoveryResult.failure('RecoveryManager not initialized');
    }

    AppLogger.w('Starting auto-recovery process', 'RecoveryManager');

    // 1. 尝试从备份恢复
    final backupResult = await _restoreFromBackup();
    if (backupResult.success) {
      return backupResult;
    }
    AppLogger.w('Backup restore failed: ${backupResult.message}', 'RecoveryManager');

    // 2. 尝试从预构建数据库恢复
    final prebuiltResult = await restoreFromPrebuilt();
    if (prebuiltResult.success) {
      return prebuiltResult;
    }
    AppLogger.w('Prebuilt restore failed: ${prebuiltResult.message}', 'RecoveryManager');

    // 3. 重建数据库
    return rebuild();
  }

  /// 从重建数据库
  ///
  /// 删除损坏的数据库文件并创建新的空数据库
  ///
  /// 返回：恢复结果
  Future<RecoveryResult> rebuild() async {
    if (_dbPath == null) {
      return RecoveryResult.failure('RecoveryManager not initialized');
    }

    AppLogger.w('Rebuilding database from scratch', 'RecoveryManager');

    try {
      // 关闭连接池
      await ConnectionPool.instance.dispose();

      final dbFile = File(_dbPath!);

      // 备份损坏的数据库（如果存在）
      if (await dbFile.exists()) {
        final corruptedPath = '$_dbPath$_corruptedSuffix.${DateTime.now().millisecondsSinceEpoch}';
        await dbFile.copy(corruptedPath);
        await dbFile.delete();
        AppLogger.i('Corrupted database backed up to: $corruptedPath', 'RecoveryManager');
      }

      // 重新初始化 FFI
      await SqfliteBootstrapService.instance.ensureInitialized();

      // 创建新数据库
      final db = await databaseFactoryFfi.openDatabase(_dbPath!);
      await db.close();

      // 重新初始化连接池
      await ConnectionPool.initialize(dbPath: _dbPath!);

      AppLogger.i('Database rebuilt successfully', 'RecoveryManager');
      return RecoveryResult.success('Database rebuilt successfully', {
        'dbPath': _dbPath,
        'method': 'rebuild',
      });
    } catch (e, stack) {
      AppLogger.e('Failed to rebuild database', e, stack, 'RecoveryManager');
      return RecoveryResult.failure('Failed to rebuild database: $e');
    }
  }

  /// 从 bundled assets 恢复数据库
  ///
  /// 从应用资源中复制预构建的数据库
  ///
  /// 返回：恢复结果
  Future<RecoveryResult> restoreFromPrebuilt() async {
    if (_dbPath == null) {
      return RecoveryResult.failure('RecoveryManager not initialized');
    }

    AppLogger.i('Attempting to restore from prebuilt database', 'RecoveryManager');

    try {
      // 检查 asset 是否存在
      try {
        await rootBundle.load(_prebuiltDbAsset);
      } catch (e) {
        return RecoveryResult.failure('Prebuilt database asset not found: $_prebuiltDbAsset');
      }

      // 关闭连接池
      await ConnectionPool.instance.dispose();

      final dbFile = File(_dbPath!);

      // 备份损坏的数据库（如果存在）
      if (await dbFile.exists()) {
        final corruptedPath = '$_dbPath$_corruptedSuffix.${DateTime.now().millisecondsSinceEpoch}';
        await dbFile.copy(corruptedPath);
        await dbFile.delete();
      }

      // 从 asset 复制
      final bytes = await rootBundle.load(_prebuiltDbAsset);
      await dbFile.writeAsBytes(bytes.buffer.asUint8List());

      // 重新初始化连接池
      await ConnectionPool.initialize(dbPath: _dbPath!);

      AppLogger.i('Database restored from prebuilt successfully', 'RecoveryManager');
      return RecoveryResult.success('Database restored from prebuilt', {
        'dbPath': _dbPath,
        'method': 'prebuilt',
        'source': _prebuiltDbAsset,
      });
    } catch (e, stack) {
      AppLogger.e('Failed to restore from prebuilt', e, stack, 'RecoveryManager');
      return RecoveryResult.failure('Failed to restore from prebuilt: $e');
    }
  }

  /// 从备份恢复数据库
  ///
  /// 返回：恢复结果
  Future<RecoveryResult> _restoreFromBackup() async {
    if (_dbPath == null) {
      return RecoveryResult.failure('RecoveryManager not initialized');
    }

    final backupPath = '$_dbPath$_backupSuffix';
    final backupFile = File(backupPath);

    if (!await backupFile.exists()) {
      return RecoveryResult.failure('No backup file found');
    }

    AppLogger.i('Attempting to restore from backup', 'RecoveryManager');

    try {
      // 关闭连接池
      await ConnectionPool.instance.dispose();

      final dbFile = File(_dbPath!);

      // 备份损坏的数据库（如果存在）
      if (await dbFile.exists()) {
        final corruptedPath = '$_dbPath$_corruptedSuffix.${DateTime.now().millisecondsSinceEpoch}';
        await dbFile.copy(corruptedPath);
      }

      // 从备份恢复
      await backupFile.copy(_dbPath!);

      // 重新初始化连接池
      await ConnectionPool.initialize(dbPath: _dbPath!);

      AppLogger.i('Database restored from backup successfully', 'RecoveryManager');
      return RecoveryResult.success('Database restored from backup', {
        'dbPath': _dbPath,
        'method': 'backup',
        'backupPath': backupPath,
      });
    } catch (e, stack) {
      AppLogger.e('Failed to restore from backup', e, stack, 'RecoveryManager');
      return RecoveryResult.failure('Failed to restore from backup: $e');
    }
  }

  /// 创建数据库备份
  ///
  /// 返回：备份结果
  Future<RecoveryResult> createBackup() async {
    if (_dbPath == null) {
      return RecoveryResult.failure('RecoveryManager not initialized');
    }

    try {
      final dbFile = File(_dbPath!);
      if (!await dbFile.exists()) {
        return RecoveryResult.failure('Database file not found');
      }

      final backupPath = '$_dbPath$_backupSuffix';
      await dbFile.copy(backupPath);

      AppLogger.i('Database backup created: $backupPath', 'RecoveryManager');
      return RecoveryResult.success('Backup created', {
        'backupPath': backupPath,
      });
    } catch (e, stack) {
      AppLogger.e('Failed to create backup', e, stack, 'RecoveryManager');
      return RecoveryResult.failure('Failed to create backup: $e');
    }
  }

  /// 清理旧的损坏数据库备份
  ///
  /// [keepCount] 保留的备份数量
  Future<void> cleanupOldCorruptedFiles({int keepCount = 3}) async {
    if (_dbPath == null) return;

    try {
      final dbDir = Directory(p.dirname(_dbPath!));
      if (!await dbDir.exists()) return;

      final files = await dbDir
          .list()
          .where((entity) => entity is File)
          .map((entity) => entity as File)
          .where((file) => p.basename(file.path).startsWith(p.basename(_dbPath!) + _corruptedSuffix))
          .toList();

      // 按修改时间排序（最新的在前）
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      // 删除旧的文件
      if (files.length > keepCount) {
        final filesToDelete = files.sublist(keepCount);
        for (final file in filesToDelete) {
          await file.delete();
          AppLogger.d('Deleted old corrupted backup: ${file.path}', 'RecoveryManager');
        }
      }

      AppLogger.i('Cleaned up ${files.length - keepCount} old corrupted backups', 'RecoveryManager');
    } catch (e) {
      AppLogger.w('Failed to cleanup old corrupted files: $e', 'RecoveryManager');
    }
  }

  /// 获取所有恢复相关的文件信息
  ///
  /// 返回：文件信息映射
  Future<Map<String, dynamic>> getRecoveryFilesInfo() async {
    if (_dbPath == null) {
      return {'error': 'RecoveryManager not initialized'};
    }

    final info = <String, dynamic>{
      'dbPath': _dbPath,
    };

    // 主数据库文件
    final dbFile = File(_dbPath!);
    info['mainExists'] = await dbFile.exists();
    if (await dbFile.exists()) {
      final stat = await dbFile.stat();
      info['mainSize'] = stat.size;
      info['mainModified'] = stat.modified.toIso8601String();
    }

    // 备份文件
    final backupFile = File('$_dbPath$_backupSuffix');
    info['backupExists'] = await backupFile.exists();
    if (await backupFile.exists()) {
      final stat = await backupFile.stat();
      info['backupSize'] = stat.size;
      info['backupModified'] = stat.modified.toIso8601String();
    }

    // 损坏备份文件
    final dbDir = Directory(p.dirname(_dbPath!));
    if (await dbDir.exists()) {
      final corruptedFiles = await dbDir
          .list()
          .where((entity) => entity is File)
          .map((entity) => entity as File)
          .where((file) => p.basename(file.path).startsWith(p.basename(_dbPath!) + _corruptedSuffix))
          .toList();

      info['corruptedBackupsCount'] = corruptedFiles.length;
      info['corruptedBackups'] = corruptedFiles.map((f) => p.basename(f.path)).toList();
    }

    return info;
  }
}
