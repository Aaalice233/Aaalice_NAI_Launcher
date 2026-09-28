import 'package:dio/dio.dart';

import '../datasources/remote/danbooru_api_service.dart';
import '../datasources/remote/gelbooru_api_service.dart';
import '../datasources/remote/online_gallery/gallery_source_adapter.dart';
import '../models/online_gallery/gallery_item.dart';
import '../models/online_gallery/gallery_source.dart';
import '../models/online_gallery/gelbooru_credentials.dart';

class OnlineGalleryRemoteFavoritesPage {
  const OnlineGalleryRemoteFavoritesPage({
    required this.items,
    required this.rawCount,
  });

  final List<GalleryItem> items;
  final int rawCount;
}

class OnlineGalleryRepository {
  const OnlineGalleryRepository({
    required Map<GallerySourceId, GallerySourceAdapter> adapters,
    required DanbooruApiService danbooruApi,
    required GelbooruApiService gelbooruApi,
  }) : _adapters = adapters,
       _danbooruApi = danbooruApi,
       _gelbooruApi = gelbooruApi;

  final Map<GallerySourceId, GallerySourceAdapter> _adapters;
  final DanbooruApiService _danbooruApi;
  final GelbooruApiService _gelbooruApi;

  GallerySourceAdapter adapter(GallerySourceId sourceId) =>
      _adapters[sourceId]!;

  Future<GalleryPage> search(
    GallerySourceId sourceId,
    GallerySearchRequest request, {
    required CancelToken cancelToken,
  }) => adapter(sourceId).search(request, cancelToken: cancelToken);

  Future<GalleryPage> ranking(
    GallerySourceId sourceId,
    GalleryRankingRequest request, {
    required CancelToken cancelToken,
  }) => adapter(sourceId).ranking(request, cancelToken: cancelToken);

  Future<GalleryPage> random(
    GallerySourceId sourceId,
    GalleryRandomRequest request, {
    required CancelToken cancelToken,
  }) => adapter(sourceId).random(request, cancelToken: cancelToken);

  Future<GalleryDetail> detail(
    GalleryItem item, {
    required CancelToken cancelToken,
  }) => adapter(item.sourceId).detail(item, cancelToken: cancelToken);

  Future<OnlineGalleryRemoteFavoritesPage> danbooruFavorites({
    required String username,
    required int page,
    required int limit,
  }) async {
    final items = await _danbooruApi.getFavorites(
      username: username,
      page: page,
      limit: limit,
    );
    return OnlineGalleryRemoteFavoritesPage(
      items: items,
      rawCount: items.length,
    );
  }

  Future<OnlineGalleryRemoteFavoritesPage> gelbooruFavorites({
    required GelbooruCredentials credentials,
    required int page,
    required int limit,
    required CancelToken cancelToken,
  }) async {
    final result = await _gelbooruApi.getFavorites(
      credentials: credentials,
      pid: page - 1,
      limit: limit,
      cancelToken: cancelToken,
    );
    return OnlineGalleryRemoteFavoritesPage(
      items: result.posts,
      rawCount: result.rawCount,
    );
  }

  Future<bool> addDanbooruFavorite(int postId) =>
      _danbooruApi.addFavorite(postId);

  Future<bool> removeDanbooruFavorite(int postId) =>
      _danbooruApi.removeFavorite(postId);
}
