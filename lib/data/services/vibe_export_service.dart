import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/vibe_image_embedder.dart';
import '../models/vibe/vibe_export_format.dart';
import '../models/vibe/vibe_library_entry.dart';

part 'vibe_export_service.g.dart';

/// Vibe 导出进度回调
typedef ExportProgressCallback = void Function({
  required int current,
  required int total,
  required String currentItem,
});

/// Vibe 导出服务
///
/// 负责将 Vibe 库条目导出为不同格式
class VibeExportService {
  static const String _tag = 'VibeExport';

  /// 导出为 Bundle 格式
  ///
  /// [entries] - 要导出的条目列表
  /// [options] - 导出选项
  /// [onProgress] - 进度回调
  Future<String?> exportAsBundle(
    List<VibeLibraryEntry> entries, {
    required VibeExportOptions options,
    ExportProgressCallback? onProgress,
  }) async {
    if (entries.isEmpty) {
      AppLogger.w('Cannot export empty entries to bundle', _tag);
      return null;
    }

    final stopwatch = Stopwatch()..start();

    try {
      final outputDir = await _getExportDirectory();
      final fileName = _generateFileName(
        options.fileName,
        'vibe-bundle',
        kNaiv4vibebundleExtension,
      );
      final filePath = p.join(outputDir, fileName);

      AppLogger.i(
        'Starting bundle export: ${entries.length} entries to $filePath',
        _tag,
      );

      final bundleData = await _buildBundleData(
        entries,
        options,
        onProgress,
      );

      final file = File(filePath);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(bundleData),
      );

      stopwatch.stop();
      AppLogger.i(
        'Bundle export completed: ${entries.length} entries in ${stopwatch.elapsedMilliseconds}ms',
        _tag,
      );

      return filePath;
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.e('Bundle export failed', e, stackTrace, _tag);
      return null;
    }
  }

  /// 导出为嵌入图片格式
  ///
  /// [entry] - 要导出的条目
  /// [options] - 导出选项
  /// [imageData] - 可选的图片数据，如果不提供则从 entry 或 targetImagePath 获取
  Future<String?> exportAsEmbeddedImage(
    VibeLibraryEntry entry, {
    required VibeExportOptions options,
    Uint8List? imageData,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // 获取图片数据
      final rawImageData = imageData ?? await _getImageData(entry, options);
      if (rawImageData == null || rawImageData.isEmpty) {
        AppLogger.w(
          'No image data available for embedded export: ${entry.displayName}',
          _tag,
        );
        return null;
      }

      // 验证图片格式
      if (!_isValidPng(rawImageData)) {
        AppLogger.w(
          'Invalid PNG data for embedded export: ${entry.displayName}',
          _tag,
        );
        return null;
      }

      // 创建 VibeReference
      final vibeReference = entry.toVibeReference();

      // 检查是否有编码数据
      if (vibeReference.vibeEncoding.isEmpty) {
        AppLogger.w(
          'No vibe encoding available for embedded export: ${entry.displayName}',
          _tag,
        );
        return null;
      }

      AppLogger.i(
        'Starting embedded image export: ${entry.displayName}',
        _tag,
      );

      // 嵌入 Vibe 数据到图片
      final embeddedImageData = await VibeImageEmbedder.embedVibeToImage(
        rawImageData,
        vibeReference,
      );

      // 保存文件
      final outputDir = await _getExportDirectory();
      final fileName = _generateFileName(
        options.fileName,
        '${entry.displayName}_vibe',
        'png',
      );
      final filePath = p.join(outputDir, fileName);

      final file = File(filePath);
      await file.writeAsBytes(embeddedImageData);

      stopwatch.stop();
      AppLogger.i(
        'Embedded image export completed: $filePath in ${stopwatch.elapsedMilliseconds}ms',
        _tag,
      );

      return filePath;
    } on InvalidImageFormatException catch (e) {
      stopwatch.stop();
      AppLogger.e(
        'Invalid image format for embedded export: ${entry.displayName}',
        e,
        null,
        _tag,
      );
      return null;
    } on VibeEmbedException catch (e) {
      stopwatch.stop();
      AppLogger.e(
        'Vibe embed failed for: ${entry.displayName}',
        e,
        null,
        _tag,
      );
      return null;
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.e(
        'Embedded image export failed: ${entry.displayName}',
        e,
        stackTrace,
        _tag,
      );
      return null;
    }
  }

  /// 导出为纯编码格式
  ///
  /// [entries] - 要导出的条目列表
  /// [options] - 导出选项
  /// [onProgress] - 进度回调
  Future<String?> exportAsEncoding(
    List<VibeLibraryEntry> entries, {
    required VibeExportOptions options,
    ExportProgressCallback? onProgress,
  }) async {
    if (entries.isEmpty) {
      AppLogger.w('Cannot export empty entries to encoding list', _tag);
      return null;
    }

    final stopwatch = Stopwatch()..start();

    try {
      final outputDir = await _getExportDirectory();
      final fileName = _generateFileName(
        options.fileName,
        'vibe-encodings',
        'txt',
      );
      final filePath = p.join(outputDir, fileName);

      AppLogger.i(
        'Starting encoding export: ${entries.length} entries to $filePath',
        _tag,
      );

      final encodingList = <String>[];

      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];

        onProgress?.call(
          current: i,
          total: entries.length,
          currentItem: entry.displayName,
        );

        // 只导出具有有效编码的条目
        if (entry.vibeEncoding.isNotEmpty) {
          encodingList.add(entry.vibeEncoding);
          AppLogger.d(
            'Added encoding for: ${entry.displayName} (${i + 1}/${entries.length})',
            _tag,
          );
        } else {
          AppLogger.w(
            'Skipping entry without encoding: ${entry.displayName}',
            _tag,
          );
        }
      }

      if (encodingList.isEmpty) {
        AppLogger.w('No valid encodings to export', _tag);
        return null;
      }

      final file = File(filePath);
      await file.writeAsString(encodingList.join('\n'));

      onProgress?.call(
        current: entries.length,
        total: entries.length,
        currentItem: '',
      );

      stopwatch.stop();
      AppLogger.i(
        'Encoding export completed: ${encodingList.length} encodings in ${stopwatch.elapsedMilliseconds}ms',
        _tag,
      );

      return filePath;
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.e('Encoding export failed', e, stackTrace, _tag);
      return null;
    }
  }

  /// 构建 Bundle 数据
  Future<Map<String, dynamic>> _buildBundleData(
    List<VibeLibraryEntry> entries,
    VibeExportOptions options,
    ExportProgressCallback? onProgress,
  ) async {
    final vibeEntries = <Map<String, dynamic>>[];

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];

      onProgress?.call(
        current: i,
        total: entries.length,
        currentItem: entry.displayName,
      );

      final entryData = <String, dynamic>{
        'name': entry.displayName,
      };

      // 添加编码数据（如果启用）
      if (options.includeEncoding && entry.vibeEncoding.isNotEmpty) {
        entryData['encodings'] = {
          'nai-diffusion-4-full': {
            'vibe': {
              'encoding': entry.vibeEncoding,
            },
          },
        };
      }

      // 添加导入信息
      entryData['importInfo'] = {
        'strength': entry.strength,
        'information_extracted': entry.infoExtracted,
      };

      // 添加缩略图（如果启用且存在）
      if (options.includeThumbnail && entry.hasVibeThumbnail) {
        entryData['thumbnail'] = base64Encode(entry.vibeThumbnail!);
      }

      // 添加原始图片数据（如果存在）
      if (entry.rawImageData != null && entry.rawImageData!.isNotEmpty) {
        entryData['image'] = base64Encode(entry.rawImageData!);
      }

      vibeEntries.add(entryData);

      AppLogger.d(
        'Added to bundle: ${entry.displayName} (${i + 1}/${entries.length})',
        _tag,
      );
    }

    return {
      'identifier': 'novelai-vibe-transfer-bundle',
      'version': options.version,
      'exportedAt': DateTime.now().toIso8601String(),
      'entryCount': entries.length,
      'vibes': vibeEntries,
    };
  }

  /// 获取导出目录
  Future<String> _getExportDirectory() async {
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        return downloadsDir.path;
      }
    } catch (e) {
      AppLogger.w('Failed to get downloads directory: $e', _tag);
    }

    // 降级到应用文档目录
    final appDir = await getApplicationDocumentsDirectory();
    return appDir.path;
  }

  /// 生成文件名
  String _generateFileName(
    String? customName,
    String defaultBaseName,
    String extension,
  ) {
    final timestamp = DateTime.now();
    final formattedTime =
        '${timestamp.year}${_twoDigits(timestamp.month)}${_twoDigits(timestamp.day)}_'
        '${_twoDigits(timestamp.hour)}${_twoDigits(timestamp.minute)}${_twoDigits(timestamp.second)}';

    final baseName = customName?.trim().isNotEmpty == true
        ? customName!.trim()
        : '${defaultBaseName}_$formattedTime';

    // 清理文件名中的非法字符
    final sanitizedBaseName = _sanitizeFileName(baseName);

    return '$sanitizedBaseName.$extension';
  }

  /// 清理文件名中的非法字符
  String _sanitizeFileName(String fileName) {
    // 移除或替换 Windows/Unix 文件系统中的非法字符
    return fileName
        .replaceAll(RegExp(r'[<>:"/\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 将数字格式化为两位字符串
  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// 获取图片数据
  ///
  /// 按优先级尝试获取图片数据:
  /// 1. entry.rawImageData
  /// 2. 从 entry.filePath 读取
  /// 3. 从 options.targetImagePath 读取
  Future<Uint8List?> _getImageData(
    VibeLibraryEntry entry,
    VibeExportOptions options,
  ) async {
    // 优先使用 entry 中存储的原始图片数据
    if (entry.rawImageData != null && entry.rawImageData!.isNotEmpty) {
      AppLogger.d('Using rawImageData from entry: ${entry.displayName}', _tag);
      return entry.rawImageData;
    }

    // 其次尝试从 entry 的 filePath 读取
    if (entry.filePath != null && entry.filePath!.isNotEmpty) {
      try {
        final file = File(entry.filePath!);
        if (await file.exists()) {
          AppLogger.d(
            'Reading image from entry filePath: ${entry.filePath}',
            _tag,
          );
          return await file.readAsBytes();
        }
      } catch (e) {
        AppLogger.w(
          'Failed to read image from entry filePath: ${entry.filePath}',
          _tag,
        );
      }
    }

    // 最后尝试从 options.targetImagePath 读取
    if (options.targetImagePath != null && options.targetImagePath!.isNotEmpty) {
      try {
        final file = File(options.targetImagePath!);
        if (await file.exists()) {
          AppLogger.d(
            'Reading image from targetImagePath: ${options.targetImagePath}',
            _tag,
          );
          return await file.readAsBytes();
        }
      } catch (e) {
        AppLogger.w(
          'Failed to read image from targetImagePath: ${options.targetImagePath}',
          _tag,
        );
      }
    }

    return null;
  }

  /// 验证数据是否为有效的 PNG 图片
  bool _isValidPng(Uint8List data) {
    if (data.length < 8) {
      return false;
    }

    // PNG 文件签名: 89 50 4E 47 0D 0A 1A 0A
    const pngSignature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

    for (var i = 0; i < pngSignature.length; i++) {
      if (data[i] != pngSignature[i]) {
        return false;
      }
    }

    return true;
  }

  /// 导出为原始图片格式（不含 Vibe 元数据）
  ///
  /// [entry] - 要导出的条目
  /// [options] - 导出选项
  Future<String?> exportAsRawImage(
    VibeLibraryEntry entry, {
    required VibeExportOptions options,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // 获取图片数据
      final imageData = await _getImageData(
        entry,
        options.copyWith(targetImagePath: options.targetImagePath),
      );

      if (imageData == null || imageData.isEmpty) {
        AppLogger.w(
          'No image data available for raw export: ${entry.displayName}',
          _tag,
        );
        return null;
      }

      // 检测图片格式
      final extension = _detectImageFormat(imageData);

      AppLogger.i(
        'Starting raw image export: ${entry.displayName} ($extension)',
        _tag,
      );

      // 保存文件
      final outputDir = await _getExportDirectory();
      final fileName = _generateFileName(
        options.fileName,
        '${entry.displayName}_raw',
        extension,
      );
      final filePath = p.join(outputDir, fileName);

      final file = File(filePath);
      await file.writeAsBytes(imageData);

      stopwatch.stop();
      AppLogger.i(
        'Raw image export completed: $filePath in ${stopwatch.elapsedMilliseconds}ms',
        _tag,
      );

      return filePath;
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.e(
        'Raw image export failed: ${entry.displayName}',
        e,
        stackTrace,
        _tag,
      );
      return null;
    }
  }

  /// 检测图片格式并返回扩展名
  String _detectImageFormat(Uint8List data) {
    if (data.length < 8) {
      return 'bin';
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (data[0] == 0x89 &&
        data[1] == 0x50 &&
        data[2] == 0x4E &&
        data[3] == 0x47) {
      return 'png';
    }

    // JPEG: FF D8 FF
    if (data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) {
      return 'jpg';
    }

    // GIF: GIF87a or GIF89a
    if (data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46) {
      return 'gif';
    }

    // WebP: RIFF....WEBP
    if (data[0] == 0x52 &&
        data[1] == 0x49 &&
        data[2] == 0x46 &&
        data[3] == 0x46 &&
        data[8] == 0x57 &&
        data[9] == 0x45 &&
        data[10] == 0x42 &&
        data[11] == 0x50) {
      return 'webp';
    }

    // BMP: BM
    if (data[0] == 0x42 && data[1] == 0x4D) {
      return 'bmp';
    }

    return 'bin';
  }

  /// 批量导出为 Bundle 格式（包含完整图片数据）
  ///
  /// 与 exportAsBundle 不同，此方法会确保所有原始图片数据都被包含在导出中
  Future<String?> exportAsFullBundle(
    List<VibeLibraryEntry> entries, {
    required VibeExportOptions options,
    ExportProgressCallback? onProgress,
  }) async {
    if (entries.isEmpty) {
      AppLogger.w('Cannot export empty entries to full bundle', _tag);
      return null;
    }

    final stopwatch = Stopwatch()..start();

    try {
      final outputDir = await _getExportDirectory();
      final fileName = _generateFileName(
        options.fileName,
        'vibe-full-bundle',
        kNaiv4vibebundleExtension,
      );
      final filePath = p.join(outputDir, fileName);

      AppLogger.i(
        'Starting full bundle export: ${entries.length} entries to $filePath',
        _tag,
      );

      final bundleData = await _buildFullBundleData(
        entries,
        options,
        onProgress,
      );

      if (bundleData == null) {
        AppLogger.w('No valid data to export to full bundle', _tag);
        return null;
      }

      final file = File(filePath);

      // 根据选项决定是否压缩
      if (options.compress) {
        AppLogger.w('Compression not yet implemented, exporting uncompressed', _tag);
      }

      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(bundleData),
      );

      stopwatch.stop();
      AppLogger.i(
        'Full bundle export completed: ${entries.length} entries in ${stopwatch.elapsedMilliseconds}ms',
        _tag,
      );

      return filePath;
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.e('Full bundle export failed', e, stackTrace, _tag);
      return null;
    }
  }

  /// 构建完整 Bundle 数据（包含所有图片数据）
  Future<Map<String, dynamic>?> _buildFullBundleData(
    List<VibeLibraryEntry> entries,
    VibeExportOptions options,
    ExportProgressCallback? onProgress,
  ) async {
    final vibeEntries = <Map<String, dynamic>>[];
    var validEntryCount = 0;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];

      onProgress?.call(
        current: i,
        total: entries.length,
        currentItem: entry.displayName,
      );

      try {
        final entryData = await _buildFullEntryData(entry, options);
        if (entryData != null) {
          vibeEntries.add(entryData);
          validEntryCount++;

          AppLogger.d(
            'Added full data to bundle: ${entry.displayName} (${i + 1}/${entries.length})',
            _tag,
          );
        } else {
          AppLogger.w(
            'Skipped entry with no exportable data: ${entry.displayName}',
            _tag,
          );
        }
      } catch (e) {
        AppLogger.w(
          'Failed to process entry for bundle: ${entry.displayName}, error: $e',
          _tag,
        );
      }
    }

    if (vibeEntries.isEmpty) {
      return null;
    }

    return {
      'identifier': 'novelai-vibe-transfer-full-bundle',
      'version': options.version,
      'exportedAt': DateTime.now().toIso8601String(),
      'entryCount': validEntryCount,
      'vibes': vibeEntries,
      'includesImages': options.includeImages,
    };
  }

  /// 构建单个条目的完整数据
  Future<Map<String, dynamic>?> _buildFullEntryData(
    VibeLibraryEntry entry,
    VibeExportOptions options,
  ) async {
    // 检查是否有有效编码或图片数据
    final hasEncoding = entry.vibeEncoding.isNotEmpty;
    final hasImageData = entry.rawImageData != null && entry.rawImageData!.isNotEmpty;
    final hasFilePath = entry.filePath != null && entry.filePath!.isNotEmpty;

    if (!hasEncoding && !hasImageData && !hasFilePath) {
      return null;
    }

    final entryData = <String, dynamic>{
      'name': entry.displayName,
      'id': entry.id,
      'createdAt': entry.createdAt.toIso8601String(),
    };

    // 添加编码数据（如果启用且有编码）
    if (options.includeEncoding && hasEncoding) {
      entryData['encodings'] = {
        'nai-diffusion-4-full': {
          'vibe': {
            'encoding': entry.vibeEncoding,
          },
        },
      };
    }

    // 添加导入信息
    entryData['importInfo'] = {
      'strength': entry.strength,
      'information_extracted': entry.infoExtracted,
      'sourceType': entry.sourceType.name,
    };

    // 添加元数据
    entryData['metadata'] = {
      'vibeDisplayName': entry.vibeDisplayName,
      'tags': entry.tags,
      'isFavorite': entry.isFavorite,
      'usedCount': entry.usedCount,
      'categoryId': entry.categoryId,
    };

    // 添加缩略图（如果启用且存在）
    if (options.includeThumbnail) {
      if (entry.hasVibeThumbnail) {
        entryData['thumbnail'] = base64Encode(entry.vibeThumbnail!);
      } else if (entry.hasThumbnail) {
        entryData['thumbnail'] = base64Encode(entry.thumbnail!);
      }
    }

    // 添加完整图片数据（仅当启用 includeImages 时）
    if (options.includeImages) {
      Uint8List? imageDataToInclude;
      if (hasImageData) {
        imageDataToInclude = entry.rawImageData;
        AppLogger.d(
          'Using rawImageData for full export: ${entry.displayName}',
          _tag,
        );
      } else if (hasFilePath) {
        try {
          final file = File(entry.filePath!);
          if (await file.exists()) {
            imageDataToInclude = await file.readAsBytes();
            AppLogger.d(
              'Reading image from file for full export: ${entry.filePath}',
              _tag,
            );
          }
        } catch (e) {
          AppLogger.w(
            'Failed to read image for bundle: ${entry.filePath}',
            _tag,
          );
        }
      }

      if (imageDataToInclude != null && imageDataToInclude.isNotEmpty) {
        entryData['image'] = base64Encode(imageDataToInclude);
        entryData['imageFormat'] = _detectImageFormat(imageDataToInclude);
        AppLogger.d(
          'Added full image to export: ${entry.displayName} (${imageDataToInclude.length} bytes)',
          _tag,
        );
      }
    }

    return entryData;
  }
}

/// VibeExportService Provider
@riverpod
VibeExportService vibeExportService(Ref ref) {
  return VibeExportService();
}
