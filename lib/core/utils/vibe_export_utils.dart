import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../data/models/vibe/vibe_library_entry.dart';
import '../../data/models/vibe/vibe_reference.dart';
import 'app_logger.dart';
import 'file_name_sanitizer.dart';
import 'vibe_image_embedder.dart';

class VibeEmbeddedPngExportPlan {
  const VibeEmbeddedPngExportPlan({
    required this.entryId,
    required this.displayName,
    required this.vibes,
    required this.carrierImageBytes,
    required this.fileName,
  });

  final String entryId;
  final String displayName;
  final List<VibeReference> vibes;
  final Uint8List carrierImageBytes;
  final String fileName;
}

/// Vibe 导出工具类
///
/// 用于将 VibeReference 导出为 .naiv4vibe 格式文件
class VibeExportUtils {
  static const String _identifier = 'novelai-vibe-transfer';
  static const int _version = 1;
  static const String _rawImageCandidateId = 'raw_image';
  static const String _vibeThumbnailCandidateId = 'vibe_thumbnail';
  static const String _thumbnailCandidateId = 'thumbnail';

  /// 收集条目可用的 PNG 导出载体图
  static List<VibeExportImageCandidate> collectImageCandidates(
    VibeLibraryEntry entry,
  ) {
    final candidates = <VibeExportImageCandidate>[];
    final seenHashes = <String>{};

    void addCandidate(String id, String label, Uint8List? bytes) {
      if (bytes == null || bytes.isEmpty) {
        return;
      }
      final hash = sha256.convert(bytes).toString();
      if (!seenHashes.add(hash)) {
        return;
      }
      candidates.add(
        VibeExportImageCandidate(id: id, label: label, bytes: bytes),
      );
    }

    addCandidate(_rawImageCandidateId, '原始图片', entry.rawImageData);
    addCandidate(_vibeThumbnailCandidateId, 'Vibe 预览图', entry.vibeThumbnail);
    addCandidate(_thumbnailCandidateId, '库缩略图', entry.thumbnail);

    return candidates;
  }

  /// 为单个条目选择默认 PNG 导出载体图
  static VibeExportImageCandidate? selectDefaultImageCandidate(
    VibeLibraryEntry entry,
  ) {
    final candidates = collectImageCandidates(entry);
    if (candidates.isEmpty) {
      return null;
    }
    return candidates.first;
  }

  /// 生成批量 PNG 导出计划
  static List<VibeEmbeddedPngExportPlan> buildEmbeddedPngExportPlans(
    List<VibeLibraryEntry> entries,
  ) {
    final plans = <VibeEmbeddedPngExportPlan>[];

    for (final entry in entries) {
      final candidate = selectDefaultImageCandidate(entry);
      if (candidate == null) {
        continue;
      }
      plans.add(
        VibeEmbeddedPngExportPlan(
          entryId: entry.id,
          displayName: entry.displayName,
          vibes: [entry.toVibeReference()],
          carrierImageBytes: candidate.bytes,
          fileName: _generateEmbeddedPngFileName(entry.displayName),
        ),
      );
    }

    return plans;
  }

  /// 使用给定载体图构建带 Vibe 元数据的 PNG
  static Future<Uint8List> buildEmbeddedPngBytes({
    required List<VibeReference> vibes,
    required Uint8List carrierImageBytes,
  }) async {
    return VibeImageEmbedder.embedVibesToImage(carrierImageBytes, vibes);
  }

  /// 导出带 Vibe 元数据的 PNG
  static Future<String?> exportToEmbeddedPng(
    List<VibeReference> vibes, {
    required Uint8List carrierImageBytes,
    required String fileName,
  }) async {
    try {
      if (vibes.isEmpty) {
        AppLogger.e('无法导出 PNG：Vibe 列表为空', null, null, 'VibeExport');
        return null;
      }

      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '导出 PNG Vibe 图片',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['png'],
      );

      if (outputFile == null) {
        AppLogger.i('用户取消了 PNG 保存', 'VibeExport');
        return null;
      }

      final embeddedBytes = await buildEmbeddedPngBytes(
        vibes: vibes,
        carrierImageBytes: carrierImageBytes,
      );
      await File(outputFile).writeAsBytes(embeddedBytes);

      AppLogger.i('PNG Vibe 导出成功: $outputFile', 'VibeExport');
      return outputFile;
    } catch (e, stack) {
      AppLogger.e('导出 PNG Vibe 文件失败', e, stack, 'VibeExport');
      return null;
    }
  }

  /// 批量导出多个条目为各自独立的 PNG
  static Future<List<String>> exportEntriesToEmbeddedPngDirectory(
    List<VibeLibraryEntry> entries,
  ) async {
    final plans = buildEmbeddedPngExportPlans(entries);
    if (plans.isEmpty) {
      AppLogger.e('无法导出 PNG：没有任何 Vibe 拥有可用图片', null, null, 'VibeExport');
      return const [];
    }

    final outputDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择 PNG 导出目录',
    );
    if (outputDirectory == null || outputDirectory.isEmpty) {
      AppLogger.i('用户取消了 PNG 批量导出目录选择', 'VibeExport');
      return const [];
    }

    final exportedPaths = <String>[];
    for (final plan in plans) {
      final embeddedBytes = await buildEmbeddedPngBytes(
        vibes: plan.vibes,
        carrierImageBytes: plan.carrierImageBytes,
      );
      final outputPath = p.join(outputDirectory, plan.fileName);
      await File(outputPath).writeAsBytes(embeddedBytes);
      exportedPaths.add(outputPath);
    }

    AppLogger.i('批量 PNG Vibe 导出成功: ${exportedPaths.length} 个文件', 'VibeExport');
    return exportedPaths;
  }

  /// 导出 VibeReference 为 .naiv4vibe 文件
  ///
  /// [vibe] 要导出的 Vibe 参考对象
  /// [name] 显示名称（可选，默认使用 vibe.displayName）
  /// [defaultModel] 默认模型名称（可选，默认 'nai-diffusion-4-full'）
  ///
  /// 返回：导出成功返回文件路径，失败返回 null
  static Future<String?> exportToNaiv4Vibe(
    VibeReference vibe, {
    String? name,
    String defaultModel = 'nai-diffusion-4-full',
    String? outputDirectory,
  }) async {
    try {
      // 检查是否有可导出的数据
      if (!_hasExportableData(vibe)) {
        AppLogger.e('无法导出：Vibe 没有编码数据或原始图片', null, null, 'VibeExport');
        return null;
      }

      final fileName = _generateFileName(name ?? vibe.displayName);
      final outputFile = await _resolveOutputFilePath(
        outputDirectory: outputDirectory,
        fileName: fileName,
        dialogTitle: '导出 Vibe 文件',
        allowedExtensions: const ['naiv4vibe'],
      );

      if (outputFile == null) {
        AppLogger.i('用户取消了文件保存', 'VibeExport');
        return null;
      }

      // 生成 .naiv4vibe JSON 数据
      final jsonData = await _generateNaiv4VibeJson(
        vibe,
        name: name,
        defaultModel: defaultModel,
      );

      // 写入文件
      final file = File(outputFile);
      await file.writeAsString(jsonData);

      AppLogger.i('Vibe 导出成功: $outputFile', 'VibeExport');
      return outputFile;
    } catch (e, stack) {
      AppLogger.e('导出 Vibe 文件失败', e, stack, 'VibeExport');
      return null;
    }
  }

  /// 批量导出多个 Vibe 为 .naiv4vibebundle 文件
  ///
  /// [vibes] 要导出的 Vibe 参考列表
  /// [bundleName] 包名称
  ///
  /// 返回：导出成功返回文件路径，失败返回 null
  static Future<String?> exportToNaiv4VibeBundle(
    List<VibeReference> vibes,
    String bundleName, {
    String? outputDirectory,
  }) async {
    try {
      if (vibes.isEmpty) {
        AppLogger.e('无法导出：Vibe 列表为空', null, null, 'VibeExport');
        return null;
      }

      final fileName = _generateBundleFileName(bundleName);
      final outputFile = await _resolveOutputFilePath(
        outputDirectory: outputDirectory,
        fileName: fileName,
        dialogTitle: '导出 Vibe Bundle',
        allowedExtensions: const ['naiv4vibebundle'],
      );

      if (outputFile == null) {
        AppLogger.i('用户取消了文件保存', 'VibeExport');
        return null;
      }

      // 生成 bundle JSON 数据
      final bundleData = await _generateBundleJson(vibes);

      // 写入文件
      final file = File(outputFile);
      await file.writeAsString(bundleData);

      AppLogger.i('Vibe Bundle 导出成功: $outputFile', 'VibeExport');
      return outputFile;
    } catch (e, stack) {
      AppLogger.e('导出 Vibe Bundle 失败', e, stack, 'VibeExport');
      return null;
    }
  }

  /// 导出多个库条目为一个 ZIP 包。
  ///
  /// ZIP 内部会尽量保持“一个库条目一个文件”的直观结构：
  /// - 普通 Vibe 条目导出为 `.naiv4vibe`
  /// - Bundle 条目导出为 `.naiv4vibebundle`
  static Future<String?> exportEntriesToZip(
    List<VibeLibraryEntry> entries, {
    String? name,
    bool includeThumbnails = true,
    bool compress = true,
  }) async {
    try {
      if (entries.isEmpty) {
        AppLogger.e('无法导出 ZIP：Vibe 列表为空', null, null, 'VibeExport');
        return null;
      }

      final fileName = _generateZipFileName(name ?? 'vibe_library_export');
      final outputFile = await _resolveOutputFilePath(
        outputDirectory: null,
        fileName: fileName,
        dialogTitle: '导出 Vibe ZIP',
        allowedExtensions: const ['zip'],
      );

      if (outputFile == null) {
        AppLogger.i('用户取消了 ZIP 保存', 'VibeExport');
        return null;
      }

      final zipBytes = await buildVibeZipArchiveBytes(
        entries,
        includeThumbnails: includeThumbnails,
        compress: compress,
      );
      await File(outputFile).writeAsBytes(zipBytes);

      AppLogger.i('Vibe ZIP 导出成功: $outputFile', 'VibeExport');
      return outputFile;
    } catch (e, stack) {
      AppLogger.e('导出 Vibe ZIP 失败', e, stack, 'VibeExport');
      return null;
    }
  }

  /// 构建 Vibe ZIP 字节，用于 UI 导出和单元测试。
  static Future<Uint8List> buildVibeZipArchiveBytes(
    List<VibeLibraryEntry> entries, {
    bool includeThumbnails = true,
    bool compress = true,
  }) async {
    if (entries.isEmpty) {
      throw ArgumentError('entries 不能为空');
    }

    final archive = Archive();
    final usedNames = <String>{};

    for (final entry in entries) {
      final archiveFile = await _buildZipFileForEntry(
        entry,
        usedNames: usedNames,
        includeThumbnails: includeThumbnails,
      );
      if (archiveFile != null) {
        archive.addFile(archiveFile);
      }
    }

    if (archive.files.isEmpty) {
      throw StateError('没有可导出的 Vibe 条目');
    }

    final zipBytes = ZipEncoder().encode(
      archive,
      level: compress ? Deflate.BEST_COMPRESSION : Deflate.NO_COMPRESSION,
    );
    if (zipBytes == null) {
      throw StateError('ZIP 编码失败');
    }

    return Uint8List.fromList(zipBytes);
  }

  static Future<ArchiveFile?> _buildZipFileForEntry(
    VibeLibraryEntry entry, {
    required Set<String> usedNames,
    required bool includeThumbnails,
  }) async {
    final fileName = _uniqueArchiveFileName(
      _archiveFileNameForEntry(entry),
      usedNames,
    );

    final bytes = await _zipBytesForEntry(
      entry,
      includeThumbnails: includeThumbnails,
    );
    if (bytes == null || bytes.isEmpty) {
      AppLogger.w('跳过无法导出的 ZIP 条目: ${entry.displayName}', 'VibeExport');
      return null;
    }

    return ArchiveFile(fileName, bytes.length, bytes);
  }

  static Future<Uint8List?> _zipBytesForEntry(
    VibeLibraryEntry entry, {
    required bool includeThumbnails,
  }) async {
    if (entry.isBundle) {
      final filePath = entry.filePath;
      if (filePath != null &&
          filePath.isNotEmpty &&
          p.extension(filePath).toLowerCase() == '.naiv4vibebundle') {
        final file = File(filePath);
        if (await file.exists()) {
          return file.readAsBytes();
        }
      }

      final bundleVibes = _buildBundleVibesFromEntry(entry);
      if (bundleVibes.isEmpty) {
        return null;
      }
      final bundleJson = await _generateBundleJson(
        bundleVibes,
        includeThumbnails: includeThumbnails,
      );
      return Uint8List.fromList(utf8.encode(bundleJson));
    }

    final vibe = entry.toVibeReference();
    if (!_hasExportableData(vibe)) {
      return null;
    }

    final jsonData = await _generateNaiv4VibeJson(
      vibe,
      name: entry.displayName,
      includeThumbnail: includeThumbnails,
    );
    return Uint8List.fromList(utf8.encode(jsonData));
  }

  static List<VibeReference> _buildBundleVibesFromEntry(
    VibeLibraryEntry entry,
  ) {
    final names = entry.bundledVibeNames;
    if (names == null || names.isEmpty) {
      return const <VibeReference>[];
    }

    final encodings = entry.bundledVibeEncodings;
    final previews = entry.bundledVibePreviews;
    final strengths = entry.bundledVibeStrengths;
    final infoExtracted = entry.bundledVibeInfoExtracted;

    return [
      for (var i = 0; i < names.length; i++)
        VibeReference(
          displayName: names[i],
          vibeEncoding: encodings != null && i < encodings.length
              ? encodings[i]
              : '',
          thumbnail: previews != null && i < previews.length
              ? previews[i]
              : null,
          strength: strengths != null && i < strengths.length
              ? strengths[i]
              : entry.strength,
          infoExtracted: infoExtracted != null && i < infoExtracted.length
              ? infoExtracted[i]
              : entry.infoExtracted,
          sourceType: VibeSourceType.naiv4vibebundle,
        ),
    ];
  }

  static String _archiveFileNameForEntry(VibeLibraryEntry entry) {
    final extension = entry.isBundle ? 'naiv4vibebundle' : 'naiv4vibe';
    final baseName = FileNameSanitizer.sanitize(
      entry.displayName,
      fallback: entry.isBundle ? 'vibe-bundle' : 'vibe',
      maxLength: 80,
    );
    return '$baseName.$extension';
  }

  static String _uniqueArchiveFileName(String fileName, Set<String> usedNames) {
    final extension = p.extension(fileName);
    final baseName = p.basenameWithoutExtension(fileName);
    var candidate = fileName.replaceAll('\\', '/');
    var index = 1;

    while (!usedNames.add(candidate.toLowerCase())) {
      candidate = '$baseName ($index)$extension';
      index++;
    }

    return candidate;
  }

  /// 生成 .naiv4vibe JSON 数据
  static Future<String> _generateNaiv4VibeJson(
    VibeReference vibe, {
    String? name,
    String defaultModel = 'nai-diffusion-4-full',
    bool includeThumbnail = true,
  }) async {
    final displayName = name ?? vibe.displayName;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // 计算 ID (sha256 hash)
    final id = _generateId(vibe);

    // 确定类型和数据
    final String type;
    final String? imageBase64;
    final Map<String, dynamic> encodings;

    if (vibe.sourceType == VibeSourceType.rawImage &&
        vibe.rawImageData != null) {
      // 原始图片模式：导出为 image 类型
      type = 'image';
      imageBase64 = base64Encode(vibe.rawImageData!);
      encodings = {};
    } else if (vibe.vibeEncoding.isNotEmpty) {
      // 预编码模式：导出为 encoding 类型
      type = 'encoding';
      imageBase64 = vibe.thumbnail != null
          ? base64Encode(vibe.thumbnail!)
          : null;

      // 构建 encodings 结构
      encodings = {
        defaultModel: {
          'vibe': {'encoding': vibe.vibeEncoding},
        },
      };
    } else {
      // 使用缩略图作为图片
      type = 'image';
      imageBase64 = vibe.thumbnail != null
          ? base64Encode(vibe.thumbnail!)
          : null;
      encodings = {};
    }

    // 生成缩略图（如果没有，使用原图缩小）
    final String? thumbnailBase64 = includeThumbnail
        ? await _generateThumbnailBase64(vibe)
        : null;

    // 构建 JSON 结构
    final jsonMap = <String, dynamic>{
      'identifier': _identifier,
      'version': _version,
      'type': type,
      'id': id,
      'name': displayName,
      'createdAt': timestamp,
      if (imageBase64 != null) 'image': imageBase64,
      'encodings': encodings,
      if (thumbnailBase64 != null) 'thumbnail': thumbnailBase64,
      'importInfo': {
        'model': defaultModel,
        'information_extracted': vibe.infoExtracted,
        'strength': vibe.strength,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(jsonMap);
  }

  /// 生成 bundle JSON 数据
  static Future<String> _generateBundleJson(
    List<VibeReference> vibes, {
    bool includeThumbnails = true,
  }) async {
    final vibeEntries = <Map<String, dynamic>>[];

    for (final vibe in vibes) {
      if (!_hasExportableData(vibe)) {
        AppLogger.w('跳过无法导出的 Vibe: ${vibe.displayName}', 'VibeExport');
        continue;
      }

      final entry = await _generateBundleEntry(
        vibe,
        includeThumbnail: includeThumbnails,
      );
      vibeEntries.add(entry);
    }

    final bundleMap = <String, dynamic>{
      'identifier': 'novelai-vibe-transfer-bundle',
      'version': 1,
      'vibes': vibeEntries,
    };

    return const JsonEncoder.withIndent('  ').convert(bundleMap);
  }

  /// 生成单个 bundle 条目（简化格式，仅包含必要字段）
  ///
  /// 包含：name、importInfo.strength、encodings、thumbnail
  static Future<Map<String, dynamic>> _generateBundleEntry(
    VibeReference vibe, {
    bool includeThumbnail = true,
  }) async {
    // 构建 encodings 结构
    final Map<String, dynamic> encodings;

    if (vibe.vibeEncoding.isNotEmpty) {
      encodings = {
        'nai-diffusion-4-full': {
          'vibe': {'encoding': vibe.vibeEncoding},
        },
      };
    } else {
      encodings = {};
    }

    final entry = <String, dynamic>{
      'name': vibe.displayName,
      'encodings': encodings,
      'importInfo': {
        'information_extracted': vibe.infoExtracted,
        'strength': vibe.strength,
      },
    };

    // 添加缩略图（如果存在）
    final thumbnailBase64 = includeThumbnail
        ? await _generateThumbnailBase64(vibe)
        : null;
    if (thumbnailBase64 != null && thumbnailBase64.isNotEmpty) {
      entry['thumbnail'] = thumbnailBase64;
    }

    // 添加原始图片数据（如果encodings为空但原始数据存在，用于后续编码）
    if (vibe.vibeEncoding.isEmpty &&
        vibe.rawImageData != null &&
        vibe.rawImageData!.isNotEmpty) {
      entry['image'] = base64Encode(vibe.rawImageData!);
    }

    return entry;
  }

  /// 生成缩略图的 base64（如果没有缩略图，尝试生成一个）
  static Future<String?> _generateThumbnailBase64(VibeReference vibe) async {
    // 如果已有缩略图，直接使用
    if (vibe.thumbnail != null && vibe.thumbnail!.isNotEmpty) {
      return base64Encode(vibe.thumbnail!);
    }

    // 如果有原始图片数据，使用原始图片
    if (vibe.rawImageData != null && vibe.rawImageData!.isNotEmpty) {
      // 这里可以添加图片压缩逻辑，但目前直接使用原图
      return base64Encode(vibe.rawImageData!);
    }

    return null;
  }

  /// 检查 Vibe 是否有可导出的数据
  static bool _hasExportableData(VibeReference vibe) {
    return vibe.vibeEncoding.isNotEmpty ||
        (vibe.rawImageData != null && vibe.rawImageData!.isNotEmpty) ||
        (vibe.thumbnail != null && vibe.thumbnail!.isNotEmpty);
  }

  /// 生成唯一 ID (SHA256)
  static String _generateId(VibeReference vibe) {
    final data = <int>[];

    // 使用 vibe 编码或图片数据生成 ID
    if (vibe.vibeEncoding.isNotEmpty) {
      data.addAll(utf8.encode(vibe.vibeEncoding));
    } else if (vibe.rawImageData != null) {
      data.addAll(vibe.rawImageData!);
    } else if (vibe.thumbnail != null) {
      data.addAll(vibe.thumbnail!);
    } else {
      // 回退：使用名称和时间戳
      data.addAll(utf8.encode(vibe.displayName));
      data.addAll(utf8.encode(DateTime.now().toIso8601String()));
    }

    final hash = sha256.convert(data);
    return hash.toString();
  }

  /// 生成文件名
  static String _generateFileName(String name) {
    final finalName = FileNameSanitizer.sanitize(
      name,
      fallback: 'vibe',
      maxLength: 50,
    );

    return '$finalName.naiv4vibe';
  }

  /// 生成 bundle 文件名
  static String _generateBundleFileName(String name) {
    final finalName = FileNameSanitizer.sanitize(
      name,
      fallback: 'vibe-bundle',
      maxLength: 50,
    );

    return '$finalName.naiv4vibebundle';
  }

  static String _generateZipFileName(String name) {
    final finalName = FileNameSanitizer.sanitize(
      name,
      fallback: 'vibe-library',
      maxLength: 50,
    );

    return '$finalName.zip';
  }

  static String _generateEmbeddedPngFileName(String name) {
    final finalName = FileNameSanitizer.sanitize(
      name,
      fallback: 'vibe',
      maxLength: 50,
    );

    return '${finalName}_vibe.png';
  }

  static Future<String?> _resolveOutputFilePath({
    required String? outputDirectory,
    required String fileName,
    required String dialogTitle,
    required List<String> allowedExtensions,
  }) async {
    final directory = outputDirectory?.trim();
    if (directory != null && directory.isNotEmpty) {
      final outputDir = Directory(directory);
      await outputDir.create(recursive: true);
      return _createUniqueFilePath(outputDir.path, fileName);
    }

    return FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
  }

  static Future<String> _createUniqueFilePath(
    String directoryPath,
    String fileName,
  ) async {
    final extension = p.extension(fileName);
    final baseName = p.basenameWithoutExtension(fileName);
    var candidatePath = p.join(directoryPath, fileName);
    var index = 1;

    while (await File(candidatePath).exists()) {
      candidatePath = p.join(directoryPath, '$baseName ($index)$extension');
      index++;
    }

    return candidatePath;
  }

  /// 验证 .naiv4vibe JSON 格式是否有效
  static bool validateNaiv4VibeJson(String jsonString) {
    try {
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      // 检查必需字段
      if (jsonData['identifier'] != _identifier) {
        return false;
      }

      if (jsonData['version'] != _version) {
        return false;
      }

      if (jsonData['id'] == null || jsonData['id'] is! String) {
        return false;
      }

      if (jsonData['name'] == null || jsonData['name'] is! String) {
        return false;
      }

      final type = jsonData['type'] as String?;
      if (type != 'image' && type != 'encoding') {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}

class VibeExportImageCandidate {
  const VibeExportImageCandidate({
    required this.id,
    required this.label,
    required this.bytes,
  });

  final String id;
  final String label;
  final Uint8List bytes;
}
