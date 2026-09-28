import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:nai_launcher/data/models/gallery/gallery_album.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';
import 'package:nai_launcher/data/services/gallery/unified_gallery_service.dart';
import 'package:nai_launcher/presentation/providers/gallery_album_provider.dart';
import 'package:nai_launcher/presentation/providers/gallery_category_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';

void main() {
  late _RecordingGalleryService service;
  late ProviderContainer container;

  setUp(() {
    service = _RecordingGalleryService();
    container = ProviderContainer(
      overrides: [
        galleryServiceProvider.overrideWith(() => _StubGalleryService(service)),
        galleryAlbumNotifierProvider.overrideWith(_TestAlbumNotifier.new),
        galleryCategoryNotifierProvider.overrideWith(_TestCategoryNotifier.new),
      ],
    );
    addTearDown(container.dispose);
  });

  GalleryAlbumNotifier albums() =>
      container.read(galleryAlbumNotifierProvider.notifier);

  FilterCriteria criteria() =>
      container.read(localGalleryNotifierProvider).filterCriteria;

  String? selectedAlbumId() =>
      container.read(galleryAlbumNotifierProvider).selectedAlbumId;

  group('GalleryAlbumNotifier.selectAlbum', () {
    test('drops the previous album when favorites is selected', () async {
      await albums().selectAlbum('album-a');
      expect(criteria().albumId, 'album-a');

      await albums().selectAlbum('favorites');

      expect(selectedAlbumId(), 'favorites');
      expect(criteria().albumId, isNull);
      expect(criteria().categoryId, isNull);
      expect(criteria().showFavoritesOnly, isTrue);
    });

    test('never narrows favorites by the previous album', () async {
      await albums().selectAlbum('album-a');
      await albums().selectAlbum('favorites');

      expect(
        service.applied.where(
          (applied) => applied.showFavoritesOnly && applied.albumId != null,
        ),
        isEmpty,
      );
    });

    test('drops the favorites flag when a normal album is selected', () async {
      await albums().selectAlbum('favorites');

      await albums().selectAlbum('album-a');

      expect(selectedAlbumId(), 'album-a');
      expect(criteria().albumId, 'album-a');
      expect(criteria().showFavoritesOnly, isFalse);
    });

    test('clears both after browsing an album', () async {
      await albums().selectAlbum('album-a');

      await albums().selectAlbum(null);

      expect(selectedAlbumId(), isNull);
      expect(criteria().albumId, isNull);
      expect(criteria().showFavoritesOnly, isFalse);
    });

    test('clears both after browsing favorites', () async {
      await albums().selectAlbum('favorites');

      await albums().selectAlbum(null);

      expect(selectedAlbumId(), isNull);
      expect(criteria().albumId, isNull);
      expect(criteria().showFavoritesOnly, isFalse);
    });
  });
}

class _RecordingGalleryService extends Mock implements LocalGalleryService {
  final List<FilterCriteria> applied = [];

  @override
  bool get isInitialized => true;

  @override
  int get filteredCount => 0;

  @override
  int get totalCount => 0;

  @override
  FilterCriteria get currentFilter =>
      applied.isEmpty ? const FilterCriteria() : applied.last;

  @override
  Future<void> applyFilter(FilterCriteria criteria) async {
    applied.add(criteria);
  }

  @override
  Future<void> dispose() async {}
}

class _StubGalleryService extends GalleryService {
  _StubGalleryService(this.service);

  final LocalGalleryService service;

  @override
  LocalGalleryService build() => service;

  @override
  Future<void> ensureInitialized() async {}
}

class _TestAlbumNotifier extends GalleryAlbumNotifier {
  @override
  GalleryAlbumState build() => GalleryAlbumState(
    albums: [
      GalleryAlbum(
        id: 'album-a',
        name: 'Album A',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ],
  );
}

class _TestCategoryNotifier extends GalleryCategoryNotifier {
  @override
  GalleryCategoryState build() => const GalleryCategoryState();
}
