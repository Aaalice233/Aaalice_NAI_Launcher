import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/danbooru_post_card.dart';

void main() {
  testWidgets('passes Gelbooru image headers and cache key to preview image', (
    tester,
  ) async {
    const previewUrl =
        'https://img4.gelbooru.com/thumbnails/51/d1/thumbnail_image.jpg';

    const post = DanbooruPost(
      id: 123,
      width: 600,
      height: 900,
      rating: 'g',
      previewFileUrl: previewUrl,
      tagString: 'test_tag',
      site: 'gelbooru',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DanbooruPostCard(
              post: post,
              itemWidth: 200,
              isFavorited: false,
              selectionMode: true,
              isSelected: false,
              canSelect: true,
              onTap: () {},
              onTagTap: (_) {},
              onFavoriteToggle: () {},
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage).first,
    );

    expect(image.imageUrl, previewUrl);
    expect(image.httpHeaders?['Referer'], 'https://gelbooru.com/');
    expect(image.cacheKey, 'gelbooru-image-v2:$previewUrl');
  });

  testWidgets('Gelbooru search cards hide favorite actions', (tester) async {
    const post = DanbooruPost(
      id: 124,
      width: 600,
      height: 900,
      rating: 'g',
      previewFileUrl: 'https://img4.gelbooru.com/thumbnail.jpg',
      tagString: 'test_tag',
      site: 'gelbooru',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DanbooruPostCard(
              post: post,
              itemWidth: 200,
              isFavorited: false,
              showFavoriteAction: false,
              onTap: () {},
              onTagTap: (_) {},
            ),
          ),
        ),
      ),
    );

    final card = find.byType(DanbooruPostCard);
    await tester.sendEventToBinding(
      PointerHoverEvent(position: tester.getCenter(card)),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byTooltip('Favorite'), findsNothing);
    expect(find.byTooltip('Unfavorite'), findsNothing);
  });

  testWidgets('hover preview remains inside a small app viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const post = DanbooruPost(
      id: 126,
      width: 600,
      height: 900,
      rating: 'g',
      previewFileUrl: 'https://example.com/thumbnail.jpg',
      tagString: 'test_tag',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: SizedBox(
                    width: 150,
                    child: DanbooruPostCard(
                      post: post,
                      itemWidth: 150,
                      isFavorited: false,
                      onTap: () {},
                      onTagTap: (_) {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final card = find.byType(DanbooruPostCard);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await tester.pump();
    await mouse.moveTo(tester.getCenter(card));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 301));

    final preview = find.byKey(const ValueKey('online-gallery-hover-preview'));
    expect(preview, findsOneWidget);
    final rect = tester.getRect(preview);
    expect(rect.left, greaterThanOrEqualTo(10));
    expect(rect.top, greaterThanOrEqualTo(10));
    expect(rect.right, lessThanOrEqualTo(490));
    expect(rect.bottom, lessThanOrEqualTo(350));
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.getTopLeft(preview).dy,
        closeTo(rect.top, 0.01),
        reason: 'bottom-clamped hover previews must not shift between frames',
      );
    }

    final media = find.byKey(const ValueKey('online-gallery-hover-media'));
    final hoverImage = tester.widget<CachedNetworkImage>(
      find
          .descendant(of: media, matching: find.byType(CachedNetworkImage))
          .first,
    );
    expect(hoverImage.fit, BoxFit.fitWidth);
    expect(hoverImage.alignment, Alignment.topCenter);
  });

  testWidgets('hover preview preserves landscape ratio and wide-image floor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> verify({
      required DanbooruPost post,
      required double expectedHeight,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 150,
                  child: DanbooruPostCard(
                    post: post,
                    itemWidth: 150,
                    isFavorited: false,
                    onTap: () {},
                    onTagTap: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final card = find.byType(DanbooruPostCard);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await tester.pump();
      await mouse.moveTo(tester.getCenter(card));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pump();

      final media = find.byKey(const ValueKey('online-gallery-hover-media'));
      expect(media, findsOneWidget);
      expect(tester.getSize(media).height, closeTo(expectedHeight, 0.1));
      final hoverImage = tester.widget<CachedNetworkImage>(
        find
            .descendant(of: media, matching: find.byType(CachedNetworkImage))
            .first,
      );
      expect(hoverImage.fit, BoxFit.contain);
      expect(hoverImage.alignment, Alignment.center);
      await mouse.removePointer();
    }

    await verify(
      post: const DanbooruPost(
        id: 127,
        width: 6000,
        height: 4000,
        rating: 'g',
        previewFileUrl: 'https://example.com/landscape.jpg',
        tagString: 'test_tag',
      ),
      expectedHeight: 316 / 1.5,
    );
    await verify(
      post: const DanbooruPost(
        id: 128,
        width: 4000,
        height: 1000,
        rating: 'g',
        previewFileUrl: 'https://example.com/wide.jpg',
        tagString: 'test_tag',
      ),
      expectedHeight: 150,
    );
  });

  testWidgets('Gelbooru favorite cards show a static read-only marker', (
    tester,
  ) async {
    const post = DanbooruPost(
      id: 125,
      width: 600,
      height: 900,
      rating: 'g',
      previewFileUrl: 'https://img4.gelbooru.com/thumbnail.jpg',
      tagString: 'test_tag',
      site: 'gelbooru',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DanbooruPostCard(
              post: post,
              itemWidth: 200,
              isFavorited: true,
              showFavoriteAction: true,
              favoriteReadOnly: true,
              onTap: () {},
              onTagTap: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Read-only favorites'), findsOneWidget);
    expect(find.byTooltip('Unfavorite'), findsNothing);
  });
}
