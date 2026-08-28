import 'dart:typed_data';

import '../models/vibe/vibe_library_category.dart';
import '../models/vibe/vibe_library_entry.dart';

/// Persistence contract used by the Vibe library application service.
abstract interface class VibeLibraryRepositoryProtocol {
  Future<void> init();
  Future<void> ensureInit();
  Future<VibeLibraryEntry?> readEntry(String id);
  Future<void> putEntry(VibeLibraryEntry entry);
  Future<void> deleteEntry(String id);
  Future<void> clearEntries();
  Future<List<VibeLibraryEntry>> readAllEntries();
  Future<void> forEachEntry(
    Future<void> Function(VibeLibraryEntry entry) visit,
  );
  Future<VibeLibraryEntry?> firstEntryWhere(
    bool Function(VibeLibraryEntry entry) test,
  );
  Future<bool> containsEntry(String id);
  Future<List<VibeLibraryEntry>> readDisplayEntries();
  Future<void> replaceDisplayEntries(Iterable<VibeLibraryEntry> entries);
  Future<void> upsertDisplayEntryIfReady(VibeLibraryEntry entry);
  Future<void> deleteDisplayEntryIfReady(String id);
  Future<Uint8List?> readThumbnail(String id);
  Future<void> putThumbnail(String id, Uint8List bytes);
  Future<void> deleteThumbnail(String id);
  Future<void> clearThumbnails();
  Future<bool> isDisplayCacheReady();
  Future<void> setDisplayCacheReady(bool ready);
  Future<List<VibeLibraryCategory>> readCategories();
  Future<VibeLibraryCategory?> readCategory(String id);
  Future<void> putCategory(VibeLibraryCategory category);
  Future<void> deleteCategory(String id);
  Future<void> clearCategories();
  Future<void> close();
}

abstract interface class VibeGenerationStateRepositoryProtocol {
  Future<void> saveJson(String stateJson);
  Future<String?> loadJson();
  Future<void> clear();
}
