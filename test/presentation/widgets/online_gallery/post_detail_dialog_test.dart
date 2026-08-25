import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/data/services/danbooru_auth_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_output_filter_provider.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_prompt_tag_settings_provider.dart';
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

  testWidgets('Gelbooru search detail exposes the local favorite action', (
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

    expect(find.byTooltip('Favorite'), findsOneWidget);
    expect(find.byTooltip('Unfavorite'), findsNothing);
  });

  testWidgets('Gelbooru detail displays unclassified post tags', (
    tester,
  ) async {
    const post = DanbooruPost(
      id: 204,
      site: 'gelbooru',
      previewFileUrl: 'https://img4.gelbooru.com/thumbnail.jpg',
      tagString: 'solo blue_hair',
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
    await tester.pump();

    expect(find.text('General (2)'), findsOneWidget);
    expect(find.text('solo'), findsOneWidget);
    expect(find.text('blue hair'), findsOneWidget);
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

  testWidgets('copy tags respects selected prompt tag categories', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    const post = DanbooruPost(
      id: 205,
      site: 'danbooru',
      previewFileUrl: 'https://cdn.donmai.us/preview/205.jpg',
      tagString: 'solo example_artist',
      tagStringGeneral: 'solo',
      tagStringArtist: 'example_artist',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          onlineGalleryPromptTagSettingsProvider.overrideWith(
            _ArtistOnlyPromptTagSettingsNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PostDetailDialog(post: post),
        ),
      ),
    );

    await tester.tap(find.text('Copy Tags'));
    await tester.pump();

    expect(copiedText, 'artist:example_artist');
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('filtered tags are styled and omitted from copied output', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    const post = DanbooruPost(
      id: 206,
      site: 'danbooru',
      previewFileUrl: 'https://cdn.donmai.us/preview/206.jpg',
      tagString: 'solo watermark',
      tagStringGeneral: 'solo watermark',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          onlineGalleryOutputFilterProvider.overrideWith(
            _WatermarkOutputFilterNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PostDetailDialog(post: post),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byTooltip(
        'Removed when copying, sending, or adding to queue; '
        'right-click to manage',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Copy Tags'));
    await tester.pump();
    expect(copiedText, 'solo');

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('right-clicking a detail tag opens quick-list actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const post = DanbooruPost(
      id: 207,
      site: 'danbooru',
      previewFileUrl: 'https://cdn.donmai.us/preview/207.jpg',
      tagString: 'solo',
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
    await tester.pump();

    await tester.tap(find.text('solo'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('Add to output filter'), findsOneWidget);
    expect(find.text('Add to blacklist'), findsOneWidget);
  });

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
      favoritesSourceId: GallerySourceId.gelbooru,
      gelbooruFavoritesCache: ModeCache(posts: [post]),
      favoritedPostKeys: {'gelbooru:203'},
    );
  }
}

class _WatermarkOutputFilterNotifier extends OnlineGalleryOutputFilterNotifier {
  @override
  OnlineGalleryOutputFilterSettings build() {
    return const OnlineGalleryOutputFilterSettings(tags: {'watermark'});
  }
}

class _ArtistOnlyPromptTagSettingsNotifier
    extends OnlineGalleryPromptTagSettingsNotifier {
  @override
  OnlineGalleryPromptTagSettings build() {
    return const OnlineGalleryPromptTagSettings(
      categories: {OnlineGalleryPromptTagCategory.artist},
    );
  }
}

class _LoggedOutDanbooruAuth extends DanbooruAuth {
  @override
  DanbooruAuthState build() => const DanbooruAuthState();
}
