import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/storage_keys.dart';
import '../storage/local_storage_service.dart';
import '../utils/app_logger.dart';

/// Vibe库路径管理助手
///
/// 管理Vibe库的保存路径，提供以下功能：
/// - 获取当前路径（自定义或默认）
/// - 设置自定义路径
/// - 获取默认路径（{appDir}/vibes/）
/// - 自动创建默认路径
class VibeLibraryPathHelper {
  VibeLibraryPathHelper._();

  static final VibeLibraryPathHelper instance = VibeLibraryPathHelper._();

  final _localStorage = LocalStorageService();

  /// 默认文件夹名称
  static const String _defaultFolderName = 'vibes';

  /// 缓存的默认路径
  String? _cachedDefaultPath;

  /// 获取Vibe库保存路径
  ///
  /// 优先返回用户自定义路径，如果没有设置则返回默认路径
  /// 默认路径不存在时会自动创建
  Future<String> getPath() async {
    final customPath = getCustomPath();
    if (customPath != null && customPath.isNotEmpty) {
      return customPath;
    }
    return getDefaultPath();
  }

  /// 获取当前路径（同步版本，不保证目录存在）
  ///
  /// 优先返回用户自定义路径，如果没有设置则返回默认路径
  String? getPathSync() {
    final customPath = getCustomPath();
    if (customPath != null && customPath.isNotEmpty) {
      return customPath;
    }
    return _cachedDefaultPath;
  }

  /// 获取用户自定义路径
  String? getCustomPath() {
    return _localStorage.getSetting<String>(StorageKeys.vibeLibrarySavePath);
  }

  /// 获取默认路径
  ///
  /// 默认路径为 {appDir}/vibes/
  Future<String> getDefaultPath() async {
    if (_cachedDefaultPath != null) {
      return _cachedDefaultPath!;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final defaultPath = p.join(appDir.path, _defaultFolderName);
      _cachedDefaultPath = defaultPath;
      return defaultPath;
    } catch (e) {
      AppLogger.e('获取应用目录失败', e);
      // 降级方案：使用临时目录
      final tempDir = Directory.systemTemp;
      final fallbackPath = p.join(tempDir.path, 'nai_launcher', _defaultFolderName);
      _cachedDefaultPath = fallbackPath;
      return fallbackPath;
    }
  }

  /// 设置自定义路径
  ///
  /// [path] 新的路径，如果为null则清除自定义路径
  Future<void> setPath(String? path) async {
    if (path != null && path.isNotEmpty) {
      await _localStorage.setSetting(StorageKeys.vibeLibrarySavePath, path);
      AppLogger.i('Vibe库路径已设置: $path');
    } else {
      await _localStorage.deleteSetting(StorageKeys.vibeLibrarySavePath);
      AppLogger.i('Vibe库路径已重置为默认');
    }
  }

  /// 重置为默认路径
  Future<void> resetToDefault() async {
    await _localStorage.deleteSetting(StorageKeys.vibeLibrarySavePath);
    _cachedDefaultPath = null;
    AppLogger.i('Vibe库路径已重置为默认');
  }

  /// 检查是否使用了自定义路径
  bool get hasCustomPath {
    final customPath = getCustomPath();
    return customPath != null && customPath.isNotEmpty;
  }

  /// 确保路径存在（如果不存在则创建）
  ///
  /// [path] 要检查的路径
  /// 返回是否成功创建或路径已存在
  Future<bool> ensurePathExists(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        AppLogger.i('创建Vibe库目录: $path');
      }
      return true;
    } catch (e) {
      AppLogger.e('创建Vibe库目录失败: $path', e);
      return false;
    }
  }

  /// 获取用于显示的简化路径
  ///
  /// [defaultLabel] 使用默认路径时的显示文本
  String getDisplayPath([String defaultLabel = '默认']) {
    if (hasCustomPath) {
      return getCustomPath()!;
    }
    return defaultLabel;
  }

  /// 清除缓存的默认路径
  ///
  /// 在应用重新启动或需要刷新时调用
  void clearCache() {
    _cachedDefaultPath = null;
  }
}
