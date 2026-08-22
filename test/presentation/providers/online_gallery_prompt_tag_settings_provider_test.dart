import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_prompt_tag_settings_provider.dart';

void main() {
  group('OnlineGalleryPromptTagSettings', () {
    const categorizedItem = GalleryItem(
      sourceId: GallerySourceId.danbooru,
      id: 1,
      cover: GalleryMedia(
        id: '1',
        previewUrl: 'https://example.com/preview.jpg',
        width: 512,
        height: 768,
      ),
      tags: ['general', 'character', 'copyright', 'artist', 'meta'],
      tagStringGeneral: 'general',
      tagStringCharacter: 'character',
      tagStringCopyright: 'copyright',
      tagStringArtist: 'artist',
      tagStringMeta: 'meta',
    );

    test('builds prompt from only selected categories in stable order', () {
      const settings = OnlineGalleryPromptTagSettings(
        categories: {
          OnlineGalleryPromptTagCategory.artist,
          OnlineGalleryPromptTagCategory.general,
        },
      );

      expect(settings.promptFor(categorizedItem), 'general, artist');
    });

    test('falls back to source tags when categories are unavailable', () {
      const item = GalleryItem(
        sourceId: GallerySourceId.gelbooru,
        id: 2,
        cover: GalleryMedia(
          id: '2',
          previewUrl: 'https://example.com/preview.jpg',
          width: 512,
          height: 768,
        ),
        tags: ['first', 'second'],
      );
      const settings = OnlineGalleryPromptTagSettings(
        categories: {OnlineGalleryPromptTagCategory.artist},
      );

      expect(settings.promptFor(item), 'first, second');
    });
  });

  group('OnlineGalleryPromptTagSettingsNotifier', () {
    test('loads and persists selected categories', () async {
      final storage = _FakeStorage()
        ..values[StorageKeys.onlineGalleryPromptTagCategories] = <String>[
          'general',
          'artist',
        ];
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(onlineGalleryPromptTagSettingsProvider).categories,
        {
          OnlineGalleryPromptTagCategory.general,
          OnlineGalleryPromptTagCategory.artist,
        },
      );

      final changed = await container
          .read(onlineGalleryPromptTagSettingsProvider.notifier)
          .setCategory(OnlineGalleryPromptTagCategory.artist, false);

      expect(changed, isTrue);
      expect(
        storage.values[StorageKeys.onlineGalleryPromptTagCategories],
        <String>['general'],
      );
    });

    test('does not allow removing the last category', () async {
      final storage = _FakeStorage()
        ..values[StorageKeys.onlineGalleryPromptTagCategories] = <String>[
          'artist',
        ];
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      );
      addTearDown(container.dispose);

      final changed = await container
          .read(onlineGalleryPromptTagSettingsProvider.notifier)
          .setCategory(OnlineGalleryPromptTagCategory.artist, false);

      expect(changed, isFalse);
      expect(
        container.read(onlineGalleryPromptTagSettingsProvider).categories,
        {OnlineGalleryPromptTagCategory.artist},
      );
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
