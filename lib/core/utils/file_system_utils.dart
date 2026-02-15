import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_logger.dart';

/// 文件系统工具类
///
/// 提供通用的文件系统操作功能：
/// - [ensureDirectory] 确保目录存在（如果不存在则递归创建）
/// - [copyDirectory] 递归复制目录及其内容
class FileSystemUtils {
  FileSystemUtils._();

  /// 确保目录存在
  ///
  /// [path] 目录路径
  /// [logTag] 日志标签，用于区分调用来源
  /// 返回是否成功创建或路径已存在
  static Future<bool> ensureDirectory(String path, {String logTag = 'FileSystem'}) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        AppLogger.i('创建目录: $path', logTag);
      }
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('创建目录失败: $path', logTag, stackTrace);
      return false;
    }
  }

  /// 递归复制目录
  ///
  /// [source] 源目录
  /// [destination] 目标目录
  /// 会递归复制所有子目录和文件
  static Future<void> copyDirectory(Directory source, Directory destination) async {
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await copyDirectory(entity, Directory(newPath));
      }
    }
  }
}
