import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/vibe_performance_diagnostics.dart';
import '../models/vibe/vibe_library_category.dart';
import '../models/vibe/vibe_library_entry.dart';
import 'vibe_library_storage_protocol.dart';

/// Owns the stable Hive schema and all box lifecycle concerns for the Vibe library.
class HiveVibeLibraryRepository implements VibeLibraryRepositoryProtocol {
  static const entriesBoxName = 'vibe_library_entries';
  static const displayEntriesBoxName = 'vibe_library_display_entries_v2';
  static const thumbnailCacheBoxName = 'vibe_library_thumbnail_cache_v1';
  static const categoriesBoxName = 'vibe_library_categories';
  static const displayCacheReadyKey = 'vibe_library_display_cache_ready_v2';
  static const _tag = 'VibeLibrary';

  // Entries embed encodings and source images; a non-lazy box would pin the
  // whole table in memory for the rest of the session.
  LazyBox<VibeLibraryEntry>? entriesBox;
  Box<VibeLibraryEntry>? displayEntriesBox;
  LazyBox<Uint8List>? thumbnailCacheBox;
  Box<VibeLibraryCategory>? categoriesBox;

  Future<void>? _entriesInitFuture;
  Future<void>? _displayEntriesInitFuture;
  Future<void>? _thumbnailCacheInitFuture;
  Future<void>? _categoriesInitFuture;

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(23)) {
      Hive.registerAdapter(VibeLibraryEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(21)) {
      Hive.registerAdapter(VibeLibraryCategoryAdapter());
    }
  }

  @override
  Future<void> init() async {
    await VibePerformanceDiagnostics.measure('storage.init', () async {
      _registerAdapters();
      await Future.wait([ensureDisplayEntriesBox(), ensureCategoriesBox()]);
      AppLogger.d('VibeLibraryStorageService initialized', _tag);
    });
  }

  Future<void> ensureEntriesBox() async {
    if (entriesBox?.isOpen == true) return;
    _registerAdapters();
    final active = _entriesInitFuture;
    if (active != null) return active;
    final future = Hive.openLazyBox<VibeLibraryEntry>(entriesBoxName).then((
      box,
    ) {
      entriesBox = box;
    });
    _entriesInitFuture = future;
    try {
      await future;
    } finally {
      if (identical(_entriesInitFuture, future)) _entriesInitFuture = null;
    }
  }

  Future<LazyBox<VibeLibraryEntry>> _entries() async {
    await ensureEntriesBox();
    return entriesBox!;
  }

  Future<void> ensureDisplayEntriesBox() async {
    if (displayEntriesBox?.isOpen == true) return;
    _registerAdapters();
    final active = _displayEntriesInitFuture;
    if (active != null) return active;
    final future = Hive.openBox<VibeLibraryEntry>(displayEntriesBoxName).then((
      box,
    ) {
      displayEntriesBox = box;
    });
    _displayEntriesInitFuture = future;
    try {
      await future;
    } finally {
      if (identical(_displayEntriesInitFuture, future)) {
        _displayEntriesInitFuture = null;
      }
    }
  }

  Future<void> ensureThumbnailCacheBox() async {
    if (thumbnailCacheBox?.isOpen == true) return;
    _registerAdapters();
    final active = _thumbnailCacheInitFuture;
    if (active != null) return active;
    final future = Hive.openLazyBox<Uint8List>(thumbnailCacheBoxName).then((
      box,
    ) {
      thumbnailCacheBox = box;
    });
    _thumbnailCacheInitFuture = future;
    try {
      await future;
    } finally {
      if (identical(_thumbnailCacheInitFuture, future)) {
        _thumbnailCacheInitFuture = null;
      }
    }
  }

  Future<void> ensureCategoriesBox() async {
    if (categoriesBox?.isOpen == true) return;
    _registerAdapters();
    final active = _categoriesInitFuture;
    if (active != null) return active;
    final future = Hive.openBox<VibeLibraryCategory>(categoriesBoxName).then((
      box,
    ) {
      categoriesBox = box;
    });
    _categoriesInitFuture = future;
    try {
      await future;
    } finally {
      if (identical(_categoriesInitFuture, future)) {
        _categoriesInitFuture = null;
      }
    }
  }

  @override
  Future<VibeLibraryEntry?> readEntry(String id) async =>
      (await _entries()).get(id);

  @override
  Future<void> putEntry(VibeLibraryEntry entry) async =>
      (await _entries()).put(entry.id, entry);

  @override
  Future<void> deleteEntry(String id) async => (await _entries()).delete(id);

  @override
  Future<void> clearEntries() async {
    await (await _entries()).clear();
  }

  @override
  Future<Set<String>> readEntryIds() async =>
      (await _entries()).keys.whereType<String>().toSet();

  @override
  Future<List<VibeLibraryEntry>> readAllEntries() async {
    final entries = <VibeLibraryEntry>[];
    await forEachEntry((entry) async => entries.add(entry));
    return entries;
  }

  @override
  Stream<VibeLibraryEntry> streamEntries() async* {
    final box = await _entries();
    for (final key in box.keys.toList(growable: false)) {
      final entry = await box.get(key);
      if (entry != null) yield entry;
    }
  }

  @override
  Future<void> forEachEntry(
    Future<void> Function(VibeLibraryEntry) visit,
  ) async {
    await for (final entry in streamEntries()) {
      await visit(entry);
    }
  }

  @override
  Future<VibeLibraryEntry?> firstEntryWhere(
    bool Function(VibeLibraryEntry) test,
  ) async {
    var checked = 0;
    VibeLibraryEntry? match;
    await forEachEntry((entry) async {
      if (match == null && test(entry)) match = entry;
      checked++;
      if (checked % 4 == 0) await Future<void>.delayed(Duration.zero);
    });
    return match;
  }

  @override
  Future<bool> containsEntry(String id) async =>
      (await _entries()).containsKey(id);

  @override
  Future<Set<String>> readDisplayEntryIds() async {
    await ensureDisplayEntriesBox();
    return displayEntriesBox!.keys.whereType<String>().toSet();
  }

  @override
  Future<List<VibeLibraryEntry>> readDisplayEntries() async {
    await ensureDisplayEntriesBox();
    return displayEntriesBox!.values.toList(growable: false);
  }

  @override
  Future<void> replaceDisplayEntries(Iterable<VibeLibraryEntry> entries) async {
    await ensureDisplayEntriesBox();
    await displayEntriesBox!.clear();
    final byId = {for (final entry in entries) entry.id: entry};
    if (byId.isNotEmpty) await displayEntriesBox!.putAll(byId);
  }

  @override
  Future<void> upsertDisplayEntryIfReady(VibeLibraryEntry entry) async {
    if (!await isDisplayCacheReady()) return;
    await ensureDisplayEntriesBox();
    await displayEntriesBox!.put(entry.id, entry.toDisplayEntry());
  }

  @override
  Future<void> deleteDisplayEntryIfReady(String id) async {
    if (!await isDisplayCacheReady()) return;
    await ensureDisplayEntriesBox();
    await displayEntriesBox!.delete(id);
  }

  @override
  Future<Uint8List?> readThumbnail(String id) async {
    try {
      await ensureThumbnailCacheBox();
      return await thumbnailCacheBox!.get(id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> putThumbnail(String id, Uint8List bytes) async {
    await ensureThumbnailCacheBox();
    await thumbnailCacheBox!.put(id, bytes);
  }

  @override
  Future<void> deleteThumbnail(String id) async {
    await ensureThumbnailCacheBox();
    await thumbnailCacheBox!.delete(id);
  }

  @override
  Future<void> clearThumbnails() async {
    await ensureThumbnailCacheBox();
    await thumbnailCacheBox!.clear();
  }

  @override
  Future<bool> isDisplayCacheReady() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(displayCacheReadyKey) == true;
  }

  @override
  Future<void> setDisplayCacheReady(bool ready) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(displayCacheReadyKey, ready);
  }

  @override
  Future<List<VibeLibraryCategory>> readCategories() async {
    await ensureCategoriesBox();
    return categoriesBox!.values.toList(growable: false);
  }

  @override
  Future<VibeLibraryCategory?> readCategory(String id) async {
    await ensureCategoriesBox();
    return categoriesBox!.get(id);
  }

  @override
  Future<void> putCategory(VibeLibraryCategory category) async {
    await ensureCategoriesBox();
    await categoriesBox!.put(category.id, category);
  }

  @override
  Future<void> putCategories(List<VibeLibraryCategory> categories) async {
    await ensureCategoriesBox();
    await categoriesBox!.putAll({
      for (final category in categories) category.id: category,
    });
  }

  @override
  Future<void> deleteCategory(String id) async {
    await ensureCategoriesBox();
    await categoriesBox!.delete(id);
  }

  @override
  Future<void> clearCategories() async {
    await ensureCategoriesBox();
    await categoriesBox!.clear();
  }

  @override
  Future<void> close() async {
    await _closeBox(entriesBox);
    await _closeBox(displayEntriesBox);
    await _closeBox(thumbnailCacheBox);
    await _closeBox(categoriesBox);
    AppLogger.d('VibeLibraryStorageService closed', _tag);
  }

  Future<void> _closeBox(BoxBase? box) async {
    if (box?.isOpen == true) {
      await box!.close();
    }
  }
}
