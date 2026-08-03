import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/data/models/online_gallery/gelbooru_credentials.dart';
import 'package:nai_launcher/data/services/danbooru_auth_service.dart';
import 'package:nai_launcher/data/services/gelbooru_auth_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/danbooru_suggestion_provider.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_screen.dart';

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

    await tester.tap(find.byType(PopupMenuButton<String>).first);
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

class _GelbooruSearchGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      source: 'gelbooru',
      searchCache: ModeCache(posts: [_gelbooruPost], hasMore: false),
    );
  }
}

class _SafebooruSearchGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      source: 'safebooru',
      searchCache: ModeCache(posts: [_danbooruPost], hasMore: false),
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

class _GelbooruFavoritesGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      viewMode: GalleryViewMode.favorites,
      favoritesSource: 'gelbooru',
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
