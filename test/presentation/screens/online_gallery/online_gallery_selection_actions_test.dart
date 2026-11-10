import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/selection_mode_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/widgets/queue/enqueue_result_toast.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_selection_actions.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_action.dart';

import '../../../helpers/empty_gallery_source_adapter.dart';
import '../../../helpers/fake_save_file_picker.dart';
import '../../../helpers/memory_local_storage.dart';
import '../../../helpers/enqueue_result_fixture.dart';

void main() {
  for (final fixture in EnqueueFixture.values) {
    testWidgets('批量入队 ${fixture.name} 保留真实计数与可重试选择', (tester) async {
      final posts = [
        const GalleryItem(id: 1, tagString: 'one'),
        const GalleryItem(id: 2, tagString: 'two'),
        const GalleryItem(id: 3),
      ];
      final queue = ResultQueueNotifier(fixture);
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(MemoryLocalStorage()),
          onlineGalleryNotifierProvider.overrideWith(
            () => _QueueGallery(posts),
          ),
          replicationQueueNotifierProvider.overrideWith(() => queue),
        ],
      );
      addTearDown(container.dispose);
      late OnlineGallerySelectionActions actions;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(onlineGallerySelectionNotifierProvider);
                ref.watch(onlineGalleryNotifierProvider);
                actions = OnlineGallerySelectionActions(
                  context: context,
                  ref: ref,
                );
                return const Scaffold();
              },
            ),
          ),
        ),
      );
      final selection = container.read(
        onlineGallerySelectionNotifierProvider.notifier,
      );
      selection.replaceSelection(posts.map((post) => post.stableKey).toList());
      await actions.addSelectedToQueue(posts);
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('zh'));
      final batchMessage = l10n.onlineGallery_queueBatchCompleted(
        fixture == EnqueueFixture.saved ? 2 : 0,
        1,
        fixture == EnqueueFixture.full ? 2 : 0,
      );
      final expected = switch (fixture) {
        EnqueueFixture.saved || EnqueueFixture.full => batchMessage,
        EnqueueFixture.unexpected => l10n.queue_enqueueUnexpectedError,
        _ =>
          '${enqueueFailureMessage(l10n, fixture.resolve(queue.received))}\n$batchMessage',
      };
      expect(find.text(expected), findsOneWidget);
      final remaining = container
          .read(onlineGallerySelectionNotifierProvider)
          .selectedIds;
      expect(remaining, switch (fixture) {
        EnqueueFixture.started => {posts[1].stableKey},
        EnqueueFixture.withdrawn ||
        EnqueueFixture.unsaved => {posts[0].stableKey, posts[1].stableKey},
        EnqueueFixture.unexpected =>
          posts.map((post) => post.stableKey).toSet(),
        _ => isEmpty,
      });
      expect(find.textContaining('private'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
    });
  }

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
              final selected = {for (final post in state.posts) post.stableKey};
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

  testWidgets('AI TAG search and ranking selections offer bulk download', (
    tester,
  ) async {
    final feeds = {
      'search': OnlineGalleryState(
        sourceId: GallerySourceId.aiTag,
        searchCache: ModeCache(posts: [_pendingAiTagItem(101)]),
      ),
      'ranking': OnlineGalleryState(
        viewMode: GalleryViewMode.popular,
        popularSourceId: GallerySourceId.aiTag,
        popularCache: ModeCache(posts: [_pendingAiTagItem(102)]),
      ),
    };

    for (final MapEntry(key: feed, value: state) in feeds.entries) {
      final ids = await actionIds(tester, state);
      expect(ids, contains(ImageCardActionId.save), reason: feed);
    }
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
              cover: GalleryMedia.noImage,
            ),
          ],
        ),
      ),
    );

    expect(ids, isNot(contains(ImageCardActionId.save)));
  });

  testWidgets(
    'bulk download completes when the screen unmounts during folder picking',
    (tester) async {
      final picker = _PendingDirectoryPicker();
      useFakeFilePicker(picker);
      final adapter = _DetailAdapter();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(MemoryLocalStorage()),
          onlineGalleryTagMetadataLoaderProvider.overrideWithValue(
            (_) async => const {},
          ),
          onlineGallerySourceAdaptersProvider.overrideWithValue({
            for (final source in GallerySourceId.values)
              source: source == GallerySourceId.aiTag
                  ? adapter
                  : EmptyGallerySourceAdapter(source),
          }),
        ],
      );
      addTearDown(container.dispose);
      final keepAlive = container.listen(
        onlineGalleryNotifierProvider,
        (_, _) {},
      );
      addTearDown(keepAlive.close);
      final showActions = ValueNotifier(true);
      addTearDown(showActions.dispose);
      late OnlineGallerySelectionActions actions;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ValueListenableBuilder<bool>(
              valueListenable: showActions,
              builder: (_, visible, _) => visible
                  ? Consumer(
                      builder: (context, ref, _) {
                        actions = OnlineGallerySelectionActions(
                          context: context,
                          ref: ref,
                        );
                        return const SizedBox.shrink();
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );

      Object? error;
      var finished = false;
      unawaited(
        actions
            .downloadSelected([_pendingAiTagItem(101)])
            .then((_) => finished = true, onError: (Object e) => error = e),
      );
      await tester.pump();
      showActions.value = false;
      await tester.pump();
      picker.directory.complete('unused-directory');
      for (var pumps = 0; pumps < 10 && !finished && error == null; pumps++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(error, isNull);
      expect(finished, isTrue);
      expect(adapter.detailRequests, 1);
    },
  );
}

class _QueueGallery extends OnlineGalleryNotifier {
  _QueueGallery(this.posts);
  final List<GalleryItem> posts;
  @override
  OnlineGalleryState build() =>
      OnlineGalleryState(searchCache: ModeCache(posts: posts));
}

class _PendingDirectoryPicker extends FakeSaveFilePicker {
  final Completer<String?> directory = Completer<String?>();

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) => directory.future;
}

class _DetailAdapter extends GallerySourceAdapter {
  int detailRequests = 0;

  @override
  GallerySourceId get sourceId => GallerySourceId.aiTag;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async => GalleryPage(
    items: const [],
    cursor: request.cursor,
    nextCursor: null,
    hasMore: false,
    rawItemCount: 0,
  );

  @override
  Future<GalleryDetail> detail(
    GalleryItem item, {
    CancelToken? cancelToken,
  }) async {
    detailRequests++;
    return GalleryDetail(
      item: item,
      media: const [GalleryMedia(id: '101_p0', mediaType: 'image')],
    );
  }
}

GalleryItem _pendingAiTagItem(int id) => GalleryItem(
  id: id,
  sourceId: GallerySourceId.aiTag,
  mediaCount: 2,
  cover: GalleryMedia(id: '${id}_pending', mediaType: 'image'),
);
