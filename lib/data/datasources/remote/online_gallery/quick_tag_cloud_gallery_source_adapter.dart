import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../models/online_gallery/gallery_item.dart';
import '../../../models/online_gallery/gallery_source.dart';
import '../../../services/online_gallery/quick_tag_cloud_access.dart';
import '../../../services/online_gallery/quick_tag_cloud_media_resolver.dart';
import '../../../services/online_gallery/quick_tag_cloud_remote_catalog_service.dart';
import '../../../services/online_gallery/quick_tag_cloud_user_service.dart';
import 'gallery_source_adapter.dart';

enum QuickTagCloudBrowseScope { catalog, latest, recent }

enum QuickTagCloudMediaFilter { all, withImages, withoutImages }

class QuickTagCloudGalleryQuery {
  const QuickTagCloudGalleryQuery({
    this.codexId = 'suozhang',
    this.categoryPath = const [],
    this.updateFilterId = '',
    this.scope = QuickTagCloudBrowseScope.catalog,
    this.mediaFilter = QuickTagCloudMediaFilter.all,
    this.allowNsfw = false,
    this.allowR18g = false,
    this.favoritesOnly = false,
  });

  static const defaultStableKey = 'suozhang|||catalog|all|false|false|false';

  static QuickTagCloudGalleryQuery? tryParseStableKey(String? value) {
    if (value == null || value.length > 4096) return null;
    final parts = value.split('|');
    if (parts.length != 8) return null;
    try {
      final codexId = Uri.decodeComponent(parts[0]);
      if (codexId.isEmpty) return null;
      final categoryPath = parts[1].isEmpty
          ? const <String>[]
          : parts[1]
                .split('/')
                .map(Uri.decodeComponent)
                .where((part) => part.isNotEmpty)
                .toList(growable: false);
      final updateFilterId = Uri.decodeComponent(parts[2]);
      final scope = _enumByName(QuickTagCloudBrowseScope.values, parts[3]);
      final mediaFilter = _enumByName(
        QuickTagCloudMediaFilter.values,
        parts[4],
      );
      final allowNsfw = _parseStableKeyBool(parts[5]);
      final allowR18g = _parseStableKeyBool(parts[6]);
      final favoritesOnly = _parseStableKeyBool(parts[7]);
      if (scope == null ||
          mediaFilter == null ||
          allowNsfw == null ||
          allowR18g == null ||
          favoritesOnly == null) {
        return null;
      }
      return QuickTagCloudGalleryQuery(
        codexId: codexId,
        categoryPath: categoryPath,
        updateFilterId: updateFilterId,
        scope: scope,
        mediaFilter: mediaFilter,
        allowNsfw: allowNsfw,
        allowR18g: allowR18g,
        favoritesOnly: favoritesOnly,
      );
    } on FormatException {
      return null;
    }
  }

  final String codexId;
  final List<String> categoryPath;
  final String updateFilterId;
  final QuickTagCloudBrowseScope scope;
  final QuickTagCloudMediaFilter mediaFilter;
  final bool allowNsfw;
  final bool allowR18g;
  final bool favoritesOnly;

  String get stableKey => [
    Uri.encodeComponent(codexId),
    categoryPath.map(Uri.encodeComponent).join('/'),
    Uri.encodeComponent(updateFilterId),
    scope.name,
    mediaFilter.name,
    allowNsfw,
    allowR18g,
    favoritesOnly,
  ].join('|');
}

T? _enumByName<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

bool? _parseStableKeyBool(String value) => switch (value) {
  'true' => true,
  'false' => false,
  _ => null,
};

typedef QuickTagCloudQueryReader = QuickTagCloudGalleryQuery Function();

class QuickTagCloudGallerySourceAdapter extends GallerySourceAdapter {
  QuickTagCloudGallerySourceAdapter({
    required QuickTagCloudRemoteCatalogService catalogService,
    required QuickTagCloudUserService userService,
    required QuickTagCloudQueryReader queryReader,
    DateTime Function()? clock,
  }) : _catalogService = catalogService,
       _userService = userService,
       _queryReader = queryReader,
       _clock = clock ?? DateTime.now;

  static const Duration catalogRefreshInterval = Duration(minutes: 15);

  final QuickTagCloudRemoteCatalogService _catalogService;
  final QuickTagCloudUserService _userService;
  final QuickTagCloudQueryReader _queryReader;
  final DateTime Function() _clock;
  final Map<String, _QuickTagCloudRecord> _records = {};
  final Map<String, List<_QuickTagCloudRecord>> _catalogRecordSets = {};
  final Map<String, Future<List<_QuickTagCloudRecord>>> _catalogRecordLoads =
      {};
  final Map<String, List<_QuickTagCloudRecord>> _matchingRecordSets = {};
  final Map<String, String> _searchHaystacks = {};
  int _cacheRevision = 0;

  QuickTagCloudCatalog? _catalog;
  DateTime? _catalogFetchedAt;
  Future<QuickTagCloudCatalog>? _catalogRequest;

  @override
  GallerySourceId get sourceId => GallerySourceId.quickTagCloud;

  QuickTagCloudCatalog? get currentCatalog => _catalog;

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
      _throwIfCancelled(cancelToken);
      final loaded = await _catalogService.fetchCatalog(
        cancelToken: cancelToken,
      );
      _throwIfCancelled(cancelToken);
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

  QuickTagCloudCatalog _acceptCatalog(QuickTagCloudCatalog loaded) {
    if (_catalog?.release != loaded.release) _clearDerivedCaches();
    _catalog = loaded;
    _catalogFetchedAt = _clock();
    return loaded;
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
    _clearDerivedCaches();
    _catalogService.clearMemoryCache();
  }

  Future<void> clearDiskCache() async {
    _catalog = null;
    _catalogFetchedAt = null;
    _catalogRequest = null;
    _clearDerivedCaches();
    await _catalogService.clearDiskCache();
  }

  void _clearDerivedCaches() {
    _cacheRevision++;
    _records.clear();
    _catalogRecordSets.clear();
    _catalogRecordLoads.clear();
    _matchingRecordSets.clear();
    _searchHaystacks.clear();
  }

  Future<Set<String>> favoriteKeys() async {
    await _userService.ensureInitialized();
    return _userService.favoriteKeys
        .map((key) => sourceId.stableItemKey(key))
        .toSet();
  }

  Future<bool> toggleFavorite(GalleryItem item) async {
    final record = await _recordFor(item);
    final favorited = await _userService.toggleFavorite(record.savedEntry);
    _matchingRecordSets.clear();
    return favorited;
  }

  Future<void> recordViewed(GalleryItem item) async {
    final record = await _recordFor(item);
    await _userService.recordViewed(record.savedEntry);
    _matchingRecordSets.clear();
  }

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) => _mapSourceErrors(() => _search(request, cancelToken: cancelToken));

  Future<GalleryPage> _search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    _throwIfCancelled(cancelToken);
    final query = _queryForRatings(_queryReader(), request.ratings);
    final records = await _matchingRecords(
      query,
      searchText: request.query,
      selectedRatings: request.ratings,
      cancelToken: cancelToken,
    );
    final page = galleryCursorPage(request.cursor);
    final start = (page - 1) * request.pageSize;
    final pageRecords = start >= records.length
        ? const <_QuickTagCloudRecord>[]
        : records.sublist(start, min(start + request.pageSize, records.length));
    for (final record in pageRecords) {
      _rememberRecord(record);
    }
    final items = pageRecords.map(_toGalleryItem).toList(growable: false);
    final hasMore = start + items.length < records.length;
    return GalleryPage(
      items: items,
      cursor: '$page',
      nextCursor: hasMore ? '${page + 1}' : null,
      hasMore: hasMore,
      total: records.length,
      rawItemCount: items.length,
    );
  }

  @override
  Future<GalleryPage> random(
    GalleryRandomRequest request, {
    CancelToken? cancelToken,
  }) => _mapSourceErrors(() => _random(request, cancelToken: cancelToken));

  Future<GalleryPage> _random(
    GalleryRandomRequest request, {
    CancelToken? cancelToken,
  }) async {
    _throwIfCancelled(cancelToken);
    final query = _queryForRatings(_queryReader(), request.ratings);
    final searchText = switch (request) {
      GalleryRandomSearchRequest(:final query) => query,
      GalleryRandomRankingRequest(:final query) => query,
      GalleryRandomFavoritesRequest() => '',
    };
    final cursor = switch (request) {
      GalleryRandomSearchRequest(:final cursor) => cursor,
      GalleryRandomRankingRequest(:final cursor) => cursor,
      GalleryRandomFavoritesRequest(:final cursor) => cursor,
    };
    final cursorParts = cursor?.split(':') ?? const <String>[];
    final parsedSeed = cursorParts.length == 2
        ? int.tryParse(cursorParts.first)
        : null;
    final parsedOffset = cursorParts.length == 2
        ? int.tryParse(cursorParts.last)
        : null;
    final seed = parsedSeed ?? randomGenerator.nextInt(0x7fffffff);
    final offset = parsedOffset == null || parsedOffset < 0 ? 0 : parsedOffset;
    final records = await _matchingRecords(
      query,
      searchText: searchText,
      selectedRatings: request.ratings,
      cancelToken: cancelToken,
    );
    final shuffled = List<_QuickTagCloudRecord>.of(records)
      ..shuffle(Random(seed));
    final pageRecords = offset >= shuffled.length
        ? const <_QuickTagCloudRecord>[]
        : shuffled.sublist(
            offset,
            min(offset + request.pageSize, shuffled.length),
          );
    final nextOffset = offset + pageRecords.length;
    final hasMore = nextOffset < shuffled.length;
    for (final record in pageRecords) {
      _rememberRecord(record);
    }
    final items = pageRecords.map(_toGalleryItem).toList(growable: false);
    return GalleryPage(
      items: items,
      cursor: '$seed:$offset',
      nextCursor: hasMore ? '$seed:$nextOffset' : null,
      hasMore: hasMore,
      total: records.length,
      rawItemCount: items.length,
    );
  }

  @override
  Future<GalleryDetail> detail(GalleryItem item, {CancelToken? cancelToken}) =>
      _mapSourceErrors(() => _detail(item, cancelToken: cancelToken));

  Future<GalleryDetail> _detail(
    GalleryItem item, {
    CancelToken? cancelToken,
  }) async {
    _throwIfCancelled(cancelToken);
    final record = await _recordFor(item, cancelToken: cancelToken);
    final media = [
      for (final item in _mediaFor(record))
        item.copyWith(
          displayUrl: item.downloadUrl.isEmpty
              ? item.displayUrl
              : item.downloadUrl,
        ),
    ];
    return GalleryDetail(
      item: _toGalleryItem(record),
      media: media,
      prompt: record.entry.tags,
      negativePrompt: record.entry.negative,
      description: record.entry.note,
      categoryPath: record.entry.path,
      note: record.entry.note,
      rawTags: record.entry.rawTag.isEmpty ? const [] : [record.entry.rawTag],
      characterPrompts: [
        for (final character in record.entry.characterPrompts)
          GalleryCharacterPrompt(
            label: character.label,
            prompt: character.prompt,
            negativePrompt: character.negative,
          ),
      ],
      contributors: [
        for (final contributor in record.meta.contributors)
          GalleryContributor(name: contributor.name, role: contributor.role),
      ],
      sourceUrl: _sourceUrl(record),
      rawSourceMetadata: _metadataFor(record),
    );
  }

  Future<_QuickTagCloudRecord> _recordFor(
    GalleryItem item, {
    CancelToken? cancelToken,
  }) async {
    _throwIfCancelled(cancelToken);
    final cached = _records[item.sourceWorkId];
    if (cached != null) return cached;
    final parts = item.sourceWorkId.split('/');
    if (parts.length != 2) {
      throw GallerySourceException(
        GallerySourceErrorCode.detailNotFound,
        source: sourceId,
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
          final record = _QuickTagCloudRecord(
            codex.asMediaMeta(),
            codex,
            entry,
            codex.mediaOverride ?? catalog.media,
          );
          _rememberRecord(record);
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
        final record = _QuickTagCloudRecord(
          saved.meta,
          saved.codex,
          saved.entry,
          saved.media,
        );
        _rememberRecord(record);
        return record;
      }
    }
    throw GallerySourceException(
      GallerySourceErrorCode.detailNotFound,
      source: sourceId,
    );
  }

  QuickTagCloudGalleryQuery _queryForRatings(
    QuickTagCloudGalleryQuery query,
    Set<String> ratings,
  ) => QuickTagCloudGalleryQuery(
    codexId: query.codexId,
    categoryPath: query.categoryPath,
    updateFilterId: query.updateFilterId,
    scope: query.scope,
    mediaFilter: query.mediaFilter,
    allowNsfw: QuickTagCloudAccess.allowsNsfw(ratings),
    allowR18g: QuickTagCloudAccess.allowsR18g(ratings),
    favoritesOnly: query.favoritesOnly,
  );

  Future<List<_QuickTagCloudRecord>> _matchingRecords(
    QuickTagCloudGalleryQuery query, {
    required String searchText,
    required Set<String> selectedRatings,
    CancelToken? cancelToken,
  }) async {
    _throwIfCancelled(cancelToken);
    await _userService.ensureInitialized();
    final saved = query.favoritesOnly
        ? _userService.favorites
        : query.scope == QuickTagCloudBrowseScope.recent
        ? _userService.recent
        : null;
    final records = saved != null
        ? [
            for (final item in saved)
              _QuickTagCloudRecord(
                item.meta,
                item.codex,
                item.entry,
                item.media,
              ),
          ]
        : await _loadCatalogRecords(query, cancelToken: cancelToken);
    final cacheRevision = _cacheRevision;
    final normalizedSearch = searchText.trim().toLowerCase();
    final ratingsKey = (selectedRatings.toList()..sort()).join();
    final matchingCacheKey = saved == null
        ? '${_catalog?.release ?? ''}|${query.stableKey}|$ratingsKey|$normalizedSearch'
        : null;
    final cachedMatches = matchingCacheKey == null
        ? null
        : _matchingRecordSets[matchingCacheKey];
    if (cachedMatches != null) return cachedMatches;
    final terms = normalizedSearch
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    final filtered = <_QuickTagCloudRecord>[];
    final cacheSearchHaystacks = records.length <= 5000;
    for (var index = 0; index < records.length; index++) {
      if (index % 256 == 0) _throwIfCancelled(cancelToken);
      final record = records[index];
      if (!_isAccessible(record, query, selectedRatings)) continue;
      if (!_matchesCodex(record, query.codexId)) continue;
      if (!_matchesCategory(record.entry.path, query.categoryPath)) continue;
      if (query.scope == QuickTagCloudBrowseScope.latest &&
          !_matchesLatest(record)) {
        continue;
      }
      if (query.updateFilterId.isNotEmpty &&
          !_matchesUpdateFilter(record, query.updateFilterId)) {
        continue;
      }
      if (query.mediaFilter == QuickTagCloudMediaFilter.withImages &&
          !record.entry.hasImage) {
        continue;
      }
      if (query.mediaFilter == QuickTagCloudMediaFilter.withoutImages &&
          record.entry.hasImage) {
        continue;
      }
      if (terms.isNotEmpty) {
        final haystack = _searchHaystack(record, cache: cacheSearchHaystacks);
        if (!terms.every(haystack.contains)) continue;
      }
      filtered.add(record);
    }
    _throwIfCancelled(cancelToken);
    if (terms.isNotEmpty) {
      filtered.sort((left, right) {
        final leftScore = _searchScore(left, normalizedSearch);
        final rightScore = _searchScore(right, normalizedSearch);
        return rightScore.compareTo(leftScore);
      });
    }
    final result = List<_QuickTagCloudRecord>.unmodifiable(filtered);
    if (matchingCacheKey != null && cacheRevision == _cacheRevision) {
      _matchingRecordSets.remove(matchingCacheKey);
      _matchingRecordSets[matchingCacheKey] = result;
      while (_matchingRecordSets.length > 4) {
        _matchingRecordSets.remove(_matchingRecordSets.keys.first);
      }
    }
    return result;
  }

  Future<List<_QuickTagCloudRecord>> _loadCatalogRecords(
    QuickTagCloudGalleryQuery query, {
    CancelToken? cancelToken,
  }) async {
    final catalog = await getCatalog(cancelToken: cancelToken);
    final cacheKey = '${catalog.release}|${query.codexId}|${query.allowNsfw}';
    final cached = _catalogRecordSets[cacheKey];
    if (cached != null) return cached;
    final cacheRevision = _cacheRevision;
    if (cancelToken != null) {
      final loaded = List<_QuickTagCloudRecord>.unmodifiable(
        await _loadCatalogRecordSet(catalog, query, cancelToken: cancelToken),
      );
      _throwIfCancelled(cancelToken);
      if (cacheRevision == _cacheRevision) {
        _cacheCatalogRecords(cacheKey, loaded);
      }
      return loaded;
    }
    final existingLoad = _catalogRecordLoads[cacheKey];
    if (existingLoad != null) return existingLoad;
    final pending = _loadCatalogRecordSet(catalog, query);
    _catalogRecordLoads[cacheKey] = pending;
    try {
      final loaded = List<_QuickTagCloudRecord>.unmodifiable(await pending);
      if (cacheRevision == _cacheRevision) {
        _cacheCatalogRecords(cacheKey, loaded);
      }
      return loaded;
    } finally {
      if (identical(_catalogRecordLoads[cacheKey], pending)) {
        _catalogRecordLoads.remove(cacheKey);
      }
    }
  }

  void _cacheCatalogRecords(
    String cacheKey,
    List<_QuickTagCloudRecord> records,
  ) {
    _catalogRecordSets.remove(cacheKey);
    _catalogRecordSets[cacheKey] = records;
    while (_catalogRecordSets.length > 3) {
      _catalogRecordSets.remove(_catalogRecordSets.keys.first);
    }
  }

  Future<List<_QuickTagCloudRecord>> _loadCatalogRecordSet(
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
    final output = <_QuickTagCloudRecord>[];
    const concurrency = 3;
    for (var start = 0; start < accessibleMetas.length; start += concurrency) {
      _throwIfCancelled(cancelToken);
      final batch = accessibleMetas.sublist(
        start,
        min(start + concurrency, accessibleMetas.length),
      );
      final loaded = await Future.wait([
        for (final meta in batch)
          _catalogService.fetchCodex(catalog, meta, cancelToken: cancelToken),
      ]);
      _throwIfCancelled(cancelToken);
      for (var index = 0; index < batch.length; index++) {
        final codex = loaded[index];
        final effectiveMeta = codex.asMediaMeta();
        output.addAll(
          codex.entries.map(
            (entry) => _QuickTagCloudRecord(
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

  bool _isAccessible(
    _QuickTagCloudRecord record,
    QuickTagCloudGalleryQuery query,
    Set<String> selectedRatings,
  ) {
    if (QuickTagCloudAccess.isCodexLocked(
      record.codex,
      allowNsfw: query.allowNsfw,
    )) {
      return false;
    }
    if (QuickTagCloudAccess.isEntryAccessBlocked(
      record.entry,
      allowNsfw: query.allowNsfw,
      allowR18g: query.allowR18g,
    )) {
      return false;
    }
    return QuickTagCloudAccess.matchesGalleryRatings(
      record.entry,
      codex: record.codex,
      selectedRatings: selectedRatings,
    );
  }

  bool _matchesCodex(_QuickTagCloudRecord record, String selectedId) {
    if (selectedId == 'all' || record.codex.id == selectedId) return true;
    if (record.codex.aliases.contains(selectedId)) return true;
    final selected = _catalog?.findCodex(selectedId);
    if (selected == null) return false;
    final savedIdentities = {record.codex.id, ...record.codex.aliases};
    return selected.aliases.any(savedIdentities.contains);
  }

  bool _matchesCategory(List<String> path, List<String> selected) {
    if (selected.isEmpty) return true;
    if (path.length < selected.length) return false;
    for (var index = 0; index < selected.length; index++) {
      if (path[index] != selected[index]) return false;
    }
    return true;
  }

  bool _matchesLatest(_QuickTagCloudRecord record) {
    if (record.entry.isNew) return true;
    final latestIds = record.meta.updateFilters
        .where((filter) => filter.latest)
        .map((filter) => filter.id)
        .toSet();
    return record.entry.updateBatches.any(latestIds.contains);
  }

  bool _matchesUpdateFilter(_QuickTagCloudRecord record, String filterId) =>
      record.entry.updateBatches.contains(filterId) ||
      filterId == 'latest' && _matchesLatest(record);

  String _searchHaystack(_QuickTagCloudRecord record, {required bool cache}) {
    String build() => [
      record.entry.title,
      record.entry.tags,
      record.entry.negative,
      record.entry.note,
      record.entry.rating,
      record.entry.rawTag,
      record.entry.path.join(' '),
      record.entry.updateBatches.join(' '),
      record.entry.characterPrompts
          .map(
            (character) =>
                '${character.label} ${character.prompt} ${character.negative}',
          )
          .join(' '),
      record.entry.images
          .map(
            (image) => [
              image.rawTag,
              _rawSearchValue(image.raw, 'author'),
              _rawSearchValue(image.raw, 'credit'),
              _rawSearchValue(image.raw, 'rawTags'),
            ].join(' '),
          )
          .join(' '),
      _rawSearchValue(record.entry.raw, 'author'),
      _rawSearchValue(record.entry.raw, 'credit'),
      _rawSearchValue(record.entry.raw, 'rawTags'),
      _rawSearchValue(record.entry.raw, 'type'),
      record.codex.title,
      record.codex.author,
      record.codex.source,
      record.codex.type,
      record.codex.version,
      record.codex.aliases.join(' '),
      record.meta.contributors
          .map((item) => '${item.name} ${item.role}')
          .join(' '),
      record.meta.links.map((item) => '${item.label} ${item.url}').join(' '),
    ].join('\n').toLowerCase();

    return cache ? _searchHaystacks.putIfAbsent(record.workId, build) : build();
  }

  String _rawSearchValue(Map<String, dynamic> raw, String key) {
    final value = raw[key];
    if (value is Iterable) return value.join(' ');
    return value?.toString() ?? '';
  }

  int _searchScore(_QuickTagCloudRecord record, String query) {
    final title = record.entry.title.toLowerCase();
    if (title == query) return 4;
    if (title.startsWith(query)) return 3;
    if (title.contains(query)) return 2;
    return 1;
  }

  GalleryItem _toGalleryItem(_QuickTagCloudRecord record) {
    final media = _mediaFor(record);
    final cover = media.isEmpty
        ? const GalleryMedia(id: 'no-image')
        : media.first;
    final entry = record.entry;
    return GalleryItem(
      id: _stableNumericId(record.workId),
      workId: record.workId,
      sourceId: sourceId,
      site: sourceId.key,
      title: entry.title,
      author: _displayAttribution(record),
      description: entry.note,
      createdAt: record.codex.version,
      source: _sourceUrl(record),
      rating: QuickTagCloudAccess.galleryRating(entry, codex: record.codex),
      imageWidth: cover.width,
      imageHeight: cover.height,
      tagString: entry.tags,
      tags: _promptTags(entry.tags),
      fileExt: cover.extension,
      fileUrl: cover.downloadUrl.isEmpty ? null : cover.downloadUrl,
      largeFileUrl: cover.displayUrl.isEmpty ? null : cover.displayUrl,
      previewFileUrl: cover.previewUrl.isEmpty ? null : cover.previewUrl,
      cover: cover,
      mediaCount: media.length,
      rawSourceMetadata: _metadataFor(record),
    );
  }

  List<GalleryMedia> _mediaFor(_QuickTagCloudRecord record) {
    final resolver = QuickTagCloudMediaResolver(media: record.media);
    final images = record.entry.images;
    return [
      for (var index = 0; index < images.length; index++)
        _galleryMedia(resolver, record, images[index], index),
    ];
  }

  GalleryMedia _galleryMedia(
    QuickTagCloudMediaResolver resolver,
    _QuickTagCloudRecord record,
    QuickTagCloudImage image,
    int index,
  ) {
    final preview = resolver.imageItemUrl(
      QuickTagCloudMediaKind.image,
      record.entry,
      image,
      record.codex,
    );
    final hasOriginal = record.codex.hasOriginal && image.hasOriginal;
    final original = hasOriginal
        ? resolver.imageItemUrl(
            QuickTagCloudMediaKind.original,
            record.entry,
            image,
            record.codex,
          )
        : preview;
    final dimensions = image.dimensions.isKnown
        ? image.dimensions
        : record.entry.dimensions;
    final parsedExtension = p
        .extension(Uri.tryParse(original)?.path ?? '')
        .replaceFirst('.', '')
        .toLowerCase();
    final extension = RegExp(r'^[a-z0-9]{1,10}$').hasMatch(parsedExtension)
        ? parsedExtension
        : '';
    return GalleryMedia(
      id: '${record.workId}:$index',
      previewUrl: preview,
      displayUrl: preview,
      downloadUrl: original,
      width: dimensions.width,
      height: dimensions.height,
      extension: extension.isEmpty ? null : extension,
      rawMetadata: image.rawTag.isEmpty ? record.entry.rawTag : image.rawTag,
      prompt: record.entry.tags,
      negativePrompt: record.entry.negative,
      metadata: <String, dynamic>{...image.raw, 'hasOriginal': hasOriginal},
    );
  }

  Map<String, dynamic> _metadataFor(_QuickTagCloudRecord record) => {
    'codexId': record.codex.id,
    'codexTitle': record.codex.title,
    'codexVersion': record.codex.version,
    'codexAuthor': record.codex.author,
    'codexNsfw': record.codex.nsfw,
    'loadSource': record.codex.loadSource.name,
    'sourceRelease': record.codex.sourceRelease,
    'entryId': record.entry.id,
    'entryAuthor': record.entry.author,
    'entryCredit': record.entry.credit,
    'detailRevision': _detailRevision(record),
    'prompt': record.entry.tags,
    'negativePrompt': record.entry.negative,
    'note': record.entry.note,
    'categoryPath': record.entry.path,
    'rawTag': record.entry.rawTag,
    'characterPrompts': [
      for (final character in record.entry.characterPrompts)
        {
          'label': character.label,
          'prompt': character.prompt,
          'negative': character.negative,
        },
    ],
    'contributors': [
      for (final contributor in record.meta.contributors)
        {'name': contributor.name, 'role': contributor.role},
    ],
    'sourceUrl': _sourceUrl(record),
    'declaredSource': record.codex.source,
    'entry': record.entry.raw,
  };

  String _displayAttribution(_QuickTagCloudRecord record) {
    final values = <String>[];
    for (final value in [
      record.entry.credit,
      record.entry.author,
      record.codex.author,
    ]) {
      final normalized = value.trim();
      if (normalized.isNotEmpty && !values.contains(normalized)) {
        values.add(normalized);
      }
    }
    return values.join(' · ');
  }

  String _detailRevision(_QuickTagCloudRecord record) => _stableNumericId(
    jsonEncode({
      'release': record.codex.sourceRelease,
      'version': record.codex.version,
      'assetBaseUrl': record.codex.assetBaseUrl,
      'mediaBaseUrl': record.media.baseUrl,
      'entry': record.entry.raw,
    }),
  ).toRadixString(16);

  String _sourceUrl(_QuickTagCloudRecord record) {
    for (final value in [
      ...record.meta.links.map((link) => link.url),
      record.codex.source,
      record.codex.sourceDataUrl,
    ]) {
      final uri = Uri.tryParse(value);
      if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
        return uri.toString();
      }
    }
    return '';
  }

  void _rememberRecord(_QuickTagCloudRecord record) {
    _records.remove(record.workId);
    _records[record.workId] = record;
    while (_records.length > 2000) {
      _records.remove(_records.keys.first);
    }
  }

  void _throwIfCancelled(CancelToken? cancelToken) {
    final error = cancelToken?.cancelError;
    if (error != null) throw error;
  }

  Future<T> _mapSourceErrors<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on GallerySourceException {
      rethrow;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw mapGalleryDioException(error, sourceId);
    } on QuickTagCloudIntegrityException catch (error) {
      throw GallerySourceException(
        GallerySourceErrorCode.malformedResponse,
        source: sourceId,
        cause: error,
      );
    } on FormatException catch (error) {
      throw GallerySourceException(
        GallerySourceErrorCode.malformedResponse,
        source: sourceId,
        cause: error,
      );
    } catch (error) {
      throw GallerySourceException(
        GallerySourceErrorCode.unknown,
        source: sourceId,
        cause: error,
      );
    }
  }

  List<String> _promptTags(String prompt) => prompt
      .split(RegExp(r'[,，\n]+'))
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toList(growable: false);

  int _stableNumericId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}

class _QuickTagCloudRecord {
  const _QuickTagCloudRecord(this.meta, this.codex, this.entry, this.media);

  final QuickTagCloudCodexMeta meta;
  final QuickTagCloudCodex codex;
  final QuickTagCloudEntry entry;
  final QuickTagCloudMediaConfig media;

  String get workId => quickTagCloudEntryWorkId(codex.id, entry.id);

  QuickTagCloudSavedEntry get savedEntry => QuickTagCloudSavedEntry.fromLive(
    meta: meta,
    codex: codex,
    entry: entry,
    media: media,
  );
}
