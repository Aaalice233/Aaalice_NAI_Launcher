import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// 模型导入失败(超限、IO 错误等)
class Model3dImportException implements Exception {
  final String message;

  const Model3dImportException(this.message);

  @override
  String toString() => 'Model3dImportException: $message';
}

/// 3D 模型库:按 SHA-256 内容寻址存储导入的模型文件
///
/// modelRef 约定:
/// - `builtin:mannequin` 内置程序化人偶(JS 侧生成,不占库文件)
/// - `lib:<sha256>`      库目录下 `<sha256>.glb`
class Model3dLibraryService {
  Model3dLibraryService({
    required this.libraryDir,
    this.maxFileBytes = 200 * 1024 * 1024,
  });

  static const builtinMannequinRef = 'builtin:mannequin';
  static const _libPrefix = 'lib:';

  final Directory libraryDir;
  final int maxFileBytes;

  /// 导入模型:校验大小 → 流式 SHA-256 → 拷贝(已存在则去重跳过)
  Future<String> importModel(File source) async {
    final length = await source.length();
    if (length > maxFileBytes) {
      throw Model3dImportException(
        'file too large: $length > $maxFileBytes bytes',
      );
    }
    final digest = await sha256.bind(source.openRead()).first;
    final hash = digest.toString();
    final target = File(p.join(libraryDir.path, '$hash.glb'));
    if (!await target.exists()) {
      await libraryDir.create(recursive: true);
      await source.copy(target.path);
    }
    return '$_libPrefix$hash';
  }

  /// modelRef → 本地服务 URL 路径(builtin 与未知前缀返回 null)
  String? urlPathFor(String modelRef) {
    if (!modelRef.startsWith(_libPrefix)) return null;
    return '/models/${modelRef.substring(_libPrefix.length)}.glb';
  }

  /// modelRef → 库文件(不检查存在性;builtin 与未知前缀返回 null)
  File? resolveFile(String modelRef) {
    if (!modelRef.startsWith(_libPrefix)) return null;
    return File(
      p.join(libraryDir.path, '${modelRef.substring(_libPrefix.length)}.glb'),
    );
  }
}
