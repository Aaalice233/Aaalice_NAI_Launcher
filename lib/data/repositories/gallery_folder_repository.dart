import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../models/gallery/gallery_folder.dart';

/// 画廊文件夹仓库
class GalleryFolderRepository {
  GalleryFolderRepository._();
  static final GalleryFolderRepository instance = GalleryFolderRepository._();

  final _localStorage = LocalStorageService();
  StreamSubscription<FileSystemEvent>? _watchSubscription;
  void Function()? _onFoldersChanged;

  static const _supportedExtensions = {'.png', '.jpg', '.jpeg', '.webp'};

  /// 获取图片保存根路径
  ///
  /// 优先使用用户设置的自定义路径，如果没有设置则返回默认路径
  /// 默认路径：Documents/NAI_Launcher/images/
  Future<String?> getRootPath() async {
    // 优先使用用户设置的自定义路径
    final customPath = _localStorage.getImageSavePath();
    if (customPath != null && customPath.isNotEmpty) {
      return customPath;
    }

    // 使用默认路径
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, 'NAI_Launcher', 'images');
  }

  /// 扫描文件夹列表
  Future<List<GalleryFolder>> scanFolders() async {
    final rootPath = await getRootPath();
    if (rootPath == null || rootPath.isEmpty) return [];

    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) return [];

    final folders = <GalleryFolder>[];

    try {
      await for (final entity in rootDir.list(followLinks: false)) {
        if (entity is Directory) {
          final folder = await _createFolderFromDirectory(entity);
          if (folder != null) folders.add(folder);
        }
      }
      folders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      AppLogger.e('扫描文件夹失败', e);
    }

    return folders;
  }

  Future<GalleryFolder?> _createFolderFromDirectory(Directory dir) async {
    try {
      final stat = await dir.stat();
      return GalleryFolder(
        id: _generateFolderId(dir.path),
        name: p.basename(dir.path),
        path: dir.path,
        imageCount: await _countImagesInFolder(dir.path),
        createdAt: stat.changed,
        modifiedAt: stat.modified,
      );
    } catch (e) {
      AppLogger.e('创建文件夹对象失败: ${dir.path}', e);
      return null;
    }
  }

  String _generateFolderId(String path) => md5.convert(utf8.encode(path)).toString().substring(0, 16);

  Future<int> _countImagesInFolder(String folderPath) async {
    int count = 0;
    try {
      await for (final entity in Directory(folderPath).list(followLinks: false)) {
        if (entity is File && _supportedExtensions.contains(p.extension(entity.path).toLowerCase())) {
          count++;
        }
      }
    } catch (_) {}
    return count;
  }

  /// 创建新文件夹
  Future<GalleryFolder?> createFolder(String name) async {
    final rootPath = await getRootPath();
    if (rootPath == null || rootPath.isEmpty) return null;

    final cleanName = _sanitizeFolderName(name);
    if (cleanName.isEmpty) return null;

    final folderPath = p.join(rootPath, cleanName);
    final dir = Directory(folderPath);

    try {
      if (await dir.exists()) {
        AppLogger.w('文件夹已存在: $folderPath');
        return await _createFolderFromDirectory(dir);
      }

      await dir.create(recursive: false);
      AppLogger.i('创建文件夹成功: $folderPath');
      return await _createFolderFromDirectory(dir);
    } catch (e) {
      AppLogger.e('创建文件夹失败: $folderPath', e);
      return null;
    }
  }

  String _sanitizeFolderName(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 删除文件夹
  Future<bool> deleteFolder(String folderPath, {bool recursive = false}) async {
    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) return true;

      if (!recursive) {
        // 转换为列表检查是否为空
        final items = await dir.list().toList();
        if (items.isNotEmpty) {
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
      if (!await dir.exists()) return null;

      final cleanName = _sanitizeFolderName(newName);
      if (cleanName.isEmpty) return null;

      final newPath = p.join(p.dirname(oldPath), cleanName);
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
  Future<bool> moveImageToFolder(String imagePath, String targetFolderPath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return false;

      final fileName = p.basename(imagePath);
      var newPath = p.join(targetFolderPath, fileName);

      if (await File(newPath).exists()) {
        final baseName = p.basenameWithoutExtension(fileName);
        final ext = p.extension(fileName);
        newPath = p.join(targetFolderPath, '${baseName}_${DateTime.now().millisecondsSinceEpoch}$ext');
      }

      await file.rename(newPath);
      return true;
    } catch (e) {
      AppLogger.e('移动图片失败: $imagePath -> $targetFolderPath', e);
      return false;
    }
  }

  /// 批量移动图片到文件夹
  Future<int> moveImagesToFolder(List<String> imagePaths, String targetFolderPath) async {
    int successCount = 0;
    for (final imagePath in imagePaths) {
      if (await moveImageToFolder(imagePath, targetFolderPath)) successCount++;
    }
    return successCount;
  }

  /// 开始监听文件夹变化
  Future<void> startWatching({void Function()? onChanged}) async {
    _onFoldersChanged = onChanged;

    final rootPath = await getRootPath();
    if (rootPath == null || rootPath.isEmpty) return;

    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) return;

    await stopWatching();

    try {
      _watchSubscription = rootDir.watch().listen((event) {
        if (event is FileSystemCreateEvent || event is FileSystemDeleteEvent) {
          final entity = FileSystemEntity.typeSync(event.path);
          if (entity == FileSystemEntityType.directory || event is FileSystemDeleteEvent) {
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
    if (rootPath == null || rootPath.isEmpty) return 0;

    int count = 0;
    final rootDir = Directory(rootPath);

    try {
      await for (final entity in rootDir.list(followLinks: false)) {
        if (entity is File && _supportedExtensions.contains(p.extension(entity.path).toLowerCase())) {
          count++;
        } else if (entity is Directory) {
          count += await _countImagesInFolder(entity.path);
        }
      }
    } catch (e) {
      AppLogger.e('统计图片总数失败', e);
    }

    return count;
  }
}
