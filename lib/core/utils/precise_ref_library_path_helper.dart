import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_logger.dart';
import 'file_system_utils.dart';

/// 精准参考库路径管理助手
///
/// 管理精准参考库原图文件的保存目录（{Documents}/NAI_Launcher/precise_refs/）。
/// MVP 不支持自定义路径；新功能无历史数据，也不需要旧位置迁移。
class PreciseRefLibraryPathHelper {
  PreciseRefLibraryPathHelper._();

  static final PreciseRefLibraryPathHelper instance =
      PreciseRefLibraryPathHelper._();

  static const String _defaultFolderName = 'precise_refs';
  static const String _tag = 'PreciseRefLibrary';

  String? _cachedDefaultPath;

  /// 获取默认保存路径（{Documents}/NAI_Launcher/precise_refs/）
  Future<String> getDefaultPath() async {
    if (_cachedDefaultPath != null) {
      return _cachedDefaultPath!;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final defaultPath = p.join(
        appDir.path,
        'NAI_Launcher',
        _defaultFolderName,
      );
      _cachedDefaultPath = defaultPath;
      return defaultPath;
    } catch (e) {
      AppLogger.e('获取应用目录失败', e);
      final tempDir = Directory.systemTemp;
      final fallbackPath = p.join(
        tempDir.path,
        'nai_launcher',
        _defaultFolderName,
      );
      _cachedDefaultPath = fallbackPath;
      return fallbackPath;
    }
  }

  /// 确保路径存在（如果不存在则创建）
  Future<bool> ensurePathExists(String path) async {
    return FileSystemUtils.ensureDirectory(path, logTag: _tag);
  }

  /// 清除缓存的默认路径（测试或刷新时使用）
  void clearCache() {
    _cachedDefaultPath = null;
  }
}
