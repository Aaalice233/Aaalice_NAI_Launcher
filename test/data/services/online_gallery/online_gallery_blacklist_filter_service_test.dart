import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/online_gallery_detail_coordinator.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/quick_tag_cloud_gallery_mapper.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/quick_tag_cloud_gallery_repository.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/data/services/online_gallery/online_gallery_blacklist_filter_service.dart';
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_parser.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/ai_tag_character_gallery.dart';
import '../../../helpers/empty_gallery_source_adapter.dart';
import '../../../helpers/memory_local_storage.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  for (final feed in ['search', 'ranking', 'random']) {
    test(
      'AI TAG $feed filters a positive character on the second image',
      () async {
        final storage = MemoryLocalStorage()
          ..values[StorageKeys.onlineGalleryBlacklistTags] = ['brass_badge']
          ..values[StorageKeys.onlineGalleryBrowsingSessionV1] =
              encodeOnlineGalleryBrowsingSession(
                OnlineGalleryState(
                  sourceId: GallerySourceId.aiTag,
                  popularSourceId: GallerySourceId.aiTag,
                  viewMode: feed == 'ranking'
                      ? GalleryViewMode.popular
                      : GalleryViewMode.search,
                ),
              );
        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storage),
            onlineGallerySourceAdaptersProvider.overrideWithValue({
              for (final source in GallerySourceId.values)
                source: source == GallerySourceId.aiTag
                    ? aiTagCharacterGallery()
                    : EmptyGallerySourceAdapter(source),
            }),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(onlineGalleryNotifierProvider.notifier);
        if (feed == 'random') {
          await notifier.setRandomEnabled(true);
        } else {
          await notifier.loadPosts();
        }

        final state = container.read(onlineGalleryNotifierProvider);
        expect(state.error, isNull);
        expect(state.activeSourceId, GallerySourceId.aiTag);
        expect(state.posts.map((item) => item.id), [22]);
      },
    );
  }

  const filter = OnlineGalleryBlacklistFilterService(OnlineGalleryQuery());
  final noDetailRequests = OnlineGalleryDetailCoordinator(
    loader: (_, _) => throw StateError('Complete tags must not fetch a detail'),
  );

  test(
    'completed AI TAG items blacklist whole positive tags in each weight syntax',
    () async {
      final adapter = aiTagCharacterGallery();
      final items = [
        for (final id in [11, 22])
          (await adapter.detail(
            GalleryItem(id: id, sourceId: GallerySourceId.aiTag),
          )).item.copyWith(rank: 1),
      ];
      for (final tag in [
        'brass_badge',
        'green_eyes',
        'silver_ribbon',
        'blue_cape',
      ]) {
        final result = await filter.filter(
          items: items,
          blacklist: {tag},
          details: noDetailRequests,
        );
        expect(result.items.map((item) => item.id), [22], reason: tag);
        expect(result.detailFailures, 0);
      }
      final result = await filter.filter(
        items: items,
        blacklist: {
          'main_negative',
          'character_negative',
          'title_only',
          'brass',
        },
        details: noDetailRequests,
      );
      expect(result.items, items);
    },
  );

  test(
    'QuickTagCloud filters work characters even on complete text-only listings',
    () async {
      final meta = QuickTagCloudParser.parseCodexes(const [
        {'id': 'book', 'title': 'Book'},
      ]).single;
      final codex = QuickTagCloudParser.parseCodex(const {
        'id': 'book',
        'entries': [
          {
            'id': 'first',
            'tags': 'solo',
            'characterPrompts': [
              {
                'label': 'actor',
                'prompt': '(green eyes:1.2)',
                'negative': 'glasses',
              },
            ],
          },
        ],
      }, meta);
      final item = const QuickTagCloudGalleryMapper().toGalleryItem(
        QuickTagCloudGalleryRecord(
          meta,
          codex,
          codex.entries.single,
          const QuickTagCloudMediaConfig(),
        ),
      );
      expect(item.tags, ['solo']);
      for (final tag in ['green_eyes', 'glasses', 'actor']) {
        final result = await filter.filter(
          items: [item],
          blacklist: {tag},
          details: noDetailRequests,
        );
        expect(result.detailFailures, 0);
        expect(result.items, tag == 'green_eyes' ? isEmpty : [item]);
      }
    },
  );
}
