import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import 'generation_history_storage_service.dart';

/// 图片保存位置变更后，修复设置里仍指向旧目录的图片路径。
///
/// 生成历史与词库缩略图把图片的完整路径存进设置。用户把图库搬到新目录
/// （或在设置里换了保存位置）后，这些路径找不到文件，表现为历史图片
/// 无法加载、词库缩略图消失。只有旧路径的文件已不存在、而按相对位置换算到
/// 当前目录后的文件存在时才改写，不会动仍然有效的路径。
class StoredImagePathRelocator {
  StoredImagePathRelocator({
    required this.currentRoot,
    required Iterable<String> previousRoots,
    bool Function(String path)? fileExists,
    p.Context? pathContext,
  }) : _context = pathContext ?? p.context,
       _fileExists = fileExists ?? ((path) => File(path).existsSync()),
       previousRoots = previousRoots
           .where((root) => root.isNotEmpty)
           .where(
             (root) => !(pathContext ?? p.context).equals(root, currentRoot),
           )
           .toList(growable: false);

  static const _tag = 'ImagePathRelocator';

  final String currentRoot;
  final List<String> previousRoots;
  final p.Context _context;
  final bool Function(String path) _fileExists;

  /// 返回 [storedPath] 现在应当使用的路径；无需或无法换算时原样返回。
  String resolve(String storedPath) {
    if (storedPath.isEmpty || _fileExists(storedPath)) return storedPath;
    for (final root in previousRoots) {
      if (!_context.isWithin(root, storedPath)) continue;
      final candidate = _context.join(
        currentRoot,
        _context.relative(storedPath, from: root),
      );
      if (_fileExists(candidate)) return candidate;
    }
    return storedPath;
  }

  /// 修复生成历史记录里的 `filePath`，返回被改写的条数。
  Future<int> repairHistory(GenerationHistoryStorageService history) {
    return history.remapFilePaths(resolve);
  }

  /// 修复词库条目的缩略图路径，返回被改写的条数。
  Future<int> repairTagLibrary(LocalStorageService storage) async {
    final raw = storage.getTagLibraryEntriesJson();
    if (raw == null || raw.isEmpty) return 0;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return 0;

    var changed = 0;
    final entries = <Object?>[];
    for (final item in decoded) {
      final thumbnail = item is Map ? item['thumbnail'] : null;
      if (thumbnail is String) {
        final resolved = resolve(thumbnail);
        if (resolved != thumbnail) {
          entries.add(<dynamic, dynamic>{
            ...item as Map,
            'thumbnail': resolved,
          });
          changed++;
          continue;
        }
      }
      entries.add(item);
    }
    if (changed > 0) {
      await storage.setTagLibraryEntriesJson(jsonEncode(entries));
    }
    return changed;
  }

  /// 启动时执行：修复历史记录与词库缩略图，失败只记录日志、不阻塞启动。
  static Future<void> repairAll({
    required LocalStorageService storage,
    required String currentRoot,
    required String defaultRoot,
    GenerationHistoryStorageService? history,
  }) async {
    try {
      final relocator = StoredImagePathRelocator(
        currentRoot: currentRoot,
        previousRoots: [...storage.getImageSavePathHistory(), defaultRoot],
      );
      if (relocator.previousRoots.isEmpty) return;

      final historyFixed = await relocator.repairHistory(
        history ?? GenerationHistoryStorageService(),
      );
      final libraryFixed = await relocator.repairTagLibrary(storage);
      if (historyFixed > 0 || libraryFixed > 0) {
        AppLogger.i('已修复图片路径：历史记录 $historyFixed 条，词库缩略图 $libraryFixed 个', _tag);
      }
    } catch (error, stackTrace) {
      AppLogger.e('修复图片路径失败', error, stackTrace, _tag);
    }
  }
}
