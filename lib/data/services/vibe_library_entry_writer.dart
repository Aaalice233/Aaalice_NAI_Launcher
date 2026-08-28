import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/utils/novelai_vibe_codec.dart';
import '../models/vibe/vibe_library_entry.dart';
import '../models/vibe/vibe_reference.dart';
import 'vibe_display_cache_repository.dart';
import 'vibe_file_storage_service.dart';
import 'vibe_library_storage_protocol.dart';
import 'vibe_library_storage_types.dart';

/// Transactional entry/file mutation boundary for the Vibe library.
class VibeLibraryEntryWriter {
  VibeLibraryEntryWriter(this._repository, this._files, this._displayCache);

  final VibeLibraryRepositoryProtocol _repository;
  final VibeFileStorageService _files;
  final VibeDisplayCacheRepository _displayCache;

  Future<VibeLibraryEntry> save(VibeLibraryEntry entry) async {
    var saved = entry.normalizedForLibraryStorage();
    if (saved.filePath?.isNotEmpty != true) saved = await _saveFile(saved);
    await _persist(saved);
    return saved;
  }

  Future<VibeLibraryEntry?> saveParams(
    String id, {
    required double strength,
    required double infoExtracted,
    VibeReference? persistedVibeData,
  }) async {
    final entry = await _repository.readEntry(id);
    if (entry == null) return null;
    final updated = persistedVibeData == null
        ? entry.updateStrength(strength).updateInfoExtracted(infoExtracted)
        : entry.updateVibeData(persistedVibeData);
    final path = updated.filePath;
    if (!updated.isBundle && path?.isNotEmpty == true) {
      await _files.overwriteVibeFile(
        path!,
        updated.toVibeReference(),
        displayName: updated.displayName,
      );
    }
    await _persist(updated);
    return updated;
  }

  Future<VibeLibraryEntry?> saveBundleChildParams(
    String id, {
    required int childIndex,
    required double strength,
    required double infoExtracted,
    VibeReference? persistedVibeData,
  }) async {
    final entry = await _repository.readEntry(id);
    final path = entry?.filePath;
    if (entry == null || !entry.isBundle || path?.isNotEmpty != true) {
      return null;
    }
    var children = await _files.extractVibesFromBundle(path!);
    if (children.isEmpty) children = buildBundleReferences(entry);
    if (childIndex < 0 || childIndex >= children.length) return null;
    children = List.of(children);
    final current = children[childIndex];
    children[childIndex] = (persistedVibeData ?? current)
        .copyWith(
          displayName: current.displayName,
          bundleSource: current.bundleSource,
          strength: VibeReference.sanitizeStrength(strength),
          infoExtracted: VibeReference.sanitizeInfoExtracted(infoExtracted),
        )
        .normalizedForLibraryStorage();
    await _files.overwriteBundleFile(path, children);
    final updated = _withBundleData(entry, children);
    await _persist(updated);
    return updated;
  }

  Future<VibeLibraryEntry> saveBundle(
    List<VibeReference> vibes, {
    required String name,
    String? categoryId,
    List<String>? tags,
    VibeLibraryEntry? replaceEntry,
  }) async {
    if (vibes.isEmpty) throw ArgumentError('vibes cannot be empty');
    final existingPath = replaceEntry?.filePath;
    final overwritePath = existingPath != null && existingPath.isNotEmpty
        ? existingPath
        : null;
    final overwrite =
        overwritePath != null &&
        p.extension(overwritePath).toLowerCase() == '.naiv4vibebundle' &&
        await File(overwritePath).exists();
    final path = overwrite
        ? overwritePath
        : await _files.saveBundleToFile(vibes, bundleName: name);
    if (overwrite) {
      await _files.overwriteBundleFile(
        path,
        vibes,
        preserveExistingData: false,
      );
    }
    var entry = VibeLibraryEntry.fromVibeReference(
      name: p.basenameWithoutExtension(path),
      vibeData: vibes.first,
      categoryId: categoryId,
      tags: tags,
      filePath: path,
    );
    if (replaceEntry != null) {
      entry = entry.copyWith(
        id: replaceEntry.id,
        isFavorite: replaceEntry.isFavorite,
        usedCount: replaceEntry.usedCount,
        lastUsedAt: replaceEntry.lastUsedAt,
        createdAt: replaceEntry.createdAt,
      );
    }
    entry = _withBundleData(
      entry.copyWith(bundleId: p.basenameWithoutExtension(path)),
      vibes,
    );
    await _persist(entry);
    return entry;
  }

  Future<bool> delete(String id) async {
    final entry = await _repository.readEntry(id);
    if (entry == null) return false;
    final path = entry.filePath;
    if (path?.isNotEmpty == true) await _files.deleteVibeFile(path!);
    await _repository.deleteEntry(id);
    await _displayCache.entryDeleted(id);
    return true;
  }

  Future<int> deleteMany(Iterable<String> ids) async {
    var count = 0;
    for (final id in ids) {
      if (await delete(id)) count++;
    }
    return count;
  }

  Future<VibeLibraryEntry?> recordUsage(String id) =>
      _update(id, (entry) => entry.recordUsage());
  Future<VibeLibraryEntry?> toggleFavorite(String id) =>
      _update(id, (entry) => entry.toggleFavorite());
  Future<VibeLibraryEntry?> updateCategory(String id, String? categoryId) =>
      _update(id, (entry) => entry.copyWith(categoryId: categoryId));
  Future<VibeLibraryEntry?> updateTags(String id, List<String> tags) =>
      _update(id, (entry) => entry.copyWith(tags: tags));
  Future<VibeLibraryEntry?> updateThumbnail(String id, Uint8List? bytes) =>
      _update(id, (entry) => entry.copyWith(thumbnail: bytes));

  Future<VibeLibraryEntry?> updateEncodingModel(String id, String model) async {
    final normalized = NovelAiVibeCodec.normalizeModelOrNull(model);
    if (normalized == null) return null;
    final entry = await _repository.readEntry(id);
    if (entry == null) return null;
    final path = entry.filePath;

    if (!entry.isBundle) {
      final vibe = path?.isNotEmpty == true
          ? await _files.loadVibeFromFile(path!)
          : entry.toVibeReference();
      if (vibe == null || !vibe.hasVibeEncoding) return null;
      final updatedVibe = vibe.copyWith(encodingModel: normalized);
      final updated = entry.updateVibeData(updatedVibe);
      if (path?.isNotEmpty == true) {
        await _files.overwriteVibeFile(
          path!,
          updatedVibe,
          displayName: updated.name,
          defaultModel: normalized,
        );
      }
      await _persist(updated);
      return updated;
    }

    if (path?.isNotEmpty != true) return null;
    final children = await _files.extractVibesFromBundle(path!);
    if (children.isEmpty || !children.any((vibe) => vibe.hasVibeEncoding)) {
      return null;
    }
    final updatedChildren = [
      for (final vibe in children)
        vibe.hasVibeEncoding ? vibe.copyWith(encodingModel: normalized) : vibe,
    ];
    await _files.overwriteBundleFile(
      path,
      updatedChildren.where((vibe) => vibe.hasVibeEncoding).toList(),
      defaultModel: normalized,
    );
    final existingModels = entry.bundledVibeEncodingModels;
    final updated = _withBundleData(entry, updatedChildren).copyWith(
      encodingModel: updatedChildren.first.hasVibeEncoding
          ? normalized
          : entry.encodingModel,
      bundledVibeEncodingModels: [
        for (var index = 0; index < updatedChildren.length; index++)
          updatedChildren[index].hasVibeEncoding
              ? normalized
              : existingModels != null && index < existingModels.length
              ? existingModels[index]
              : null,
      ],
    );
    await _persist(updated);
    return updated;
  }

  Future<VibeLibraryEntry?> updateFileName(String id, String name) async {
    final entry = await _repository.readEntry(id);
    final path = entry?.filePath;
    if (entry == null || path?.isNotEmpty != true) return null;
    final renamed = await _files.renameVibeFile(path!, name);
    if (renamed == null) return null;
    final updated = entry.copyWith(name: name.trim(), filePath: renamed);
    await _persist(updated);
    return updated;
  }

  Future<VibeEntryRenameResult> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const VibeEntryRenameResult.failure(
        VibeEntryRenameError.invalidName,
      );
    }
    final entry = await _repository.readEntry(id);
    if (entry == null) {
      return const VibeEntryRenameResult.failure(
        VibeEntryRenameError.entryNotFound,
      );
    }
    final conflict = await _repository.firstEntryWhere(
      (candidate) =>
          candidate.id != id &&
          candidate.name.trim().toLowerCase() == trimmed.toLowerCase(),
    );
    if (conflict != null) {
      return const VibeEntryRenameResult.failure(
        VibeEntryRenameError.nameConflict,
      );
    }
    if (entry.filePath?.isNotEmpty != true) {
      return const VibeEntryRenameResult.failure(
        VibeEntryRenameError.filePathMissing,
      );
    }
    final updated = await updateFileName(id, trimmed);
    return updated == null
        ? const VibeEntryRenameResult.failure(
            VibeEntryRenameError.fileRenameFailed,
          )
        : VibeEntryRenameResult.success(updated);
  }

  Future<VibeLibraryEntry?> updatePreviews(
    String id, {
    int maxCount = 4,
  }) async {
    final entry = await _repository.readEntry(id);
    final path = entry?.filePath;
    if (entry == null || !entry.isBundle || path?.isNotEmpty != true) {
      return entry;
    }
    final previews = await _files.extractPreviewsFromBundle(
      path!,
      maxCount: maxCount,
    );
    return _update(
      id,
      (value) => value.copyWith(bundledVibePreviews: previews),
    );
  }

  Future<void> clear() async {
    await _repository.clearEntries();
    await _displayCache.clear();
  }

  Future<VibeLibraryEntry?> _update(
    String id,
    VibeLibraryEntry Function(VibeLibraryEntry entry) transform,
  ) async {
    final entry = await _repository.readEntry(id);
    if (entry == null) return null;
    final updated = transform(entry);
    await _persist(updated);
    return updated;
  }

  Future<void> _persist(VibeLibraryEntry entry) async {
    await _repository.putEntry(entry);
    await _displayCache.entryChanged(entry);
  }

  Future<VibeLibraryEntry> _saveFile(VibeLibraryEntry entry) async {
    final path = entry.isBundle
        ? await _files.saveBundleToFile(
            buildBundleReferences(entry),
            bundleName: entry.name,
          )
        : await _files.saveVibeToFile(
            entry.toVibeReference(),
            customName: entry.name,
          );
    return entry.copyWith(
      name: p.basenameWithoutExtension(path),
      filePath: path,
    );
  }

  VibeLibraryEntry _withBundleData(
    VibeLibraryEntry entry,
    List<VibeReference> vibes,
  ) {
    final previews = vibes
        .map((vibe) => vibe.thumbnail)
        .whereType<Uint8List>()
        .take(4)
        .toList();
    return entry.copyWith(
      bundledVibeNames: vibes.map((vibe) => vibe.displayName).toList(),
      bundledVibePreviews: previews.isEmpty ? null : previews,
      bundledVibeEncodings: vibes.map((vibe) => vibe.vibeEncoding).toList(),
      bundledVibeStrengths: vibes.map((vibe) => vibe.strength).toList(),
      bundledVibeInfoExtracted: vibes
          .map((vibe) => vibe.infoExtracted)
          .toList(),
      bundledVibeEncodingModels: vibes
          .map((vibe) => vibe.encodingModel)
          .toList(),
    );
  }

  List<VibeReference> buildBundleReferences(VibeLibraryEntry entry) {
    final encodings = entry.bundledVibeEncodings;
    if (encodings == null || encodings.isEmpty) {
      return [entry.toVibeReference()];
    }
    return [
      for (var index = 0; index < encodings.length; index++)
        VibeReference(
          displayName: index < (entry.bundledVibeNames?.length ?? 0)
              ? entry.bundledVibeNames![index]
              : '${entry.name}#$index',
          vibeEncoding: encodings[index],
          thumbnail: index < (entry.bundledVibePreviews?.length ?? 0)
              ? entry.bundledVibePreviews![index]
              : null,
          strength: index < (entry.bundledVibeStrengths?.length ?? 0)
              ? entry.bundledVibeStrengths![index]
              : entry.strength,
          infoExtracted: index < (entry.bundledVibeInfoExtracted?.length ?? 0)
              ? entry.bundledVibeInfoExtracted![index]
              : entry.infoExtracted,
          encodingModel: index < (entry.bundledVibeEncodingModels?.length ?? 0)
              ? entry.bundledVibeEncodingModels![index]
              : entry.encodingModel,
          sourceType: VibeSourceType.naiv4vibebundle,
        ),
    ];
  }
}
