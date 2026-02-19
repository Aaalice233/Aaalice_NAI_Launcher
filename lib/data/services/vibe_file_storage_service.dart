import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/utils/app_logger.dart';
import '../../core/utils/vibe_export_utils.dart';
import '../../core/utils/vibe_file_parser.dart';
import '../../core/utils/vibe_library_path_helper.dart';
import '../models/vibe/vibe_library_entry.dart';
import '../models/vibe/vibe_reference.dart';

class VibeFolderSyncResult {
  const VibeFolderSyncResult({
    required this.scannedCount,
    required this.upsertedCount,
    required this.deletedCount,
    required this.failedCount,
    required this.errors,
  });

  final int scannedCount;
  final int upsertedCount;
  final int deletedCount;
  final int failedCount;
  final List<String> errors;
}

/// Vibe 文件系统存储服务
///
/// 负责 vibes 文件夹内的文件读写、重命名、删除以及与 Hive 条目的同步。
class VibeFileStorageService {
  static const String _singleFileExtension = '.naiv4vibe';
  static const String _bundleFileExtension = '.naiv4vibebundle';
  static const String _tag = 'VibeFileStorage';

  /// 保存单个 Vibe 到 .naiv4vibe 文件
  Future<String> saveVibeToFile(
    VibeReference vibe, {
    String? customName,
    String defaultModel = 'nai-diffusion-4-full',
  }) async {
    final directoryPath = await _ensureVibeDirectory();
    final baseName = _normalizeFileBaseName(customName ?? vibe.displayName);
    final fileName = await _generateUniqueFileName(
      directoryPath,
      baseName,
      _singleFileExtension,
    );
    final filePath = p.join(directoryPath, fileName);

    try {
      final jsonString = _buildNaiv4VibeJson(
        vibe,
        displayName: customName ?? vibe.displayName,
        defaultModel: defaultModel,
      );
      await File(filePath).writeAsString(jsonString);
      AppLogger.i('Vibe 文件保存成功: $filePath', _tag);
      return filePath;
    } catch (e, stackTrace) {
      AppLogger.e('保存 Vibe 文件失败: $filePath', e, stackTrace, _tag);
      rethrow;
    }
  }

  /// 保存多个 Vibe 到 .naiv4vibebundle 文件
  Future<String> saveBundleToFile(
    List<VibeReference> vibes, {
    String? bundleName,
  }) async {
    if (vibes.isEmpty) {
      throw ArgumentError('vibes 不能为空');
    }

    final directoryPath = await _ensureVibeDirectory();
    final baseName = _normalizeFileBaseName(bundleName ?? 'vibe-bundle');
    final fileName = await _generateUniqueFileName(
      directoryPath,
      baseName,
      _bundleFileExtension,
    );
    final filePath = p.join(directoryPath, fileName);

    try {
      final jsonString = _buildBundleJson(vibes);
      await File(filePath).writeAsString(jsonString);
      AppLogger.i('Vibe Bundle 保存成功: $filePath', _tag);
      return filePath;
    } catch (e, stackTrace) {
      AppLogger.e('保存 Vibe Bundle 失败: $filePath', e, stackTrace, _tag);
      rethrow;
    }
  }

  /// 从文件读取 Vibe 数据
  ///
  /// 对 bundle 文件返回第一个可用 Vibe。
  Future<VibeReference?> loadVibeFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        AppLogger.w('文件不存在: $filePath', _tag);
        return null;
      }

      final bytes = await file.readAsBytes();
      final fileName = p.basename(filePath);
      final extension = p.extension(fileName).toLowerCase();

      if (extension == _singleFileExtension &&
          !VibeExportUtils.validateNaiv4VibeJson(utf8.decode(bytes))) {
        AppLogger.w('文件格式校验失败: $filePath', _tag);
      }

      final references = await VibeFileParser.parseFile(fileName, bytes);
      if (references.isEmpty) {
        AppLogger.w('未解析到 Vibe 数据: $filePath', _tag);
        return null;
      }

      return references.first;
    } catch (e, stackTrace) {
      AppLogger.e('读取 Vibe 文件失败: $filePath', e, stackTrace, _tag);
      return null;
    }
  }

  /// 删除 Vibe 文件
  Future<bool> deleteVibeFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return true;
      }
      await file.delete();
      AppLogger.i('删除 Vibe 文件成功: $filePath', _tag);
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('删除 Vibe 文件失败: $filePath', e, stackTrace, _tag);
      return false;
    }
  }

  /// 重命名 Vibe 文件（自动处理文件名冲突）
  Future<String?> renameVibeFile(String oldPath, String newName) async {
    try {
      final oldFile = File(oldPath);
      if (!await oldFile.exists()) {
        AppLogger.w('重命名失败，文件不存在: $oldPath', _tag);
        return null;
      }

      final extension = p.extension(oldPath).toLowerCase();
      final targetExtension = extension == _bundleFileExtension
          ? _bundleFileExtension
          : _singleFileExtension;
      final baseName = _normalizeFileBaseName(newName);
      final directoryPath = p.dirname(oldPath);
      final uniqueFileName = await _generateUniqueFileName(
        directoryPath,
        baseName,
        targetExtension,
      );
      final newPath = p.join(directoryPath, uniqueFileName);

      await oldFile.rename(newPath);
      AppLogger.i('重命名 Vibe 文件成功: $oldPath -> $newPath', _tag);
      return newPath;
    } catch (e, stackTrace) {
      AppLogger.e('重命名 Vibe 文件失败: $oldPath', e, stackTrace, _tag);
      return null;
    }
  }

  /// 从 bundle 中提取单个 vibe
  Future<VibeReference?> extractVibeFromBundle(String bundlePath, int index) async {
    try {
      final file = File(bundlePath);
      if (!await file.exists()) {
        AppLogger.w('Bundle 文件不存在: $bundlePath', _tag);
        return null;
      }

      final bytes = await file.readAsBytes();
      final vibes = await VibeFileParser.fromBundle(p.basename(bundlePath), bytes);

      if (index < 0 || index >= vibes.length) {
        AppLogger.w('Bundle 索引越界: $index, length: ${vibes.length}', _tag);
        return null;
      }

      return vibes[index];
    } catch (e, stackTrace) {
      AppLogger.e('从 Bundle 提取 Vibe 失败: $bundlePath', e, stackTrace, _tag);
      return null;
    }
  }

  /// 从 bundle 中提取前 N 个缩略图
  Future<List<Uint8List>> extractPreviewsFromBundle(
    String bundlePath, {
    int maxCount = 4,
  }) async {
    if (maxCount <= 0) return const [];

    try {
      final file = File(bundlePath);
      if (!await file.exists()) {
        AppLogger.w('Bundle 文件不存在: $bundlePath', _tag);
        return const [];
      }

      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final vibes = data['vibes'] as List<dynamic>? ?? const [];
      final previews = <Uint8List>[];

      for (final item in vibes.take(maxCount)) {
        if (item is! Map<String, dynamic>) continue;

        final thumbnail = _decodeBase64Image(item['thumbnail']) ??
            _decodeBase64Image(item['image']);
        if (thumbnail != null) previews.add(thumbnail);
      }

      return previews;
    } catch (e, stackTrace) {
      AppLogger.e('提取 Bundle 缩略图失败: $bundlePath', e, stackTrace, _tag);
      return const [];
    }
  }

  Uint8List? _decodeBase64Image(String? base64String) {
    if (base64String == null || base64String.isEmpty) return null;
    try {
      return base64Decode(base64String);
    } catch (_) {
      return null;
    }
  }

  /// 获取 vibes 文件夹中所有 Vibe 文件
  Future<List<FileSystemEntity>> listVibeFiles() async {
    final directoryPath = await _ensureVibeDirectory();

    try {
      final entities = await Directory(directoryPath).list().toList();
      return entities.where((entity) {
        if (entity is! File) {
          return false;
        }
        final extension = p.extension(entity.path).toLowerCase();
        return extension == _singleFileExtension ||
            extension == _bundleFileExtension;
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.e('列出 Vibe 文件失败: $directoryPath', e, stackTrace, _tag);
      return const [];
    }
  }

  /// 扫描文件夹并与 Hive 条目同步（不直接操作 Hive）
  Future<VibeFolderSyncResult> syncFolderToHive({
    required List<VibeLibraryEntry> existingEntries,
    required Future<void> Function(VibeLibraryEntry entry) onUpsertEntry,
    Future<void> Function(VibeLibraryEntry entry)? onDeleteEntry,
  }) async {
    final errors = <String>[];
    var scannedCount = 0;
    var upsertedCount = 0;
    var deletedCount = 0;
    var failedCount = 0;

    final existingPathMap = <String, VibeLibraryEntry>{
      for (final entry in existingEntries)
        if (entry.filePath != null && entry.filePath!.isNotEmpty)
          _normalizePath(entry.filePath!): entry,
    };

    final currentPathSet = <String>{};
    final files = await listVibeFiles();

    for (final entity in files) {
      if (entity is! File) continue;

      scannedCount++;
      final filePath = entity.path;
      final normalizedPath = _normalizePath(filePath);
      currentPathSet.add(normalizedPath);

      try {
        final existingEntry = existingPathMap[normalizedPath];
        final discovered = await _buildEntryFromFile(filePath, existingEntry);

        if (discovered == null) {
          failedCount++;
          errors.add('解析失败: $filePath');
          continue;
        }

        await onUpsertEntry(discovered);
        upsertedCount++;
      } catch (e, stackTrace) {
        failedCount++;
        errors.add('同步失败: $filePath, error: $e');
        AppLogger.e('同步文件到 Hive 条目失败: $filePath', e, stackTrace, _tag);
      }
    }

    if (onDeleteEntry != null) {
      for (final entry in existingEntries) {
        final filePath = entry.filePath;
        if (filePath == null || filePath.isEmpty) continue;

        final normalizedPath = _normalizePath(filePath);
        if (currentPathSet.contains(normalizedPath)) continue;

        try {
          await onDeleteEntry(entry);
          deletedCount++;
        } catch (e, stackTrace) {
          failedCount++;
          errors.add('删除失效条目失败: $filePath, error: $e');
          AppLogger.e('删除失效条目失败: $filePath', e, stackTrace, _tag);
        }
      }
    }

    return VibeFolderSyncResult(
      scannedCount: scannedCount,
      upsertedCount: upsertedCount,
      deletedCount: deletedCount,
      failedCount: failedCount,
      errors: errors,
    );
  }

  Future<VibeLibraryEntry?> _buildEntryFromFile(
    String filePath,
    VibeLibraryEntry? existingEntry,
  ) async {
    try {
      final extension = p.extension(filePath).toLowerCase();
      final fallbackName = p.basenameWithoutExtension(filePath);

      if (extension == _bundleFileExtension) {
        return await _buildBundleEntryFromFile(filePath, fallbackName, existingEntry);
      }

      final vibe = await loadVibeFromFile(filePath);
      if (vibe == null) return null;

      return _mergeWithExistingEntry(
        generatedEntry: _buildSingleEntry(filePath, fallbackName, vibe),
        existingEntry: existingEntry,
        filePath: filePath,
      );
    } catch (e, stackTrace) {
      AppLogger.e('构建条目失败: $filePath', e, stackTrace, _tag);
      return null;
    }
  }

  Future<VibeLibraryEntry?> _buildBundleEntryFromFile(
    String filePath,
    String fallbackName,
    VibeLibraryEntry? existingEntry,
  ) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final vibes = await VibeFileParser.fromBundle(p.basename(filePath), bytes);
    if (vibes.isEmpty) return null;

    final previews = await extractPreviewsFromBundle(filePath);
    final names = vibes.map((item) => item.displayName).toList(growable: false);
    final generatedEntry = _buildBundleEntry(filePath, fallbackName, vibes);

    return _mergeWithExistingEntry(
      generatedEntry: generatedEntry,
      existingEntry: existingEntry,
      filePath: filePath,
    ).copyWith(
      bundleId: existingEntry?.bundleId ?? p.basenameWithoutExtension(filePath),
      bundledVibeNames: names,
      bundledVibePreviews: previews.isEmpty ? existingEntry?.bundledVibePreviews : previews,
    );
  }

  VibeLibraryEntry _buildBundleEntry(
    String filePath,
    String fileName,
    List<VibeReference> references,
  ) {
    final firstVibe = references.first;

    return VibeLibraryEntry.fromVibeReference(
      name: fileName,
      vibeData: firstVibe,
      thumbnail: firstVibe.thumbnail,
      filePath: filePath,
      isFavorite: false,
    );
  }

  VibeLibraryEntry _buildSingleEntry(
    String filePath,
    String fileName,
    VibeReference reference,
  ) {
    return VibeLibraryEntry.fromVibeReference(
      name: fileName,
      vibeData: reference,
      thumbnail: reference.thumbnail,
      filePath: filePath,
      isFavorite: false,
    );
  }

  VibeLibraryEntry _mergeWithExistingEntry({
    required VibeLibraryEntry generatedEntry,
    required VibeLibraryEntry? existingEntry,
    required String filePath,
  }) {
    if (existingEntry == null) {
      return generatedEntry.copyWith(filePath: filePath);
    }

    // 保留用户设置的元数据，但 name 保持与文件名一致（用户可以通过重命名文件来重命名条目）
    return generatedEntry.copyWith(
      id: existingEntry.id,
      categoryId: existingEntry.categoryId,
      tags: existingEntry.tags,
      isFavorite: existingEntry.isFavorite,
      usedCount: existingEntry.usedCount,
      lastUsedAt: existingEntry.lastUsedAt,
      createdAt: existingEntry.createdAt,
      thumbnail: existingEntry.thumbnail,
      filePath: filePath,
      bundleId: existingEntry.bundleId,
      bundledVibeNames: existingEntry.bundledVibeNames,
      bundledVibePreviews: existingEntry.bundledVibePreviews,
    );
  }

  Future<String> _ensureVibeDirectory() async {
    final path = await VibeLibraryPathHelper.instance.getPath();

    try {
      final directory = Directory(path);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        AppLogger.i('创建 Vibe 文件目录: $path', _tag);
      }
      return path;
    } catch (e, stackTrace) {
      AppLogger.e('创建 Vibe 文件目录失败: $path', e, stackTrace, _tag);
      rethrow;
    }
  }

  Future<String> _generateUniqueFileName(
    String directory,
    String baseName,
    String extension,
  ) async {
    final normalizedBaseName = _normalizeFileBaseName(baseName);
    var candidate = '$normalizedBaseName$extension';
    var counter = 2;

    while (await File(p.join(directory, candidate)).exists()) {
      candidate = '$normalizedBaseName ($counter)$extension';
      counter++;
    }

    return candidate;
  }

  String _normalizePath(String filePath) {
    return p.normalize(filePath).toLowerCase();
  }

  String _normalizeFileBaseName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    if (sanitized.isEmpty) {
      return 'vibe';
    }

    if (sanitized.length > 120) {
      return sanitized.substring(0, 120);
    }

    return sanitized;
  }

  String _buildNaiv4VibeJson(
    VibeReference vibe, {
    required String displayName,
    required String defaultModel,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final idSource = vibe.vibeEncoding.isNotEmpty
        ? vibe.vibeEncoding
        : base64Encode(vibe.rawImageData ?? vibe.thumbnail ?? Uint8List(0));
    final id = base64Url.encode(utf8.encode('$idSource|$timestamp')).substring(0, 32);

    final isRawImage =
        vibe.sourceType == VibeSourceType.rawImage && vibe.rawImageData != null;
    final type = isRawImage ? 'image' : 'encoding';

    final data = <String, dynamic>{
      'identifier': 'novelai-vibe-transfer',
      'version': 1,
      'type': type,
      'id': id,
      'name': displayName,
      'createdAt': timestamp,
      'encodings': type == 'encoding'
          ? {
              defaultModel: {
                'vibe': {
                  'encoding': vibe.vibeEncoding,
                },
              },
            }
          : <String, dynamic>{},
      'importInfo': {
        'model': defaultModel,
        'information_extracted': vibe.infoExtracted,
        'strength': vibe.strength,
      },
    };

    if (isRawImage) {
      data['image'] = base64Encode(vibe.rawImageData!);
    }

    if (vibe.thumbnail != null && vibe.thumbnail!.isNotEmpty) {
      data['thumbnail'] = base64Encode(vibe.thumbnail!);
    }

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  String _buildBundleJson(List<VibeReference> vibes) {
    final entries = vibes.map((vibe) {
      final data = <String, dynamic>{
        'name': vibe.displayName,
        'encodings': vibe.vibeEncoding.isEmpty
            ? <String, dynamic>{}
            : {
                'nai-diffusion-4-full': {
                  'vibe': {
                    'encoding': vibe.vibeEncoding,
                  },
                },
              },
        'importInfo': {
          'strength': vibe.strength,
        },
      };

      if (vibe.thumbnail != null && vibe.thumbnail!.isNotEmpty) {
        data['thumbnail'] = base64Encode(vibe.thumbnail!);
      }

      if (vibe.rawImageData != null && vibe.rawImageData!.isNotEmpty) {
        data['image'] = base64Encode(vibe.rawImageData!);
      }

      return data;
    }).toList(growable: false);

    return const JsonEncoder.withIndent('  ').convert(
      <String, dynamic>{
        'identifier': 'novelai-vibe-transfer-bundle',
        'version': 1,
        'vibes': entries,
      },
    );
  }
}
