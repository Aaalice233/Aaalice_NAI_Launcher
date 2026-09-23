import 'dart:io';

import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/gallery_folder_repository.dart';

const String _logTag = 'AgentChat';

/// 当前图片导出根目录，用作文件工具的 cwd 与相对路径根。
Future<Directory?> resolveCurrentImageProjectDirectory() async {
  final currentRoot = await GalleryFolderRepository.instance.getRootPath();
  if (currentRoot == null || currentRoot.isEmpty) return null;
  return Directory(currentRoot);
}

/// 解析文件工具工作区：优先图片导出根目录，让 Agent 能按相对路径读取生成的图片；
/// 解析失败时回退到应用支持目录下的 `agent/workspace`。
Future<Directory> resolveAgentWorkspaceDirectory(
  Directory supportDir, {
  Directory? preferred,
  Future<Directory?> Function()? imageProjectDirectory,
}) async {
  var workspace = preferred;
  if (workspace == null) {
    try {
      workspace =
          await (imageProjectDirectory ?? resolveCurrentImageProjectDirectory)
              .call();
    } catch (e) {
      AppLogger.w('resolve image export dir failed: $e', _logTag);
    }
  }
  final resolved =
      workspace ??
      Directory(
        '${supportDir.path}${Platform.pathSeparator}agent'
        '${Platform.pathSeparator}workspace',
      );
  try {
    await resolved.create(recursive: true);
  } catch (e) {
    AppLogger.w('agent workspace create failed: $e', _logTag);
  }
  return resolved;
}
