import 'package:cached_network_image/cached_network_image.dart';
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
}
