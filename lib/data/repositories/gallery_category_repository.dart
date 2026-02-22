import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../models/gallery/gallery_category.dart';

/// 画廊分类仓库
class GalleryCategoryRepository {
  GalleryCategoryRepository._();
  static final GalleryCategoryRepository instance = GalleryCategoryRepository._();

  final _localStorage = LocalStorageService();

  static const _categoriesFileName = '.gallery_categories.json';
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

  Future<String?> _getCategoriesFilePath() async {
    final rootPath = await getRootPath();
    return rootPath != null ? p.join(rootPath, _categoriesFileName) : null;
  }

  Future<List<GalleryCategory>> loadCategories() async {
    try {
      final filePath = await _getCategoriesFilePath();
      if (filePath == null) return [];

      final file = File(filePath);
      if (!await file.exists()) return [];

      final jsonList = jsonDecode(await file.readAsString()) as List;
      return jsonList.map((j) => GalleryCategory.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      AppLogger.e('加载分类配置失败', e);
      return [];
    }
  }

  /// 保存所有分类
  Future<bool> saveCategories(List<GalleryCategory> categories) async {
    try {
      final filePath = await _getCategoriesFilePath();
      if (filePath == null) return false;

      final file = File(filePath);
      final jsonList = categories.map((c) => c.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));

      return true;
    } catch (e) {
      AppLogger.e('保存分类配置失败', e);
      return false;
    }
  }

  /// 创建分类（同时创建文件夹）
  Future<GalleryCategory?> createCategory({
    required String name,
    String? parentId,
    List<GalleryCategory> existingCategories = const [],
  }) async {
    final rootPath = await getRootPath();
    if (rootPath == null) return null;

    final cleanName = _sanitizeFolderName(name);
    if (cleanName.isEmpty) return null;

    final (relativePath, absolutePath) = parentId == null
        ? (cleanName, p.join(rootPath, cleanName))
        : _buildChildPath(rootPath, cleanName, parentId, existingCategories);

    if (absolutePath.isEmpty) return null;

    final dir = Directory(absolutePath);
    if (await dir.exists()) {
      AppLogger.w('分类文件夹已存在: $absolutePath');
      return null;
    }

    try {
      await dir.create(recursive: true);

      final siblings = existingCategories.where((c) => c.parentId == parentId);
      final category = GalleryCategory.create(
        name: name,
        folderPath: relativePath,
        parentId: parentId,
        sortOrder: siblings.length,
      );

      AppLogger.i('创建分类成功: ${category.name} -> $absolutePath');
      return category;
    } catch (e) {
      AppLogger.e('创建分类文件夹失败: $absolutePath', e);
      return null;
    }
  }

  (String relative, String absolute) _buildChildPath(
    String rootPath,
    String cleanName,
    String parentId,
    List<GalleryCategory> categories,
  ) {
    final parent = categories.findById(parentId);
    if (parent == null) {
      AppLogger.e('父分类不存在: $parentId');
      return ('', '');
    }
    final relativePath = p.join(parent.folderPath, cleanName);
    return (relativePath, p.join(rootPath, relativePath));
  }

  /// 重命名分类（同时重命名文件夹）
  Future<GalleryCategory?> renameCategory(
    GalleryCategory category,
    String newName,
    List<GalleryCategory> allCategories,
  ) async {
    final rootPath = await getRootPath();
    if (rootPath == null) return null;

    final cleanName = _sanitizeFolderName(newName);
    if (cleanName.isEmpty) return null;

    final oldPath = p.join(rootPath, category.folderPath);
    final newPath = p.join(p.dirname(oldPath), cleanName);

    try {
      final oldDir = Directory(oldPath);
      if (!await oldDir.exists()) {
        AppLogger.w('原分类文件夹不存在: $oldPath');
        return null;
      }

      if (await Directory(newPath).exists()) {
        AppLogger.w('目标文件夹已存在: $newPath');
        return null;
      }

      await oldDir.rename(newPath);

      AppLogger.i('重命名分类成功: ${category.name} -> $newName');
      return category.copyWith(
        name: newName,
        folderPath: p.relative(newPath, from: rootPath),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      AppLogger.e('重命名分类失败: ${category.name}', e);
      return null;
    }
  }

  /// 更新所有子分类的文件夹路径
  List<GalleryCategory> updateDescendantPaths(
    String oldParentPath,
    String newParentPath,
    List<GalleryCategory> categories,
  ) {
    return categories.map((c) {
      if (c.folderPath.startsWith(oldParentPath)) {
        return c.copyWith(
          folderPath: c.folderPath.replaceFirst(oldParentPath, newParentPath),
          updatedAt: DateTime.now(),
        );
      }
      return c;
    }).toList();
  }

  /// 移动分类到新父级（同时移动文件夹）
  Future<GalleryCategory?> moveCategory(
    GalleryCategory category,
    String? newParentId,
    List<GalleryCategory> allCategories,
  ) async {
    final rootPath = await getRootPath();
    if (rootPath == null) return null;

    if (newParentId != null && allCategories.wouldCreateCycle(category.id, newParentId)) {
      AppLogger.w('移动会造成循环引用');
      return null;
    }

    final (newRelativePath, newAbsolutePath) = newParentId == null
        ? (p.basename(category.folderPath), p.join(rootPath, p.basename(category.folderPath)))
        : _buildMovePaths(rootPath, category, newParentId, allCategories);

    if (newAbsolutePath.isEmpty) return null;

    final oldPath = p.join(rootPath, category.folderPath);

    try {
      final oldDir = Directory(oldPath);
      if (!await oldDir.exists()) {
        AppLogger.w('原分类文件夹不存在: $oldPath');
        return null;
      }

      if (await Directory(newAbsolutePath).exists()) {
        AppLogger.w('目标文件夹已存在: $newAbsolutePath');
        return null;
      }

      final newParentDir = Directory(p.dirname(newAbsolutePath));
      if (!await newParentDir.exists()) await newParentDir.create(recursive: true);

      await oldDir.rename(newAbsolutePath);

      AppLogger.i('移动分类成功: ${category.name}');
      return category.copyWith(
        parentId: newParentId,
        folderPath: newRelativePath,
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      AppLogger.e('移动分类失败: ${category.name}', e);
      return null;
    }
  }

  (String relative, String absolute) _buildMovePaths(
    String rootPath,
    GalleryCategory category,
    String newParentId,
    List<GalleryCategory> categories,
  ) {
    final newParent = categories.findById(newParentId);
    if (newParent == null) {
      AppLogger.e('目标父分类不存在: $newParentId');
      return ('', '');
    }
    final relativePath = p.join(newParent.folderPath, p.basename(category.folderPath));
    return (relativePath, p.join(rootPath, relativePath));
  }

  /// 删除分类
  Future<bool> deleteCategory(
    GalleryCategory category,
    List<GalleryCategory> allCategories, {
    bool deleteFolder = true,
    bool recursive = false,
  }) async {
    final rootPath = await getRootPath();
    if (rootPath == null) return false;

    final children = allCategories.getChildren(category.id);
    if (children.isNotEmpty && !recursive) {
      AppLogger.w('分类包含子分类，无法删除: ${category.name}');
      return false;
    }

    final folderPath = p.join(rootPath, category.folderPath);

    try {
      if (deleteFolder) {
        final dir = Directory(folderPath);
        if (await dir.exists()) {
          if (!recursive && !await _isFolderEmpty(folderPath)) {
            AppLogger.w('文件夹不为空，无法删除: $folderPath');
            return false;
          }
          await dir.delete(recursive: recursive);
        }
      }

      AppLogger.i('删除分类成功: ${category.name}');
      return true;
    } catch (e) {
      AppLogger.e('删除分类失败: ${category.name}', e);
      return false;
    }
  }

  /// 移动图片到分类
  Future<String?> moveImageToCategory(String imagePath, GalleryCategory? targetCategory) async {
    final rootPath = await getRootPath();
    if (rootPath == null) return null;

    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final fileName = p.basename(imagePath);
      final targetDir = targetCategory == null
          ? rootPath
          : p.join(rootPath, targetCategory.folderPath);

      final dir = Directory(targetDir);
      if (!await dir.exists()) await dir.create(recursive: true);

      var targetPath = p.join(targetDir, fileName);

      if (await File(targetPath).exists()) {
        final baseName = p.basenameWithoutExtension(fileName);
        final ext = p.extension(fileName);
        targetPath = p.join(targetDir, '${baseName}_${DateTime.now().millisecondsSinceEpoch}$ext');
      }

      await file.rename(targetPath);
      return targetPath;
    } catch (e) {
      AppLogger.e('移动图片失败: $imagePath', e);
      return null;
    }
  }

  /// 批量移动图片到分类
  Future<int> moveImagesToCategory(List<String> imagePaths, GalleryCategory? targetCategory) async {
    int successCount = 0;
    for (final imagePath in imagePaths) {
      if (await moveImageToCategory(imagePath, targetCategory) != null) successCount++;
    }
    return successCount;
  }

  /// 统计分类内的图片数量
  Future<int> countImagesInCategory(
    GalleryCategory category, {
    bool includeDescendants = true,
  }) async {
    final rootPath = await getRootPath();
    if (rootPath == null) return 0;

    return _countImagesInFolder(
      p.join(rootPath, category.folderPath),
      recursive: includeDescendants,
    );
  }

  /// 获取分类对应的绝对文件夹路径
  Future<String?> getCategoryAbsolutePath(GalleryCategory category) async {
    final rootPath = await getRootPath();
    if (rootPath == null) return null;
    return p.join(rootPath, category.folderPath);
  }

  /// 同步分类与文件系统
  ///
  /// 扫描文件系统中的文件夹，创建缺失的分类
  /// 删除不存在的分类
  Future<List<GalleryCategory>> syncWithFileSystem(
    List<GalleryCategory> existingCategories,
  ) async {
    final rootPath = await getRootPath();
    if (rootPath == null) return existingCategories;

    final updatedCategories = <GalleryCategory>[];
    final existingPaths = existingCategories.map((c) => c.folderPath).toSet();

    // 检查现有分类的文件夹是否存在
    for (final category in existingCategories) {
      final folderPath = p.join(rootPath, category.folderPath);
      if (await Directory(folderPath).exists()) {
        // 更新图片数量
        final imageCount = await _countImagesInFolder(folderPath);
        updatedCategories.add(category.updateImageCount(imageCount));
      }
      // 如果文件夹不存在，则不添加到更新列表（相当于删除）
    }

    // 扫描文件系统中的新文件夹
    await _scanAndAddNewFolders(
      rootPath,
      rootPath,
      null,
      existingPaths,
      updatedCategories,
    );

    return updatedCategories;
  }

  /// 递归扫描并添加新文件夹
  Future<void> _scanAndAddNewFolders(
    String rootPath,
    String currentPath,
    String? parentId,
    Set<String> existingPaths,
    List<GalleryCategory> categories,
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

          if (!existingPaths.contains(relativePath)) {
            // 新文件夹，创建分类
            final imageCount = await _countImagesInFolder(entity.path);
            final category = GalleryCategory.create(
              name: folderName,
              folderPath: relativePath,
              parentId: parentId,
              sortOrder: categories.where((c) => c.parentId == parentId).length,
            ).updateImageCount(imageCount);

            categories.add(category);
            existingPaths.add(relativePath);

            // 递归扫描子文件夹
            await _scanAndAddNewFolders(
              rootPath,
              entity.path,
              category.id,
              existingPaths,
              categories,
            );
          } else {
            // 已存在的分类，查找其ID并递归扫描子文件夹
            final existingCategory = categories.where(
              (c) => c.folderPath == relativePath,
            ).firstOrNull;

            if (existingCategory != null) {
              await _scanAndAddNewFolders(
                rootPath,
                entity.path,
                existingCategory.id,
                existingPaths,
                categories,
              );
            }
          }
        }
      }
    } catch (e) {
      AppLogger.e('扫描文件夹失败: $currentPath', e);
    }
  }

  String _sanitizeFolderName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<bool> _isFolderEmpty(String folderPath) async {
    try {
      return await Directory(folderPath).list().isEmpty;
    } catch (_) {
      return true;
    }
  }

  Future<int> _countImagesInFolder(String folderPath, {bool recursive = false}) async {
    int count = 0;
    try {
      await for (final entity in Directory(folderPath).list(recursive: recursive, followLinks: false)) {
        if (entity is File && _supportedExtensions.contains(p.extension(entity.path).toLowerCase())) {
          count++;
        }
      }
    } catch (e) {
      AppLogger.w('Failed to get total image count', 'GalleryCategoryRepository');
    }
    return count;
  }
}
