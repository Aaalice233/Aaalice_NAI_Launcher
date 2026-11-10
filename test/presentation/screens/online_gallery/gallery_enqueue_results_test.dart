import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_detail_launcher.dart';
import 'package:nai_launcher/presentation/widgets/danbooru_post_card.dart';
import 'package:nai_launcher/presentation/widgets/queue/enqueue_result_toast.dart';

import '../../../helpers/enqueue_result_fixture.dart';
import '../../../helpers/memory_local_storage.dart';

void main() {
  for (final detail in [false, true]) {
    for (final fixture in EnqueueFixture.values) {
      testWidgets('${detail ? '详情' : '卡片'}入队报告 ${fixture.name}', (
        tester,
      ) async {
        final queue = ResultQueueNotifier(fixture);
        final l10n = lookupAppLocalizations(const Locale('zh'));
        const post = GalleryItem(id: 4, tagString: 'one');
        const codex = GalleryItem(
          id: 5,
          sourceId: GallerySourceId.quickTagCloud,
          cover: GalleryMedia.noImage,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localStorageServiceProvider.overrideWithValue(
                MemoryLocalStorage(),
              ),
              onlineGalleryNotifierProvider.overrideWith(_DetailGallery.new),
              replicationQueueNotifierProvider.overrideWith(() => queue),
            ],
            child: InteractionPolicyScope(
              initialPolicy: const InteractionPolicy(
                modality: InteractionModality.pointer,
                precisePointerAvailable: true,
                touchAvailable: false,
              ),
              child: MaterialApp(
                locale: const Locale('zh'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: Consumer(
                  builder: (context, ref, _) => Scaffold(
                    body: detail
                        ? TextButton(
                            onPressed: () =>
                                OnlineGalleryDetailLauncher(
                                  context: context,
                                  ref: ref,
                                ).show(
                                  context,
                                  codex,
                                  preloadedDetail: const GalleryDetail(
                                    item: codex,
                                    media: [],
                                    prompt: 'one',
                                  ),
                                ),
                            child: const Text('DETAIL'),
                          )
                        : Center(
                            child: SizedBox(
                              width: 250,
                              height: 350,
                              child: DanbooruPostCard(
                                post: post,
                                itemWidth: 250,
                                isFavorited: false,
                                onTap: () {},
                                onTagTap: (_) {},
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
        if (detail) {
          await tester.tap(find.text('DETAIL'));
          await tester.pumpAndSettle();
          final action = find.text(l10n.onlineGallery_codexAddToQueue);
          await tester.ensureVisible(action);
          await tester.tap(action);
        } else {
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          addTearDown(mouse.removePointer);
          await mouse.addPointer(location: Offset.zero);
          await mouse.moveTo(tester.getCenter(find.byType(DanbooruPostCard)));
          await tester.pump();
          await tester.tap(find.byTooltip(l10n.onlineGallery_addToQueue));
        }
        await tester.pump();
        final expected = switch (fixture) {
          EnqueueFixture.saved => l10n.onlineGallery_addedToQueueWithCount(0),
          EnqueueFixture.full => l10n.onlineGallery_queueFullMax,
          EnqueueFixture.unexpected => l10n.queue_enqueueUnexpectedError,
          _ => enqueueFailureMessage(
            l10n,
            fixture.resolve([ReplicationTask.create(prompt: 'test')]),
          )!,
        };
        expect(find.text(expected), findsOneWidget);
        expect(find.textContaining('private'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 4));
        if (detail) {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }
      });
    }
  }
}

class _DetailGallery extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() => const OnlineGalleryState();
  @override
  Future<void> recordQuickTagCloudViewed(GalleryItem item) async {}
  @override
  bool isFavorited(Object postOrId) => false;
}
