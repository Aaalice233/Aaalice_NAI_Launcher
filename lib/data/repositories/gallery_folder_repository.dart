import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

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

  Future<String?> getRootPath() async => Future.value(_localStorage.getImageSavePath());

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

  Future<int> _countImagesInFolder(String folderPath, {bool recursive = false}) async {
    int count = 0;
    try {
      await for (final entity in Directory(folderPath).list(recursive: recursive, followLinks: false)) {
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

  /// 递归扫描所有文件夹（包含嵌套）
  Future<List<GalleryFolder>> scanFoldersRecursively() async {
    final rootPath = await getRootPath();
    if (rootPath == null || rootPath.isEmpty) return [];

    final folders = <GalleryFolder>[];
    await _scanFolderRecursive(rootPath, rootPath, null, folders);
    return folders;
  }

  Future<void> _scanFolderRecursive(
    String rootPath,
    String currentPath,
    String? parentId,
    List<GalleryFolder> folders,
  ) async {
    final dir = Directory(currentPath);
    if (!await dir.exists()) return;

    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          final folderName = p.basename(entity.path);
          // 跳过隐藏文件夹
          if (folderName.startsWith('.')) continue;

          final relativePath = p.relative(entity.path, from: rootPath);
          final folder = await _createNestedFolderFromDirectory(
            entity,
            relativePath,
            parentId,
          );
          if (folder != null) {
            folders.add(folder);
            // 递归扫描子文件夹
            await _scanFolderRecursive(rootPath, entity.path, folder.id, folders);
          }
        }
      }
    } catch (e) {
      AppLogger.e('递归扫描文件夹失败: $currentPath', e);
    }
  }

  Future<GalleryFolder?> _createNestedFolderFromDirectory(
    Directory dir,
    String relativePath,
    String? parentId,
  ) async {
    try {
      final stat = await dir.stat();
      final imageCount = await _countImagesInFolder(dir.path, recursive: true);
      return GalleryFolder(
        id: _generateFolderId(dir.path),
        name: p.basename(dir.path),
        path: relativePath,
        parentId: parentId,
        imageCount: imageCount,
        createdAt: stat.changed,
        updatedAt: stat.modified,
      );
    } catch (e) {
      AppLogger.e('创建嵌套文件夹对象失败: ${dir.path}', e);
      return null;
    }
  }

  /// 创建嵌套文件夹（在指定父文件夹下）
  Future<GalleryFolder?> createNestedFolder({
    required String name,
    String? parentId,
    List<GalleryFolder> existingFolders = const [],
  }) async {
    final rootPath = await getRootPath();
    if (rootPath == null) return null;

    final cleanName = _sanitizeFolderName(name);
    if (cleanName.isEmpty) return null;

    final (relativePath, absolutePath) = parentId == null
        ? (cleanName, p.join(rootPath, cleanName))
        : _buildChildPath(rootPath, cleanName, parentId, existingFolders);

    if (absolutePath.isEmpty) return null;

    final dir = Directory(absolutePath);
    if (await dir.exists()) {
      AppLogger.w('文件夹已存在: $absolutePath');
      return null;
    }

    try {
      await dir.create(recursive: true);

      final siblings = existingFolders.where((f) => f.parentId == parentId);
      final folder = GalleryFolder.create(
        name: name,
        path: relativePath,
        parentId: parentId,
        sortOrder: siblings.length,
      );

      AppLogger.i('创建嵌套文件夹成功: ${folder.name} -> $absolutePath');
      return folder;
    } catch (e) {
      AppLogger.e('创建嵌套文件夹失败: $absolutePath', e);
      return null;
    }
  }

  (String relative, String absolute) _buildChildPath(
    String rootPath,
    String cleanName,
    String parentId,
    List<GalleryFolder> folders,
  ) {
    final parent = folders.findById(parentId);
    if (parent == null) {
      AppLogger.e('父文件夹不存在: $parentId');
      return ('', '');
    }
    final relativePath = p.join(parent.path, cleanName);
    return (relativePath, p.join(rootPath, relativePath));
  }

  /// 移动文件夹到新父级（同时移动物理文件夹）
  Future<GalleryFolder?> moveFolder(
    GalleryFolder folder,
    String? newParentId,
    List<GalleryFolder> allFolders,
  ) async {
    final rootPath = await getRootPath();
    if (rootPath == null) return null;

    // 检查循环引用
    if (newParentId != null && allFolders.wouldCreateCycle(folder.id, newParentId)) {
      AppLogger.w('移动会造成循环引用');
      return null;
    }

    final (newRelativePath, newAbsolutePath) = newParentId == null
        ? (p.basename(folder.path), p.join(rootPath, p.basename(folder.path)))
        : _buildMovePaths(rootPath, folder, newParentId, allFolders);

    if (newAbsolutePath.isEmpty) return null;

    final oldAbsolutePath = p.join(rootPath, folder.path);

    try {
      final oldDir = Directory(oldAbsolutePath);
      if (!await oldDir.exists()) {
        AppLogger.w('原文件夹不存在: $oldAbsolutePath');
        return null;
      }

      if (await Directory(newAbsolutePath).exists()) {
        AppLogger.w('目标文件夹已存在: $newAbsolutePath');
        return null;
      }

      // 确保目标父目录存在
      final newParentDir = Directory(p.dirname(newAbsolutePath));
      if (!await newParentDir.exists()) await newParentDir.create(recursive: true);

      await oldDir.rename(newAbsolutePath);

      AppLogger.i('移动文件夹成功: ${folder.name}');
      return folder.moveTo(newParentId, newRelativePath);
    } catch (e) {
      AppLogger.e('移动文件夹失败: ${folder.name}', e);
      return null;
    }
  }

  (String relative, String absolute) _buildMovePaths(
    String rootPath,
    GalleryFolder folder,
    String newParentId,
    List<GalleryFolder> folders,
  ) {
    final newParent = folders.findById(newParentId);
    if (newParent == null) {
      AppLogger.e('目标父文件夹不存在: $newParentId');
      return ('', '');
    }
    final relativePath = p.join(newParent.path, p.basename(folder.path));
    return (relativePath, p.join(rootPath, relativePath));
  }

  /// 更新所有后代文件夹的路径
  List<GalleryFolder> updateDescendantPaths(
    String oldParentPath,
    String newParentPath,
    List<GalleryFolder> folders,
  ) {
    return folders.map((f) {
      if (f.path.startsWith(oldParentPath)) {
        return f.copyWith(
          path: f.path.replaceFirst(oldParentPath, newParentPath),
          updatedAt: DateTime.now(),
        );
      }
      return f;
    }).toList();
  }

  /// 检查文件夹是否为空（包含子文件夹）
  Future<bool> isFolderEmpty(String folderPath, {bool recursive = false}) async {
    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) return true;

      if (recursive) {
        // 递归模式：检查是否包含任何文件
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) return false;
        }
        return true;
      } else {
        // 非递归模式：只检查直接内容
        return await dir.list().isEmpty;
      }
    } catch (_) {
      return true;
    }
  }

  /// 获取文件夹的后代文件夹ID集合
  Set<String> getDescendantIds(String folderId, List<GalleryFolder> allFolders) {
    return allFolders.getDescendantIds(folderId);
  }

  /// 递归统计文件夹中的图片数量
  Future<int> countImagesRecursively(String folderPath) async {
    return _countImagesInFolder(folderPath, recursive: true);
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
