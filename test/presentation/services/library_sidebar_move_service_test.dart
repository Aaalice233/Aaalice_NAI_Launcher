import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/gallery/gallery_tree_drop_slot.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_category.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/presentation/providers/library_sidebar_sort_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_category_provider.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_provider.dart';
import 'package:nai_launcher/presentation/services/library_sidebar_move_service.dart';
import 'package:nai_launcher/presentation/utils/library_sidebar_sort.dart';

void main() {
  ProviderContainer containerFor(_Storage storage, {_VibeStorage? vibes}) {
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        if (vibes != null) ...[
          vibeLibraryStorageServiceProvider.overrideWithValue(vibes),
          vibeLibraryCategoryNotifierProvider.overrideWith(
            () => _VibeCategories(vibes.categories),
          ),
          vibeLibraryNotifierProvider.overrideWith(_Vibes.new),
        ],
      ],
    );
    if (vibes != null) {
      container.listen(vibeLibraryCategoryNotifierProvider, (_, _) {});
      container.listen(vibeLibraryNotifierProvider, (_, _) {});
    }
    addTearDown(container.dispose);
    return container;
  }

  List<String> rootIds(ProviderContainer container) {
    final categories = container
        .read(tagLibraryPageNotifierProvider)
        .categories;
    return categories.rootCategories.sortedByOrder().map((c) => c.id).toList();
  }

  test(
    'manual tag move starts from displayed order and preserves other branches',
    () async {
      final storage = _Storage();
      storage.values[LibrarySidebarSection.tagCategories.storageKey] =
          LibrarySidebarSort.nameAscending.name;
      final container = containerFor(storage);
      container
          .read(tagLibraryPageNotifierProvider.notifier)
          .selectCategory('b');
      expect(
        await container
            .read(librarySidebarMoveServiceProvider)
            .moveTagCategory('c', 'b', GalleryTreeDropSlot.before),
        isTrue,
      );
      expect(rootIds(container), ['a', 'c', 'b']);
      final state = container.read(tagLibraryPageNotifierProvider);
      expect(state.selectedCategoryId, 'b');
      expect(
        state.categories.getChildren('a').sortedByOrder().map((c) => c.id),
        ['a1', 'a2'],
      );
      expect(
        container
            .read(
              librarySidebarSortProvider(LibrarySidebarSection.tagCategories),
            )
            .sort,
        LibrarySidebarSort.original,
      );
      expect(rootIds(containerFor(storage)), ['a', 'c', 'b']);
    },
  );

  test(
    'moving into a category keeps auto sorting and moving to root works',
    () async {
      final storage = _Storage();
      storage.values[LibrarySidebarSection.tagCategories.storageKey] =
          LibrarySidebarSort.countDescending.name;
      final container = containerFor(storage);
      final service = container.read(librarySidebarMoveServiceProvider);
      expect(
        await service.moveTagCategory('c', 'a', GalleryTreeDropSlot.child),
        isTrue,
      );
      expect(
        container
            .read(tagLibraryPageNotifierProvider)
            .categories
            .singleWhere((category) => category.id == 'c')
            .parentId,
        'a',
      );
      expect(
        container
            .read(
              librarySidebarSortProvider(LibrarySidebarSection.tagCategories),
            )
            .sort,
        LibrarySidebarSort.countDescending,
      );
      expect(
        await service.moveTagCategory('c', null, GalleryTreeDropSlot.child),
        isTrue,
      );
      expect(
        container
            .read(tagLibraryPageNotifierProvider)
            .categories
            .singleWhere((category) => category.id == 'c')
            .parentId,
        isNull,
      );
      expect(
        await service.moveTagCategory('a', 'a1', GalleryTreeDropSlot.child),
        isFalse,
      );
    },
  );

  test(
    'failed category writes preserve both selection order and sort preference',
    () async {
      final storage = _Storage()..failCategories = true;
      storage.values[LibrarySidebarSection.tagCategories.storageKey] =
          LibrarySidebarSort.nameAscending.name;
      final container = containerFor(storage);
      final originalJson = storage.categories;
      await expectLater(
        container
            .read(librarySidebarMoveServiceProvider)
            .moveTagCategory('c', 'b', GalleryTreeDropSlot.before),
        throwsStateError,
      );
      expect(rootIds(container), ['b', 'c', 'a']);
      expect(storage.categories, originalJson);
      expect(
        container
            .read(
              librarySidebarSortProvider(LibrarySidebarSection.tagCategories),
            )
            .sort,
        LibrarySidebarSort.nameAscending,
      );
    },
  );

  test('Vibe categories reorder in one batch without adding nesting', () async {
    final storage = _Storage();
    storage.values[LibrarySidebarSection.vibeCategories.storageKey] =
        LibrarySidebarSort.nameAscending.name;
    final vibes = _VibeStorage();
    final container = containerFor(storage, vibes: vibes);
    container
        .read(vibeLibraryCategoryNotifierProvider.notifier)
        .selectCategory('b');
    final service = container.read(librarySidebarMoveServiceProvider);
    expect(
      await service.moveVibeCategory('c', 'b', GalleryTreeDropSlot.before),
      isTrue,
    );
    expect(vibes.categories.sortedByOrder().map((c) => c.id), ['a', 'c', 'b']);
    expect(vibes.writes, 1);
    expect(
      container.read(vibeLibraryCategoryNotifierProvider).selectedCategoryId,
      'b',
    );
    expect(
      container
          .read(
            librarySidebarSortProvider(LibrarySidebarSection.vibeCategories),
          )
          .sort,
      LibrarySidebarSort.original,
    );
    expect(
      await service.moveVibeCategory('c', 'a', GalleryTreeDropSlot.child),
      isFalse,
    );
    expect(vibes.writes, 1);
  });

  test(
    'failed Vibe batch leaves stored and displayed categories unchanged',
    () async {
      final storage = _Storage();
      storage.values[LibrarySidebarSection.vibeCategories.storageKey] =
          LibrarySidebarSort.nameAscending.name;
      final vibes = _VibeStorage()..fail = true;
      final container = containerFor(storage, vibes: vibes);
      await expectLater(
        container
            .read(librarySidebarMoveServiceProvider)
            .moveVibeCategory('c', 'b', GalleryTreeDropSlot.before),
        throwsStateError,
      );
      expect(
        container
            .read(vibeLibraryCategoryNotifierProvider)
            .categories
            .map((c) => c.id),
        ['b', 'c', 'a'],
      );
      expect(vibes.categories.map((c) => c.id), ['b', 'c', 'a']);
      expect(
        container
            .read(
              librarySidebarSortProvider(LibrarySidebarSection.vibeCategories),
            )
            .sort,
        LibrarySidebarSort.nameAscending,
      );
    },
  );
}

class _Storage extends LocalStorageService {
  final values = <String, Object?>{};
  bool failCategories = false;
  String categories = jsonEncode([
    for (final (index, id) in ['b', 'c', 'a', 'a2', 'a1'].indexed)
      TagLibraryCategory(
        id: id,
        name: id,
        sortOrder: index,
        parentId: id.length == 2 ? 'a' : null,
        createdAt: DateTime(2026),
      ).toJson(),
  ]);
  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] ?? defaultValue) as T?;
  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }

  @override
  String? getTagLibraryCategoriesJson() => categories;
  @override
  Future<void> setTagLibraryCategoriesJson(String json) async {
    if (failCategories) throw StateError('disk full');
    categories = json;
  }
}

class _VibeStorage extends VibeLibraryStorageService {
  List<VibeLibraryCategory> categories = [
    for (final (index, id) in ['b', 'c', 'a'].indexed)
      VibeLibraryCategory(
        id: id,
        name: id,
        sortOrder: index,
        createdAt: DateTime(2026),
      ),
  ];
  int writes = 0;
  bool fail = false;
  @override
  Future<void> saveCategories(List<VibeLibraryCategory> updated) async {
    if (fail) throw StateError('batch write failed');
    categories = updated;
    writes++;
  }
}

class _VibeCategories extends VibeLibraryCategoryNotifier {
  _VibeCategories(this.categories);
  final List<VibeLibraryCategory> categories;
  @override
  VibeLibraryCategoryState build() =>
      VibeLibraryCategoryState(categories: categories);
}

class _Vibes extends VibeLibraryNotifier {
  @override
  VibeLibraryState build() => const VibeLibraryState();
}
