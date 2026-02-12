import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/vibe_file_parser.dart';
import '../../core/utils/vibe_image_embedder.dart';
import '../models/vibe/vibe_library_entry.dart';
import '../models/vibe/vibe_reference_v4.dart';

typedef ImportProgressCallback = void Function(
  int current,
  int total,
  String message,
);

enum ConflictResolution {
  skip,
  replace,
  rename,
  ask,
}

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

  Future<VibeLibraryEntry> saveEntry(VibeLibraryEntry entry);
}

class VibeImportService {
  VibeImportService({
    required VibeLibraryImportRepository repository,
  }) : _repository = repository;

  final VibeLibraryImportRepository _repository;

  Future<VibeImportResult> importFromFile({
    required List<PlatformFile> files,
    String? categoryId,
    List<String>? tags,
    ConflictResolution conflictResolution = ConflictResolution.rename,
    ImportProgressCallback? onProgress,
  }) async {
    if (files.isEmpty) {
      return VibeImportResult.empty();
    }

    final sourceItems = <_ParsedSource>[];
    final errors = <ImportError>[];

    for (final file in files) {
      final fileName = file.name;
      try {
        final bytes = await _readPlatformFileBytes(file);
        final references = await VibeFileParser.parseFile(fileName, bytes);
        for (final reference in references) {
          sourceItems.add(
            _ParsedSource(
              source: fileName,
              reference: reference,
            ),
          );
        }
      } catch (e, stackTrace) {
        AppLogger.e(
          'Failed to parse vibe import file: $fileName',
          e,
          stackTrace,
          'VibeImportService',
        );
        errors.add(
          ImportError(
            source: fileName,
            error: '文件解析失败',
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
      progressPrefix: '导入文件',
    );

    if (errors.isEmpty) {
      return result;
    }

    return VibeImportResult(
      totalCount: result.totalCount + errors.length,
      successCount: result.successCount,
      failCount: result.failCount + errors.length,
      skipCount: result.skipCount,
      importedEntries: result.importedEntries,
      errors: <ImportError>[...result.errors, ...errors],
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
    if (images.isEmpty) {
      return VibeImportResult.empty();
    }

    final sourceItems = <_ParsedSource>[];
    final errors = <ImportError>[];

    for (final image in images) {
      try {
        final reference = await VibeImageEmbedder.extractVibeFromImage(
          image.bytes,
        );
        sourceItems.add(
          _ParsedSource(
            source: image.source,
            reference: reference,
          ),
        );
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
      progressPrefix: '导入图片',
    );

    if (errors.isEmpty) {
      return result;
    }

    return VibeImportResult(
      totalCount: result.totalCount + errors.length,
      successCount: result.successCount,
      failCount: result.failCount + errors.length,
      skipCount: result.skipCount,
      importedEntries: result.importedEntries,
      errors: <ImportError>[...result.errors, ...errors],
      hasConflicts: result.hasConflicts,
    );
  }

  Future<VibeImportResult> importFromEncoding({
    required List<VibeEncodingImportItem> items,
    String? categoryId,
    List<String>? tags,
    ConflictResolution conflictResolution = ConflictResolution.rename,
    ImportProgressCallback? onProgress,
  }) async {
    if (items.isEmpty) {
      return VibeImportResult.empty();
    }

    final sourceItems = <_ParsedSource>[];
    final errors = <ImportError>[];

    for (final item in items) {
      try {
        final references = await _parseEncodingItem(item);
        for (final reference in references) {
          sourceItems.add(
            _ParsedSource(
              source: item.source,
              reference: reference,
            ),
          );
        }
      } catch (e, stackTrace) {
        AppLogger.e(
          'Failed to parse vibe encoding from source: ${item.source}',
          e,
          stackTrace,
          'VibeImportService',
        );
        errors.add(
          ImportError(
            source: item.source,
            error: '编码解析失败',
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
      progressPrefix: '导入编码',
    );

    if (errors.isEmpty) {
      return result;
    }

    return VibeImportResult(
      totalCount: result.totalCount + errors.length,
      successCount: result.successCount,
      failCount: result.failCount + errors.length,
      skipCount: result.skipCount,
      importedEntries: result.importedEntries,
      errors: <ImportError>[...result.errors, ...errors],
      hasConflicts: result.hasConflicts,
    );
  }

  Future<VibeImportResult> _importParsedSources(
    List<_ParsedSource> sources, {
    required String? categoryId,
    required List<String>? tags,
    required ConflictResolution conflictResolution,
    required ImportProgressCallback? onProgress,
    required String progressPrefix,
  }) async {
    if (sources.isEmpty) {
      return VibeImportResult.empty();
    }

    final existingEntries = await _repository.getAllEntries();
    final nameMap = <String, VibeLibraryEntry>{
      for (final entry in existingEntries) _normalizeName(entry.name): entry,
    };

    final importedEntries = <VibeLibraryEntry>[];
    final errors = <ImportError>[];
    var successCount = 0;
    var failCount = 0;
    var skipCount = 0;
    var hasConflicts = false;

    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      final current = i + 1;
      final baseName = source.reference.displayName.trim().isEmpty
          ? 'vibe-$current'
          : source.reference.displayName.trim();

      onProgress?.call(
        current,
        sources.length,
        '$progressPrefix($current/${sources.length}): $baseName',
      );

      try {
        final conflictEntry = nameMap[_normalizeName(baseName)];
        if (conflictEntry != null) {
          hasConflicts = true;
        }

        final resolvedName = _resolveName(
          preferredName: baseName,
          existingNameMap: nameMap,
          strategy: conflictResolution,
          conflictEntry: conflictEntry,
        );

        if (resolvedName == null) {
          skipCount++;
          errors.add(
            ImportError(
              source: source.source,
              error: '名称冲突，已跳过: $baseName',
            ),
          );
          continue;
        }

        final entry = _buildEntry(
          source.reference,
          name: resolvedName,
          categoryId: categoryId,
          tags: tags,
          conflictEntry: conflictEntry,
          strategy: conflictResolution,
        );

        final saved = await _repository.saveEntry(entry);
        importedEntries.add(saved);
        successCount++;

        nameMap[_normalizeName(saved.name)] = saved;
      } catch (e, stackTrace) {
        AppLogger.e(
          'Failed to import vibe from source: ${source.source}',
          e,
          stackTrace,
          'VibeImportService',
        );
        errors.add(
          ImportError(
            source: source.source,
            error: '保存失败',
            details: e,
          ),
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

  Future<List<VibeReferenceV4>> _parseEncodingItem(
    VibeEncodingImportItem item,
  ) async {
    final normalized = item.encoding.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Empty encoding content');
    }

    if (normalized.startsWith('{')) {
      final jsonObject =
          jsonDecode(normalized) as Map<String, dynamic>;

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
      return <VibeReferenceV4>[single];
    }

    final displayName = item.displayName ?? item.source;
    return <VibeReferenceV4>[
      VibeReferenceV4(
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

  String? _resolveName({
    required String preferredName,
    required Map<String, VibeLibraryEntry> existingNameMap,
    required ConflictResolution strategy,
    required VibeLibraryEntry? conflictEntry,
  }) {
    if (conflictEntry == null) {
      return preferredName;
    }

    switch (strategy) {
      case ConflictResolution.skip:
      case ConflictResolution.ask:
        return null;
      case ConflictResolution.replace:
        return preferredName;
      case ConflictResolution.rename:
        return _generateUniqueName(preferredName, existingNameMap);
    }
  }

  String _generateUniqueName(
    String baseName,
    Map<String, VibeLibraryEntry> existingNameMap,
  ) {
    var index = 2;
    var candidate = '$baseName ($index)';
    while (existingNameMap.containsKey(_normalizeName(candidate))) {
      index++;
      candidate = '$baseName ($index)';
    }
    return candidate;
  }

  VibeLibraryEntry _buildEntry(
    VibeReferenceV4 reference, {
    required String name,
    required String? categoryId,
    required List<String>? tags,
    required VibeLibraryEntry? conflictEntry,
    required ConflictResolution strategy,
  }) {
    final tagsToUse = tags ?? const <String>[];

    if (conflictEntry != null && strategy == ConflictResolution.replace) {
      return conflictEntry.copyWith(
        name: name,
        vibeDisplayName: reference.displayName,
        vibeEncoding: reference.vibeEncoding,
        vibeThumbnail: reference.thumbnail,
        rawImageData: reference.rawImageData,
        strength: reference.strength,
        infoExtracted: reference.infoExtracted,
        sourceTypeIndex: reference.sourceType.index,
        categoryId: categoryId,
        tags: tagsToUse,
        thumbnail: reference.thumbnail,
      );
    }

    return VibeLibraryEntry.fromVibeReference(
      name: name,
      vibeData: reference,
      categoryId: categoryId,
      tags: tagsToUse,
      thumbnail: reference.thumbnail,
    );
  }
}

class VibeImageImportItem {
  const VibeImageImportItem({
    required this.source,
    required this.bytes,
  });

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
  });

  final String source;
  final VibeReferenceV4 reference;
}
