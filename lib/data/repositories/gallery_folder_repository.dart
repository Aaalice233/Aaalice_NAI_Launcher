import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;

import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../models/gallery/gallery_folder.dart';

/// 画廊文件夹仓库
///
/// 管理本地画廊的文件夹结构，支持：
/// - 扫描子文件夹
/// - 创建新文件夹
/// - 监听文件系统变化
/// - 获取文件夹图片数量
class GalleryFolderRepository {
  GalleryFolderRepository._();

  static final GalleryFolderRepository instance = GalleryFolderRepository._();

  final _localStorage = LocalStorageService();

  /// 文件系统监听器
  StreamSubscription<FileSystemEvent>? _watchSubscription;

  /// 文件夹变化回调
  void Function()? _onFoldersChanged;

  /// 支持的图片扩展名
  static const _supportedExtensions = {'.png', '.jpg', '.jpeg', '.webp'};

  /// 获取画廊根路径
  Future<String?> getRootPath() async {
    return _localStorage.getImageSavePath();
  }

  /// 扫描文件夹列表
  ///
  /// 返回根目录下的所有子文件夹
  Future<List<GalleryFolder>> scanFolders() async {
    final rootPath = await getRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      return [];
    }

    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) {
      return [];
    }

    final folders = <GalleryFolder>[];

    try {
      await for (final entity in rootDir.list(followLinks: false)) {
        if (entity is Directory) {
          final folder = await _createFolderFromDirectory(entity);
          if (folder != null) {
            folders.add(folder);
          }
        }
      }

      // 按名称排序
      folders.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    } catch (e) {
      AppLogger.e('扫描文件夹失败', e);
    }

    return folders;
  }

  /// 从 Directory 创建 GalleryFolder
  Future<GalleryFolder?> _createFolderFromDirectory(Directory dir) async {
    try {
      final stat = await dir.stat();
      final name = p.basename(dir.path);
      final id = _generateFolderId(dir.path);
      final imageCount = await _countImagesInFolder(dir.path);

      return GalleryFolder(
        id: id,
        name: name,
        path: dir.path,
        imageCount: imageCount,
        createdAt: stat.changed,
        modifiedAt: stat.modified,
      );
    } catch (e) {
      AppLogger.e('创建文件夹对象失败: ${dir.path}', e);
      return null;
    }
  }

  /// 生成文件夹唯一ID
  String _generateFolderId(String path) {
    final bytes = utf8.encode(path);
    final digest = md5.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// 统计文件夹内的图片数量
  Future<int> _countImagesInFolder(String folderPath) async {
    int count = 0;
    final dir = Directory(folderPath);

    try {
      await for (final entity
          in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (_supportedExtensions.contains(ext)) {
            count++;
          }
        }
      }
    } catch (e) {
      // 忽略访问错误
    }

    return count;
  }

  /// 创建新文件夹
  ///
  /// [name] 文件夹名称
  /// 返回创建的文件夹，如果失败返回 null
  Future<GalleryFolder?> createFolder(String name) async {
    final rootPath = await getRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      return null;
    }

    // 清理文件夹名称（移除非法字符）
    final cleanName = _sanitizeFolderName(name);
    if (cleanName.isEmpty) {
      return null;
    }

    final folderPath = p.join(rootPath, cleanName);
    final dir = Directory(folderPath);

    try {
      // 检查是否已存在
      if (await dir.exists()) {
        AppLogger.w('文件夹已存在: $folderPath');
        return await _createFolderFromDirectory(dir);
      }

      // 创建文件夹
      await dir.create(recursive: false);
      AppLogger.i('创建文件夹成功: $folderPath');

      return await _createFolderFromDirectory(dir);
    } catch (e) {
      AppLogger.e('创建文件夹失败: $folderPath', e);
      return null;
    }
  }

  /// 清理文件夹名称
  String _sanitizeFolderName(String name) {
    // Windows 非法字符: \ / : * ? " < > |
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 删除文件夹
  ///
  /// [folderId] 文件夹ID
  /// [recursive] 是否递归删除（包括文件夹内的所有内容）
  Future<bool> deleteFolder(String folderPath, {bool recursive = false}) async {
    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        return true;
      }

      // 检查文件夹是否为空
      if (!recursive) {
        final contents = await dir.list().length;
        if (contents > 0) {
          AppLogger.w('文件夹不为空，无法删除: $folderPath');
          return false;
        }
      }

      await dir.delete(recursive: recursive);
      AppLogger.i('删除文件夹成功: $folderPath');
      return true;
    } catch (e) {
      AppLogger.e('删除文件夹失败: $folderPath', e);
      return false;
    }
  }

  /// 重命名文件夹
  Future<GalleryFolder?> renameFolder(String oldPath, String newName) async {
    try {
      final dir = Directory(oldPath);
      if (!await dir.exists()) {
        return null;
      }

      final cleanName = _sanitizeFolderName(newName);
      if (cleanName.isEmpty) {
        return null;
      }

      final parentPath = p.dirname(oldPath);
      final newPath = p.join(parentPath, cleanName);

      // 检查新名称是否已存在
      if (await Directory(newPath).exists()) {
        AppLogger.w('目标文件夹已存在: $newPath');
        return null;
      }

      final newDir = await dir.rename(newPath);
      AppLogger.i('重命名文件夹成功: $oldPath -> $newPath');

      return await _createFolderFromDirectory(newDir);
    } catch (e) {
      AppLogger.e('重命名文件夹失败: $oldPath', e);
      return null;
    }
  }

  /// 移动图片到文件夹
  Future<bool> moveImageToFolder(
    String imagePath,
    String targetFolderPath,
  ) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return false;
      }

      final fileName = p.basename(imagePath);
      final newPath = p.join(targetFolderPath, fileName);

      // 如果目标已存在，添加时间戳避免覆盖
      var finalPath = newPath;
      if (await File(newPath).exists()) {
        final baseName = p.basenameWithoutExtension(fileName);
        final ext = p.extension(fileName);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        finalPath = p.join(targetFolderPath, '${baseName}_$timestamp$ext');
      }

      await file.rename(finalPath);
      return true;
    } catch (e) {
      AppLogger.e('移动图片失败: $imagePath -> $targetFolderPath', e);
      return false;
    }
  }

  /// 批量移动图片到文件夹
  Future<int> moveImagesToFolder(
    List<String> imagePaths,
    String targetFolderPath,
  ) async {
    int successCount = 0;

    for (final imagePath in imagePaths) {
      if (await moveImageToFolder(imagePath, targetFolderPath)) {
        successCount++;
      }
    }

    return successCount;
  }

  /// 开始监听文件夹变化
  Future<void> startWatching({void Function()? onChanged}) async {
    _onFoldersChanged = onChanged;

    final rootPath = await getRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      return;
    }

    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) {
      return;
    }

    // 取消之前的监听
    await stopWatching();

    try {
      _watchSubscription = rootDir.watch().listen((event) {
        // 只关注目录的创建和删除
        if (event is FileSystemCreateEvent || event is FileSystemDeleteEvent) {
          final entity = FileSystemEntity.typeSync(event.path);
          if (entity == FileSystemEntityType.directory ||
              event is FileSystemDeleteEvent) {
            _onFoldersChanged?.call();
          }
        }
      });
    } catch (e) {
      AppLogger.e('启动文件夹监听失败', e);
    }
  }

  /// 停止监听
  Future<void> stopWatching() async {
    await _watchSubscription?.cancel();
    _watchSubscription = null;
  }

  /// 获取根目录下的图片总数
  Future<int> getTotalImageCount() async {
    final rootPath = await getRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      return 0;
    }

    int count = 0;
    final rootDir = Directory(rootPath);

    try {
      // 统计根目录下的图片
      await for (final entity
          in rootDir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (_supportedExtensions.contains(ext)) {
            count++;
          }
        }
      }

      // 统计所有子文件夹下的图片
      await for (final entity
          in rootDir.list(recursive: false, followLinks: false)) {
        if (entity is Directory) {
          count += await _countImagesInFolder(entity.path);
        }
      }
    } catch (e) {
      AppLogger.e('统计图片总数失败', e);
    }

    return count;
  }
}
