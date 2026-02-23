import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/app_logger.dart';

/// 临时图像服务
///
/// 管理未保存图像的临时文件：
/// - 生成后立即写入临时文件
/// - 从临时文件解析元数据
/// - 用户保存时复制到正式目录
/// - 应用启动时清理旧临时文件
class TempImageService {
  static final TempImageService _instance = TempImageService._internal();
  factory TempImageService() => _instance;
  TempImageService._internal();

  static const String _tempDirName = 'temp_images';
  static const Duration _maxTempAge = Duration(days: 7);

  /// 获取临时目录
  Future<Directory> getTempDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final tempDir = Directory(p.join(appDir.path, _tempDirName));
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return tempDir;
  }

  /// 保存图像到临时文件
  ///
  /// 返回临时文件路径
  Future<String> saveTempImage(Uint8List bytes, String id) async {
    final tempDir = await getTempDirectory();
    final file = File(p.join(tempDir.path, 'temp_$id.png'));
    await file.writeAsBytes(bytes);
    AppLogger.d('Saved temp image: ${file.path}', 'TempImageService');
    return file.path;
  }

  /// 获取临时文件路径（不写入）
  Future<String> getTempPath(String id) async {
    final tempDir = await getTempDirectory();
    return p.join(tempDir.path, 'temp_$id.png');
  }

  /// 检查临时文件是否存在
  Future<bool> tempFileExists(String id) async {
    final tempDir = await getTempDirectory();
    final file = File(p.join(tempDir.path, 'temp_$id.png'));
    return file.exists();
  }

  /// 获取临时文件
  Future<File?> getTempFile(String id) async {
    final tempDir = await getTempDirectory();
    final file = File(p.join(tempDir.path, 'temp_$id.png'));
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// 删除临时文件
  Future<void> deleteTempFile(String id) async {
    final tempDir = await getTempDirectory();
    final file = File(p.join(tempDir.path, 'temp_$id.png'));
    if (await file.exists()) {
      await file.delete();
      AppLogger.d('Deleted temp image: ${file.path}', 'TempImageService');
    }
  }

  /// 清理过期临时文件（应用启动时调用）
  Future<void> cleanupOldTempFiles() async {
    try {
      final tempDir = await getTempDirectory();
      final now = DateTime.now();
      int deletedCount = 0;

      await for (final entity in tempDir.list()) {
        if (entity is File && entity.path.endsWith('.png')) {
          try {
            final stat = await entity.stat();
            if (now.difference(stat.modified) > _maxTempAge) {
              await entity.delete();
              deletedCount++;
            }
          } catch (e) {
            AppLogger.w('Failed to check/delete temp file: ${entity.path}', 'TempImageService');
          }
        }
      }

      if (deletedCount > 0) {
        AppLogger.i('Cleaned up $deletedCount old temp files', 'TempImageService');
      }
    } catch (e, stack) {
      AppLogger.e('Failed to cleanup temp files', e, stack, 'TempImageService');
    }
  }

  /// 获取所有临时文件
  Future<List<File>> getAllTempFiles() async {
    final tempDir = await getTempDirectory();
    final files = <File>[];

    await for (final entity in tempDir.list()) {
      if (entity is File && entity.path.endsWith('.png')) {
        files.add(entity);
      }
    }

    return files;
  }

  /// 清空所有临时文件
  Future<void> clearAllTempFiles() async {
    final tempDir = await getTempDirectory();
    int deletedCount = 0;

    await for (final entity in tempDir.list()) {
      if (entity is File && entity.path.endsWith('.png')) {
        try {
          await entity.delete();
          deletedCount++;
        } catch (e) {
          AppLogger.w('Failed to delete temp file: ${entity.path}', 'TempImageService');
        }
      }
    }

    AppLogger.i('Cleared $deletedCount temp files', 'TempImageService');
  }

  /// 将临时文件移动到正式目录
  ///
  /// 返回新的正式文件路径
  Future<String> moveToPermanent(String tempId, String targetDir, String fileName) async {
    final tempDir = await getTempDirectory();
    final tempFile = File(p.join(tempDir.path, 'temp_$tempId.png'));

    if (!await tempFile.exists()) {
      throw Exception('Temp file not found: $tempId');
    }

    final targetPath = p.join(targetDir, fileName);
    await tempFile.rename(targetPath);
    AppLogger.d('Moved temp file to: $targetPath', 'TempImageService');

    return targetPath;
  }

  /// 复制临时文件到正式目录
  ///
  /// 返回新的正式文件路径
  Future<String> copyToPermanent(String tempId, String targetDir, String fileName) async {
    final tempDir = await getTempDirectory();
    final tempFile = File(p.join(tempDir.path, 'temp_$tempId.png'));

    if (!await tempFile.exists()) {
      throw Exception('Temp file not found: $tempId');
    }

    final targetPath = p.join(targetDir, fileName);
    await tempFile.copy(targetPath);
    AppLogger.d('Copied temp file to: $targetPath', 'TempImageService');

    return targetPath;
  }
}
