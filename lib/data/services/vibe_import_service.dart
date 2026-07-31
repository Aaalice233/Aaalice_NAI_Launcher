import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/vibe_file_parser.dart';
import '../models/vibe/vibe_library_entry.dart';
import '../models/vibe/vibe_reference.dart';

typedef ImportProgressCallback =
    void Function(int current, int total, String message);

typedef VibeNamingCallback =
    Future<String?> Function(
      String suggestedName, {
      required bool isBatch,
      Uint8List? thumbnail,
    });

typedef BundleImportOptionCallback =
    Future<BundleImportOption?> Function(
      String bundleName,
      List<VibeReference> vibes,
    );

class BundleImportOption {
  const BundleImportOption._({
    required this.keepAsBundle,
    this.selectedIndices,
    this.configuredReferences,
  });

  const BundleImportOption.keepAsBundle({
    List<VibeReference>? configuredReferences,
  }) : this._(
         keepAsBundle: true,
         selectedIndices: null,
         configuredReferences: configuredReferences,
       );

  const BundleImportOption.split({List<VibeReference>? configuredReferences})
    : this._(
        keepAsBundle: false,
        selectedIndices: null,
        configuredReferences: configuredReferences,
      );

  const BundleImportOption.select(
    List<int> indices, {
    List<VibeReference>? configuredReferences,
  }) : this._(
         keepAsBundle: false,
         selectedIndices: indices,
         configuredReferences: configuredReferences,
       );

  final bool keepAsBundle;
  final List<int>? selectedIndices;
  final List<VibeReference>? configuredReferences;
}

enum ConflictResolution { skip, replace, rename, ask }

class ImportError {
  const ImportError({required this.source, required this.error, this.details});

  final String source;
  final String error;
  final Object? details;
}

class VibeImportResult {
  const VibeImportResult({
    required this.totalCount,
    required this.successCount,
    required this.failCount,
    required this.skipCount,
    required this.importedEntries,
    required this.errors,
    required this.hasConflicts,
  });

  factory VibeImportResult.empty() {
    return const VibeImportResult(
      totalCount: 0,
      successCount: 0,
      failCount: 0,
      skipCount: 0,
      importedEntries: <VibeLibraryEntry>[],
      errors: <ImportError>[],
      hasConflicts: false,
    );
  }

  final int totalCount;
  final int successCount;
  final int failCount;
  final int skipCount;
  final List<VibeLibraryEntry> importedEntries;
  final List<ImportError> errors;
  final bool hasConflicts;
}

abstract class VibeLibraryImportRepository {
  Future<List<VibeLibraryEntry>> getAllEntries();

  Future<VibeLibraryEntry?> findEntryByName(String name);

  Future<VibeLibraryEntry> saveEntry(VibeLibraryEntry entry);

  Future<VibeLibraryEntry> saveBundleEntry(
    List<VibeReference> vibes, {
    required String name,
    String? categoryId,
    List<String>? tags,
    VibeLibraryEntry? replaceEntry,
  });
}

class VibeImportService {
  VibeImportService({required VibeLibraryImportRepository repository})
    : _repository = repository;

  final VibeLibraryImportRepository _repository;

  Future<VibeImportResult> importFromFile({
    required List<PlatformFile> files,
    String? categoryId,
    List<String>? tags,
    ConflictResolution conflictResolution = ConflictResolution.rename,
    ImportProgressCallback? onProgress,
    VibeNamingCallback? onNaming,
    BundleImportOptionCallback? onBundleOption,
  }) async {
    if (files.isEmpty) return VibeImportResult.empty();

    final sourceItems = <_ParsedSource>[];
    final errors = <ImportError>[];

    for (final file in files) {
      try {
        final bytes = await _readPlatformFileBytes(file);
        final references = await VibeFileParser.parseFile(file.name, bytes);
        final prepared = await _prepareFileSources(
          fileName: file.name,
          references: references,
          onBundleOption: onBundleOption,
        );
        sourceItems.addAll(prepared);
      } catch (e, stackTrace) {
        AppLogger.e(
          'Failed to parse vibe import file: ${file.name}',
          e,
          stackTrace,
          'VibeImportService',
        );
        errors.add(ImportError(source: file.name, error: '文件解析失败', details: e));
      }
    }

    final result = await _importParsedSources(
      sourceItems,
      categoryId: categoryId,
      tags: tags,
      conflictResolution: conflictResolution,
      onProgress: onProgress,
      onNaming: onNaming,
      progressPrefix: '导入文件',
    );

    return _mergeImportResult(result, errors);
  }

  VibeImportResult _mergeImportResult(
    VibeImportResult result,
    List<ImportError> parseErrors,
  ) {
    if (parseErrors.isEmpty) return result;

    return VibeImportResult(
      totalCount: result.totalCount + parseErrors.length,
      successCount: result.successCount,
      failCount: result.failCount + parseErrors.length,
      skipCount: result.skipCount,
      importedEntries: result.importedEntries,
      errors: [...result.errors, ...parseErrors],
      hasConflicts: result.hasConflicts,
    );
  }

  Future<VibeImportResult> importFromImage({
    required List<VibeImageImportItem> images,
    String? categoryId,
    List<String>? tags,
    ConflictResolution conflictResolution = ConflictResolution.rename,
    ImportProgressCallback? onProgress,
  }) async {
    if (images.isEmpty) return VibeImportResult.empty();

    final sourceItems = <_ParsedSource>[];
    final errors = <ImportError>[];

    for (final image in images) {
      try {
        final references = await VibeFileParser.parseFile(
          image.source,
          image.bytes,
        );
        for (final vibe in references) {
          AppLogger.d(
            'Prepared vibe import: ${vibe.displayName}, sourceType=${vibe.sourceType.name}, thumbnail: ${vibe.thumbnail != null ? '${vibe.thumbnail!.length} bytes' : 'null'}',
            'VibeImportService',
          );
          sourceItems.add(_ParsedSource(source: image.source, reference: vibe));
        }
      } catch (e, stackTrace) {
        AppLogger.e(
          'Failed to extract vibe from image: ${image.source}',
          e,
          stackTrace,
          'VibeImportService',
        );
        errors.add(
          ImportError(
            source: image.source,
            error: '图片不包含有效 Vibe 数据',
            details: e,
          ),
        );
      }
    }

    final result = await _importParsedSources(
      sourceItems,
      categoryId: categoryId,
      tags: tags,
      conflictResolution: conflictResolution,
      onProgress: onProgress,
      onNaming: null,
      progressPrefix: '导入图片',
    );

    return _mergeImportResult(result, errors);
  }

  Future<VibeImportResult> importFromEncoding({
    required List<VibeEncodingImportItem> items,
    String? categoryId,
    List<String>? tags,
    ConflictResolution conflictResolution = ConflictResolution.rename,
    ImportProgressCallback? onProgress,
  }) async {
    if (items.isEmpty) return VibeImportResult.empty();

    final sourceItems = <_ParsedSource>[];
    final errors = <ImportError>[];

    for (final item in items) {
      try {
        final references = await _parseEncodingItem(item);
        for (final reference in references) {
          sourceItems.add(
            _ParsedSource(source: item.source, reference: reference),
          );
        }
      } catch (e, stackTrace) {
        AppLogger.e(
          'Failed to parse vibe encoding: ${item.source}',
          e,
          stackTrace,
          'VibeImportService',
        );
        errors.add(
          ImportError(source: item.source, error: '编码解析失败', details: e),
        );
      }
    }

    final result = await _importParsedSources(
      sourceItems,
      categoryId: categoryId,
      tags: tags,
      conflictResolution: conflictResolution,
      onProgress: onProgress,
      onNaming: null,
      progressPrefix: '导入编码',
    );

    return _mergeImportResult(result, errors);
  }

  Future<VibeImportResult> _importParsedSources(
    List<_ParsedSource> sources, {
    required String? categoryId,
    required List<String>? tags,
    required ConflictResolution conflictResolution,
    required ImportProgressCallback? onProgress,
    required VibeNamingCallback? onNaming,
    required String progressPrefix,
  }) async {
    if (sources.isEmpty) return VibeImportResult.empty();

    final nameMap = <String, VibeLibraryEntry>{};

    final importedEntries = <VibeLibraryEntry>[];
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
          : source.reference.displayName;
      final baseName = defaultName.trim().isEmpty
          ? 'vibe-$current'
          : defaultName.trim();

      final isBatch = sources.length > 1;
      var candidateName = baseName;

      if (onNaming != null) {
        final customName = await onNaming(
          baseName,
          isBatch: isBatch,
          thumbnail: source.reference.thumbnail,
        );

        if (customName == null || customName.trim().isEmpty) {
          skipCount++;
          errors.add(
            ImportError(
              source: source.source,
              error: customName == null
                  ? '用户取消命名，已跳过: $baseName'
                  : '名称为空，已跳过: $baseName',
            ),
          );
          continue;
        }

        candidateName = customName.trim();
        if (isBatch) {
          candidateName = await _resolveBatchNaming(
            baseName: candidateName,
            usageMap: batchNamingIndexMap,
            existingNameMap: nameMap,
          );
        }
      }

      onProgress?.call(
        current,
        sources.length,
        '$progressPrefix($current/${sources.length}): $baseName',
      );

      try {
        final conflictEntry = await _findEntryByNameCached(
          candidateName,
          nameMap,
        );
        if (conflictEntry != null) hasConflicts = true;

        final resolvedName = await _resolveName(
          preferredName: candidateName,
          existingNameMap: nameMap,
          strategy: conflictResolution,
          conflictEntry: conflictEntry,
        );

        if (resolvedName == null) {
          skipCount++;
          errors.add(
            ImportError(source: source.source, error: '名称冲突，已跳过: $baseName'),
          );
          continue;
        }

        final bundledReferences = source.bundledReferences;
        final VibeLibraryEntry saved;
        if (bundledReferences != null && bundledReferences.isNotEmpty) {
          saved = await _repository.saveBundleEntry(
            bundledReferences,
            name: resolvedName,
            categoryId: categoryId,
            tags: tags,
            replaceEntry:
                conflictEntry != null &&
                    conflictResolution == ConflictResolution.replace
                ? conflictEntry
                : null,
          );
        } else {
          final entry = _buildEntry(
            source.reference,
            name: resolvedName,
            categoryId: categoryId,
            tags: tags,
            conflictEntry: conflictEntry,
            strategy: conflictResolution,
            bundleFileName: source.bundleFileName,
          );

          AppLogger.d(
            'Built entry: ${entry.name}, thumbnail: ${entry.thumbnail != null ? '${entry.thumbnail!.length} bytes' : 'null'}, '
                'vibeThumbnail: ${entry.vibeThumbnail != null ? '${entry.vibeThumbnail!.length} bytes' : 'null'}',
            'VibeImportService',
          );

          saved = await _repository.saveEntry(entry);
        }

        importedEntries.add(saved);
        successCount++;
        nameMap[_normalizeName(saved.name)] = saved;
      } catch (e, stackTrace) {
        AppLogger.e(
          'Failed to import vibe: ${source.source}',
          e,
          stackTrace,
          'VibeImportService',
        );
        errors.add(
          ImportError(source: source.source, error: '保存失败', details: e),
        );
        failCount++;
      }
    }

    return VibeImportResult(
      totalCount: sources.length,
      successCount: successCount,
      failCount: failCount,
      skipCount: skipCount,
      importedEntries: importedEntries,
      errors: errors,
      hasConflicts: hasConflicts,
    );
  }

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

  Future<List<VibeReference>> _parseEncodingItem(
    VibeEncodingImportItem item,
  ) async {
    final normalized = item.encoding.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Empty encoding content');
    }

    if (normalized.startsWith('{')) {
      final jsonObject = jsonDecode(normalized) as Map<String, dynamic>;

      if (jsonObject.containsKey('vibes')) {
        final bundleBytes = Uint8List.fromList(utf8.encode(normalized));
        return VibeFileParser.fromBundle(
          '${item.source}.naiv4vibebundle',
          bundleBytes,
          defaultStrength: item.defaultStrength,
        );
      }

      final vibeBytes = Uint8List.fromList(utf8.encode(normalized));
      final single = await VibeFileParser.fromNaiV4Vibe(
        '${item.source}.naiv4vibe',
        vibeBytes,
        defaultStrength: item.defaultStrength,
      );
      return <VibeReference>[single];
    }

    final displayName = item.displayName ?? item.source;
    return <VibeReference>[
      VibeReference(
        displayName: displayName,
        vibeEncoding: normalized,
        strength: item.defaultStrength,
        sourceType: VibeSourceType.naiv4vibe,
      ),
    ];
  }

  String _normalizeName(String name) {
    return name.trim().toLowerCase();
  }

  Future<VibeLibraryEntry?> _findEntryByNameCached(
    String name,
    Map<String, VibeLibraryEntry> nameMap,
  ) async {
    final normalized = _normalizeName(name);
    final cached = nameMap[normalized];
    if (cached != null) {
      return cached;
    }

    final existing = await _repository.findEntryByName(name);
    if (existing != null) {
      nameMap[_normalizeName(existing.name)] = existing;
    }
    return existing;
  }

  Future<String> _resolveBatchNaming({
    required String baseName,
    required Map<String, int> usageMap,
    required Map<String, VibeLibraryEntry> existingNameMap,
  }) async {
    final normalizedBase = _normalizeName(baseName);
    var index = usageMap[normalizedBase] ?? 0;

    while (true) {
      final candidate = index == 0 ? baseName : '$baseName-$index';
      if (await _findEntryByNameCached(candidate, existingNameMap) == null) {
        usageMap[normalizedBase] = index + 1;
        return candidate;
      }
      index++;
    }
  }

  Future<List<_ParsedSource>> _prepareFileSources({
    required String fileName,
    required List<VibeReference> references,
    required BundleImportOptionCallback? onBundleOption,
  }) async {
    if (references.isEmpty) {
      return const <_ParsedSource>[];
    }

    final isBundle = _isBundleFile(fileName, references);
    if (!isBundle || references.length <= 1) {
      return _mapToParsedSources(fileName, references);
    }

    final option = onBundleOption == null
        ? const BundleImportOption.split()
        : await onBundleOption(fileName, references);
    if (option == null) {
      return const <_ParsedSource>[];
    }

    final configuredReferences = _normalizeConfiguredReferences(
      references,
      option.configuredReferences,
    );

    if (option.keepAsBundle) {
      return _createBundleSource(fileName, configuredReferences);
    }

    final filteredReferences = _filterReferencesByIndices(
      configuredReferences,
      option.selectedIndices,
    );

    return _mapToParsedSources(fileName, filteredReferences);
  }

  List<VibeReference> _normalizeConfiguredReferences(
    List<VibeReference> original,
    List<VibeReference>? configured,
  ) {
    if (configured == null || configured.length != original.length) {
      return original;
    }
    return configured;
  }

  List<_ParsedSource> _createBundleSource(
    String fileName,
    List<VibeReference> references,
  ) {
    final bundleName = _suggestBundleName(fileName);
    final anchorReference = references.first.copyWith(displayName: bundleName);
    return <_ParsedSource>[
      _ParsedSource(
        source: fileName,
        reference: anchorReference,
        preferredName: bundleName,
        bundledReferences: references,
        // 不设置 bundleFileName，让 saveEntry 自动保存文件
        // 否则 saveEntry 会认为文件已存在而跳过保存
        bundleFileName: null,
      ),
    ];
  }

  List<VibeReference> _filterReferencesByIndices(
    List<VibeReference> references,
    List<int>? selectedIndices,
  ) {
    if (selectedIndices == null) return references;

    return selectedIndices
        .where((index) => index >= 0 && index < references.length)
        .map((index) => references[index])
        .toList();
  }

  List<_ParsedSource> _mapToParsedSources(
    String fileName,
    List<VibeReference> references,
  ) {
    return references
        .map(
          (reference) => _ParsedSource(source: fileName, reference: reference),
        )
        .toList();
  }

  bool _isBundleFile(String fileName, List<VibeReference> references) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.naiv4vibebundle')) {
      return true;
    }
    return references.any(
      (reference) => reference.sourceType == VibeSourceType.naiv4vibebundle,
    );
  }

  String _suggestBundleName(String fileName) {
    final lowerName = fileName.toLowerCase();
    const extension = '.naiv4vibebundle';
    if (lowerName.endsWith(extension)) {
      return fileName.substring(0, fileName.length - extension.length);
    }
    return fileName;
  }

  Future<String?> _resolveName({
    required String preferredName,
    required Map<String, VibeLibraryEntry> existingNameMap,
    required ConflictResolution strategy,
    required VibeLibraryEntry? conflictEntry,
  }) async {
    if (conflictEntry == null) return preferredName;

    switch (strategy) {
      case ConflictResolution.skip:
      case ConflictResolution.ask:
        return null;
      case ConflictResolution.replace:
        return preferredName;
      case ConflictResolution.rename:
        return await _generateUniqueName(preferredName, existingNameMap);
    }
  }

  Future<String> _generateUniqueName(
    String baseName,
    Map<String, VibeLibraryEntry> existingNameMap,
  ) async {
    var index = 2;
    var candidate = '$baseName ($index)';
    while (await _findEntryByNameCached(candidate, existingNameMap) != null) {
      index++;
      candidate = '$baseName ($index)';
    }
    return candidate;
  }

  VibeLibraryEntry _buildEntry(
    VibeReference reference, {
    required String name,
    required String? categoryId,
    required List<String>? tags,
    required VibeLibraryEntry? conflictEntry,
    required ConflictResolution strategy,
    List<VibeReference>? bundledReferences,
    String? bundleFileName,
  }) {
    final tagsToUse = tags ?? const <String>[];
    final bundleData = _extractBundleData(bundledReferences);

    if (conflictEntry != null && strategy == ConflictResolution.replace) {
      return conflictEntry.copyWith(
        name: name,
        vibeDisplayName: reference.displayName,
        vibeEncoding: reference.vibeEncoding,
        vibeThumbnail: reference.thumbnail,
        rawImageData: reference.rawImageData,
        strength: reference.strength,
        infoExtracted: reference.infoExtracted,
        encodingModel: reference.encodingModel,
        sourceTypeIndex: reference.sourceType.index,
        categoryId: categoryId,
        tags: tagsToUse,
        thumbnail: reference.thumbnail,
        bundledVibeNames: bundleData.names,
        bundledVibePreviews: bundleData.previews,
        bundledVibeEncodings: bundleData.encodings,
        bundledVibeStrengths: bundleData.strengths,
        bundledVibeInfoExtracted: bundleData.infoExtracted,
        bundledVibeEncodingModels: bundleData.encodingModels,
        filePath: bundleFileName,
      );
    }

    return VibeLibraryEntry.fromVibeReference(
      name: name,
      vibeData: reference,
      categoryId: categoryId,
      tags: tagsToUse,
      thumbnail: reference.thumbnail,
      filePath: bundleFileName,
    ).copyWith(
      bundledVibeNames: bundleData.names,
      bundledVibePreviews: bundleData.previews,
      bundledVibeEncodings: bundleData.encodings,
      bundledVibeStrengths: bundleData.strengths,
      bundledVibeInfoExtracted: bundleData.infoExtracted,
      bundledVibeEncodingModels: bundleData.encodingModels,
    );
  }

  ({
    List<String>? names,
    List<Uint8List>? previews,
    List<String>? encodings,
    List<double>? strengths,
    List<double>? infoExtracted,
    List<String?>? encodingModels,
  })
  _extractBundleData(List<VibeReference>? bundledReferences) {
    if (bundledReferences == null || bundledReferences.isEmpty) {
      return (
        names: null,
        previews: null,
        encodings: null,
        strengths: null,
        infoExtracted: null,
        encodingModels: null,
      );
    }

    final names = bundledReferences
        .map((item) => item.displayName)
        .where((item) => item.trim().isNotEmpty)
        .toList();

    final previews = bundledReferences
        .map((item) => item.thumbnail)
        .whereType<Uint8List>()
        .take(4)
        .toList();

    final encodings = bundledReferences
        .map((item) => item.vibeEncoding)
        .toList(growable: false);
    final strengths = bundledReferences
        .map((item) => item.strength)
        .toList(growable: false);
    final infoExtracted = bundledReferences
        .map((item) => item.infoExtracted)
        .toList(growable: false);
    final encodingModels = bundledReferences
        .map((item) => item.encodingModel)
        .toList(growable: false);

    return (
      names: names.isNotEmpty ? names : null,
      previews: previews.isNotEmpty ? previews : null,
      encodings: encodings,
      strengths: strengths,
      infoExtracted: infoExtracted,
      encodingModels: encodingModels,
    );
  }
}

class VibeImageImportItem {
  const VibeImageImportItem({required this.source, required this.bytes});

  final String source;
  final Uint8List bytes;
}

class VibeEncodingImportItem {
  const VibeEncodingImportItem({
    required this.source,
    required this.encoding,
    this.displayName,
    this.defaultStrength = 0.6,
  });

  final String source;
  final String encoding;
  final String? displayName;
  final double defaultStrength;
}

class _ParsedSource {
  const _ParsedSource({
    required this.source,
    required this.reference,
    this.preferredName,
    this.bundledReferences,
    this.bundleFileName,
  });

  final String source;
  final VibeReference reference;
  final String? preferredName;
  final List<VibeReference>? bundledReferences;
  final String? bundleFileName;
}
