import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';

/// 图库保存目录仓库
///
/// 职责是解析图片保存根目录（用户自定义路径优先，否则
/// Documents/NAI_Launcher/images）及目录维度的统计。相册等逻辑组织
/// 由 gallery_album 体系承担；物理目录树的管理入口已随文件夹面板移除。
class GalleryFolderRepository {
  GalleryFolderRepository._();
  static final GalleryFolderRepository instance = GalleryFolderRepository._();

  final _localStorage = LocalStorageService();

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

  /// 获取根目录下的图片总数
  Future<int> getTotalImageCount() async {
    final rootPath = await getRootPath();
    if (rootPath == null || rootPath.isEmpty) return 0;

    int count = 0;
    final rootDir = Directory(rootPath);

    try {
      await for (final entity in rootDir.list(followLinks: false)) {
        if (entity is File &&
            _supportedExtensions.contains(
              p.extension(entity.path).toLowerCase(),
            )) {
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

  Future<int> _countImagesInFolder(String folderPath) async {
    int count = 0;
    try {
      await for (final entity in Directory(
        folderPath,
      ).list(followLinks: false)) {
        if (entity is File &&
            _supportedExtensions.contains(
              p.extension(entity.path).toLowerCase(),
            )) {
          count++;
        }
      }
    } catch (e) {
      AppLogger.w('Failed to get total image count', 'GalleryFolderRepository');
    }
    return count;
  }
}
