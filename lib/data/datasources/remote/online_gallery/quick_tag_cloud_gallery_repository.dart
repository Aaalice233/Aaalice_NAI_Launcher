import 'dart:math';

import 'package:dio/dio.dart';

import '../../../../core/online_gallery/gallery_tag_query.dart';
import '../../../../core/utils/prompt_tag_utils.dart';
import '../../../models/online_gallery/gallery_item.dart';
import '../../../models/online_gallery/gallery_source.dart';
import '../../../services/online_gallery/quick_tag_cloud_access.dart';
import '../../../services/online_gallery/quick_tag_cloud_remote_catalog_service.dart';
import '../../../services/online_gallery/quick_tag_cloud_user_service.dart';
import 'gallery_source_adapter.dart';
import 'quick_tag_cloud_gallery_query.dart';

class QuickTagCloudGalleryRepository {
  QuickTagCloudGalleryRepository({
    required QuickTagCloudRemoteCatalogService catalogService,
    required QuickTagCloudUserService userService,
    DateTime Function()? clock,
  }) : _catalogService = catalogService,
       _userService = userService,
       _clock = clock ?? DateTime.now;

  static const Duration catalogRefreshInterval = Duration(minutes: 15);

  final QuickTagCloudRemoteCatalogService _catalogService;
  final QuickTagCloudUserService _userService;
  final DateTime Function() _clock;
  final Map<String, QuickTagCloudGalleryRecord> _records = {};
  final Map<String, List<QuickTagCloudGalleryRecord>> _catalogRecordSets = {};
  final Map<String, Future<List<QuickTagCloudGalleryRecord>>>
  _catalogRecordLoads = {};
  int _cacheRevision = 0;

  QuickTagCloudCatalog? _catalog;
  DateTime? _catalogFetchedAt;
  Future<QuickTagCloudCatalog>? _catalogRequest;

  QuickTagCloudCatalog? get currentCatalog => _catalog;
  int get cacheRevision => _cacheRevision;

  Future<QuickTagCloudCatalog> getCatalog({
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    final cached = _catalog;
    final fetchedAt = _catalogFetchedAt;
    if (!forceRefresh &&
        cached != null &&
        fetchedAt != null &&
        _clock().difference(fetchedAt) < catalogRefreshInterval) {
      return cached;
    }
    if (cancelToken != null) {
      throwIfCancelled(cancelToken);
      final loaded = await _catalogService.fetchCatalog(
        cancelToken: cancelToken,
      );
      throwIfCancelled(cancelToken);
      return _acceptCatalog(loaded);
    }
    final existingRequest = _catalogRequest;
    if (!forceRefresh && existingRequest != null) return existingRequest;
    final pending = _catalogService.fetchCatalog();
    _catalogRequest = pending;
    try {
      return _acceptCatalog(await pending);
    } finally {
      if (identical(_catalogRequest, pending)) _catalogRequest = null;
    }
  }

  Future<QuickTagCloudCodex> getCodex(
    String codexId, {
    CancelToken? cancelToken,
  }) async {
    final catalog = await getCatalog(cancelToken: cancelToken);
    final meta = catalog.findCodex(codexId);
    if (meta == null) {
      throw ArgumentError.value(codexId, 'codexId', 'Unknown codex');
    }
    return _catalogService.fetchCodex(catalog, meta, cancelToken: cancelToken);
  }

  void invalidateCatalog() {
    _catalogFetchedAt = null;
    clearDerivedCaches();
    _catalogService.clearMemoryCache();
  }

  Future<void> clearDiskCache() async {
    _catalog = null;
    _catalogFetchedAt = null;
    _catalogRequest = null;
    clearDerivedCaches();
    await _catalogService.clearDiskCache();
  }

  void clearDerivedCaches() {
    _cacheRevision++;
    _records.clear();
    _catalogRecordSets.clear();
    _catalogRecordLoads.clear();
  }

  Future<List<QuickTagCloudGalleryRecord>> loadCatalogRecords(
    QuickTagCloudGalleryQuery query, {
    CancelToken? cancelToken,
  }) async {
    final catalog = await getCatalog(cancelToken: cancelToken);
    final cacheKey = '${catalog.release}|${query.codexId}|${query.allowNsfw}';
    final cached = _catalogRecordSets[cacheKey];
    if (cached != null) return cached;
    final revision = _cacheRevision;
    if (cancelToken != null) {
      final loaded = List<QuickTagCloudGalleryRecord>.unmodifiable(
        await _loadCatalogRecordSet(catalog, query, cancelToken: cancelToken),
      );
      throwIfCancelled(cancelToken);
      if (revision == _cacheRevision) _cacheCatalogRecords(cacheKey, loaded);
      return loaded;
    }
    final existingLoad = _catalogRecordLoads[cacheKey];
    if (existingLoad != null) return existingLoad;
    final pending = _loadCatalogRecordSet(catalog, query);
    _catalogRecordLoads[cacheKey] = pending;
    try {
      final loaded = List<QuickTagCloudGalleryRecord>.unmodifiable(
        await pending,
      );
      if (revision == _cacheRevision) _cacheCatalogRecords(cacheKey, loaded);
      return loaded;
    } finally {
      if (identical(_catalogRecordLoads[cacheKey], pending)) {
        _catalogRecordLoads.remove(cacheKey);
      }
    }
  }

  Future<QuickTagCloudGalleryRecord> recordFor(
    GalleryItem item, {
    CancelToken? cancelToken,
  }) async {
    throwIfCancelled(cancelToken);
    final cached = _records[item.sourceWorkId];
    if (cached != null) return cached;
    final parts = item.sourceWorkId.split('/');
    if (parts.length != 2) {
      throw const GallerySourceException(
        GallerySourceErrorCode.detailNotFound,
        source: GallerySourceId.quickTagCloud,
      );
    }
    try {
      final codexId = Uri.decodeComponent(parts[0]);
      final entryId = Uri.decodeComponent(parts[1]);
      final catalog = await getCatalog(cancelToken: cancelToken);
      final meta = catalog.findCodex(codexId);
      if (meta != null) {
        final codex = await _catalogService.fetchCodex(
          catalog,
          meta,
          cancelToken: cancelToken,
        );
        QuickTagCloudEntry? entry;
        for (final candidate in codex.entries) {
          if (candidate.id == entryId) {
            entry = candidate;
            break;
          }
        }
        if (entry != null) {
          final record = QuickTagCloudGalleryRecord(
            codex.asMediaMeta(),
            codex,
            entry,
            codex.mediaOverride ?? catalog.media,
          );
          rememberRecord(record);
          return record;
        }
      }
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) rethrow;
      // User-owned snapshots remain usable when the upstream and release cache
      // are both unavailable.
    }
    await _userService.ensureInitialized();
    for (final saved in [..._userService.favorites, ..._userService.recent]) {
      if (saved.stableKey == item.sourceWorkId) {
        final record = QuickTagCloudGalleryRecord(
          saved.meta,
          saved.codex,
          saved.entry,
          saved.media,
        );
        rememberRecord(record);
        return record;
      }
    }
    throw const GallerySourceException(
      GallerySourceErrorCode.detailNotFound,
      source: GallerySourceId.quickTagCloud,
    );
  }

  void rememberRecord(QuickTagCloudGalleryRecord record) {
    _records.remove(record.workId);
    _records[record.workId] = record;
    while (_records.length > 2000) {
      _records.remove(_records.keys.first);
    }
  }

  QuickTagCloudCatalog _acceptCatalog(QuickTagCloudCatalog loaded) {
    if (_catalog?.release != loaded.release) clearDerivedCaches();
    _catalog = loaded;
    _catalogFetchedAt = _clock();
    return loaded;
  }

  void _cacheCatalogRecords(
    String cacheKey,
    List<QuickTagCloudGalleryRecord> records,
  ) {
    _catalogRecordSets.remove(cacheKey);
    _catalogRecordSets[cacheKey] = records;
    while (_catalogRecordSets.length > 3) {
      _catalogRecordSets.remove(_catalogRecordSets.keys.first);
    }
  }

  Future<List<QuickTagCloudGalleryRecord>> _loadCatalogRecordSet(
    QuickTagCloudCatalog catalog,
    QuickTagCloudGalleryQuery query, {
    CancelToken? cancelToken,
  }) async {
    final metas = query.codexId == 'all'
        ? catalog.codexes
        : [
            catalog.findCodex(query.codexId),
          ].whereType<QuickTagCloudCodexMeta>();
    final accessibleMetas = metas
        .where(
          (meta) => !QuickTagCloudAccess.isCodexLocked(
            meta,
            allowNsfw: query.allowNsfw,
          ),
        )
        .toList(growable: false);
    final output = <QuickTagCloudGalleryRecord>[];
    const concurrency = 3;
    for (var start = 0; start < accessibleMetas.length; start += concurrency) {
      throwIfCancelled(cancelToken);
      final batch = accessibleMetas.sublist(
        start,
        min(start + concurrency, accessibleMetas.length),
      );
      final loaded = await Future.wait([
        for (final meta in batch)
          _catalogService.fetchCodex(catalog, meta, cancelToken: cancelToken),
      ]);
      throwIfCancelled(cancelToken);
      for (var index = 0; index < batch.length; index++) {
        final codex = loaded[index];
        final effectiveMeta = codex.asMediaMeta();
        output.addAll(
          codex.entries.map(
            (entry) => QuickTagCloudGalleryRecord(
              effectiveMeta,
              codex,
              entry,
              codex.mediaOverride ?? catalog.media,
            ),
          ),
        );
      }
    }
    return output;
  }

  static void throwIfCancelled(CancelToken? cancelToken) {
    final error = cancelToken?.cancelError;
    if (error != null) throw error;
  }
}

class QuickTagCloudGalleryRecord {
  QuickTagCloudGalleryRecord(this.meta, this.codex, this.entry, this.media);

  final QuickTagCloudCodexMeta meta;
  final QuickTagCloudCodex codex;
  final QuickTagCloudEntry entry;
  final QuickTagCloudMediaConfig media;

  late final List<String> promptTags = List.unmodifiable(
    PromptTagUtils.parseForDisplay(entry.tags),
  );
  late final Set<String> normalizedTags = Set.unmodifiable(
    normalizeGalleryTagSet(promptTags),
  );

  String get workId => quickTagCloudEntryWorkId(codex.id, entry.id);

  QuickTagCloudSavedEntry get savedEntry => QuickTagCloudSavedEntry.fromLive(
    meta: meta,
    codex: codex,
    entry: entry,
    media: media,
  );
}
