import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/gallery/gallery_tree_drop_slot.dart';
import '../providers/gallery_album_provider.dart';
import '../providers/gallery_category_provider.dart';
import '../providers/library_sidebar_sort_provider.dart';
import '../providers/tag_library_page_provider.dart';
import '../providers/vibe_library_category_provider.dart';
import '../providers/vibe_library_provider.dart';
import '../utils/library_sidebar_sort.dart';

final librarySidebarMoveServiceProvider = Provider(
  LibrarySidebarMoveService.new,
);

/// Adapt presentation ordering to each store's existing move transaction.
class LibrarySidebarMoveService {
  LibrarySidebarMoveService(this._ref);
  final Ref _ref;

  Future<bool> moveFolder(String id, String target, GalleryTreeDropSlot slot) {
    final categories = _ref.read(galleryCategoryNotifierProvider).categories;
    final owner = _ref.read(galleryCategoryNotifierProvider.notifier);
    return _move(
      LibrarySidebarSection.folders,
      slot,
      (sort) => owner.moveCategoryToSlot(
        id,
        target,
        slot,
        displayOrder: _displayOrder(
          categories,
          sort,
          idOf: (c) => c.id,
          nameOf: (c) => c.name,
          countOf: (c) => c.imageCount,
          orderOf: (c) => c.sortOrder,
        ),
      ),
    );
  }

  Future<bool> moveAlbum(String id, String target, GalleryTreeDropSlot slot) {
    final albums = _ref.read(galleryAlbumNotifierProvider).albums;
    final owner = _ref.read(galleryAlbumNotifierProvider.notifier);
    return _move(
      LibrarySidebarSection.albums,
      slot,
      (sort) => owner.moveAlbumToSlot(
        id,
        target,
        slot,
        displayOrder: _displayOrder(
          albums,
          sort,
          idOf: (a) => a.id,
          nameOf: (a) => a.name,
          countOf: (a) => a.imageCount,
          orderOf: (a) => a.sortOrder,
        ),
      ),
    );
  }

  Future<bool> moveVibeCategory(
    String id,
    String target,
    GalleryTreeDropSlot slot,
  ) {
    final categories = _ref
        .read(vibeLibraryCategoryNotifierProvider)
        .categories;
    final counts = _ref.read(vibeLibraryNotifierProvider).categoryEntryCounts;
    final owner = _ref.read(vibeLibraryCategoryNotifierProvider.notifier);
    return _move(
      LibrarySidebarSection.vibeCategories,
      slot,
      (sort) => owner.moveCategoryToSlot(
        id,
        target,
        slot,
        displayOrder: _displayOrder(
          categories,
          sort,
          idOf: (c) => c.id,
          nameOf: (c) => c.displayName,
          countOf: (c) => counts[c.id] ?? 0,
          orderOf: (c) => c.sortOrder,
        ),
      ),
    );
  }

  Future<bool> moveTagCategory(
    String id,
    String? target,
    GalleryTreeDropSlot slot,
  ) {
    final data = _ref.read(tagLibraryPageNotifierProvider);
    final counts = data.categoryEntryCounts;
    final owner = _ref.read(tagLibraryPageNotifierProvider.notifier);
    return _move(
      LibrarySidebarSection.tagCategories,
      slot,
      (sort) => owner.moveCategoryToSlot(
        id,
        target,
        slot,
        displayOrder: _displayOrder(
          data.categories,
          sort,
          idOf: (c) => c.id,
          nameOf: (c) => c.displayName,
          countOf: (c) => counts[c.id] ?? 0,
          orderOf: (c) => c.sortOrder,
        ),
      ),
    );
  }

  Future<bool> _move(
    LibrarySidebarSection section,
    GalleryTreeDropSlot slot,
    Future<bool> Function(LibrarySidebarSort) move,
  ) {
    // Changing parentage does not override the user's automatic display order.
    if (slot == GalleryTreeDropSlot.child) {
      return move(LibrarySidebarSort.original);
    }
    return _ref
        .read(librarySidebarSortProvider(section).notifier)
        .applyManualMove(move);
  }

  Map<String, int>? _displayOrder<T>(
    List<T> items,
    LibrarySidebarSort sort, {
    required String Function(T) idOf,
    required String Function(T) nameOf,
    required int Function(T) countOf,
    required int Function(T) orderOf,
  }) {
    if (sort == LibrarySidebarSort.original) return null;
    final sorted = sortLibrarySidebarItems(
      items,
      sort: sort,
      idOf: idOf,
      nameOf: nameOf,
      countOf: countOf,
      orderOf: orderOf,
    );
    return {for (var i = 0; i < sorted.length; i++) idOf(sorted[i]): i};
  }
}
