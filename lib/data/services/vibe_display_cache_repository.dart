import 'dart:typed_data';

import '../../core/database/utils/lru_cache.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/async_work_pool.dart';
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

  static const _tag = 'VibeLibrary';

  final VibeLibraryRepositoryProtocol _repository;
  final AsyncWorkPool _thumbnailReadPool = AsyncWorkPool(4);
  final Map<String, Future<Uint8List?>> _loadsById = {};
  int _thumbnailLoadGeneration = 0;

  // 重建先取键快照再逐条读；排在它后面的镜像写入才不会被重建结果覆盖或漏掉
  Future<void> _maintenance = Future<void>.value();

  // 缩略图 ≤256px/64KB，256 条上限最多约 16MB
  final LRUCache<String, Uint8List> _memoryThumbnails = LRUCache(maxSize: 256);

  Future<List<VibeLibraryEntry>> getEntries() => _serialized(() async {
    if (await _repository.isDisplayCacheReady()) {
      return _repository.readDisplayEntries();
    }
    return _rebuild();
  });

  Future<List<VibeLibraryEntry>> rebuild() => _serialized(_rebuild);

  Future<List<VibeLibraryEntry>> _rebuild() async {
    final span = VibePerformanceDiagnostics.start(
      'storage.rebuildDisplayEntriesCache',
    );
    final entries = <VibeLibraryEntry>[];
    try {
      await _repository.forEachEntry((entry) async {
        entries.add(entry.toDisplayEntry());
        await Future<void>.delayed(Duration.zero);
      });
      // 展示表替换失败时，下次读取会重新构建。
      await _repository.setDisplayCacheReady(false);
      await _repository.replaceDisplayEntries(entries);
      await _repository.setDisplayCacheReady(true);
      return List.unmodifiable(entries);
    } finally {
      span.finish(details: {'entries': entries.length});
    }
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _maintenance.then((_) => operation());
    _maintenance = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// 同步读取内存缓存的缩略图；未命中返回 null。
  ///
  /// 卡片重建时先走这里，避免异步读盘期间渲染占位符造成闪烁。
  Uint8List? peekThumbnail(String id) => _memoryThumbnails.get(id);

  Future<Uint8List?> getThumbnail(
    String id, {
    bool Function()? isCancelled,
  }) async {
    final memory = _memoryThumbnails.get(id);
    if (memory != null) return memory;

    final active = _loadsById[id];
    if (active != null) return active;
    final generation = _thumbnailLoadGeneration;
    final load = _thumbnailReadPool.run(
      () => _loadThumbnail(id),
      isCancelled: () =>
          generation != _thumbnailLoadGeneration ||
          (isCancelled?.call() ?? false),
    );
    _loadsById[id] = load;
    try {
      return await load;
    } finally {
      if (identical(_loadsById[id], load)) _loadsById.remove(id);
    }
  }

  void cancelPendingThumbnailLoads() {
    _thumbnailLoadGeneration++;
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

  Future<void> entryChanged(VibeLibraryEntry entry) {
    _memoryThumbnails.remove(entry.id);
    return _serialized(() async {
      await _mirrorEntry(entry);
      await _repository.deleteThumbnail(entry.id);
      // 排队期间的读取可能把旧缩略图重新放回内存
      _memoryThumbnails.remove(entry.id);
    });
  }

  Future<void> mirrorEntry(VibeLibraryEntry entry) =>
      _serialized(() => _mirrorEntry(entry));

  Future<void> _mirrorEntry(VibeLibraryEntry entry) =>
      _mirror(() => _repository.upsertDisplayEntryIfReady(entry));

  Future<void> entryDeleted(String id) {
    _memoryThumbnails.remove(id);
    return _serialized(() async {
      await _mirror(() => _repository.deleteDisplayEntryIfReady(id));
      await _repository.deleteThumbnail(id);
      _memoryThumbnails.remove(id);
    });
  }

  Future<void> clear() {
    _memoryThumbnails.clear();
    return _serialized(() async {
      await _repository.replaceDisplayEntries(const []);
      await _repository.clearThumbnails();
      await _repository.setDisplayCacheReady(true);
    });
  }

  // 源条目已经写入；镜像失败却保持就绪，旧行会一直被当成最新数据
  Future<void> _mirror(Future<void> Function() write) async {
    try {
      await write();
    } catch (error, stackTrace) {
      try {
        await _repository.setDisplayCacheReady(false);
      } catch (resetError, resetStackTrace) {
        AppLogger.e(
          'Failed to invalidate Vibe display cache',
          resetError,
          resetStackTrace,
          _tag,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
