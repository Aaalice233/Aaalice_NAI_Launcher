import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/data/services/danbooru_auth_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/post_detail_dialog.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/video_player_widget.dart';

void main() {
  testWidgets('video posts without a direct media URL show the preview image', (
    tester,
  ) async {
    const previewUrl =
        'https://img4.gelbooru.com/thumbnails/aa/bb/thumbnail_video.jpg';
    const post = DanbooruPost(
      id: 14416916,
      site: 'gelbooru',
      fileExt: 'mp4',
      previewFileUrl: previewUrl,
      tagString: 'video solo',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PostDetailDialog(post: post),
        ),
      ),
    );

    expect(find.byType(VideoPlayerWidget), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CachedNetworkImage && widget.imageUrl == previewUrl,
      ),
      findsOneWidget,
    );
  });

  testWidgets('Gelbooru search detail does not expose a favorite action', (
    tester,
  ) async {
    const post = DanbooruPost(
      id: 201,
      site: 'gelbooru',
      previewFileUrl: 'https://img4.gelbooru.com/thumbnail.jpg',
      tagString: 'solo',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PostDetailDialog(post: post),
        ),
      ),
    );

    expect(find.byTooltip('Favorite'), findsNothing);
    expect(find.byTooltip('Unfavorite'), findsNothing);
  });

  testWidgets(
    'Gelbooru favorite detail shows a non-clickable read-only marker',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineGalleryNotifierProvider.overrideWith(
              _GelbooruFavoriteGalleryNotifier.new,
            ),
            danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PostDetailDialog(post: _GelbooruFavoriteGalleryNotifier.post),
          ),
        ),
      );

      expect(find.byTooltip('Read-only favorites'), findsOneWidget);
      expect(find.byTooltip('Unfavorite'), findsNothing);
    },
  );

  testWidgets('Danbooru detail retains its writable favorite action', (
    tester,
  ) async {
    const post = DanbooruPost(
      id: 202,
      site: 'danbooru',
      previewFileUrl: 'https://cdn.donmai.us/preview/202.jpg',
      tagStringGeneral: 'solo',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PostDetailDialog(post: post),
        ),
      ),
    );

    expect(find.byTooltip('Favorite'), findsOneWidget);
  });
}

class _GelbooruFavoriteGalleryNotifier extends OnlineGalleryNotifier {
  static const post = DanbooruPost(
    id: 203,
    site: 'gelbooru',
    previewFileUrl: 'https://img4.gelbooru.com/thumbnail.jpg',
    tagString: 'solo',
  );

  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      viewMode: GalleryViewMode.favorites,
      favoritesSource: 'gelbooru',
      gelbooruFavoritesCache: ModeCache(posts: [post]),
      favoritedPostKeys: {'gelbooru:203'},
    );
  }
}

class _LoggedOutDanbooruAuth extends DanbooruAuth {
  @override
  DanbooruAuthState build() => const DanbooruAuthState();
}
