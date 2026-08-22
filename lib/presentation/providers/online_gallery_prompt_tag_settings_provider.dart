import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';
import '../../data/models/online_gallery/gallery_item.dart';
import 'online_gallery_output_filter_provider.dart';

enum OnlineGalleryPromptTagCategory {
  general,
  character,
  copyright,
  artist,
  meta,
}

class OnlineGalleryPromptTagSettings {
  const OnlineGalleryPromptTagSettings({required this.categories});

  static const defaultCategories = <OnlineGalleryPromptTagCategory>{
    OnlineGalleryPromptTagCategory.general,
    OnlineGalleryPromptTagCategory.character,
    OnlineGalleryPromptTagCategory.copyright,
  };

  static const _promptCategoryOrder = <OnlineGalleryPromptTagCategory>[
    OnlineGalleryPromptTagCategory.artist,
    OnlineGalleryPromptTagCategory.character,
    OnlineGalleryPromptTagCategory.copyright,
    OnlineGalleryPromptTagCategory.general,
    OnlineGalleryPromptTagCategory.meta,
  ];

  final Set<OnlineGalleryPromptTagCategory> categories;

  OnlineGalleryPromptTagSettings copyWith({
    Set<OnlineGalleryPromptTagCategory>? categories,
  }) {
    return OnlineGalleryPromptTagSettings(
      categories: Set.unmodifiable(categories ?? this.categories),
    );
  }

  String promptFor(
    GalleryItem item, {
    OnlineGalleryOutputFilterSettings? outputFilter,
  }) {
    final categoryTags = <OnlineGalleryPromptTagCategory, List<String>>{
      OnlineGalleryPromptTagCategory.general: item.generalTags,
      OnlineGalleryPromptTagCategory.character: item.characterTags,
      OnlineGalleryPromptTagCategory.copyright: item.copyrightTags,
      OnlineGalleryPromptTagCategory.artist: item.artistTags,
      OnlineGalleryPromptTagCategory.meta: item.metaTags,
    };
    final hasCategorizedTags = categoryTags.values.any(
      (tags) => tags.isNotEmpty,
    );

    // Gelbooru and AI TAG do not always expose per-category fields. Keeping the
    // source-provided tag list prevents the selector from erasing their prompt.
    if (!hasCategorizedTags) {
      return (outputFilter?.filterTags(item.tags) ?? item.tags).join(', ');
    }

    final selectedTags = <String>{};
    for (final category in _promptCategoryOrder) {
      if (!categories.contains(category)) continue;
      for (final tag in categoryTags[category]!) {
        final rendered = category == OnlineGalleryPromptTagCategory.artist
            ? _formatArtistTag(tag)
            : tag;
        if (outputFilter?.contains(tag) == true ||
            outputFilter?.contains(rendered) == true) {
          continue;
        }
        selectedTags.add(rendered);
      }
    }
    return selectedTags.join(', ');
  }

  String _formatArtistTag(String tag) {
    const prefix = 'artist:';
    if (tag.toLowerCase().startsWith(prefix)) {
      return '$prefix${tag.substring(prefix.length)}';
    }
    return '$prefix$tag';
  }
}

final onlineGalleryPromptTagSettingsProvider =
    NotifierProvider<
      OnlineGalleryPromptTagSettingsNotifier,
      OnlineGalleryPromptTagSettings
    >(OnlineGalleryPromptTagSettingsNotifier.new);

class OnlineGalleryPromptTagSettingsNotifier
    extends Notifier<OnlineGalleryPromptTagSettings> {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  OnlineGalleryPromptTagSettings build() {
    final storedNames = _storage.getSetting<List>(
      StorageKeys.onlineGalleryPromptTagCategories,
    );
    final categories = storedNames
        ?.whereType<String>()
        .map(_categoryFromName)
        .whereType<OnlineGalleryPromptTagCategory>()
        .toSet();

    return OnlineGalleryPromptTagSettings(
      categories: Set.unmodifiable(
        categories == null || categories.isEmpty
            ? OnlineGalleryPromptTagSettings.defaultCategories
            : categories,
      ),
    );
  }

  Future<bool> setCategory(
    OnlineGalleryPromptTagCategory category,
    bool selected,
  ) async {
    final categories = state.categories.toSet();
    if (selected) {
      categories.add(category);
    } else if (categories.length == 1 && categories.contains(category)) {
      return false;
    } else {
      categories.remove(category);
    }

    state = state.copyWith(categories: categories);
    await _storage.setSetting<List<String>>(
      StorageKeys.onlineGalleryPromptTagCategories,
      OnlineGalleryPromptTagCategory.values
          .where(categories.contains)
          .map((category) => category.name)
          .toList(growable: false),
    );
    return true;
  }

  OnlineGalleryPromptTagCategory? _categoryFromName(String name) {
    for (final category in OnlineGalleryPromptTagCategory.values) {
      if (category.name == name) return category;
    }
    return null;
  }
}
