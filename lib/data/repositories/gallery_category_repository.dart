import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../models/gallery/gallery_category.dart';

/// 画廊分类仓库
///
/// 管理分类的CRUD操作，并与文件系统同步
/// 分类与物理文件夹一一对应
class GalleryCategoryRepository {
  GalleryCategoryRepository._();

  static final GalleryCategoryRepository instance =
      GalleryCategoryRepository._();

  final _localStorage = LocalStorageService();

  /// 分类配置文件名
  static const _categoriesFileName = '.gallery_categories.json';

  /// 支持的图片扩展名
  static const _supportedExtensions = {'.png', '.jpg', '.jpeg', '.webp'};

  /// 获取画廊根路径
  Future<String?> getRootPath() async {
    return _localStorage.getImageSavePath();
  }

  /// 获取分类配置文件路径
  Future<String?> _getCategoriesFilePath() async {
    final rootPath = await getRootPath();
    if (rootPath == null) return null;
    return p.join(rootPath, _categoriesFileName);
  }

  /// 加载所有分类
  Future<List<GalleryCategory>> loadCategories() async {
    try {
      final filePath = await _getCategoriesFilePath();
      if (filePath == null) return [];

      final file = File(filePath);
      if (!await file.exists()) return [];

      final jsonStr = await file.readAsString();
      final jsonList = jsonDecode(jsonStr) as List;

      return jsonList
          .map((json) => GalleryCategory.fromJson(json as Map<String, dynamic>))
          .toList();
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
  ///
  /// [name] 分类名称
  /// [parentId] 父分类ID（null表示根级分类）
  /// [existingCategories] 现有分类列表（用于构建路径和排序）
  Future<GalleryCategory?> createCategory({
    required String name,
    String? parentId,
    List<GalleryCategory> existingCategories = const [],
  }) async {
    final rootPath = await getRootPath();
    if (rootPath == null) return null;

    // 清理文件夹名称
    final cleanName = _sanitizeFolderName(name);
    if (cleanName.isEmpty) return null;

    // 构建文件夹路径
    String relativePath;
    String absolutePath;

    if (parentId == null) {
      // 根级分类
      relativePath = cleanName;
      absolutePath = p.join(rootPath, cleanName);
    } else {
      // 子分类 - 需要找到父分类的路径
      final parent = existingCategories.findById(parentId);
      if (parent == null) {
        AppLogger.e('父分类不存在: $parentId');
        return null;
      }
      relativePath = p.join(parent.folderPath, cleanName);
      absolutePath = p.join(rootPath, relativePath);
    }

    // 检查文件夹是否已存在
    final dir = Directory(absolutePath);
    if (await dir.exists()) {
      AppLogger.w('分类文件夹已存在: $absolutePath');
      return null;
    }

    try {
      // 创建文件夹
      await dir.create(recursive: true);

      // 计算排序顺序
      final siblings = existingCategories.where((c) => c.parentId == parentId);
      final sortOrder = siblings.isEmpty ? 0 : siblings.length;

      // 创建分类对象
      final category = GalleryCategory.create(
        name: name,
        folderPath: relativePath,
        parentId: parentId,
        sortOrder: sortOrder,
      );

      AppLogger.i('创建分类成功: ${category.name} -> $absolutePath');
      return category;
    } catch (e) {
      AppLogger.e('创建分类文件夹失败: $absolutePath', e);
      return null;
    }
  }

  /// 重命名分类（同时重命名文件夹）
  ///
  /// 会同时更新所有子分类的文件夹路径
  Future<GalleryCategory?> renameCategory(
    GalleryCategory category,
    String newName,
    List<GalleryCategory> allCategories,
  ) async {
    final rootPath = await getRootPath();
    if (rootPath == null) return null;

    final cleanName = _sanitizeFolderName(newName);
    if (cleanName.isEmpty) return null;

    final oldAbsolutePath = p.join(rootPath, category.folderPath);
    final parentPath = p.dirname(oldAbsolutePath);
    final newAbsolutePath = p.join(parentPath, cleanName);

    try {
      final oldDir = Directory(oldAbsolutePath);
      if (!await oldDir.exists()) {
        AppLogger.w('原分类文件夹不存在: $oldAbsolutePath');
        return null;
      }

      if (await Directory(newAbsolutePath).exists()) {
        AppLogger.w('目标文件夹已存在: $newAbsolutePath');
        return null;
      }

      // 重命名文件夹
      await oldDir.rename(newAbsolutePath);

      // 计算新的相对路径
      final newRelativePath = p.relative(newAbsolutePath, from: rootPath);

      // 更新分类对象
      final updated = category.copyWith(
        name: newName,
        folderPath: newRelativePath,
        updatedAt: DateTime.now(),
      );

      AppLogger.i('重命名分类成功: ${category.name} -> $newName');
      return updated;
    } catch (e) {
      AppLogger.e('重命名分类失败: ${category.name}', e);
      return null;
    }
  }

  /// 更新所有子分类的文件夹路径
  ///
  /// 当父分类被重命名或移动时调用
  List<GalleryCategory> updateDescendantPaths(
    String oldParentPath,
    String newParentPath,
    List<GalleryCategory> categories,
  ) {
    return categories.map((c) {
      if (c.folderPath.startsWith(oldParentPath)) {
        final newPath =
            c.folderPath.replaceFirst(oldParentPath, newParentPath);
        return c.copyWith(
          folderPath: newPath,
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

    // 检查循环引用
    if (newParentId != null &&
        allCategories.wouldCreateCycle(category.id, newParentId)) {
      AppLogger.w('移动会造成循环引用');
      return null;
    }

    // 构建新路径
    String newRelativePath;
    String newAbsolutePath;

    if (newParentId == null) {
      // 移动到根级
      newRelativePath = p.basename(category.folderPath);
      newAbsolutePath = p.join(rootPath, newRelativePath);
    } else {
      // 移动到其他分类下
      final newParent = allCategories.findById(newParentId);
      if (newParent == null) {
        AppLogger.e('目标父分类不存在: $newParentId');
        return null;
      }
      newRelativePath = p.join(newParent.folderPath, p.basename(category.folderPath));
      newAbsolutePath = p.join(rootPath, newRelativePath);
    }

    final oldAbsolutePath = p.join(rootPath, category.folderPath);

    try {
      final oldDir = Directory(oldAbsolutePath);
      if (!await oldDir.exists()) {
        AppLogger.w('原分类文件夹不存在: $oldAbsolutePath');
        return null;
      }

      if (await Directory(newAbsolutePath).exists()) {
        AppLogger.w('目标文件夹已存在: $newAbsolutePath');
        return null;
      }

      // 确保目标父文件夹存在
      final newParentDir = Directory(p.dirname(newAbsolutePath));
      if (!await newParentDir.exists()) {
        await newParentDir.create(recursive: true);
      }

      // 移动文件夹
      await oldDir.rename(newAbsolutePath);

      // 更新分类对象
      final updated = category.copyWith(
        parentId: newParentId,
        folderPath: newRelativePath,
        updatedAt: DateTime.now(),
      );

      AppLogger.i('移动分类成功: ${category.name}');
      return updated;
    } catch (e) {
      AppLogger.e('移动分类失败: ${category.name}', e);
      return null;
    }
  }

  /// 删除分类
  ///
  /// [deleteFolder] 是否同时删除文件夹
  /// [recursive] 是否递归删除（包括子分类和文件夹内容）
  Future<bool> deleteCategory(
    GalleryCategory category,
    List<GalleryCategory> allCategories, {
    bool deleteFolder = true,
    bool recursive = false,
  }) async {
    final rootPath = await getRootPath();
    if (rootPath == null) return false;

    // 检查是否有子分类
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
          // 检查文件夹是否为空
          final isEmpty = await _isFolderEmpty(folderPath);
          if (!isEmpty && !recursive) {
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
  ///
  /// [imagePath] 图片文件路径
  /// [targetCategory] 目标分类（null表示移动到根目录）
  Future<String?> moveImageToCategory(
    String imagePath,
    GalleryCategory? targetCategory,
  ) async {
    final rootPath = await getRootPath();
    if (rootPath == null) return null;

    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final fileName = p.basename(imagePath);
      final targetDir = targetCategory == null
          ? rootPath
          : p.join(rootPath, targetCategory.folderPath);

      // 确保目标目录存在
      final dir = Directory(targetDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      var targetPath = p.join(targetDir, fileName);

      // 如果目标已存在，添加时间戳
      if (await File(targetPath).exists()) {
        final baseName = p.basenameWithoutExtension(fileName);
        final ext = p.extension(fileName);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        targetPath = p.join(targetDir, '${baseName}_$timestamp$ext');
      }

      await file.rename(targetPath);
      return targetPath;
    } catch (e) {
      AppLogger.e('移动图片失败: $imagePath', e);
      return null;
    }
  }

  /// 批量移动图片到分类
  Future<int> moveImagesToCategory(
    List<String> imagePaths,
    GalleryCategory? targetCategory,
  ) async {
    int successCount = 0;

    for (final imagePath in imagePaths) {
      final newPath = await moveImageToCategory(imagePath, targetCategory);
      if (newPath != null) {
        successCount++;
      }
    }

    return successCount;
  }

  /// 统计分类内的图片数量
  ///
  /// [includeDescendants] 是否包含子分类的图片
  Future<int> countImagesInCategory(
    GalleryCategory category, {
    bool includeDescendants = true,
    List<GalleryCategory>? allCategories,
  }) async {
    final rootPath = await getRootPath();
    if (rootPath == null) return 0;

    final folderPath = p.join(rootPath, category.folderPath);
    return _countImagesInFolder(folderPath, recursive: includeDescendants);
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

  // ============================================================
  // 私有辅助方法
  // ============================================================

  /// 清理文件夹名称
  String _sanitizeFolderName(String name) {
    // Windows 非法字符: \ / : * ? " < > |
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 检查文件夹是否为空
  Future<bool> _isFolderEmpty(String folderPath) async {
    final dir = Directory(folderPath);
    try {
      final count = await dir.list().length;
      return count == 0;
    } catch (_) {
      return true;
    }
  }

  /// 统计文件夹内的图片数量
  Future<int> _countImagesInFolder(String folderPath,
      {bool recursive = false}) async {
    int count = 0;
    final dir = Directory(folderPath);

    try {
      await for (final entity
          in dir.list(recursive: recursive, followLinks: false)) {
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
}
