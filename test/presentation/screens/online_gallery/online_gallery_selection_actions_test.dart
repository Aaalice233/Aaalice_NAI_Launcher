import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_selection_actions.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_action.dart';

void main() {
  Future<List<ImageCardActionId>> actionIds(
    WidgetTester tester,
    OnlineGalleryState state,
  ) async {
    late List<ImageCardAction> actions;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              final selected = {
                for (final post in state.posts) post.stableKey,
              };
              actions = OnlineGallerySelectionActions(
                context: context,
                ref: ref,
              ).buildActions(state, selected);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return [for (final action in actions) action.id];
  }

  testWidgets('AI TAG search selections offer bulk download', (tester) async {
    final ids = await actionIds(
      tester,
      OnlineGalleryState(
        sourceId: GallerySourceId.aiTag,
        searchCache: ModeCache(posts: [_pendingAiTagItem(101)]),
      ),
    );

    expect(ids, contains(ImageCardActionId.save));
  });

  testWidgets('AI TAG ranking selections offer bulk download', (tester) async {
    final ids = await actionIds(
      tester,
      OnlineGalleryState(
        viewMode: GalleryViewMode.popular,
        popularSourceId: GallerySourceId.aiTag,
        popularCache: ModeCache(posts: [_pendingAiTagItem(102)]),
      ),
    );

    expect(ids, contains(ImageCardActionId.save));
  });

  testWidgets('media-less items hide bulk download', (tester) async {
    final ids = await actionIds(
      tester,
      const OnlineGalleryState(
        sourceId: GallerySourceId.quickTagCloud,
        searchCache: ModeCache(
          posts: [
            GalleryItem(
              id: 7,
              workId: 'codex-7',
              sourceId: GallerySourceId.quickTagCloud,
              cover: GalleryMedia(id: 'no-image'),
            ),
          ],
        ),
      ),
    );

    expect(ids, isNot(contains(ImageCardActionId.save)));
  });
}

GalleryItem _pendingAiTagItem(int id) => GalleryItem(
  id: id,
  sourceId: GallerySourceId.aiTag,
  mediaCount: 2,
  cover: GalleryMedia(id: '${id}_pending', mediaType: 'image'),
);
