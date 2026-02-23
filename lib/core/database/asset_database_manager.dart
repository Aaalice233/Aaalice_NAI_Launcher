import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';

/// 资产数据库管理器
///
/// 管理预打包的数据库文件（translation.db, cooccurrence.db）：
/// 1. 首次启动时从 assets 复制到应用目录
/// 2. 提供只读数据库连接
/// 3. 处理数据库版本更新
class AssetDatabaseManager {
  static final AssetDatabaseManager _instance = AssetDatabaseManager._();
  static AssetDatabaseManager get instance => _instance;
  
  AssetDatabaseManager._();
  
  // 数据库文件名
  static const String translationDb = 'translation.db';
  static const String cooccurrenceDb = 'cooccurrence.db';
  
  // 数据库路径
  String? _translationDbPath;
  String? _cooccurrenceDbPath;
  
  /// 获取翻译数据库路径
  String get translationDbPath {
    if (_translationDbPath == null) {
      throw StateError('AssetDatabaseManager not initialized. Call initialize() first.');
    }
    return _translationDbPath!;
  }
  
  /// 获取共现数据库路径
  String get cooccurrenceDbPath {
    if (_cooccurrenceDbPath == null) {
      throw StateError('AssetDatabaseManager not initialized. Call initialize() first.');
    }
    return _cooccurrenceDbPath!;
  }
  
  /// 初始化资产数据库
  ///
  /// 将预打包的数据库从 assets 复制到应用支持目录
  static Future<void> initialize() async {
    AppLogger.i('Initializing asset databases...', 'AssetDatabaseManager');
    
    final appDir = await getApplicationSupportDirectory();
    final assetDbDir = Directory(p.join(appDir.path, 'asset_databases'));
    
    if (!await assetDbDir.exists()) {
      await assetDbDir.create(recursive: true);
    }
    
    // 复制翻译数据库
    await _copyAssetDatabase(
      assetPath: 'assets/databases/$translationDb',
      targetPath: p.join(assetDbDir.path, translationDb),
      name: 'translation',
    );
    _instance._translationDbPath = p.join(assetDbDir.path, translationDb);
    
    // 复制共现数据库
    await _copyAssetDatabase(
      assetPath: 'assets/databases/$cooccurrenceDb',
      targetPath: p.join(assetDbDir.path, cooccurrenceDb),
      name: 'cooccurrence',
    );
    _instance._cooccurrenceDbPath = p.join(assetDbDir.path, cooccurrenceDb);
    
    AppLogger.i('Asset databases initialized', 'AssetDatabaseManager');
  }
  
  /// 从 assets 复制数据库文件
  static Future<void> _copyAssetDatabase({
    required String assetPath,
    required String targetPath,
    required String name,
  }) async {
    final targetFile = File(targetPath);
    
    // 检查是否需要复制
    if (await targetFile.exists()) {
      // 文件已存在且 assets 中无更新，跳过
      if (!await _assetExists(assetPath)) {
        AppLogger.i('$name database up to date', 'AssetDatabaseManager');
        return;
      }
      AppLogger.i('$name database updating from assets...', 'AssetDatabaseManager');
    } else {
      AppLogger.i('$name database not found, copying from assets...', 'AssetDatabaseManager');
    }
    
    try {
      final bytes = await _loadAssetBytes(assetPath);
      await targetFile.writeAsBytes(bytes);
      
      final size = await targetFile.length();
      AppLogger.i('$name database copied: ${_formatSize(size)}', 'AssetDatabaseManager');
    } catch (e) {
      AppLogger.e('Failed to copy $name database', e, null, 'AssetDatabaseManager');
      if (!await targetFile.exists()) rethrow;
    }
  }

  /// 检查 asset 是否存在
  static Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 加载 asset 字节数据
  static Future<List<int>> _loadAssetBytes(String path) async {
    final byteData = await rootBundle.load(path);
    return byteData.buffer.asUint8List();
  }

  /// 格式化文件大小
  static String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
  
  /// 打开翻译数据库（只读）
  Future<Database> openTranslationDatabase() async {
    return _openReadOnlyDatabase(translationDbPath, 'translation');
  }
  
  /// 打开共现数据库（只读）
  Future<Database> openCooccurrenceDatabase() async {
    return _openReadOnlyDatabase(cooccurrenceDbPath, 'cooccurrence');
  }
  
  /// 打开只读数据库
  Future<Database> _openReadOnlyDatabase(String path, String name) async {
    AppLogger.d('Opening $name database (read-only): $path', 'AssetDatabaseManager');
    
    return await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        readOnly: true,
        singleInstance: false,
      ),
    );
  }
  
  /// 检查数据库是否存在
  Future<bool> checkDatabasesExist() async {
    final transExists = await File(translationDbPath).exists();
    final coocExists = await File(cooccurrenceDbPath).exists();
    
    AppLogger.i(
      'Database check - translation: $transExists, cooccurrence: $coocExists',
      'AssetDatabaseManager',
    );
    
    return transExists && coocExists;
  }
  
  /// 获取数据库文件大小信息
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    Future<Map<String, dynamic>> getFileInfo(String path) async {
      final file = File(path);
      final exists = await file.exists();
      return {
        'path': path,
        'exists': exists,
        'size': exists ? await file.length() : 0,
      };
    }

    return {
      'translation': await getFileInfo(translationDbPath),
      'cooccurrence': await getFileInfo(cooccurrenceDbPath),
    };
  }
}
