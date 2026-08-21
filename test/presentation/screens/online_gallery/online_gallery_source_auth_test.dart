import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/data/models/online_gallery/gelbooru_credentials.dart';
import 'package:nai_launcher/data/services/danbooru_auth_service.dart';
import 'package:nai_launcher/data/services/gelbooru_auth_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/danbooru_suggestion_provider.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_screen.dart';
import 'package:nai_launcher/presentation/widgets/danbooru_post_card.dart';

void main() {
  for (final width in [1600.0, 700.0]) {
    testWidgets('Gelbooru search uses its API account entry at width $width', (
      tester,
    ) async {
      await _setViewSize(tester, width);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineGalleryNotifierProvider.overrideWith(
              _GelbooruSearchGalleryNotifier.new,
            ),
            danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
            gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
            danbooruSuggestionNotifierProvider.overrideWith(
              _EmptyDanbooruSuggestionNotifier.new,
            ),
          ],
          child: const _TestApp(),
        ),
      );
      await tester.pump();

      expect(find.text('Configure Gelbooru API'), findsOneWidget);
      expect(find.text('Login'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Safebooru search has no account entry', (tester) async {
    await _setViewSize(tester, 1600);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _SafebooruSearchGalleryNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Configure Gelbooru API'), findsNothing);
    expect(find.text('Login'), findsNothing);
  });

  testWidgets('popular mode remains a Danbooru account surface', (
    tester,
  ) async {
    await _setViewSize(tester, 1600);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _PopularGalleryNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Configure Gelbooru API'), findsNothing);
  });

  for (final entry in {
    GallerySourceId.safebooru: _SafebooruPopularGalleryNotifier.new,
    GallerySourceId.aiTag: _AiTagPopularGalleryNotifier.new,
  }.entries) {
    testWidgets('${entry.key.label} popular mode has no account entry', (
      tester,
    ) async {
      await _setViewSize(tester, 1600);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineGalleryNotifierProvider.overrideWith(entry.value),
            danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
            gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
            danbooruSuggestionNotifierProvider.overrideWith(
              _EmptyDanbooruSuggestionNotifier.new,
            ),
          ],
          child: const _TestApp(),
        ),
      );
      await tester.pump();

      expect(find.text('Login'), findsNothing);
      expect(find.text('Configure Gelbooru API'), findsNothing);
    });
  }

  testWidgets(
    'Gelbooru favorites identify read-only ID ordering on narrow UI',
    (tester) async {
      await _setViewSize(tester, 700);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineGalleryNotifierProvider.overrideWith(
              _GelbooruFavoritesGalleryNotifier.new,
            ),
            danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
            gelbooruAuthProvider.overrideWith(_AuthenticatedGelbooruAuth.new),
            danbooruSuggestionNotifierProvider.overrideWith(
              _EmptyDanbooruSuggestionNotifier.new,
            ),
          ],
          child: const _TestApp(),
        ),
      );
      await tester.pump();

      expect(find.text('Read-only favorites'), findsWidgets);
      expect(find.textContaining('Sorted by post ID'), findsOneWidget);
      expect(find.text('Configure Gelbooru API'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [1600.0, 700.0]) {
    testWidgets('AI TAG controls adapt without overflow at width $width', (
      tester,
    ) async {
      await _setViewSize(tester, width);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineGalleryNotifierProvider.overrideWith(
              _AiTagSearchGalleryNotifier.new,
            ),
            danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
            gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
            danbooruSuggestionNotifierProvider.overrideWith(
              _EmptyDanbooruSuggestionNotifier.new,
            ),
          ],
          child: const _TestApp(),
        ),
      );
      await tester.pump();

      expect(
        find.widgetWithText(
          TextField,
          'Search works, artists, titles, tags, or models',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('AI Prompt search'), findsOneWidget);
      expect(find.text('Login'), findsNothing);
      expect(find.byIcon(Icons.tune), findsNothing);
      expect(find.byIcon(Icons.blur_on), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('AI TAG detail exposes multi-image metadata actions', (
    tester,
  ) async {
    await _setViewSize(tester, 1200);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _AiTagDetailGalleryNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(DanbooruPostCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('AI TAG'), findsWidgets);
    expect(find.text('3 images'), findsOneWidget);
    expect(find.text('Copy Prompt'), findsOneWidget);
    expect(find.text('Copy full metadata'), findsOneWidget);
    expect(find.text('Download all images in this work'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsAtLeastNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty filtered page automatically continues pagination', (
    tester,
  ) async {
    await _setViewSize(tester, 1200);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _EmptyFilteredGalleryNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('danbooru:401')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('underfilled grid automatically appends the next page', (
    tester,
  ) async {
    await _setViewSize(tester, 1200);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _UnderfilledGalleryNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('danbooru:401')), findsOneWidget);
    expect(find.byKey(const ValueKey('danbooru:402')), findsOneWidget);
    expect(find.text('2 images'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page replacement renders the second page URL with stable keys', (
    tester,
  ) async {
    await _setViewSize(tester, 1200);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(_PagedGalleryNotifier.new),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('danbooru:401')), findsOneWidget);
    expect(
      tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first)
          .imageUrl,
      contains('page-1'),
    );

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();

    expect(find.byKey(const ValueKey('danbooru:401')), findsNothing);
    expect(find.byKey(const ValueKey('danbooru:402')), findsOneWidget);
    expect(
      tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first)
          .imageUrl,
      contains('page-2'),
    );
    expect(
      tester.widget<DanbooruPostCard>(find.byType(DanbooruPostCard)).post.id,
      402,
    );
  });

  testWidgets('favorites source selector switches back to Danbooru', (
    tester,
  ) async {
    await _setViewSize(tester, 1600);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _GelbooruFavoritesGalleryNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_AuthenticatedGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(PopupMenuButton<GallerySourceId>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Danbooru').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Configure Gelbooru API'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setViewSize(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: OnlineGalleryScreen(),
    );
  }
}

const _gelbooruPost = DanbooruPost(
  id: 301,
  site: 'gelbooru',
  width: 1200,
  height: 800,
  rating: 'g',
  previewFileUrl: 'https://img4.gelbooru.com/thumbnail.jpg',
  tagString: 'solo',
);

const _danbooruPost = DanbooruPost(
  id: 302,
  site: 'danbooru',
  width: 1200,
  height: 800,
  rating: 'g',
  previewFileUrl: 'https://cdn.donmai.us/preview.jpg',
  tagStringGeneral: 'solo',
);

const _aiTagPost = GalleryItem(
  id: 801,
  sourceId: GallerySourceId.aiTag,
  createdAt: '2026-07-01',
  uploaderId: 88,
  title: 'AI work',
  author: 'Alice',
  aiType: 'NAI',
  mediaCount: 3,
  rank: 3,
  tags: ['1girl'],
  cover: GalleryMedia(
    id: '801_p0',
    previewUrl: 'https://cdn.example/NAI/88/801_p0.webp',
    displayUrl: 'https://cdn.example/NAI/88/801_p0.webp',
    downloadUrl: 'https://cdn.example/NAI/88/801_p0.webp',
    width: 768,
    height: 1024,
  ),
);

const _pageOnePost = DanbooruPost(
  id: 401,
  site: 'danbooru',
  width: 1200,
  height: 800,
  rating: 'g',
  previewFileUrl: 'https://cdn.example/page-1.jpg',
  tagStringGeneral: 'solo',
);

const _pageTwoPost = DanbooruPost(
  id: 402,
  site: 'danbooru',
  width: 1200,
  height: 800,
  rating: 'g',
  previewFileUrl: 'https://cdn.example/page-2.jpg',
  tagStringGeneral: 'solo',
);

class _GelbooruSearchGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      sourceId: GallerySourceId.gelbooru,
      searchCache: ModeCache(posts: [_gelbooruPost], hasMore: false),
    );
  }
}

class _SafebooruSearchGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      sourceId: GallerySourceId.safebooru,
      searchCache: ModeCache(posts: [_danbooruPost], hasMore: false),
    );
  }
}

class _AiTagSearchGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return OnlineGalleryState(
      sourceId: GallerySourceId.aiTag,
      aiTagConfig: AiTagSourceConfig(
        assetBaseUrl: 'https://cdn.example/',
        pageSize: 60,
        availableYears: const [2026, 2025],
        availableMonths: const ['2026-07'],
        fetchedAt: DateTime(2026, 8, 9),
      ),
      searchCache: const ModeCache(posts: [_aiTagPost], hasMore: false),
    );
  }
}

class _AiTagDetailGalleryNotifier extends _AiTagSearchGalleryNotifier {
  @override
  Future<GalleryDetail> loadDetail(
    GalleryItem item, {
    bool forceRefresh = false,
  }) async {
    const media = [
      GalleryMedia(
        id: '801_p0',
        previewUrl: 'https://cdn.example/NAI/88/801_p0.webp',
        displayUrl: 'https://cdn.example/NAI/88/801_p0.webp',
        downloadUrl: 'https://cdn.example/NAI/88/801_p0.webp',
        prompt: '1girl, solo',
        negativePrompt: 'lowres',
        rawMetadata: '{"prompt":"1girl"}',
      ),
      GalleryMedia(
        id: '801_p1',
        previewUrl: 'https://cdn.example/NAI/88/801_p1.webp',
        displayUrl: 'https://cdn.example/NAI/88/801_p1.webp',
        downloadUrl: 'https://cdn.example/NAI/88/801_p1.webp',
        prompt: 'landscape',
      ),
      GalleryMedia(
        id: '801_p2',
        previewUrl: 'https://cdn.example/NAI/88/801_p2.webp',
        displayUrl: 'https://cdn.example/NAI/88/801_p2.webp',
        downloadUrl: 'https://cdn.example/NAI/88/801_p2.webp',
        prompt: 'portrait',
      ),
    ];
    return const GalleryDetail(
      item: _aiTagPost,
      media: media,
      prompt: '1girl, solo',
      negativePrompt: 'lowres',
      description: 'Description',
    );
  }
}

class _EmptyFilteredGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      searchCache: ModeCache(posts: [], page: 5, nextCursor: 'b500'),
    );
  }

  @override
  Future<void> loadPosts({bool refresh = false}) async {}

  @override
  Future<void> loadMore() async {
    state = const OnlineGalleryState(
      searchCache: ModeCache(
        posts: [_pageOnePost],
        page: 6,
        nextCursor: null,
        hasMore: false,
      ),
    );
  }
}

class _UnderfilledGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      searchCache: ModeCache(posts: [_pageOnePost], page: 1, nextCursor: '2'),
    );
  }

  @override
  Future<void> loadMore() async {
    state = const OnlineGalleryState(
      searchCache: ModeCache(
        posts: [_pageOnePost, _pageTwoPost],
        page: 2,
        nextCursor: null,
        hasMore: false,
      ),
    );
  }
}

class _PagedGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      searchCache: ModeCache(posts: [_pageOnePost], page: 1, nextCursor: '2'),
    );
  }

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> goToPage(int page) async {
    state = const OnlineGalleryState(
      searchCache: ModeCache(
        posts: [_pageTwoPost],
        page: 2,
        nextCursor: null,
        hasMore: false,
      ),
    );
  }
}

class _PopularGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      viewMode: GalleryViewMode.popular,
      popularCache: ModeCache(posts: [_danbooruPost], hasMore: false),
    );
  }
}

class _SafebooruPopularGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      viewMode: GalleryViewMode.popular,
      popularSourceId: GallerySourceId.safebooru,
      popularCache: ModeCache(posts: [_danbooruPost], hasMore: false),
    );
  }
}

class _AiTagPopularGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      viewMode: GalleryViewMode.popular,
      popularSourceId: GallerySourceId.aiTag,
      popularCache: ModeCache(posts: [_aiTagPost], hasMore: false),
    );
  }
}

class _GelbooruFavoritesGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      viewMode: GalleryViewMode.favorites,
      favoritesSourceId: GallerySourceId.gelbooru,
      gelbooruFavoritesCache: ModeCache(posts: [_gelbooruPost], hasMore: false),
      favoritedPostKeys: {'gelbooru:301'},
    );
  }
}

class _LoggedOutDanbooruAuth extends DanbooruAuth {
  @override
  DanbooruAuthState build() => const DanbooruAuthState();
}

class _UnconfiguredGelbooruAuth extends GelbooruAuth {
  @override
  GelbooruAuthState build() =>
      const GelbooruAuthState(status: GelbooruAuthStatus.unconfigured);
}

class _AuthenticatedGelbooruAuth extends GelbooruAuth {
  @override
  GelbooruAuthState build() => const GelbooruAuthState(
    credentials: GelbooruCredentials(userId: 99, apiKey: 'key'),
    status: GelbooruAuthStatus.authenticated,
  );
}

class _EmptyDanbooruSuggestionNotifier extends DanbooruSuggestionNotifier {
  @override
  TagSuggestionState build() => const TagSuggestionState();
}
