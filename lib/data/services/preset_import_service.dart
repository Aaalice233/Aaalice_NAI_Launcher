import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../core/utils/app_logger.dart';
import '../models/prompt/preset_export_format.dart';
import '../models/prompt/random_preset.dart';

/// 预设导入进度回调
typedef PresetImportProgressCallback = void Function(
  int current,
  int total,
  String message,
);

/// 预设命名回调
typedef PresetNamingCallback = Future<String?> Function(
  String suggestedName, {
  required bool isBatch,
});

/// Bundle导入选项回调
typedef PresetBundleImportOptionCallback = Future<PresetBundleImportOption?> Function(
  String bundleName,
  List<RandomPreset> presets,
);

/// Bundle导入选项
class PresetBundleImportOption {
  const PresetBundleImportOption._({
    required this.keepAsBundle,
    this.selectedIndices,
  });

  const PresetBundleImportOption.keepAsBundle()
      : this._(keepAsBundle: true, selectedIndices: null);

  const PresetBundleImportOption.split()
      : this._(keepAsBundle: false, selectedIndices: null);

  const PresetBundleImportOption.select(List<int> indices)
      : this._(keepAsBundle: false, selectedIndices: indices);

  final bool keepAsBundle;
  final List<int>? selectedIndices;
}

/// 冲突解决策略
enum ConflictResolution {
  skip,
  replace,
  rename,
  ask,
}

/// 导入错误
class ImportError {
  const ImportError({
    required this.source,
    required this.error,
    this.details,
  });

  final String source;
  final String error;
  final Object? details;
}

/// 预设导入结果
class PresetImportResult {
  const PresetImportResult({
    required this.totalCount,
    required this.successCount,
    required this.failCount,
    required this.skipCount,
    required this.importedPresets,
    required this.errors,
    required this.hasConflicts,
  });

  factory PresetImportResult.empty() {
    return const PresetImportResult(
      totalCount: 0,
      successCount: 0,
      failCount: 0,
      skipCount: 0,
      importedPresets: <RandomPreset>[],
      errors: <ImportError>[],
      hasConflicts: false,
    );
  }

  final int totalCount;
  final int successCount;
  final int failCount;
  final int skipCount;
  final List<RandomPreset> importedPresets;
  final List<ImportError> errors;
  final bool hasConflicts;
}

/// 预设库导入仓库抽象
abstract class PresetLibraryImportRepository {
  Future<List<RandomPreset>> getAllPresets();

  Future<RandomPreset> savePreset(RandomPreset preset);

  Future<void> deletePreset(String id);
}

/// 预设导入服务
///
/// 负责预设的导入和冲突检测
class PresetImportService {
  PresetImportService({
    required PresetLibraryImportRepository repository,
  }) : _repository = repository;

  final PresetLibraryImportRepository _repository;
  static const String _tag = 'PresetImportService';

  /// 从文件导入预设
  ///
  /// [files] - 要导入的文件列表
  /// [conflictResolution] - 冲突解决策略
  /// [onProgress] - 进度回调
  /// [onNaming] - 命名回调（用于自定义名称）
  /// [onBundleOption] - Bundle导入选项回调
  Future<PresetImportResult> importFromFile({
    required List<PlatformFile> files,
    ConflictResolution conflictResolution = ConflictResolution.rename,
    ImportProgressCallback? onProgress,
    PresetNamingCallback? onNaming,
    PresetBundleImportOptionCallback? onBundleOption,
  }) async {
    if (files.isEmpty) return PresetImportResult.empty();

    final sourceItems = <_ParsedSource>[];
    final errors = <ImportError>[];

    for (final file in files) {
      try {
        final bytes = await _readPlatformFileBytes(file);
        final presets = await _parsePresetFile(file.name, bytes);
        final prepared = await _prepareFileSources(
          fileName: file.name,
          presets: presets,
          onBundleOption: onBundleOption,
        );
        sourceItems.addAll(prepared);
      } catch (e, stackTrace) {
        AppLogger.e('Failed to parse preset import file: ${file.name}', e, stackTrace, _tag);
        errors.add(ImportError(source: file.name, error: '文件解析失败', details: e));
      }
    }

    final result = await _importParsedSources(
      sourceItems,
      conflictResolution: conflictResolution,
      onProgress: onProgress,
      onNaming: onNaming,
      progressPrefix: '导入文件',
    );

    return _mergeImportResult(result, errors);
  }

  /// 从编码字符串导入预设
  ///
  /// [items] - 编码导入项列表
  /// [conflictResolution] - 冲突解决策略
  /// [onProgress] - 进度回调
  Future<PresetImportResult> importFromEncoding({
    required List<PresetEncodingImportItem> items,
    ConflictResolution conflictResolution = ConflictResolution.rename,
    ImportProgressCallback? onProgress,
  }) async {
    if (items.isEmpty) return PresetImportResult.empty();

    final sourceItems = <_ParsedSource>[];
    final errors = <ImportError>[];

    for (final item in items) {
      try {
        final preset = await _parseEncodingItem(item);
        sourceItems.add(_ParsedSource(source: item.source, preset: preset));
      } catch (e, stackTrace) {
        AppLogger.e('Failed to parse preset encoding: ${item.source}', e, stackTrace, _tag);
        errors.add(ImportError(source: item.source, error: '编码解析失败', details: e));
      }
    }

    final result = await _importParsedSources(
      sourceItems,
      conflictResolution: conflictResolution,
      onProgress: onProgress,
      onNaming: null,
      progressPrefix: '导入编码',
    );

    return _mergeImportResult(result, errors);
  }

  /// 从JSON字符串导入预设
  ///
  /// [jsonString] - JSON字符串
  /// [sourceName] - 源名称（用于错误报告）
  /// [conflictResolution] - 冲突解决策略
  Future<PresetImportResult> importFromJsonString({
    required String jsonString,
    String sourceName = 'json-import',
    ConflictResolution conflictResolution = ConflictResolution.rename,
  }) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final presets = await _parsePresetData(data, sourceName);

      if (presets.isEmpty) {
        return PresetImportResult.empty();
      }

      final sourceItems = presets
          .map((preset) => _ParsedSource(source: sourceName, preset: preset))
          .toList();

      return await _importParsedSources(
        sourceItems,
        conflictResolution: conflictResolution,
        onProgress: null,
        onNaming: null,
        progressPrefix: '导入JSON',
      );
    } catch (e, stackTrace) {
      AppLogger.e('Failed to import preset from JSON: $sourceName', e, stackTrace, _tag);
      return PresetImportResult(
        totalCount: 1,
        successCount: 0,
        failCount: 1,
        skipCount: 0,
        importedPresets: const [],
        errors: [ImportError(source: sourceName, error: 'JSON解析失败', details: e)],
        hasConflicts: false,
      );
    }
  }

  /// 解析预设文件
  Future<List<RandomPreset>> _parsePresetFile(String fileName, Uint8List bytes) async {
    final content = utf8.decode(bytes);
    final lowerName = fileName.toLowerCase();

    // 解析为JSON
    final data = jsonDecode(content) as Map<String, dynamic>;

    // 检查是否为Bundle格式
    if (_isBundleFile(lowerName, data)) {
      final result = RandomPreset.parseBatchExportData(data);
      return result.presets;
    }

    // 单预设格式
    final preset = RandomPreset.fromExportJson(data);
    return [preset];
  }

  /// 检查是否为Bundle文件
  bool _isBundleFile(String fileName, Map<String, dynamic> data) {
    if (fileName.endsWith('.$kNaiv4presetbundleExtension')) {
      return true;
    }
    return RandomPreset.isValidBatchExportData(data);
  }

  /// 准备文件源
  Future<List<_ParsedSource>> _prepareFileSources({
    required String fileName,
    required List<RandomPreset> presets,
    required PresetBundleImportOptionCallback? onBundleOption,
  }) async {
    if (presets.isEmpty) {
      return const [];
    }

    final isBundle = _isBundleFile(fileName, {});

    // 如果不是Bundle或只有一个预设，直接返回
    if (!isBundle || presets.length <= 1) {
      return presets
          .map((preset) => _ParsedSource(source: fileName, preset: preset))
          .toList();
    }

    // 处理Bundle选项
    final option = onBundleOption == null
        ? const PresetBundleImportOption.split()
        : await onBundleOption(fileName, presets);

    if (option == null) {
      return const [];
    }

    if (option.keepAsBundle) {
      // 保留为Bundle - 只保留第一个预设作为锚点
      final bundleName = _suggestBundleName(fileName);
      return [
        _ParsedSource(
          source: fileName,
          preset: presets.first,
          preferredName: bundleName,
          bundledPresets: presets,
          bundleFileName: fileName,
        ),
      ];
    }

    // 拆分导入
    final selectedIndices = option.selectedIndices;
    final filteredPresets = selectedIndices == null
        ? presets
        : selectedIndices
            .where((index) => index >= 0 && index < presets.length)
            .map((index) => presets[index])
            .toList();

    return filteredPresets
        .map((preset) => _ParsedSource(source: fileName, preset: preset))
        .toList();
  }

  /// 建议Bundle名称
  String _suggestBundleName(String fileName) {
    final lowerName = fileName.toLowerCase();
    const extension = '.$kNaiv4presetbundleExtension';
    if (lowerName.endsWith(extension)) {
      return fileName.substring(0, fileName.length - extension.length);
    }
    return fileName;
  }

  /// 解析编码项
  Future<RandomPreset> _parseEncodingItem(PresetEncodingImportItem item) async {
    final normalized = item.encoding.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Empty encoding content');
    }

    // 尝试解析为Base64
    if (normalized.length > 100 && !_looksLikeJson(normalized)) {
      try {
        final decoded = base64Decode(normalized);
        final jsonString = utf8.decode(decoded);
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        return RandomPreset.fromExportJson(data);
      } catch (_) {
        // 不是有效的Base64，继续尝试其他格式
      }
    }

    // 尝试解析为JSON
    if (_looksLikeJson(normalized)) {
      final data = jsonDecode(normalized) as Map<String, dynamic>;
      return RandomPreset.fromExportJson(data);
    }

    throw const FormatException('Unsupported encoding format');
  }

  /// 检查是否看起来像JSON
  bool _looksLikeJson(String content) {
    final trimmed = content.trim();
    return trimmed.startsWith('{') && trimmed.endsWith('}');
  }

  /// 解析预设数据
  Future<List<RandomPreset>> _parsePresetData(
    Map<String, dynamic> data,
    String source,
  ) async {
    // 检查是否为Bundle格式
    if (RandomPreset.isValidBatchExportData(data)) {
      final result = RandomPreset.parseBatchExportData(data);
      return result.presets;
    }

    // 单预设格式
    final preset = RandomPreset.fromExportJson(data);
    return [preset];
  }

  /// 导入解析后的源
  Future<PresetImportResult> _importParsedSources(
    List<_ParsedSource> sources, {
    required ConflictResolution conflictResolution,
    required ImportProgressCallback? onProgress,
    required PresetNamingCallback? onNaming,
    required String progressPrefix,
  }) async {
    if (sources.isEmpty) return PresetImportResult.empty();

    final existingPresets = await _repository.getAllPresets();
    final nameMap = <String, RandomPreset>{
      for (final preset in existingPresets) _normalizeName(preset.name): preset,
    };

    final importedPresets = <RandomPreset>[];
    final errors = <ImportError>[];
    var successCount = 0;
    var failCount = 0;
    var skipCount = 0;
    var hasConflicts = false;
    final batchNamingIndexMap = <String, int>{};

    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      final current = i + 1;
      final defaultName = source.preferredName?.trim().isNotEmpty == true
          ? source.preferredName!.trim()
          : source.preset.name;
      final baseName = defaultName.trim().isEmpty ? 'preset-$current' : defaultName.trim();

      final isBatch = sources.length > 1;
      var candidateName = baseName;

      if (onNaming != null) {
        final customName = await onNaming(
          baseName,
          isBatch: isBatch,
        );

        if (customName == null || customName.trim().isEmpty) {
          skipCount++;
          errors.add(ImportError(
            source: source.source,
            error: customName == null ? '用户取消命名，已跳过: $baseName' : '名称为空，已跳过: $baseName',
          ),);
          continue;
        }

        candidateName = customName.trim();
        if (isBatch) {
          candidateName = _resolveBatchNaming(
            baseName: candidateName,
            usageMap: batchNamingIndexMap,
            existingNameMap: nameMap,
          );
        }
      }

      onProgress?.call(current, sources.length, '$progressPrefix($current/${sources.length}): $baseName');

      try {
        final conflictPreset = nameMap[_normalizeName(candidateName)];
        if (conflictPreset != null) hasConflicts = true;

        final resolvedName = _resolveName(
          preferredName: candidateName,
          existingNameMap: nameMap,
          strategy: conflictResolution,
          conflictPreset: conflictPreset,
        );

        if (resolvedName == null) {
          skipCount++;
          errors.add(ImportError(source: source.source, error: '名称冲突，已跳过: $baseName'));
          continue;
        }

        final preset = _buildPreset(
          source.preset,
          name: resolvedName,
          conflictPreset: conflictPreset,
          strategy: conflictResolution,
          bundledPresets: source.bundledPresets,
          bundleFileName: source.bundleFileName,
        );

        final saved = await _repository.savePreset(preset);
        importedPresets.add(saved);
        successCount++;
        nameMap[_normalizeName(saved.name)] = saved;
      } catch (e, stackTrace) {
        AppLogger.e('Failed to import preset: ${source.source}', e, stackTrace, _tag);
        errors.add(ImportError(source: source.source, error: '保存失败', details: e));
        failCount++;
      }
    }

    return PresetImportResult(
      totalCount: sources.length,
      successCount: successCount,
      failCount: failCount,
      skipCount: skipCount,
      importedPresets: importedPresets,
      errors: errors,
      hasConflicts: hasConflicts,
    );
  }

  /// 合并导入结果
  PresetImportResult _mergeImportResult(PresetImportResult result, List<ImportError> parseErrors) {
    if (parseErrors.isEmpty) return result;

    return PresetImportResult(
      totalCount: result.totalCount + parseErrors.length,
      successCount: result.successCount,
      failCount: result.failCount + parseErrors.length,
      skipCount: result.skipCount,
      importedPresets: result.importedPresets,
      errors: [...result.errors, ...parseErrors],
      hasConflicts: result.hasConflicts,
    );
  }

  /// 读取平台文件字节
  Future<Uint8List> _readPlatformFileBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes!;
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      throw ArgumentError('File path is empty: ${file.name}');
    }

    return File(path).readAsBytes();
  }

  /// 规范化名称
  String _normalizeName(String name) {
    return name.trim().toLowerCase();
  }

  /// 解决批处理命名
  String _resolveBatchNaming({
    required String baseName,
    required Map<String, int> usageMap,
    required Map<String, RandomPreset> existingNameMap,
  }) {
    final normalizedBase = _normalizeName(baseName);
    final currentIndex = usageMap[normalizedBase] ?? 0;
    usageMap[normalizedBase] = currentIndex + 1;

    var candidate = currentIndex == 0 ? baseName : '$baseName-$currentIndex';
    while (existingNameMap.containsKey(_normalizeName(candidate))) {
      usageMap[normalizedBase] = (usageMap[normalizedBase] ?? 0) + 1;
      final nextIndex = usageMap[normalizedBase]! - 1;
      candidate = '$baseName-$nextIndex';
    }

    return candidate;
  }

  /// 解决名称冲突
  String? _resolveName({
    required String preferredName,
    required Map<String, RandomPreset> existingNameMap,
    required ConflictResolution strategy,
    required RandomPreset? conflictPreset,
  }) {
    if (conflictPreset == null) return preferredName;

    return switch (strategy) {
      ConflictResolution.skip || ConflictResolution.ask => null,
      ConflictResolution.replace => preferredName,
      ConflictResolution.rename => _generateUniqueName(preferredName, existingNameMap),
    };
  }

  /// 生成唯一名称
  String _generateUniqueName(
    String baseName,
    Map<String, RandomPreset> existingNameMap,
  ) {
    var index = 2;
    var candidate = '$baseName ($index)';
    while (existingNameMap.containsKey(_normalizeName(candidate))) {
      index++;
      candidate = '$baseName ($index)';
    }
    return candidate;
  }

  /// 构建设置
  RandomPreset _buildPreset(
    RandomPreset source, {
    required String name,
    required RandomPreset? conflictPreset,
    required ConflictResolution strategy,
    List<RandomPreset>? bundledPresets,
    String? bundleFileName,
  }) {
    // 如果是替换策略且有冲突，保留原预设的ID
    if (conflictPreset != null && strategy == ConflictResolution.replace) {
      return source.copyWith(
        id: conflictPreset.id,
        name: name,
        isDefault: false,
        updatedAt: DateTime.now(),
      );
    }

    // 创建新预设
    return source.copyWith(
      name: name,
      isDefault: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

/// 预设编码导入项
class PresetEncodingImportItem {
  const PresetEncodingImportItem({
    required this.source,
    required this.encoding,
  });

  final String source;
  final String encoding;
}

/// 解析后的源
class _ParsedSource {
  const _ParsedSource({
    required this.source,
    required this.preset,
    this.preferredName,
    this.bundledPresets,
    this.bundleFileName,
  });

  final String source;
  final RandomPreset preset;
  final String? preferredName;
  final List<RandomPreset>? bundledPresets;
  final String? bundleFileName;
}
