import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/file_name_sanitizer.dart';
import '../../core/utils/novelai_vibe_codec.dart';
import '../../core/utils/vibe_export_utils.dart';
import '../../core/utils/vibe_file_parser.dart';
import '../../core/utils/vibe_library_path_helper.dart';
import '../models/vibe/vibe_reference.dart';
import 'vibe_file_document_codec.dart';
import 'vibe_file_storage_protocol.dart';
import 'vibe_file_storage_types.dart';

/// Vibe 文件系统存储服务
///
/// 负责 vibes 文件夹内的文件读写、重命名、删除以及与 Hive 条目的同步。
class VibeFileRepository implements VibeFileRepositoryProtocol {
  VibeFileRepository({VibeFileDocumentCodec? codec})
    : _codec = codec ?? VibeFileDocumentCodec();

  final VibeFileDocumentCodec _codec;
  static const String _singleFileExtension = '.naiv4vibe';
  static const String _bundleFileExtension = '.naiv4vibebundle';
  static const String _tag = 'VibeFileStorage';

  /// Vibe 自身没记录编码模型时，落盘用的兜底模型。
  ///
  /// NovelAI 的文件格式要求把编码挂在某个模型键（v4full / v4-5full ...）下，
  /// 表达不了"未知"。这里以前硬编码 v4full，等于给来源不明的编码伪造了一个
  /// V4 标签：库一旦从文件重建，这些条目就变成"明确的 V4 编码"，而
  /// `VibeReference.needsEncodingForModel` 会因此判定它们在 V4.5 下需要重新
  /// 编码，每次生成都白扣 2 Anlas。改成跟随用户当前的默认模型。
  String get _fallbackEncodingModel => LocalStorageService().getDefaultModel();

  /// 保存单个 Vibe 到 .naiv4vibe 文件
  @override
  Future<String> saveVibeToFile(
    VibeReference vibe, {
    String? customName,
    String? defaultModel,
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
      final jsonString = _codec.buildSingleJson(
        vibe,
        displayName: customName ?? vibe.displayName,
        defaultModel: defaultModel ?? _fallbackEncodingModel,
      );
      await File(filePath).writeAsString(jsonString);
      AppLogger.i('Vibe 文件保存成功: $filePath', _tag);
      return filePath;
    } catch (e, stackTrace) {
      AppLogger.e('保存 Vibe 文件失败: $filePath', e, stackTrace, _tag);
      rethrow;
    }
  }

  /// 覆盖单个 .naiv4vibe 文件，但尽量保留已有结构和其他模型编码
  @override
  Future<void> overwriteVibeFile(
    String filePath,
    VibeReference vibe, {
    required String displayName,
    String? defaultModel,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('Vibe 文件不存在: $filePath');
    }

    final extension = p.extension(filePath).toLowerCase();
    if (extension != _singleFileExtension) {
      throw UnsupportedError('仅支持覆盖单个 $_singleFileExtension 文件');
    }

    Map<String, dynamic> jsonData;
    try {
      final existingJson = await file.readAsString();
      final decoded = jsonDecode(existingJson);
      jsonData = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
    } catch (_) {
      jsonData = <String, dynamic>{};
    }

    final vibeForFile = vibe.normalizedForLibraryStorage();
    final replacement = NovelAiVibeCodec.buildSingleMap(
      vibeForFile,
      name: displayName,
      fallbackModel: defaultModel ?? _fallbackEncodingModel,
    );
    final merged = _codec.mergeCompatibleVibeMap(jsonData, replacement);

    await file.writeAsString(NovelAiVibeCodec.encodeJson(merged));
    AppLogger.i('Vibe 文件覆盖成功: $filePath', _tag);
  }

  /// 保存多个 Vibe 到 .naiv4vibebundle 文件
  @override
  Future<String> saveBundleToFile(
    List<VibeReference> vibes, {
    String? bundleName,
    String? defaultModel,
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
      final jsonString = _codec.buildBundleJson(
        vibes,
        defaultModel: defaultModel ?? _fallbackEncodingModel,
      );
      await File(filePath).writeAsString(jsonString);
      AppLogger.i('Vibe Bundle 保存成功: $filePath', _tag);
      return filePath;
    } catch (e, stackTrace) {
      AppLogger.e('保存 Vibe Bundle 失败: $filePath', e, stackTrace, _tag);
      rethrow;
    }
  }

  /// 覆盖已有 .naiv4vibebundle 文件
  @override
  Future<void> overwriteBundleFile(
    String filePath,
    List<VibeReference> vibes, {
    String? defaultModel,
    bool preserveExistingData = true,
  }) async {
    if (vibes.isEmpty) {
      throw ArgumentError('vibes 不能为空');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('Vibe Bundle 文件不存在: $filePath');
    }

    final extension = p.extension(filePath).toLowerCase();
    if (extension != _bundleFileExtension) {
      throw UnsupportedError('仅支持覆盖 $_bundleFileExtension 文件');
    }

    try {
      Map<String, dynamic>? existingJson;
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          existingJson = decoded;
        }
      } catch (error) {
        if (preserveExistingData) {
          throw StateError('无法安全解析现有 Vibe Bundle，已取消覆盖: $error');
        }
      }
      if (preserveExistingData && existingJson == null) {
        throw StateError('现有 Vibe Bundle 结构无效，已取消覆盖');
      }

      final replacement = NovelAiVibeCodec.buildBundleMap(
        vibes,
        fallbackModel: defaultModel ?? _fallbackEncodingModel,
      );
      final merged = preserveExistingData
          ? _codec.mergeCompatibleBundleMap(existingJson, replacement)
          : replacement;
      await file.writeAsString(NovelAiVibeCodec.encodeJson(merged));
      AppLogger.i('Vibe Bundle 文件覆盖成功: $filePath', _tag);
    } catch (e, stackTrace) {
      AppLogger.e('覆盖 Vibe Bundle 失败: $filePath', e, stackTrace, _tag);
      rethrow;
    }
  }

  /// 从文件读取 Vibe 数据
  ///
  /// 对 bundle 文件返回第一个可用 Vibe。
  @override
  Future<VibeReference?> loadVibeFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        AppLogger.w('文件不存在: $filePath', _tag);
        return null;
      }

      final fileName = p.basename(filePath);
      final extension = p.extension(fileName).toLowerCase();
      final List<VibeReference> references;

      if (extension == _bundleFileExtension) {
        references = await VibeFileParser.fromBundleFile(
          filePath,
          fileName: fileName,
        );
      } else {
        final bytes = await file.readAsBytes();
        if (extension == _singleFileExtension &&
            !VibeExportUtils.validateNaiv4VibeJson(utf8.decode(bytes))) {
          AppLogger.w('文件格式校验失败: $filePath', _tag);
        }
        references = await VibeFileParser.parseFile(fileName, bytes);
      }

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

  /// 轻量读取文件里保存的导入参数。
  ///
  /// 用于列表页/导入页纠正 Hive 中的旧参数快照，避免回读整份重对象。
  @override
  Future<VibeStoredImportParams?> loadImportParams(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final extension = p.extension(filePath).toLowerCase();
      if (extension != _singleFileExtension &&
          extension != _bundleFileExtension) {
        return null;
      }

      final jsonString = await file.readAsString();
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final importInfo = switch (extension) {
        _singleFileExtension =>
          (decoded['importInfo'] as Map?)?.cast<String, dynamic>(),
        _bundleFileExtension => _extractBundleImportInfo(decoded),
        _ => null,
      };

      if (importInfo == null) {
        return null;
      }

      return VibeStoredImportParams(
        strength: _extractStoredStrength(importInfo, 0.6),
        infoExtracted: _extractStoredInfoExtracted(importInfo, 0.7),
      );
    } catch (e, stackTrace) {
      AppLogger.e('读取 Vibe 导入参数失败: $filePath', e, stackTrace, _tag);
      return null;
    }
  }

  /// 删除 Vibe 文件
  @override
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
  @override
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

  /// 从 bundle 中批量提取 vibe。
  ///
  /// 导入多个子 Vibe 时必须走这个入口，避免按索引重复读取和解析整份 bundle。
  @override
  Future<List<VibeReference>> extractVibesFromBundle(
    String bundlePath, {
    int startIndex = 0,
    int? limit,
  }) async {
    try {
      final file = File(bundlePath);
      if (!await file.exists()) {
        AppLogger.w('Bundle 文件不存在: $bundlePath', _tag);
        return const [];
      }

      final safeStartIndex = startIndex < 0 ? 0 : startIndex;
      final safeLimit = limit == null || limit >= 0 ? limit : 0;
      if (safeLimit == 0) {
        return const [];
      }

      final vibes = await VibeFileParser.fromBundleFile(
        bundlePath,
        fileName: p.basename(bundlePath),
      );

      if (safeStartIndex >= vibes.length) {
        AppLogger.w(
          'Bundle 起始索引越界: $safeStartIndex, length: ${vibes.length}',
          _tag,
        );
        return const [];
      }

      final endIndex = safeLimit == null
          ? vibes.length
          : (safeStartIndex + safeLimit)
                .clamp(safeStartIndex, vibes.length)
                .toInt();
      return vibes.sublist(safeStartIndex, endIndex);
    } catch (e, stackTrace) {
      AppLogger.e('从 Bundle 批量提取 Vibe 失败: $bundlePath', e, stackTrace, _tag);
      return const [];
    }
  }

  /// 从 bundle 中提取单个 vibe
  @override
  Future<VibeReference?> extractVibeFromBundle(
    String bundlePath,
    int index,
  ) async {
    if (index < 0) {
      AppLogger.w('Bundle 索引越界: $index', _tag);
      return null;
    }

    final vibes = await extractVibesFromBundle(
      bundlePath,
      startIndex: index,
      limit: 1,
    );
    return vibes.isEmpty ? null : vibes.first;
  }

  /// 从 bundle 中提取前 N 个缩略图
  @override
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
      final vibesRaw = data['vibes'];
      // 类型验证：确保 vibes 是列表
      if (vibesRaw is! List<dynamic>) {
        AppLogger.w('Bundle 文件格式错误: vibes 不是列表', _tag);
        return const [];
      }
      final previews = <Uint8List>[];

      for (final item in vibesRaw.take(maxCount)) {
        // 类型验证：确保每个元素是 Map
        if (item is! Map<String, dynamic>) {
          AppLogger.w('Bundle 文件格式错误: vibe 条目不是对象', _tag);
          continue;
        }

        final thumbnail =
            _decodeBase64Image(item['thumbnail']) ??
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
      final commaIndex = base64String.startsWith('data:')
          ? base64String.indexOf(',')
          : -1;
      final payload = commaIndex >= 0
          ? base64String.substring(commaIndex + 1)
          : base64String;
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  /// 获取 vibes 文件夹中所有 Vibe 文件
  @override
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

  String _normalizeFileBaseName(String name) {
    return FileNameSanitizer.sanitize(name, fallback: 'vibe', maxLength: 120);
  }

  Map<String, dynamic>? _extractBundleImportInfo(
    Map<String, dynamic> jsonData,
  ) {
    final vibes = jsonData['vibes'] as List<dynamic>?;
    if (vibes == null || vibes.isEmpty) {
      return null;
    }

    final first = vibes.first;
    if (first is! Map) {
      return null;
    }

    return (first['importInfo'] as Map?)?.cast<String, dynamic>();
  }

  double _extractStoredStrength(
    Map<String, dynamic>? importInfo,
    double defaultValue,
  ) {
    final strengthValue = importInfo?['strength'];
    return switch (strengthValue) {
      final double v => VibeReference.sanitizeStrength(v),
      final int v => VibeReference.sanitizeStrength(v.toDouble()),
      final String v => VibeReference.sanitizeStrength(
        double.tryParse(v) ?? defaultValue,
      ),
      _ => defaultValue,
    };
  }

  double _extractStoredInfoExtracted(
    Map<String, dynamic>? importInfo,
    double defaultValue,
  ) {
    final infoValue = importInfo?['information_extracted'];
    return switch (infoValue) {
      final double v => VibeReference.sanitizeInfoExtracted(v),
      final int v => VibeReference.sanitizeInfoExtracted(v.toDouble()),
      final String v => VibeReference.sanitizeInfoExtracted(
        double.tryParse(v) ?? defaultValue,
      ),
      _ => defaultValue,
    };
  }
}
