import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/storage/local_storage_service.dart';

/// 图库保存目录仓库
///
/// 职责是解析图片保存根目录（用户自定义路径优先，否则
/// Documents/NAI_Launcher/images）。相册等逻辑组织
/// 由 gallery_album 体系承担；物理目录树的管理入口已随文件夹面板移除。
class GalleryFolderRepository {
  GalleryFolderRepository._();
  static final GalleryFolderRepository instance = GalleryFolderRepository._();

  final _localStorage = LocalStorageService();

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
}
