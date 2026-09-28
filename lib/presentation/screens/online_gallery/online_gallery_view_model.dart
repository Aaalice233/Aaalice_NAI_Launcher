import '../../../data/models/online_gallery/danbooru_post.dart';
import '../../providers/online_gallery_provider.dart';
import '../../providers/selection_mode_provider.dart';

/// Immutable presentation snapshot consumed by the gallery shell and its
/// ordinary imported widgets.
class OnlineGalleryViewModel {
  const OnlineGalleryViewModel({
    required this.gallery,
    required this.selection,
  });

  factory OnlineGalleryViewModel.from({
    required OnlineGalleryState gallery,
    required SelectionModeState selection,
  }) {
    return OnlineGalleryViewModel(gallery: gallery, selection: selection);
  }

  final OnlineGalleryState gallery;
  final SelectionModeState selection;

  GallerySourceId get activeSourceId => switch (gallery.viewMode) {
    GalleryViewMode.search => gallery.sourceId,
    GalleryViewMode.popular => gallery.popularSourceId,
    GalleryViewMode.favorites => gallery.favoritesSourceId,
  };

  ModeCache get activeCache => gallery.randomEnabled
      ? gallery.randomSession.cache
      : gallery.currentCache;

  bool get isSelectionMode => selection.isActive;
  bool get showQueryFields =>
      gallery.viewMode == GalleryViewMode.search ||
      gallery.viewMode == GalleryViewMode.favorites ||
      (gallery.viewMode == GalleryViewMode.popular &&
          gallery.popularSourceId == GallerySourceId.aiTag);

  List<String> get postStableKeys =>
      List.unmodifiable(gallery.posts.map((post) => post.stableKey));

  bool get allVisibleSelected =>
      postStableKeys.isNotEmpty &&
      postStableKeys.every(selection.selectedIds.contains);

  bool get canDownloadSelected => gallery.posts.any(
    (post) =>
        selection.selectedIds.contains(post.stableKey) && post.hasValidPreview,
  );
}
