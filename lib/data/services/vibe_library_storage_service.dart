import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../models/vibe/vibe_library_category.dart';
import '../models/vibe/vibe_library_entry.dart';
import '../models/vibe/vibe_reference.dart';
import 'vibe_display_cache_repository.dart';
import 'vibe_file_storage_service.dart';
import 'vibe_generation_state_repository.dart';
import 'vibe_library_entry_reader.dart';
import 'vibe_library_entry_writer.dart';
import 'vibe_library_hive_repository.dart';
import 'vibe_library_storage_categories.dart';
import 'vibe_library_storage_protocol.dart';
import 'vibe_library_storage_types.dart';
import 'vibe_library_sync_service.dart';

export 'vibe_library_storage_types.dart';

part 'vibe_library_storage_service.g.dart';

/// Backward-compatible application facade for Vibe library persistence.
///
/// The concrete, overridable API is retained for provider overrides and
/// downstream integrations. Hive lifecycle, entry reads, entry writes,
/// categories, display cache, generation state, and folder synchronization are
/// implemented by dedicated collaborators.
class VibeLibraryStorageService {
  VibeLibraryStorageService({
    VibeFileStorageService? fileStorage,
    VibeLibraryRepositoryProtocol? repository,
    VibeGenerationStateRepository? generationStateRepository,
  }) : _files = fileStorage ?? VibeFileStorageService(),
       _repository = repository ?? HiveVibeLibraryRepository(),
       _generation =
           generationStateRepository ?? VibeGenerationStateRepository() {
    _displayCache = VibeDisplayCacheRepository(_repository);
    _reader = VibeLibraryEntryReader(_repository, _files, _displayCache);
    _writer = VibeLibraryEntryWriter(_repository, _files, _displayCache);
    _categories = VibeLibraryCategoryRepository(
      _repository,
      getEntriesByCategory: getEntriesByCategory,
      updateEntryCategory: updateEntryCategory,
    );
    _sync = VibeLibrarySyncService(_repository, _files, _displayCache);
  }

  final VibeFileStorageService _files;
  final VibeLibraryRepositoryProtocol _repository;
  final VibeGenerationStateRepository _generation;
  late final VibeDisplayCacheRepository _displayCache;
  late final VibeLibraryEntryReader _reader;
  late final VibeLibraryEntryWriter _writer;
  late final VibeLibraryCategoryRepository _categories;
  late final VibeLibrarySyncService _sync;

  Future<void> init() => _repository.init();
  Future<void> close() => _repository.close();

  /// 同步读取内存缓存的展示缩略图；未命中返回 null。
  Uint8List? peekDisplayThumbnail(String id) => _displayCache.peekThumbnail(id);

  Future<Uint8List?> getDisplayThumbnail(String id) async {
    if (_repository is HiveVibeLibraryRepository &&
        !Hive.isBoxOpen(HiveVibeLibraryRepository.entriesBoxName) &&
        !Hive.isBoxOpen(HiveVibeLibraryRepository.displayEntriesBoxName) &&
        !Hive.isBoxOpen(HiveVibeLibraryRepository.thumbnailCacheBoxName)) {
      return null;
    }
    try {
      return await _displayCache.getThumbnail(id);
    } catch (_) {
      return null;
    }
  }

  Future<VibeLibraryEntry?> findMatchingEntry(VibeReference vibe) =>
      _reader.findMatching(vibe);
  Future<VibeLibraryEntry?> findOverwriteCandidate(List<VibeReference> vibes) =>
      _reader.findOverwriteCandidate(vibes);
  Future<VibeLibraryEntry?> findEntryByName(String name) =>
      _reader.findByName(name);
  Future<VibeLibraryEntry?> getEntry(String id) => _reader.get(id);
  Future<VibeLibraryDetailData?> getDetailData(String id) => _reader.detail(id);
  Future<VibeReference?> loadBundleChildVibe(String id, int childIndex) =>
      _reader.loadBundleChild(id, childIndex);
  Future<List<VibeLibraryEntry>> getAllEntries() => _reader.all();
  Future<List<VibeLibraryEntry>> getDisplayEntries() => _reader.display();
  Future<List<VibeLibraryEntry>> getEntriesByCategory(String? categoryId) =>
      _reader.byCategory(categoryId);
  Future<List<VibeLibraryEntry>> searchEntries(String query) =>
      _reader.search(query);
  Future<List<VibeLibraryEntry>> getFavoriteEntries() => _reader.favorites();
  Future<List<VibeLibraryEntry>> getRecentEntries({int limit = 20}) =>
      _reader.recent(limit: limit);
  Future<List<VibeLibraryEntry>> getRecentDisplayEntries({int limit = 20}) =>
      _reader.recentDisplay(limit: limit);
  Future<int> getEntriesCount() => _reader.count();
  Future<int> getEntriesCountByCategory(String? categoryId) =>
      _reader.countByCategory(categoryId);
  Future<bool> entryExists(String id) => _reader.exists(id);

  Future<int> portableFileLength(String filePath) =>
      _files.portableFileLength(filePath);
  Stream<List<int>> openPortableFile(String filePath) =>
      _files.openPortableFile(filePath);
  Future<String> importPortableFile(
    Stream<List<int>> bytes, {
    required String fileName,
  }) => _files.importPortableFile(bytes, fileName: fileName);
  Future<VibeReference?> loadPortableVibe(String filePath) =>
      _files.loadVibeFromFile(filePath);
  Future<List<VibeReference>> extractPortableBundle(String filePath) =>
      _files.extractVibesFromBundle(filePath);

  Future<void> discardPortableFile(String filePath) async {
    await _files.deletePortableFile(filePath);
  }

  Future<VibeLibraryEntry> commitPortableEntry(VibeLibraryEntry entry) async {
    final previous = await _repository.readEntry(entry.id);
    try {
      await _repository.putEntry(entry);
      await _displayCache.entryChanged(entry);
      final oldPath = previous?.filePath;
      if (oldPath?.isNotEmpty == true && oldPath != entry.filePath) {
        if (await _files.portableFileExists(oldPath!) &&
            !await _files.deletePortableFile(oldPath)) {
          throw StateError('Failed to delete replaced Vibe file');
        }
      }
      return entry;
    } catch (_) {
      if (previous == null) {
        await _repository.deleteEntry(entry.id);
        await _displayCache.entryDeleted(entry.id);
      } else {
        await _repository.putEntry(previous);
        await _displayCache.entryChanged(previous);
      }
      final newPath = entry.filePath;
      if (newPath?.isNotEmpty == true && newPath != previous?.filePath) {
        await _files.deletePortableFile(newPath!);
      }
      rethrow;
    }
  }

  Future<VibeLibraryEntry> saveEntry(VibeLibraryEntry entry) =>
      _writer.save(entry);
  Future<VibeLibraryEntry?> saveEntryParams(
    String id, {
    required double strength,
    required double infoExtracted,
    VibeReference? persistedVibeData,
  }) => _writer.saveParams(
    id,
    strength: strength,
    infoExtracted: infoExtracted,
    persistedVibeData: persistedVibeData,
  );
  Future<VibeLibraryEntry?> saveBundleChildParams(
    String id, {
    required int childIndex,
    required double strength,
    required double infoExtracted,
    VibeReference? persistedVibeData,
  }) => _writer.saveBundleChildParams(
    id,
    childIndex: childIndex,
    strength: strength,
    infoExtracted: infoExtracted,
    persistedVibeData: persistedVibeData,
  );
  Future<VibeLibraryEntry> saveBundleEntry(
    List<VibeReference> vibes, {
    required String name,
    String? categoryId,
    List<String>? tags,
    VibeLibraryEntry? replaceEntry,
  }) => _writer.saveBundle(
    vibes,
    name: name,
    categoryId: categoryId,
    tags: tags,
    replaceEntry: replaceEntry,
  );
  Future<bool> deleteEntry(String id) => _writer.delete(id);
  Future<int> deleteEntries(List<String> ids) => _writer.deleteMany(ids);
  Future<VibeLibraryEntry?> incrementUsedCount(String id) =>
      _writer.recordUsage(id);
  Future<VibeLibraryEntry?> toggleFavorite(String id) =>
      _writer.toggleFavorite(id);
  Future<VibeLibraryEntry?> updateEntryCategory(
    String id,
    String? categoryId,
  ) => _writer.updateCategory(id, categoryId);
  Future<VibeLibraryEntry?> updateEntryEncodingModel(String id, String model) =>
      _writer.updateEncodingModel(id, model);
  Future<VibeLibraryEntry?> updateEntryTags(String id, List<String> tags) =>
      _writer.updateTags(id, tags);
  Future<VibeLibraryEntry?> updateEntryThumbnail(
    String id,
    Uint8List? thumbnail,
  ) => _writer.updateThumbnail(id, thumbnail);
  Future<void> clearAllEntries() => _writer.clear();
  Future<VibeLibraryEntry?> updateEntryFile(String id, String newName) =>
      _writer.updateFileName(id, newName);
  Future<VibeEntryRenameResult> renameEntry(String id, String newName) =>
      _writer.rename(id, newName);
  Future<VibeLibraryEntry?> updateEntryPreviews(
    String id, {
    int maxCount = 4,
  }) => _writer.updatePreviews(id, maxCount: maxCount);

  Future<VibeFolderSyncResult> syncWithFileSystem({
    bool removeMissingEntries = true,
  }) async {
    try {
      return await _sync.synchronize(
        removeMissingEntries: removeMissingEntries,
      );
    } catch (error) {
      return VibeFolderSyncResult(
        scannedCount: 0,
        upsertedCount: 0,
        deletedCount: 0,
        failedCount: 1,
        errors: [error.toString()],
      );
    }
  }

  Future<VibeLibraryCategory> saveCategory(VibeLibraryCategory category) =>
      _categories.save(category);
  Future<VibeLibraryCategory?> getCategory(String id) => _categories.get(id);
  Future<List<VibeLibraryCategory>> getAllCategories() => _categories.getAll();
  Future<List<VibeLibraryCategory>> getRootCategories() =>
      _categories.getRoots();
  Future<List<VibeLibraryCategory>> getChildCategories(String parentId) =>
      _categories.getChildren(parentId);
  Future<bool> deleteCategory(String id, {bool moveEntriesToParent = true}) =>
      _categories.delete(id, moveEntriesToParent: moveEntriesToParent);
  Future<int> deleteCategories(List<String> ids) async {
    var count = 0;
    for (final id in ids) {
      if (await deleteCategory(id)) count++;
    }
    return count;
  }

  Future<VibeLibraryCategory?> updateCategoryName(String id, String newName) =>
      _categories.updateName(id, newName);
  Future<VibeLibraryCategory?> moveCategory(String id, String? parentId) =>
      _categories.move(id, parentId);
  Future<int> getCategoriesCount() async => (await getAllCategories()).length;
  Future<bool> categoryExists(String id) async => await getCategory(id) != null;
  Future<void> clearAllCategories() => _repository.clearCategories();
  Future<Set<String>> getAllTags() => _categories.getAllTags();
  Future<List<VibeLibraryEntry>> getEntriesByTag(String tag) =>
      _categories.getEntriesByTag(tag);
  Future<List<VibeLibraryEntry>> getEntriesByUsage({int limit = 20}) =>
      _categories.getEntriesByUsage(limit: limit);

  Future<void> saveGenerationState({
    required List<Map<String, dynamic>> vibeReferences,
    required List<Map<String, dynamic>> preciseReferences,
    required bool normalizeVibeStrength,
  }) => saveGenerationStateJson(
    jsonEncode({
      'vibeReferences': vibeReferences,
      'preciseReferences': preciseReferences,
      'normalizeVibeStrength': normalizeVibeStrength,
      'savedAt': DateTime.now().toIso8601String(),
    }),
  );
  Future<void> saveGenerationStateJson(String stateJson) =>
      _generation.saveJson(stateJson);
  Future<Map<String, dynamic>?> loadGenerationState() async {
    try {
      final value = await loadGenerationStateJson();
      return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to load generation state',
        error,
        stackTrace,
        'VibeLibrary',
      );
      return null;
    }
  }

  Future<String?> loadGenerationStateJson() => _generation.loadJson();
  Future<void> clearGenerationState() => _generation.clear();
}

@Riverpod(keepAlive: true)
VibeLibraryStorageService vibeLibraryStorageService(Ref ref) {
  final service = VibeLibraryStorageService();
  ref.onDispose(service.close);
  return service;
}
