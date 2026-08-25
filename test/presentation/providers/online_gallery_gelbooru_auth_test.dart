import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/danbooru_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/gelbooru_api_service.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/data/models/online_gallery/gelbooru_credentials.dart';
import 'package:nai_launcher/data/services/gelbooru_auth_service.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_local_favorites_provider.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const credentials = GelbooruCredentials(userId: 99, apiKey: 'gel-key');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer createContainer({
    String? storedCredentials,
    _FakeGelbooruApiService? gelbooruApi,
    _GalleryHttpAdapter? httpAdapter,
    _FakeDanbooruApiService? danbooruApi,
  }) {
    final adapter = httpAdapter ?? _GalleryHttpAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    return ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(
          _FakeSecureStorage(gelbooru: storedCredentials),
        ),
        gelbooruApiServiceProvider.overrideWithValue(
          gelbooruApi ?? _FakeGelbooruApiService(),
        ),
        onlineGalleryHttpClientProvider.overrideWithValue(dio),
        danbooruApiServiceProvider.overrideWithValue(
          danbooruApi ?? _FakeDanbooruApiService(),
        ),
      ],
    );
  }

  String stored(GelbooruCredentials value) => jsonEncode(value.toJson());

  test('without credentials, Gelbooru goes directly to public HTML', () async {
    final gelbooruApi = _FakeGelbooruApiService();
    final httpAdapter = _GalleryHttpAdapter();
    final container = createContainer(
      gelbooruApi: gelbooruApi,
      httpAdapter: httpAdapter,
    );
    addTearDown(container.dispose);

    await container
        .read(onlineGalleryNotifierProvider.notifier)
        .setSource('gelbooru');

    expect(gelbooruApi.searchCalls, 0);
    expect(
      httpAdapter.requests.where(
        (request) => request.queryParameters['page'] == 'dapi',
      ),
      isEmpty,
    );
    expect(httpAdapter.requests.first.queryParameters['page'], 'post');
    expect(container.read(onlineGalleryNotifierProvider).posts, hasLength(1));
  });

  test(
    'valid credentials use one DAPI call and skip dimension probes',
    () async {
      final gelbooruApi = _FakeGelbooruApiService(
        searchResult: GelbooruPostPage(posts: [_gelbooruPost(7)], rawCount: 1),
      );
      final httpAdapter = _GalleryHttpAdapter();
      final container = createContainer(
        storedCredentials: stored(credentials),
        gelbooruApi: gelbooruApi,
        httpAdapter: httpAdapter,
      );
      addTearDown(container.dispose);

      await container
          .read(onlineGalleryNotifierProvider.notifier)
          .setSource('gelbooru');

      expect(gelbooruApi.searchCalls, 1);
      expect(httpAdapter.requests, isEmpty);
      final post = container.read(onlineGalleryNotifierProvider).posts.single;
      expect(post.width, 1200);
      expect(post.height, 800);
    },
  );

  test('invalid credentials fall back once and mark auth invalid', () async {
    final gelbooruApi = _FakeGelbooruApiService(
      searchError: const GelbooruApiException(
        GelbooruApiErrorType.invalidCredentials,
        statusCode: 401,
      ),
    );
    final httpAdapter = _GalleryHttpAdapter();
    final container = createContainer(
      storedCredentials: stored(credentials),
      gelbooruApi: gelbooruApi,
      httpAdapter: httpAdapter,
    );
    addTearDown(container.dispose);

    await container
        .read(onlineGalleryNotifierProvider.notifier)
        .setSource('gelbooru');

    final galleryState = container.read(onlineGalleryNotifierProvider);
    expect(galleryState.posts, hasLength(1));
    expect(galleryState.notice, OnlineGalleryNotice.gelbooruCredentialsInvalid);
    expect(
      container.read(gelbooruAuthProvider).status,
      GelbooruAuthStatus.invalid,
    );
    expect(
      httpAdapter.requests.where(
        (request) => request.queryParameters['page'] == 'post',
      ),
      hasLength(1),
    );
  });

  test('rate limits keep credentials and do not add an HTML request', () async {
    final gelbooruApi = _FakeGelbooruApiService(
      searchError: const GelbooruApiException(
        GelbooruApiErrorType.rateLimited,
        statusCode: 429,
      ),
    );
    final httpAdapter = _GalleryHttpAdapter();
    final container = createContainer(
      storedCredentials: stored(credentials),
      gelbooruApi: gelbooruApi,
      httpAdapter: httpAdapter,
    );
    addTearDown(container.dispose);

    await container
        .read(onlineGalleryNotifierProvider.notifier)
        .setSource('gelbooru');

    expect(httpAdapter.requests, isEmpty);
    expect(
      container.read(onlineGalleryNotifierProvider).errorCode,
      OnlineGalleryErrorCode.gelbooruRateLimited,
    );
    expect(container.read(gelbooruAuthProvider).isAuthenticated, isTrue);
  });

  test('Danbooru search routing remains on posts.json', () async {
    final gelbooruApi = _FakeGelbooruApiService();
    final httpAdapter = _GalleryHttpAdapter();
    final container = createContainer(
      storedCredentials: stored(credentials),
      gelbooruApi: gelbooruApi,
      httpAdapter: httpAdapter,
    );
    addTearDown(container.dispose);

    await container
        .read(onlineGalleryNotifierProvider.notifier)
        .loadPosts(refresh: true);

    expect(gelbooruApi.searchCalls, 0);
    expect(httpAdapter.requests.single.uri.path, '/posts.json');
    expect(
      container.read(onlineGalleryNotifierProvider).posts.single.site,
      'danbooru',
    );
  });

  test(
    'Gelbooru favorites are source-scoped and never call Danbooru writes',
    () async {
      final gelbooruApi = _FakeGelbooruApiService(
        favoritesResult: GelbooruPostPage(
          posts: [_gelbooruPost(123)],
          rawCount: 1,
        ),
      );
      final danbooruApi = _FakeDanbooruApiService();
      final container = createContainer(
        storedCredentials: stored(credentials),
        gelbooruApi: gelbooruApi,
        danbooruApi: danbooruApi,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.setFavoritesSource('gelbooru');
      await notifier.switchToFavorites();

      final state = container.read(onlineGalleryNotifierProvider);
      expect(gelbooruApi.favoritesCalls, 1);
      expect(state.gelbooruFavoritesCache.posts, hasLength(1));
      expect(state.danbooruFavoritesCache.posts, isEmpty);
      expect(state.favoritedPostKeys, contains('gelbooru:123'));
      expect(state.favoritedPostKeys, isNot(contains('danbooru:123')));

      expect(await notifier.toggleFavorite(state.posts.single), isFalse);
      expect(danbooruApi.addFavoriteCalls, 0);
      expect(danbooruApi.removeFavoriteCalls, 0);
    },
  );

  test(
    'Gelbooru local and remote favorite membership remain independent',
    () async {
      final hiveDirectory = await Directory.systemTemp.createTemp(
        'online-gallery-gelbooru-favorites-',
      );
      Hive.init(hiveDirectory.path);
      await Hive.openBox<dynamic>(StorageKeys.settingsBox);
      await Hive.openBox<dynamic>(StorageKeys.localFavoritesBox);
      addTearDown(() async {
        await Hive.close();
        await hiveDirectory.delete(recursive: true);
      });

      final item = _gelbooruPost(321);
      final gelbooruApi = _FakeGelbooruApiService(
        favoritesResult: GelbooruPostPage(posts: [item], rawCount: 1),
      );
      final container = createContainer(
        storedCredentials: stored(credentials),
        gelbooruApi: gelbooruApi,
      );
      addTearDown(container.dispose);
      final localFavorites = container.read(
        onlineGalleryLocalFavoritesProvider.notifier,
      );
      await localFavorites.upsert(
        GalleryDetail(item: item, media: [item.cover]),
      );
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.setFavoritesSource(GallerySourceId.gelbooru);
      await notifier.switchToFavorites();
      expect(notifier.isFavorited(item), isTrue);

      notifier.invalidateGelbooruFavorites();
      expect(notifier.isFavorited(item), isFalse);
      expect(
        container
            .read(onlineGalleryNotifierProvider)
            .favoritedPostKeys
            .contains(item.stableKey),
        isTrue,
      );

      await notifier.setFavoritesScope(GalleryFavoritesScope.local);
      expect(notifier.isFavorited(item), isTrue);
    },
  );

  test('favorite caches retain independent scroll and pagination state', () {
    final danbooruCache = ModeCache(
      posts: [_danbooruPost(1)],
      page: 3,
      hasMore: false,
      scrollOffset: 120,
    );
    final gelbooruCache = ModeCache(
      posts: [_gelbooruPost(1)],
      page: 5,
      scrollOffset: 340,
    );

    final state = const OnlineGalleryState()
        .updateFavoritesCache(GallerySourceId.danbooru, danbooruCache)
        .updateFavoritesCache(GallerySourceId.gelbooru, gelbooruCache)
        .copyWith(
          viewMode: GalleryViewMode.favorites,
          favoritesSourceId: GallerySourceId.gelbooru,
          favoritedPostKeys: const {'danbooru:1', 'gelbooru:1'},
        );

    expect(state.currentCache.page, 5);
    expect(state.currentCache.scrollOffset, 340);
    expect(state.danbooruFavoritesCache.scrollOffset, 120);
    expect(state.favoritedPostKeys, hasLength(2));
  });

  test('switching modes restores cached Gelbooru favorites', () async {
    final gelbooruApi = _FakeGelbooruApiService(
      favoritesResult: GelbooruPostPage(
        posts: [_gelbooruPost(404)],
        rawCount: 1,
      ),
    );
    final container = createContainer(
      storedCredentials: stored(credentials),
      gelbooruApi: gelbooruApi,
    );
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.setFavoritesSource('gelbooru');
    await notifier.switchToFavorites();
    notifier.saveScrollOffset(275);
    await notifier.switchToSearch();
    await notifier.switchToFavorites();

    final state = container.read(onlineGalleryNotifierProvider);
    expect(gelbooruApi.favoritesCalls, 1);
    expect(state.posts.single.id, 404);
    expect(state.scrollOffset, 275);
  });

  test('Gelbooru page navigation uses zero-based DAPI pid', () async {
    final gelbooruApi = _FakeGelbooruApiService(
      searchResult: GelbooruPostPage(posts: [_gelbooruPost(505)], rawCount: 40),
      favoritesResult: GelbooruPostPage(
        posts: [_gelbooruPost(506)],
        rawCount: 40,
      ),
    );
    final container = createContainer(
      storedCredentials: stored(credentials),
      gelbooruApi: gelbooruApi,
    );
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.setSource('gelbooru');
    await notifier.goToPage(4);
    expect(gelbooruApi.searchPids, [0, 3]);
    expect(container.read(onlineGalleryNotifierProvider).page, 4);

    await notifier.setFavoritesSource('gelbooru');
    await notifier.switchToFavorites();
    await notifier.goToPage(3);
    expect(gelbooruApi.favoritePids, [0, 2]);
    expect(container.read(onlineGalleryNotifierProvider).page, 3);
  });
}

DanbooruPost _gelbooruPost(int id) {
  return DanbooruPost(
    id: id,
    site: 'gelbooru',
    rating: 'g',
    width: 1200,
    height: 800,
    tagString: 'solo',
    fileExt: 'jpg',
    previewFileUrl: 'https://img3.gelbooru.com/thumb/$id.jpg',
  );
}

DanbooruPost _danbooruPost(int id) {
  return DanbooruPost(
    id: id,
    site: 'danbooru',
    rating: 'g',
    width: 1200,
    height: 800,
    tagStringGeneral: 'solo',
    fileExt: 'jpg',
    previewFileUrl: 'https://cdn.donmai.us/preview/$id.jpg',
  );
}

class _FakeSecureStorage extends SecureStorageService {
  _FakeSecureStorage({this.gelbooru});

  String? gelbooru;

  @override
  Future<String?> getGelbooruCredentials() async => gelbooru;

  @override
  Future<void> deleteGelbooruCredentials() async {
    gelbooru = null;
  }

  @override
  Future<String?> getDanbooruCredentials() async => null;
}

class _FakeGelbooruApiService extends GelbooruApiService {
  _FakeGelbooruApiService({
    this.searchResult = const GelbooruPostPage(posts: [], rawCount: 0),
    this.favoritesResult = const GelbooruPostPage(posts: [], rawCount: 0),
    this.searchError,
  }) : super(Dio());

  final GelbooruPostPage searchResult;
  final GelbooruPostPage favoritesResult;
  final GelbooruApiException? searchError;
  int searchCalls = 0;
  int favoritesCalls = 0;
  final List<int> searchPids = [];
  final List<int> favoritePids = [];

  @override
  Future<GelbooruPostPage> searchPosts({
    required GelbooruCredentials credentials,
    required String tags,
    required int pid,
    int limit = 40,
    CancelToken? cancelToken,
    bool noCache = false,
  }) async {
    searchCalls++;
    searchPids.add(pid);
    if (searchError != null) throw searchError!;
    return searchResult;
  }

  @override
  Future<GelbooruPostPage> getFavorites({
    required GelbooruCredentials credentials,
    required int pid,
    int limit = 40,
    CancelToken? cancelToken,
  }) async {
    favoritesCalls++;
    favoritePids.add(pid);
    if (searchError != null) throw searchError!;
    return favoritesResult;
  }
}

class _FakeDanbooruApiService extends DanbooruApiService {
  _FakeDanbooruApiService() : super(Dio());

  int addFavoriteCalls = 0;
  int removeFavoriteCalls = 0;

  @override
  Future<bool> addFavorite(int postId) async {
    addFavoriteCalls++;
    return true;
  }

  @override
  Future<bool> removeFavorite(int postId) async {
    removeFavoriteCalls++;
    return true;
  }
}

class _GalleryHttpAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.uri.path.endsWith('.jpg')) {
      return ResponseBody.fromBytes(
        _minimalJpeg(width: 320, height: 180),
        206,
        headers: {
          Headers.contentTypeHeader: ['image/jpeg'],
        },
      );
    }
    if (options.uri.path == '/posts.json') {
      return ResponseBody.fromString(
        jsonEncode([
          {
            'id': 10,
            'rating': 'g',
            'image_width': 640,
            'image_height': 480,
            'tag_string_general': 'solo',
            'file_ext': 'jpg',
            'preview_file_url': 'https://cdn.donmai.us/preview/10.jpg',
          },
        ]),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      '''
<article class="thumbnail-preview">
  <a id="p14416915" href="https://gelbooru.com/index.php?page=post&amp;s=view&amp;id=14416915">
    <img src="https://img3.gelbooru.com/thumb/14416915.jpg" title="solo score:12 rating:general" />
  </a>
</article>
''',
      200,
      headers: {
        Headers.contentTypeHeader: ['text/html'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Uint8List _minimalJpeg({required int width, required int height}) {
  return Uint8List.fromList([
    0xff,
    0xd8,
    0xff,
    0xc0,
    0x00,
    0x11,
    0x08,
    (height >> 8) & 0xff,
    height & 0xff,
    (width >> 8) & 0xff,
    width & 0xff,
    0x03,
    0x01,
    0x11,
    0x00,
    0x02,
    0x11,
    0x00,
    0x03,
    0x11,
    0x00,
    0xff,
    0xd9,
  ]);
}
