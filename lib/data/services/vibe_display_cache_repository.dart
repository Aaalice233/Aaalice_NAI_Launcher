import 'dart:async';
import 'dart:typed_data';

import '../../core/database/utils/lru_cache.dart';
import '../../core/utils/display_thumbnail_utils.dart';
import '../../core/utils/vibe_performance_diagnostics.dart';
import '../models/vibe/vibe_library_entry.dart';
import 'vibe_library_storage_protocol.dart';

/// Owns the lightweight display-entry and thumbnail caches.
///
/// Cache failures never alter full Hive entries; callers can rebuild both
/// caches solely from the repository's source entries.
class VibeDisplayCacheRepository {
  VibeDisplayCacheRepository(this._repository);

  final VibeLibraryRepositoryProtocol _repository;
  Future<void> _thumbnailLoadQueue = Future.value();
  final Map<String, Future<Uint8List?>> _loadsById = {};

  // 缩略图 ≤256px/64KB，256 条上限最多约 16MB
  final LRUCache<String, Uint8List> _memoryThumbnails = LRUCache(maxSize: 256);

  Future<List<VibeLibraryEntry>> getEntries() async {
    if (await _repository.isDisplayCacheReady()) {
      return _repository.readDisplayEntries();
    }
    return rebuild();
  }

  Future<List<VibeLibraryEntry>> rebuild() async {
    final span = VibePerformanceDiagnostics.start(
      'storage.rebuildDisplayEntriesCache',
    );
    final entries = <VibeLibraryEntry>[];
    try {
      await _repository.forEachEntry((entry) async {
        entries.add(entry.toDisplayEntry());
        await Future<void>.delayed(Duration.zero);
      });
      await _repository.replaceDisplayEntries(entries);
      await _repository.setDisplayCacheReady(true);
      return List.unmodifiable(entries);
    } finally {
      span.finish(details: {'entries': entries.length});
    }
  }

  /// 同步读取内存缓存的缩略图；未命中返回 null。
  ///
  /// 卡片重建时先走这里，避免异步读盘期间渲染占位符造成闪烁。
  Uint8List? peekThumbnail(String id) => _memoryThumbnails.get(id);

  Future<Uint8List?> getThumbnail(String id) async {
    final memory = _memoryThumbnails.get(id);
    if (memory != null) return memory;

    final cached = await _repository.readThumbnail(id);
    if (cached != null && cached.isNotEmpty) {
      _memoryThumbnails.put(id, cached);
      return cached;
    }

    final active = _loadsById[id];
    if (active != null) return active;
    final load = _thumbnailLoadQueue.then((_) => _loadThumbnail(id));
    _thumbnailLoadQueue = load.then<void>((_) {}, onError: (_) {});
    _loadsById[id] = load;
    try {
      return await load;
    } finally {
      if (identical(_loadsById[id], load)) _loadsById.remove(id);
    }
  }

  Future<Uint8List?> _loadThumbnail(String id) async {
    try {
      final cached = await _repository.readThumbnail(id);
      if (cached != null && cached.isNotEmpty) {
        _memoryThumbnails.put(id, cached);
        return cached;
      }
      final entry = await _repository.readEntry(id);
      if (entry == null) return null;
      final source = _pickSource(entry);
      if (source == null) return null;
      final thumbnail = await DisplayThumbnailUtils.normalize(source);
      if (thumbnail == null || thumbnail.isEmpty) return null;
      await _repository.putThumbnail(id, thumbnail);
      _memoryThumbnails.put(id, thumbnail);
      return thumbnail;
    } catch (_) {
      return null;
    }
  }

  Uint8List? _pickSource(VibeLibraryEntry entry) {
    final sources = <Uint8List?>[
      entry.thumbnail,
      entry.vibeThumbnail,
      if (entry.bundledVibePreviews?.isNotEmpty == true)
        entry.bundledVibePreviews!.first,
      entry.rawImageData,
    ];
    for (final source in sources) {
      if (source != null && source.isNotEmpty) return source;
    }
    return null;
  }

  Future<void> entryChanged(VibeLibraryEntry entry) async {
    _memoryThumbnails.remove(entry.id);
    await _repository.upsertDisplayEntryIfReady(entry);
    await _repository.deleteThumbnail(entry.id);
  }

  Future<void> entryDeleted(String id) async {
    _memoryThumbnails.remove(id);
    await _repository.deleteDisplayEntryIfReady(id);
    await _repository.deleteThumbnail(id);
  }

  Future<void> clear() async {
    _memoryThumbnails.clear();
    await _repository.replaceDisplayEntries(const []);
    await _repository.clearThumbnails();
    await _repository.setDisplayCacheReady(true);
  }
}
