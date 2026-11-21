import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

import '../../core/database/datasources/gallery_data_source.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/file_name_sanitizer.dart';
import '../models/gallery/gallery_category.dart';
import '../services/gallery/gallery_image_files.dart';
import '../services/gallery/gallery_folder_counts.dart';
import '../services/gallery/gallery_path_utils.dart';

/// 画廊分类仓库
class GalleryCategoryRepository {
  GalleryCategoryRepository({
    GalleryImageFiles images = const GalleryImageFiles(),
  }) : _images = images;
  final GalleryImageFiles _images;
  static final GalleryCategoryRepository instance = GalleryCategoryRepository();

  final _localStorage = LocalStorageService();
  final _categorySaveLock = Lock();

  static const _categoriesFileName = '.gallery_categories.json';
  static const _suppressedCategoriesFileName =
      '.gallery_category_suppressed_paths.json';

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

  Future<List<GalleryCategory>> loadCategories(String rootPath) async {
    final filePath = p.join(rootPath, _categoriesFileName);
    final file = File(filePath);
    final backupFile = File('$filePath.bak');
    try {
      try {
        final categories = await _readCategories(file);
        if (categories != null) {
          await _deleteIfPresent(backupFile);
          return categories;
        }
      } catch (primaryError) {
        final categories = await _readCategories(backupFile);
        if (categories == null) rethrow;
        await backupFile.copy(file.path);
        await _deleteIfPresent(backupFile);
        AppLogger.w('分类配置损坏，已从备份恢复: $primaryError');
        return categories;
      }

      final categories = await _readCategories(backupFile);
      if (categories == null) return [];
      await backupFile.copy(file.path);
      await _deleteIfPresent(backupFile);
      AppLogger.w('分类配置提交中断，已从备份恢复');
      return categories;
    } catch (e) {
      AppLogger.e('加载分类配置失败', e);
      rethrow;
    }
  }

  Future<String?> _readConfigIfPresent(File file) async {
    try {
      return await file.readAsString();
    } on PathNotFoundException {
      return null;
    }
  }

  Future<List<GalleryCategory>?> _readCategories(File file) async {
    final contents = await _readConfigIfPresent(file);
    if (contents == null) return null;
    final jsonList = jsonDecode(contents) as List;
    return jsonList
        .map((json) => GalleryCategory.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 保存所有分类
  Future<bool> saveCategories(
    String rootPath,
    List<GalleryCategory> categories,
  ) {
    return _categorySaveLock.synchronized(() async {
      final filePath = p.join(rootPath, _categoriesFileName);
      final file = File(filePath);
      final temporaryFile = File('$filePath.tmp');
      final backupFile = File('$filePath.bak');
      var committed = false;
      try {
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        final jsonList = categories.map((c) => c.toJson()).toList();
        await temporaryFile.writeAsString(jsonEncode(jsonList), flush: true);
        if (await file.exists()) {
          await file.copy(backupFile.path);
        }
        await temporaryFile.rename(file.path);
        committed = true;
        await _deleteIfPresent(backupFile);
        return true;
      } catch (e) {
        if (!committed && await backupFile.exists() && !await file.exists()) {
          try {
            await backupFile.rename(file.path);
          } catch (restoreError) {
            AppLogger.e('恢复分类配置备份失败', restoreError);
          }
        }
        AppLogger.e('保存分类配置失败', e);
        return false;
      } finally {
        await _deleteIfPresent(temporaryFile);
      }
    });
  }

  Future<void> _deleteIfPresent(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      AppLogger.w('清理分类配置临时文件失败: ${file.path}: $e');
    }
  }

  Future<Set<String>> _loadSuppressedFolderPaths(String rootPath) async {
    try {
      final contents = await _readConfigIfPresent(
        File(p.join(rootPath, _suppressedCategoriesFileName)),
      );
      if (contents == null) return {};
      final jsonList = jsonDecode(contents);
      if (jsonList is! List) {
        throw const FormatException('Invalid hidden paths');
      }
      return jsonList
          .whereType<String>()
          .map(_normalizeCategoryPath)
          .where((path) => path.isNotEmpty)
          .toSet();
    } catch (e) {
      AppLogger.e('加载隐藏分类路径失败', e);
      rethrow;
    }
  }

  Future<void> _saveSuppressedFolderPaths(
    String rootPath,
    Set<String> paths,
  ) async {
    try {
      final file = File(p.join(rootPath, _suppressedCategoriesFileName));
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }

      final normalized =
          paths
              .map(_normalizeCategoryPath)
              .where((path) => path.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      if (normalized.isEmpty) {
        if (await file.exists()) {
          await file.delete();
        }
        return;
      }

      await file.writeAsString(jsonEncode(normalized));
    } catch (e) {
      AppLogger.e('保存隐藏分类路径失败', e);
    }
  }

  Future<void> _suppressCategoryFolderPaths(
    String rootPath,
    GalleryCategory category,
    List<GalleryCategory> allCategories, {
    required bool recursive,
  }) async {
    final suppressedPaths = await _loadSuppressedFolderPaths(rootPath);
    final categoryIds = {
      category.id,
      if (recursive) ...allCategories.getDescendantIds(category.id),
    };

    for (final item in allCategories) {
      if (categoryIds.contains(item.id)) {
        suppressedPaths.add(_normalizeCategoryPath(item.folderPath));
      }
    }

    await _saveSuppressedFolderPaths(rootPath, suppressedPaths);
  }

  String _normalizeCategoryPath(String pathValue) {
    final normalized = galleryFilePathKey(
      p.normalize(pathValue),
    ).replaceAll('\\', '/');
    return normalized == '.' ? '' : normalized.replaceAll(RegExp(r'/+$'), '');
  }

  /// 创建分类（同时创建文件夹）
  Future<GalleryCategory?> createCategory({
    required String rootPath,
    required String name,
    String? parentId,
    List<GalleryCategory> existingCategories = const [],
  }) async {
    final cleanName = _sanitizeFolderName(name);
    if (cleanName.isEmpty) return null;

    final (relativePath, absolutePath) = parentId == null
        ? (cleanName, p.join(rootPath, cleanName))
        : _buildChildPath(rootPath, cleanName, parentId, existingCategories);

    if (absolutePath.isEmpty) return null;

    final dir = Directory(absolutePath);
    if (await dir.exists()) {
      final suppressedPaths = await _loadSuppressedFolderPaths(rootPath);
      if (suppressedPaths.remove(_normalizeCategoryPath(relativePath))) {
        final siblings = existingCategories.where(
          (c) => c.parentId == parentId,
        );
        final category = GalleryCategory.create(
          name: name,
          folderPath: relativePath,
          parentId: parentId,
          sortOrder: siblings.length,
        ).updateImageCount(await _countImagesInFolder(rootPath, absolutePath));
        await _saveSuppressedFolderPaths(rootPath, suppressedPaths);
        AppLogger.i('恢复隐藏分类成功: ${category.name} -> $absolutePath');
        return category;
      }

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
    String rootPath,
    GalleryCategory category,
    String newName,
    List<GalleryCategory> allCategories,
  ) async {
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
      if (p.isWithin(oldParentPath, c.folderPath)) {
        return c.copyWith(
          folderPath: p.join(
            newParentPath,
            p.relative(c.folderPath, from: oldParentPath),
          ),
          updatedAt: DateTime.now(),
        );
      }
      return c;
    }).toList();
  }

  /// 移动分类到新父级（同时移动文件夹）
  Future<GalleryCategory?> moveCategory(
    String rootPath,
    GalleryCategory category,
    String? newParentId,
    List<GalleryCategory> allCategories,
  ) async {
    if (newParentId != null &&
        allCategories.wouldCreateCycle(category.id, newParentId)) {
      AppLogger.w('移动会造成循环引用');
      return null;
    }

    final (newRelativePath, newAbsolutePath) = newParentId == null
        ? (
            p.basename(category.folderPath),
            p.join(rootPath, p.basename(category.folderPath)),
          )
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
      if (!await newParentDir.exists()) {
        await newParentDir.create(recursive: true);
      }

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
    final relativePath = p.join(
      newParent.folderPath,
      p.basename(category.folderPath),
    );
    return (relativePath, p.join(rootPath, relativePath));
  }

  /// 删除分类
  Future<bool> deleteCategory(
    String rootPath,
    GalleryCategory category,
    List<GalleryCategory> allCategories, {
    bool deleteFolder = true,
    bool recursive = false,
  }) async {
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
      } else {
        await _suppressCategoryFolderPaths(
          rootPath,
          category,
          allCategories,
          recursive: recursive,
        );
      }

      AppLogger.i('删除分类成功: ${category.name}');
      return true;
    } catch (e) {
      AppLogger.e('删除分类失败: ${category.name}', e);
      return false;
    }
  }

  /// 移动图片到分类
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

      final dir = Directory(targetDir);
      if (!await dir.exists()) await dir.create(recursive: true);

      var targetPath = p.join(targetDir, fileName);

      if (await File(targetPath).exists()) {
        final baseName = p.basenameWithoutExtension(fileName);
        final ext = p.extension(fileName);
        final conflictStem =
            '${baseName}_${DateTime.now().millisecondsSinceEpoch}';
        targetPath = p.join(targetDir, '$conflictStem$ext');
        var suffix = 2;
        while (await File(targetPath).exists()) {
          targetPath = p.join(targetDir, '$conflictStem-$suffix$ext');
          suffix++;
        }
      }

      await file.rename(targetPath);

      // 物理移动后同步库内路径（保留行 id），使收藏、标签、相簿成员
      // 等按 image_id 关联的数据在移动后仍然有效
      await _syncDatabasePath(imagePath, targetPath);
      return targetPath;
    } catch (e) {
      AppLogger.e('移动图片失败: $imagePath', e);
      return null;
    }
  }

  Future<void> _syncDatabasePath(String oldPath, String newPath) async {
    try {
      final dataSource = GalleryDataSource();
      final imageId = await dataSource.getImageIdByPath(oldPath);
      if (imageId == null) return;
      await dataSource.updateFilePath(
        imageId,
        newPath,
        newFileName: p.basename(newPath),
      );
    } catch (e) {
      // 同步失败不阻断移动本身；下次全量扫描会按新路径重新入库
      AppLogger.w('移动后同步数据库路径失败: $oldPath -> $newPath ($e)');
    }
  }

  /// 批量移动图片到分类
  Future<int> moveImagesToCategory(
    List<String> imagePaths,
    GalleryCategory? targetCategory,
  ) async {
    int successCount = 0;
    for (final imagePath in imagePaths) {
      if (await moveImageToCategory(imagePath, targetCategory) != null) {
        successCount++;
      }
    }
    return successCount;
  }

  /// 统计分类内的图片数量
  Future<int> countImagesInCategory(GalleryCategory category) async {
    final rootPath = await getRootPath();
    if (rootPath == null) return 0;

    return _countImagesInFolder(
      rootPath,
      p.join(rootPath, category.folderPath),
    );
  }

  /// 获取分类对应的绝对文件夹路径
  Future<String?> getCategoryAbsolutePath(GalleryCategory category) async {
    final rootPath = await getRootPath();
    if (rootPath == null) return null;
    return p.join(rootPath, category.folderPath);
  }

  Future<List<GalleryCategory>> syncWithFileSystem(
    String root,
    List<GalleryCategory> existing,
  ) async {
    final directory = Directory(root);
    if (!await directory.exists()) return existing;
    final paths = <String, String>{};
    final incomplete = <String>{};
    final counts = GalleryFolderCounts();
    await _images.list(
      directory,
      onDirectory: (folder, direct) {
        counts.addToFolder(folder.path, direct);
        if (p.equals(root, folder.path)) return;
        final path = p.relative(folder.path, from: root);
        paths[_normalizeCategoryPath(path)] = path;
      },
      onIncompleteDirectory: (folder) => incomplete.add(
        _normalizeCategoryPath(p.relative(folder.path, from: root)),
      ),
    );

    bool isIncomplete(String key) =>
        incomplete.any((folder) => key == folder || key.startsWith('$folder/'));
    bool retain(String key) => paths.containsKey(key) || isIncomplete(key);

    // 可读祖先的汇总沿用最外层未读子树的旧计数。
    for (final key in incomplete) {
      if (isIncomplete(p.posix.dirname(key))) continue;
      final previous = existing
          .where((c) => _normalizeCategoryPath(c.folderPath) == key)
          .firstOrNull;
      if (previous == null) continue;
      final absolute = p.join(root, paths[key]!);
      counts.addToFolder(
        absolute,
        previous.imageCount - counts.countIn(absolute),
      );
    }

    final suppressed = await _loadSuppressedFolderPaths(root);
    final retained = suppressed.where(retain).toSet();
    if (retained.length != suppressed.length) {
      await _saveSuppressedFolderPaths(root, retained);
    }
    final present = existing
        .where((c) => retain(_normalizeCategoryPath(c.folderPath)))
        .toList();
    return _mergeFolderCounts(
      root,
      present,
      paths.entries
          .where((entry) => !isIncomplete(entry.key))
          .map((entry) => entry.value),
      retained,
      counts.countIn,
    );
  }

  Future<List<GalleryCategory>> updateForImagePaths(
    String root,
    List<GalleryCategory> existing,
    Iterable<String> files,
    int Function(String) countIn,
  ) async {
    final paths = <String, String>{};
    for (final file in files) {
      if (!GalleryImageFiles.accepts(root, file)) continue;
      final parent = p.dirname(file);
      if (p.equals(root, parent)) continue;
      var prefix = '';
      for (final segment in p.split(p.relative(parent, from: root))) {
        prefix = p.join(prefix, segment);
        paths[_normalizeCategoryPath(prefix)] = prefix;
      }
    }
    if (paths.isEmpty) return existing;
    final suppressed = await _loadSuppressedFolderPaths(root);
    return _mergeFolderCounts(
      root,
      existing,
      paths.values,
      suppressed,
      countIn,
      checkNewFolders: true,
    );
  }

  Future<List<GalleryCategory>> _mergeFolderCounts(
    String root,
    List<GalleryCategory> existing,
    Iterable<String> paths,
    Set<String> suppressed,
    int Function(String) countIn, {
    bool checkNewFolders = false,
  }) async {
    final byPath = {
      for (final c in existing) _normalizeCategoryPath(c.folderPath): c,
    };
    final blocked = {...suppressed};
    for (final path in paths) {
      final key = _normalizeCategoryPath(path);
      final parentKey = _normalizeCategoryPath(p.dirname(path));
      if (blocked.contains(key) || blocked.contains(parentKey)) {
        blocked.add(key);
        continue;
      }
      final absolute = p.join(root, path);
      final previous = byPath[key];
      if (previous == null &&
          checkNewFolders &&
          !await Directory(absolute).exists()) {
        continue;
      }
      final count = countIn(absolute);
      if (previous != null) {
        if (previous.imageCount != count) {
          byPath[key] = previous.updateImageCount(count);
        }
      } else {
        final parentId = byPath[parentKey]?.id;
        byPath[key] = GalleryCategory.create(
          name: p.basename(path),
          folderPath: path,
          parentId: parentId,
          sortOrder: byPath.values.where((c) => c.parentId == parentId).length,
        ).updateImageCount(count);
      }
    }
    return byPath.values.toList();
  }

  String _sanitizeFolderName(String name) =>
      FileNameSanitizer.segment(name.replaceAll(RegExp(r'\s+'), ' '));

  Future<bool> _isFolderEmpty(String folderPath) async {
    try {
      return await Directory(folderPath).list().isEmpty;
    } catch (_) {
      return true;
    }
  }

  Future<int> _countImagesInFolder(String rootPath, String folderPath) async {
    final files = await _images.list(
      Directory(rootPath),
      folder: Directory(folderPath),
    );
    return files.length;
  }
}
