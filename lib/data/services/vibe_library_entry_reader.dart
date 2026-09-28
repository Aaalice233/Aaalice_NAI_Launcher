import 'dart:typed_data';

import '../../core/utils/app_logger.dart';
import '../../core/utils/vibe_performance_diagnostics.dart';
import '../models/vibe/vibe_library_entry.dart';
import '../models/vibe/vibe_reference.dart';
import 'vibe_display_cache_repository.dart';
import 'vibe_file_storage_service.dart';
import 'vibe_library_storage_protocol.dart';
import 'vibe_library_storage_types.dart';

/// Read/query boundary for full entries, detail documents, and display views.
class VibeLibraryEntryReader {
  VibeLibraryEntryReader(this._repository, this._files, this._displayCache);

  static const _tag = 'VibeLibrary';

  final VibeLibraryRepositoryProtocol _repository;
  final VibeFileStorageService _files;
  final VibeDisplayCacheRepository _displayCache;

  Future<VibeLibraryEntry?> findMatching(VibeReference vibe) async {
    if (vibe.vibeEncoding.isNotEmpty) {
      final match = await _repository.firstEntryWhere(
        (entry) =>
            entry.vibeEncoding.isNotEmpty &&
            entry.vibeEncoding == vibe.vibeEncoding,
      );
      if (match != null) return match;
    }
    final thumbnail = vibe.thumbnail;
    if (thumbnail == null || thumbnail.isEmpty) return null;
    return _repository.firstEntryWhere(
      (entry) => _bytesEqual(entry.thumbnail, thumbnail),
    );
  }

  Future<VibeLibraryEntry?> findOverwriteCandidate(List<VibeReference> vibes) {
    if (vibes.length != 1) return Future.value();
    final vibe = vibes.single;
    return _repository.firstEntryWhere(
      (entry) =>
          entry.displayName == vibe.displayName &&
          (entry.vibeEncoding == vibe.vibeEncoding ||
              _bytesEqual(entry.rawImageData, vibe.rawImageData)),
    );
  }

  Future<VibeLibraryEntry?> findByName(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return Future.value();
    return _repository.firstEntryWhere(
      (entry) => entry.name.trim().toLowerCase() == normalized,
    );
  }

  Future<VibeLibraryEntry?> get(String id) async =>
      (await detail(id, operation: 'storage.getEntry'))?.entry;

  Future<VibeLibraryDetailData?> detail(
    String id, {
    String operation = 'storage.getDetailData',
  }) async {
    final span = VibePerformanceDiagnostics.start(
      operation,
      details: {'id': id},
    );
    var found = false;
    var hasFile = false;
    var fileLoaded = false;
    var fileMissing = false;
    var isBundle = false;
    var previewsLoaded = false;
    try {
      final stored = await _repository.readEntry(id);
      if (stored == null) return null;
      found = true;
      isBundle = stored.isBundle;

      final path = stored.filePath;
      if (path == null || path.isEmpty) {
        return VibeLibraryDetailData(entry: stored);
      }
      hasFile = true;

      final children = stored.isBundle
          ? await _files.extractVibesFromBundle(path)
          : const <VibeReference>[];
      final fileVibe = stored.isBundle
          ? (children.isEmpty ? null : children.first)
          : await _files.loadVibeFromFile(path);
      if (fileVibe == null) {
        fileMissing = true;
        AppLogger.w('Entry file missing or invalid: $path', _tag);
        return null;
      }
      fileLoaded = true;

      var merged = stored
          .updateVibeData(
            fileVibe.copyWith(
              vibeEncoding: fileVibe.vibeEncoding.isNotEmpty
                  ? fileVibe.vibeEncoding
                  : stored.vibeEncoding,
              thumbnail:
                  fileVibe.thumbnail ??
                  stored.vibeThumbnail ??
                  stored.thumbnail,
              rawImageData: fileVibe.rawImageData ?? stored.rawImageData,
              encodingModel: fileVibe.encodingModel ?? stored.encodingModel,
            ),
          )
          .copyWith(filePath: path);
      if (children.isNotEmpty) {
        final previews = children
            .map((vibe) => vibe.thumbnail ?? vibe.rawImageData)
            .whereType<Uint8List>()
            .where((bytes) => bytes.isNotEmpty)
            .take(4)
            .toList();
        merged = merged.copyWith(
          bundledVibeNames: children.map((vibe) => vibe.displayName).toList(),
          bundledVibePreviews: previews.isEmpty ? null : previews,
          bundledVibeEncodings: children
              .map((vibe) => vibe.vibeEncoding)
              .toList(),
          bundledVibeStrengths: children.map((vibe) => vibe.strength).toList(),
          bundledVibeInfoExtracted: children
              .map((vibe) => vibe.infoExtracted)
              .toList(),
          bundledVibeEncodingModels: children
              .map((vibe) => vibe.encodingModel)
              .toList(),
        );
        if (previews.isNotEmpty) {
          previewsLoaded = true;
        }
      }
      return VibeLibraryDetailData(
        entry: merged,
        bundleVibes: List.unmodifiable(children),
      );
    } catch (error, stackTrace) {
      AppLogger.e('Failed to get entry', error, stackTrace, _tag);
      return null;
    } finally {
      span.finish(
        details: {
          'found': found,
          'hasFile': hasFile,
          'fileLoaded': fileLoaded,
          'fileMissing': fileMissing,
          'isBundle': isBundle,
          'previewsLoaded': previewsLoaded,
        },
      );
    }
  }

  Future<VibeReference?> loadBundleChild(String id, int index) async {
    if (index < 0) return null;
    final entry = await _repository.readEntry(id);
    final path = entry?.filePath;
    if (entry == null || !entry.isBundle || path == null || path.isEmpty) {
      return null;
    }
    return _files.extractVibeFromBundle(path, index);
  }

  Future<List<VibeLibraryEntry>> all() => _readList(
    'read all entries',
    () async =>
        Future.wait((await _repository.readAllEntries()).map(_resolveParams)),
  );

  Future<List<VibeLibraryEntry>> display() =>
      _readList('read display entries', _displayCache.getEntries);

  Future<List<VibeLibraryEntry>> byCategory(String? categoryId) async =>
      (await all()).where((entry) => entry.categoryId == categoryId).toList();

  Future<List<VibeLibraryEntry>> search(String query) => _readList(
    'search entries',
    () async {
      final entries = await _repository.readAllEntries();
      final normalized = query.toLowerCase();
      if (normalized.isEmpty) return entries;
      return entries
          .where(
            (entry) =>
                entry.name.toLowerCase().contains(normalized) ||
                entry.vibeDisplayName.toLowerCase().contains(normalized) ||
                entry.tags.any((tag) => tag.toLowerCase().contains(normalized)),
          )
          .toList();
    },
  );

  Future<List<VibeLibraryEntry>> favorites() => _readList(
    'read favorite entries',
    () async => (await _repository.readAllEntries())
        .where((entry) => entry.isFavorite)
        .toList(),
  );

  Future<List<VibeLibraryEntry>> recent({int limit = 20}) =>
      _readList('read recent entries', () async {
        final entries = (await _repository.readAllEntries())
            .where((entry) => entry.lastUsedAt != null)
            .toList();
        entries.sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
        return entries.take(limit).toList();
      });

  Future<List<VibeLibraryEntry>> recentDisplay({int limit = 20}) async {
    final entries = (await display())
        .where((entry) => entry.lastUsedAt != null)
        .toList();
    entries.sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
    return entries.take(limit).toList();
  }

  Future<int> count() async => (await _repository.readAllEntries()).length;
  Future<int> countByCategory(String? id) async =>
      (await _repository.readAllEntries())
          .where((entry) => entry.categoryId == id)
          .length;
  Future<bool> exists(String id) => _repository.containsEntry(id);

  Future<List<VibeLibraryEntry>> _readList(
    String operation,
    Future<List<VibeLibraryEntry>> Function() read,
  ) async {
    try {
      return await read();
    } catch (error, stackTrace) {
      AppLogger.e('Failed to $operation', error, stackTrace, 'VibeLibrary');
      return const [];
    }
  }

  Future<VibeLibraryEntry> _resolveParams(VibeLibraryEntry entry) async {
    final path = entry.filePath;
    if (path == null || path.isEmpty) return entry;
    final params = await _files.loadImportParams(path);
    if (params == null) return entry;
    return entry.copyWith(
      strength: params.strength,
      infoExtracted: params.infoExtracted,
    );
  }

  bool _bytesEqual(Uint8List? left, Uint8List? right) {
    if (identical(left, right)) return true;
    if (left == null || right == null || left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
