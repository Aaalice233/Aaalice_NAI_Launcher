import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_output_filter_provider.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_prompt_tag_settings_provider.dart';

void main() {
  group('OnlineGalleryOutputFilterSettings', () {
    test('filters only exact normalized prompt tags', () {
      const settings = OnlineGalleryOutputFilterSettings(
        tags: {'watermark', 'mosaic_censoring'},
      );

      expect(
        settings.filterPrompt(
          'best_quality, watermark, watermark_background, {mosaic censoring}',
        ),
        'best_quality, watermark_background',
      );
    });

    test('matches artist output syntax against the source artist tag', () {
      const settings = OnlineGalleryOutputFilterSettings(
        tags: {'example_artist'},
      );

      expect(settings.contains('artist:example_artist'), isTrue);
      expect(settings.contains('another_example_artist'), isFalse);
    });

    test('filters categorized tags before formatting the output', () {
      const item = GalleryItem(
        id: 1,
        sourceId: GallerySourceId.danbooru,
        tags: ['solo', 'watermark', 'example_artist'],
        tagStringGeneral: 'solo watermark',
        tagStringArtist: 'example_artist',
      );
      const promptSettings = OnlineGalleryPromptTagSettings(
        categories: {
          OnlineGalleryPromptTagCategory.general,
          OnlineGalleryPromptTagCategory.artist,
        },
      );
      const filter = OnlineGalleryOutputFilterSettings(
        tags: {'watermark', 'example_artist'},
      );

      expect(promptSettings.promptFor(item, outputFilter: filter), 'solo');
    });
  });

  group('OnlineGalleryOutputFilterNotifier', () {
    test('uses curated defaults only when no saved value exists', () {
      final storage = _FakeStorage();
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      );
      addTearDown(container.dispose);

      final tags = container.read(onlineGalleryOutputFilterProvider).tags;
      expect(tags, containsAll(['watermark', 'mosaic_censoring']));
    });

    test('preserves an explicitly saved empty list', () {
      final storage = _FakeStorage()
        ..values[StorageKeys.onlineGalleryOutputFilterTags] = <String>[];
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      );
      addTearDown(container.dispose);

      expect(container.read(onlineGalleryOutputFilterProvider).tags, isEmpty);
    });

    test('normalizes, deduplicates, and persists added tags', () async {
      final storage = _FakeStorage()
        ..values[StorageKeys.onlineGalleryOutputFilterTags] = <String>[];
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      );
      addTearDown(container.dispose);

      final added = await container
          .read(onlineGalleryOutputFilterProvider.notifier)
          .addTags([' Watermark ', 'watermark', '-mosaic censoring']);

      expect(added, 2);
      expect(container.read(onlineGalleryOutputFilterProvider).tags, {
        'watermark',
        'mosaic_censoring',
      });
      expect(storage.values[StorageKeys.onlineGalleryOutputFilterTags], [
        'mosaic_censoring',
        'watermark',
      ]);
    });
  });
}

class _FakeStorage extends LocalStorageService {
  final Map<String, Object?> values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    return (values[key] ?? defaultValue) as T?;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}
