import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
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
      const ProviderScope(
        child: MaterialApp(
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
}
