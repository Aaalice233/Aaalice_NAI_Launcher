import 'dart:math';

import 'package:dio/dio.dart';

import '../../../models/online_gallery/gallery_item.dart';
import '../../../models/online_gallery/gallery_source.dart';
import '../../../services/online_gallery/quick_tag_cloud_access.dart';
import '../../../services/online_gallery/quick_tag_cloud_remote_catalog_service.dart';
import '../../../services/online_gallery/quick_tag_cloud_user_service.dart';
import 'gallery_random_sampler.dart';
import 'gallery_source_adapter.dart';
import 'quick_tag_cloud_gallery_mapper.dart';
import 'quick_tag_cloud_gallery_query.dart';
import 'quick_tag_cloud_gallery_repository.dart';
import 'quick_tag_cloud_query_engine.dart';

class QuickTagCloudGallerySourceAdapter extends GallerySourceAdapter {
  QuickTagCloudGallerySourceAdapter({
    required QuickTagCloudRemoteCatalogService catalogService,
    required QuickTagCloudUserService userService,
    required QuickTagCloudQueryReader queryReader,
    DateTime Function()? clock,
  }) : _userService = userService,
       _queryReader = queryReader,
       _repository = QuickTagCloudGalleryRepository(
         catalogService: catalogService,
         userService: userService,
         clock: clock,
       ) {
    _queryEngine = QuickTagCloudQueryEngine(
      repository: _repository,
      userService: userService,
    );
  }

  static const Duration catalogRefreshInterval =
      QuickTagCloudGalleryRepository.catalogRefreshInterval;

  final QuickTagCloudUserService _userService;
  final QuickTagCloudQueryReader _queryReader;
  final QuickTagCloudGalleryRepository _repository;
  final QuickTagCloudGalleryMapper _mapper = const QuickTagCloudGalleryMapper();
  late final QuickTagCloudQueryEngine _queryEngine;

  @override
  GallerySourceId get sourceId => GallerySourceId.quickTagCloud;

  QuickTagCloudCatalog? get currentCatalog => _repository.currentCatalog;

  Future<QuickTagCloudCatalog> getCatalog({
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) => _repository.getCatalog(
    forceRefresh: forceRefresh,
    cancelToken: cancelToken,
  );

  Future<QuickTagCloudCodex> getCodex(
    String codexId, {
    CancelToken? cancelToken,
  }) => _repository.getCodex(codexId, cancelToken: cancelToken);

  void invalidateCatalog() {
    _repository.invalidateCatalog();
    _queryEngine.clearCaches();
  }

  Future<void> clearDiskCache() async {
    await _repository.clearDiskCache();
    _queryEngine.clearCaches();
  }

  Future<Set<String>> favoriteKeys() async {
    await _userService.ensureInitialized();
    return _userService.favoriteKeys
        .map((key) => sourceId.stableItemKey(key))
        .toSet();
  }

  Future<bool> toggleFavorite(GalleryItem item) async {
    final record = await _repository.recordFor(item);
    final favorited = await _userService.toggleFavorite(record.savedEntry);
    _queryEngine.clearCaches();
    return favorited;
  }

  Future<void> recordViewed(GalleryItem item) async {
    final record = await _repository.recordFor(item);
    await _userService.recordViewed(record.savedEntry);
    _queryEngine.clearCaches();
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
    QuickTagCloudGalleryRepository.throwIfCancelled(cancelToken);
    final query = _queryForRatings(_queryReader(), request.ratings);
    final records = await _queryEngine.matchingRecords(
      query,
      searchText: request.query,
      selectedRatings: request.ratings,
      cancelToken: cancelToken,
    );
    final page = galleryCursorPage(request.cursor);
    final start = (page - 1) * request.pageSize;
    final pageRecords = start >= records.length
        ? const <QuickTagCloudGalleryRecord>[]
        : records.sublist(start, min(start + request.pageSize, records.length));
    for (final record in pageRecords) {
      _repository.rememberRecord(record);
    }
    final items = pageRecords
        .map(_mapper.toGalleryItem)
        .toList(growable: false);
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
    QuickTagCloudGalleryRepository.throwIfCancelled(cancelToken);
    final galleryQuery = _queryForRatings(_queryReader(), request.ratings);
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
    final records = await _queryEngine.matchingRecords(
      galleryQuery,
      searchText: searchText,
      selectedRatings: request.ratings,
      cancelToken: cancelToken,
      sortByRelevance: false,
    );
    QuickTagCloudGalleryRepository.throwIfCancelled(cancelToken);
    final pageRecords = GalleryRandomSampler().permutationSlice(
      records,
      seed: seed,
      offset: offset,
      count: request.pageSize,
    );
    final nextOffset = offset + pageRecords.length;
    final hasMore = nextOffset < records.length;
    for (final record in pageRecords) {
      _repository.rememberRecord(record);
    }
    final items = pageRecords
        .map(_mapper.toGalleryItem)
        .toList(growable: false);
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
    QuickTagCloudGalleryRepository.throwIfCancelled(cancelToken);
    final record = await _repository.recordFor(item, cancelToken: cancelToken);
    return _mapper.toGalleryDetail(record);
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
}
