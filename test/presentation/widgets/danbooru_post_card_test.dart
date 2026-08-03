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
