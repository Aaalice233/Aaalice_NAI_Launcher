import 'dart:async';
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
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/danbooru/danbooru_user.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/data/models/online_gallery/gelbooru_credentials.dart';
import 'package:nai_launcher/data/services/danbooru_auth_service.dart';
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
    bool danbooruLoggedIn = false,
    _MutableDanbooruAuth? danbooruAuth,
    Map<GallerySourceId, GallerySourceAdapter>? galleryAdapters,
  }) {
    final adapter = httpAdapter ?? _GalleryHttpAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    return ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(
          _FakeSecureStorage(
            gelbooru: storedCredentials,
            danbooru: danbooruLoggedIn
                ? jsonEncode(
                    const DanbooruCredentials(
                      username: 'tester',
                      apiKey: 'dan-key',
                    ).toJson(),
                  )
                : null,
          ),
        ),
        danbooruCredentialVerifierProvider.overrideWithValue(
          _FakeDanbooruCredentialVerifier(),
        ),
        gelbooruApiServiceProvider.overrideWithValue(
          gelbooruApi ?? _FakeGelbooruApiService(),
        ),
        onlineGalleryHttpClientProvider.overrideWithValue(dio),
        danbooruApiServiceProvider.overrideWithValue(
          danbooruApi ?? _FakeDanbooruApiService(),
        ),
        if (danbooruAuth != null)
          danbooruAuthProvider.overrideWith(() => danbooruAuth),
        if (galleryAdapters != null)
          onlineGallerySourceAdaptersProvider.overrideWithValue(
            galleryAdapters,
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

  test('favorites without credentials use local data only', () async {
    final hiveDirectory = await Directory.systemTemp.createTemp(
      'online-gallery-local-favorites-fallback-',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    await Hive.openBox<dynamic>(StorageKeys.localFavoritesBox);
    addTearDown(() async {
      await Hive.close();
      await hiveDirectory.delete(recursive: true);
    });

    final item = _gelbooruPost(77);
    final gelbooruApi = _FakeGelbooruApiService();
    final container = createContainer(gelbooruApi: gelbooruApi);
    addTearDown(container.dispose);
    await container
        .read(onlineGalleryLocalFavoritesProvider.notifier)
        .upsert(GalleryDetail(item: item, media: [item.cover]));

    final notifier = container.read(onlineGalleryNotifierProvider.notifier);
    await notifier.setFavoritesSource(GallerySourceId.gelbooru);
    await notifier.switchToFavorites();

    expect(gelbooruApi.favoritesCalls, 0);
    expect(
      container
          .read(onlineGalleryNotifierProvider)
          .posts
          .map((post) => post.id),
      [77],
    );
  });

  test('authenticated Danbooru favorite writes use the cloud', () async {
    final danbooruApi = _FakeDanbooruApiService();
    final container = createContainer(
      danbooruApi: danbooruApi,
      danbooruLoggedIn: true,
    );
    addTearDown(container.dispose);
    await container.read(danbooruAuthProvider.notifier).ensureInitialized();
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);
    final item = _danbooruPost(88);

    expect(await notifier.toggleFavorite(item), isTrue);
    expect(danbooruApi.addFavoriteCalls, 1);
    expect(notifier.isRemotelyFavorited(item), isTrue);
    expect(notifier.isLocallyFavorited(item), isFalse);

    expect(await notifier.toggleFavorite(item), isTrue);
    expect(danbooruApi.removeFavoriteCalls, 1);
    expect(notifier.isRemotelyFavorited(item), isFalse);
  });

  test('unauthenticated Danbooru favorite writes fall back locally', () async {
    final hiveDirectory = await Directory.systemTemp.createTemp(
      'online-gallery-danbooru-local-favorite-',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    await Hive.openBox<dynamic>(StorageKeys.localFavoritesBox);
    addTearDown(() async {
      await Hive.close();
      await hiveDirectory.delete(recursive: true);
    });

    final danbooruApi = _FakeDanbooruApiService();
    final container = createContainer(danbooruApi: danbooruApi);
    addTearDown(container.dispose);
    await container.read(danbooruAuthProvider.notifier).ensureInitialized();
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);
    final item = _danbooruPost(89);

    expect(await notifier.toggleFavorite(item), isTrue);
    expect(danbooruApi.addFavoriteCalls, 0);
    expect(notifier.isLocallyFavorited(item), isTrue);

    expect(await notifier.toggleFavorite(item), isTrue);
    expect(danbooruApi.removeFavoriteCalls, 0);
    expect(notifier.isLocallyFavorited(item), isFalse);
  });

  for (final sourceId in [
    GallerySourceId.aiTag,
    GallerySourceId.quickTagCloud,
  ]) {
    test(
      '${sourceId.key} favorites use the generic local write path',
      () async {
        final hiveDirectory = await Directory.systemTemp.createTemp(
          'online-gallery-${sourceId.key}-local-favorite-',
        );
        Hive.init(hiveDirectory.path);
        await Hive.openBox<dynamic>(StorageKeys.settingsBox);
        await Hive.openBox<dynamic>(StorageKeys.localFavoritesBox);
        addTearDown(() async {
          await Hive.close();
          await hiveDirectory.delete(recursive: true);
        });

        final adapter = _StaticDetailGalleryAdapter(sourceId);
        final container = createContainer(galleryAdapters: {sourceId: adapter});
        addTearDown(container.dispose);
        final item = GalleryItem(
          id: sourceId.index + 1,
          workId: 'work-${sourceId.key}',
          sourceId: sourceId,
          title: '${sourceId.label} work',
          cover: GalleryMedia(
            id: 'media-${sourceId.key}',
            displayUrl: 'https://example.test/${sourceId.key}.webp',
          ),
        );
        final notifier = container.read(onlineGalleryNotifierProvider.notifier);

        expect(await notifier.toggleFavorite(item), isTrue);
        expect(adapter.detailCalls, 1);
        expect(notifier.isLocallyFavorited(item), isTrue);
        expect(await notifier.toggleFavorite(item), isTrue);
        expect(notifier.isLocallyFavorited(item), isFalse);
      },
    );
  }

  test('Gelbooru remote favorites never call Danbooru writes', () async {
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
    expect(
      state.favoritesCacheFor(GallerySourceId.gelbooru).posts,
      hasLength(1),
    );
    expect(state.favoritesCacheFor(GallerySourceId.danbooru).posts, isEmpty);
    expect(state.favoritedPostKeys, contains('gelbooru:123'));
    expect(state.favoritedPostKeys, isNot(contains('danbooru:123')));

    expect(await notifier.toggleFavorite(state.posts.single), isFalse);
    expect(danbooruApi.addFavoriteCalls, 0);
    expect(danbooruApi.removeFavoriteCalls, 0);
  });

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
      final localItem = item.copyWith(
        title: 'Saved title',
        description: 'Complete local description',
      );
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
        GalleryDetail(item: localItem, media: [localItem.cover]),
      );
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.setFavoritesSource(GallerySourceId.gelbooru);
      await notifier.switchToFavorites();
      expect(notifier.isFavorited(item), isTrue);

      final mergedPosts = container.read(onlineGalleryNotifierProvider).posts;
      expect(mergedPosts, hasLength(1));
      expect(mergedPosts.single.title, 'Saved title');
      expect(mergedPosts.single.previewUrl, item.previewUrl);
      expect(notifier.isRemotelyFavorited(item), isTrue);
      expect(notifier.isLocallyFavorited(item), isTrue);

      expect(await notifier.toggleFavorite(item), isTrue);
      expect(notifier.isFavorited(item), isFalse);
      expect(notifier.isRemotelyFavorited(item), isTrue);
      expect(notifier.isLocallyFavorited(item), isFalse);

      notifier.invalidateGelbooruFavorites();
      expect(notifier.isFavorited(item), isFalse);
      expect(notifier.isRemotelyFavorited(item), isFalse);
    },
  );

  test('favorite search filters both local and remote results', () async {
    final hiveDirectory = await Directory.systemTemp.createTemp(
      'online-gallery-favorites-search-',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    await Hive.openBox<dynamic>(StorageKeys.localFavoritesBox);
    addTearDown(() async {
      await Hive.close();
      await hiveDirectory.delete(recursive: true);
    });

    final localMatch = _gelbooruPost(701, tagString: 'blue dog');
    final remoteMatch = _gelbooruPost(702, tagString: 'red dog');
    final remoteMiss = _gelbooruPost(703, tagString: 'green cat');
    final gelbooruApi = _FakeGelbooruApiService(
      favoritesResult: GelbooruPostPage(
        posts: [remoteMatch, remoteMiss],
        rawCount: 2,
      ),
    );
    final container = createContainer(
      storedCredentials: stored(credentials),
      gelbooruApi: gelbooruApi,
    );
    addTearDown(container.dispose);
    await container
        .read(onlineGalleryLocalFavoritesProvider.notifier)
        .upsert(GalleryDetail(item: localMatch, media: [localMatch.cover]));

    final notifier = container.read(onlineGalleryNotifierProvider.notifier);
    await notifier.setFavoritesSource(GallerySourceId.gelbooru);
    await notifier.searchFavorites('dog');

    expect(
      container
          .read(onlineGalleryNotifierProvider)
          .posts
          .map((item) => item.stableKey),
      [localMatch.stableKey, remoteMatch.stableKey],
    );
  });

  test('complete favorite failure does not expose a partial failure', () async {
    final container = createContainer(
      storedCredentials: stored(credentials),
      gelbooruApi: _FakeGelbooruApiService(
        searchError: const GelbooruApiException(
          GelbooruApiErrorType.rateLimited,
          statusCode: 429,
        ),
      ),
    );
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.setFavoritesSource(GallerySourceId.gelbooru);
    await notifier.switchToFavorites();

    final state = container.read(onlineGalleryNotifierProvider);
    expect(state.errorCode, isNotNull);
    expect(state.currentCache.hasFavoritesPartialFailure, isFalse);
    expect(state.currentCache.localFavoritesErrorCode, isNull);
    expect(state.currentCache.remoteFavoritesErrorCode, isNull);
  });

  test('remote favorites failure preserves local favorites', () async {
    final hiveDirectory = await Directory.systemTemp.createTemp(
      'online-gallery-partial-favorites-',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    await Hive.openBox<dynamic>(StorageKeys.localFavoritesBox);
    addTearDown(() async {
      await Hive.close();
      await hiveDirectory.delete(recursive: true);
    });

    final item = _gelbooruPost(888);
    final remoteItem = _gelbooruPost(889);
    final gelbooruApi = _FakeGelbooruApiService(
      favoritesResult: GelbooruPostPage(posts: [remoteItem], rawCount: 1),
    );
    final container = createContainer(
      storedCredentials: stored(credentials),
      gelbooruApi: gelbooruApi,
    );
    addTearDown(container.dispose);
    await container
        .read(onlineGalleryLocalFavoritesProvider.notifier)
        .upsert(GalleryDetail(item: item, media: [item.cover]));

    final notifier = container.read(onlineGalleryNotifierProvider.notifier);
    await notifier.setFavoritesSource(GallerySourceId.gelbooru);
    await notifier.switchToFavorites();
    gelbooruApi.searchError = const GelbooruApiException(
      GelbooruApiErrorType.rateLimited,
      statusCode: 429,
    );
    await notifier.refresh();

    final state = container.read(onlineGalleryNotifierProvider);
    expect(state.posts.map((post) => post.stableKey), [
      item.stableKey,
      remoteItem.stableKey,
    ]);
    expect(state.errorCode, isNull);
    expect(
      state.currentCache.remoteFavoritesErrorCode,
      OnlineGalleryErrorCode.gelbooruRateLimited,
    );
    expect(state.currentCache.localFavoritesErrorCode, isNull);
  });

  test('cancelled remote favorites cannot overwrite a newer mode', () async {
    final hiveDirectory = await Directory.systemTemp.createTemp(
      'online-gallery-favorites-cancellation-',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    await Hive.openBox<dynamic>(StorageKeys.localFavoritesBox);
    addTearDown(() async {
      await Hive.close();
      await hiveDirectory.delete(recursive: true);
    });

    final remoteResult = Completer<GelbooruPostPage>();
    final remoteStarted = Completer<void>();
    final gelbooruApi = _FakeGelbooruApiService(
      favoritesLoader: (pid) {
        if (!remoteStarted.isCompleted) remoteStarted.complete();
        return remoteResult.future;
      },
    );
    final container = createContainer(
      storedCredentials: stored(credentials),
      gelbooruApi: gelbooruApi,
    );
    addTearDown(container.dispose);
    final localItem = _gelbooruPost(888);
    await container
        .read(onlineGalleryLocalFavoritesProvider.notifier)
        .upsert(GalleryDetail(item: localItem, media: [localItem.cover]));
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);
    await notifier.setFavoritesSource(GallerySourceId.gelbooru);

    final pendingFavorites = notifier.switchToFavorites();
    await remoteStarted.future;
    await notifier.switchToSearch();
    remoteResult.complete(
      GelbooruPostPage(posts: [_gelbooruPost(999)], rawCount: 1),
    );
    await pendingFavorites;

    final state = container.read(onlineGalleryNotifierProvider);
    expect(state.viewMode, GalleryViewMode.search);
    expect(
      state
          .favoritesCacheFor(GallerySourceId.gelbooru)
          .posts
          .map((item) => item.id),
      [888],
    );
  });

  test('account login reloads the active unified favorites view', () async {
    final hiveDirectory = await Directory.systemTemp.createTemp(
      'online-gallery-favorites-auth-reload-',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    await Hive.openBox<dynamic>(StorageKeys.localFavoritesBox);
    addTearDown(() async {
      await Hive.close();
      await hiveDirectory.delete(recursive: true);
    });

    final auth = _MutableDanbooruAuth();
    final remoteItem = _danbooruPost(902);
    final api = _FakeDanbooruApiService(favoritesResult: [remoteItem]);
    final container = createContainer(danbooruApi: api, danbooruAuth: auth);
    addTearDown(container.dispose);
    final localItem = _danbooruPost(901);
    await container
        .read(onlineGalleryLocalFavoritesProvider.notifier)
        .upsert(GalleryDetail(item: localItem, media: [localItem.cover]));
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.switchToFavorites();
    expect(
      container.read(onlineGalleryNotifierProvider).posts.single.stableKey,
      localItem.stableKey,
    );

    auth.logIn();
    for (var attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(Duration.zero);
      final state = container.read(onlineGalleryNotifierProvider);
      if (!state.isLoading && state.posts.length == 2) break;
    }

    final state = container.read(onlineGalleryNotifierProvider);
    expect(state.posts.map((item) => item.stableKey), {
      localItem.stableKey,
      remoteItem.stableKey,
    });
    expect(api.favoritesCalls, 1);
  });

  test('cross-branch duplicate pages do not truncate later results', () async {
    final hiveDirectory = await Directory.systemTemp.createTemp(
      'online-gallery-favorites-cross-branch-duplicates-',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    await Hive.openBox<dynamic>(StorageKeys.localFavoritesBox);
    addTearDown(() async {
      await Hive.close();
      await hiveDirectory.delete(recursive: true);
    });

    final gelbooruApi = _FakeGelbooruApiService(
      favoritesByPid: {
        0: GelbooruPostPage(
          posts: [for (var id = 61; id <= 120; id++) _gelbooruPost(id)],
          rawCount: 60,
        ),
        1: GelbooruPostPage(
          posts: [for (var id = 1; id <= 60; id++) _gelbooruPost(id)],
          rawCount: 60,
        ),
        2: GelbooruPostPage(posts: [_gelbooruPost(121)], rawCount: 1),
      },
    );
    final container = createContainer(
      storedCredentials: stored(credentials),
      gelbooruApi: gelbooruApi,
    );
    addTearDown(container.dispose);
    await container
        .read(onlineGalleryLocalFavoritesProvider.notifier)
        .upsertAll([
          for (var id = 1; id <= 60; id++)
            GalleryDetail(
              item: _gelbooruPost(id),
              media: [_gelbooruPost(id).cover],
            ),
        ]);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);
    await notifier.setFavoritesSource(GallerySourceId.gelbooru);
    await notifier.switchToFavorites();

    await notifier.loadMore();
    var state = container.read(onlineGalleryNotifierProvider);
    expect(state.posts, hasLength(120));
    expect(state.hasMore, isTrue);

    await notifier.loadMore();
    state = container.read(onlineGalleryNotifierProvider);
    expect(state.posts.map((item) => item.id), contains(121));
    expect(gelbooruApi.favoritePids, [0, 1, 2]);
  });

  test('deduplication keeps the more complete favorite row', () async {
    final hiveDirectory = await Directory.systemTemp.createTemp(
      'online-gallery-favorites-richer-row-',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    await Hive.openBox<dynamic>(StorageKeys.localFavoritesBox);
    addTearDown(() async {
      await Hive.close();
      await hiveDirectory.delete(recursive: true);
    });

    final localItem = _gelbooruPost(777).copyWith(
      title: 'Complete local title',
      description: 'A complete local description with useful details',
      tags: const ['one', 'two', 'three'],
    );
    final remoteItem = _gelbooruPost(
      777,
    ).copyWith(title: 'x', description: 'y');
    final container = createContainer(
      storedCredentials: stored(credentials),
      gelbooruApi: _FakeGelbooruApiService(
        favoritesResult: GelbooruPostPage(posts: [remoteItem], rawCount: 1),
      ),
    );
    addTearDown(container.dispose);
    await container
        .read(onlineGalleryLocalFavoritesProvider.notifier)
        .upsert(GalleryDetail(item: localItem, media: [localItem.cover]));
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);
    await notifier.setFavoritesSource(GallerySourceId.gelbooru);
    await notifier.switchToFavorites();

    final merged = container.read(onlineGalleryNotifierProvider).posts.single;
    expect(merged.title, 'Complete local title');
    expect(merged.description, contains('useful details'));
    expect(merged.tags, containsAll(['one', 'two', 'three']));
  });

  test('local and remote favorites advance independent cursors', () async {
    final hiveDirectory = await Directory.systemTemp.createTemp(
      'online-gallery-favorites-pagination-',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    await Hive.openBox<dynamic>(StorageKeys.localFavoritesBox);
    addTearDown(() async {
      await Hive.close();
      await hiveDirectory.delete(recursive: true);
    });

    final gelbooruApi = _FakeGelbooruApiService(
      favoritesByPid: {
        0: GelbooruPostPage(
          posts: [for (var id = 1; id <= 60; id++) _gelbooruPost(id)],
          rawCount: 60,
        ),
        1: GelbooruPostPage(posts: [_gelbooruPost(62)], rawCount: 1),
      },
    );
    final container = createContainer(
      storedCredentials: stored(credentials),
      gelbooruApi: gelbooruApi,
    );
    addTearDown(container.dispose);
    await container
        .read(onlineGalleryLocalFavoritesProvider.notifier)
        .upsertAll([
          for (var id = 61; id >= 1; id--)
            GalleryDetail(
              item: _gelbooruPost(id),
              media: [_gelbooruPost(id).cover],
            ),
        ]);

    final notifier = container.read(onlineGalleryNotifierProvider.notifier);
    await notifier.setFavoritesSource(GallerySourceId.gelbooru);
    await notifier.switchToFavorites();
    var state = container.read(onlineGalleryNotifierProvider);
    expect(state.posts, hasLength(60));
    expect(state.currentCache.localFavoritesOffset, 60);
    expect(state.currentCache.remoteFavoritesPage, 2);
    expect(state.currentCache.localFavoritesHasMore, isTrue);
    expect(state.currentCache.remoteFavoritesHasMore, isTrue);

    await notifier.loadMore();
    state = container.read(onlineGalleryNotifierProvider);
    expect(state.posts, hasLength(62));
    expect(state.posts.map((item) => item.id), containsAll([61, 62]));
    expect(state.currentCache.localFavoritesOffset, 61);
    expect(state.currentCache.remoteFavoritesPage, 3);
    expect(state.currentCache.hasMore, isFalse);
    expect(gelbooruApi.favoritePids, [0, 1]);
  });

  test('sparse favorite jumps preserve real page order', () async {
    final hiveDirectory = await Directory.systemTemp.createTemp(
      'online-gallery-favorites-sparse-pages-',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    await Hive.openBox<dynamic>(StorageKeys.localFavoritesBox);
    addTearDown(() async {
      await Hive.close();
      await hiveDirectory.delete(recursive: true);
    });

    final gelbooruApi = _FakeGelbooruApiService(
      favoritesByPid: {
        0: GelbooruPostPage(posts: [_gelbooruPost(1)], rawCount: 1),
        6: GelbooruPostPage(posts: [_gelbooruPost(7)], rawCount: 1),
        2: GelbooruPostPage(posts: [_gelbooruPost(3)], rawCount: 1),
      },
    );
    final container = createContainer(
      storedCredentials: stored(credentials),
      gelbooruApi: gelbooruApi,
    );
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.setFavoritesSource(GallerySourceId.gelbooru);
    await notifier.switchToFavorites();
    await notifier.goToPage(7);
    await notifier.goToPage(3);

    final cache = container.read(onlineGalleryNotifierProvider).currentCache;
    expect(gelbooruApi.favoritePids, [0, 6, 2]);
    expect(cache.posts.map((item) => item.id), [1, 3, 7]);
    expect(cache.pageBoundaries.map((boundary) => boundary.page), [1, 3, 7]);
  });

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
    expect(state.favoritesCacheFor(GallerySourceId.danbooru).scrollOffset, 120);
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
      searchByPid: {
        0: GelbooruPostPage(posts: [_gelbooruPost(505)], rawCount: 40),
        3: GelbooruPostPage(posts: [_gelbooruPost(507)], rawCount: 40),
      },
      favoritesByPid: {
        0: GelbooruPostPage(posts: [_gelbooruPost(506)], rawCount: 40),
        2: GelbooruPostPage(posts: [_gelbooruPost(508)], rawCount: 40),
      },
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

DanbooruPost _gelbooruPost(int id, {String tagString = 'solo'}) {
  return DanbooruPost(
    id: id,
    site: 'gelbooru',
    rating: 'g',
    width: 1200,
    height: 800,
    tagString: tagString,
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
  _FakeSecureStorage({this.gelbooru, this.danbooru});

  String? gelbooru;
  String? danbooru;

  @override
  Future<String?> getGelbooruCredentials() async => gelbooru;

  @override
  Future<void> deleteGelbooruCredentials() async {
    gelbooru = null;
  }

  @override
  Future<String?> getDanbooruCredentials() async => danbooru;
}

class _FakeDanbooruCredentialVerifier extends DanbooruCredentialVerifier {
  @override
  Future<(DanbooruUser?, bool isNetworkError)> verify(
    DanbooruCredentials credentials,
  ) async {
    return (DanbooruUser(id: 1, name: credentials.username), false);
  }
}

class _FakeGelbooruApiService extends GelbooruApiService {
  _FakeGelbooruApiService({
    this.searchResult = const GelbooruPostPage(posts: [], rawCount: 0),
    this.searchByPid,
    this.favoritesResult = const GelbooruPostPage(posts: [], rawCount: 0),
    this.favoritesByPid,
    this.favoritesLoader,
    this.searchError,
  }) : super(Dio());

  final GelbooruPostPage searchResult;
  final Map<int, GelbooruPostPage>? searchByPid;
  final GelbooruPostPage favoritesResult;
  final Map<int, GelbooruPostPage>? favoritesByPid;
  final Future<GelbooruPostPage> Function(int pid)? favoritesLoader;
  GelbooruApiException? searchError;
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
    return searchByPid?[pid] ?? searchResult;
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
    final loader = favoritesLoader;
    if (loader != null) return loader(pid);
    return favoritesByPid?[pid] ?? favoritesResult;
  }
}

class _FakeDanbooruApiService extends DanbooruApiService {
  _FakeDanbooruApiService({this.favoritesResult = const []}) : super(Dio());

  final List<DanbooruPost> favoritesResult;
  int favoritesCalls = 0;
  int addFavoriteCalls = 0;
  int removeFavoriteCalls = 0;

  @override
  Future<List<DanbooruPost>> getFavorites({
    String? username,
    int? userId,
    dynamic page = 1,
    int limit = 40,
  }) async {
    favoritesCalls++;
    return favoritesResult;
  }

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

class _StaticDetailGalleryAdapter extends GallerySourceAdapter {
  _StaticDetailGalleryAdapter(this.sourceId);

  @override
  final GallerySourceId sourceId;
  int detailCalls = 0;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async => const GalleryPage(
    items: [],
    cursor: '1',
    nextCursor: null,
    hasMore: false,
  );

  @override
  Future<GalleryDetail> detail(
    GalleryItem item, {
    CancelToken? cancelToken,
  }) async {
    detailCalls++;
    return GalleryDetail(item: item, media: [item.cover]);
  }
}

class _MutableDanbooruAuth extends DanbooruAuth {
  @override
  DanbooruAuthState build() => const DanbooruAuthState();

  @override
  Future<void> ensureInitialized() async {}

  void logIn() {
    state = DanbooruAuthState(
      credentials: const DanbooruCredentials(
        username: 'tester',
        apiKey: 'dan-key',
      ),
      user: const DanbooruUser(id: 1, name: 'tester'),
      lastVerifiedAt: DateTime.now(),
    );
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
    const danbooruPost = {
      'id': 10,
      'rating': 'g',
      'image_width': 640,
      'image_height': 480,
      'tag_string_general': 'solo',
      'file_ext': 'jpg',
      'preview_file_url': 'https://cdn.donmai.us/preview/10.jpg',
    };
    if (options.uri.path == '/posts.json') {
      return ResponseBody.fromString(
        jsonEncode([danbooruPost]),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.uri.path.startsWith('/posts/') &&
        options.uri.path.endsWith('.json')) {
      final id = int.parse(options.uri.path.split('/').last.split('.').first);
      return ResponseBody.fromString(
        jsonEncode({
          ...danbooruPost,
          'id': id,
          'preview_file_url': 'https://cdn.donmai.us/preview/$id.jpg',
        }),
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
