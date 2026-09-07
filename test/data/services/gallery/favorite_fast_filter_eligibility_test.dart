import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';
import 'package:nai_launcher/data/services/gallery/gallery_path_utils.dart';
import 'package:nai_launcher/data/services/gallery/local_gallery_query.dart';
import 'package:nai_launcher/data/services/gallery/local_gallery_repository.dart';

void main() {
  final root = p.join(Directory.systemTemp.path, 'favorite_fast_filter');
  File fileAt(String name) => File(p.join(root, name));

  final parentAlbumFavorite = fileAt('parent_album_favorite.png');
  final childAlbumFavorite = fileAt('child_album_favorite.png');
  final unfiledFavorite = fileAt('unfiled_favorite.png');
  final albumMemberWithoutFavorite = fileAt('album_member_plain.png');
  final allFiles = <File>[
    parentAlbumFavorite,
    childAlbumFavorite,
    unfiledFavorite,
    albumMemberWithoutFavorite,
  ];
  final favorites = <File>[
    parentAlbumFavorite,
    childAlbumFavorite,
    unfiledFavorite,
  ];

  late _FakeLocalGalleryRepository repository;
  late _RecordingFilterService filterService;
  late LocalGalleryQuery query;

  setUp(() {
    repository = _FakeLocalGalleryRepository(favorites: favorites);
    filterService = _RecordingFilterService(
      favorites: favorites,
      albumMembers: {
        'album-parent': [
          parentAlbumFavorite,
          childAlbumFavorite,
          albumMemberWithoutFavorite,
        ],
        'album-child': [childAlbumFavorite],
      },
    );
    query = LocalGalleryQuery(
      repository: repository,
      filterService: filterService,
    )..replaceAll(allFiles);
  });

  group('LocalGalleryQuery favorites fast path', () {
    test('serves favorites directly when no other criteria is set', () async {
      await query.applyFilter(const FilterCriteria(showFavoritesOnly: true));

      expect(repository.queryFavoriteImagesCalls, 1);
      expect(filterService.applyFiltersCalls, 0);
      expect(
        query.effectiveFiles.map((file) => file.path),
        favorites.map((file) => file.path),
      );
      expect(query.filteredCount, favorites.length);
    });

    test('intersects favorites with the selected album', () async {
      await query.applyFilter(
        const FilterCriteria(showFavoritesOnly: true, albumId: 'album-parent'),
      );

      expect(repository.queryFavoriteImagesCalls, 0);
      expect(filterService.applyFiltersCalls, 1);
      expect(query.effectiveFiles.map((file) => file.path), [
        parentAlbumFavorite.path,
        childAlbumFavorite.path,
      ]);
      expect(query.filteredCount, 2);
    });

    test('intersects favorites with a sub album', () async {
      await query.applyFilter(
        const FilterCriteria(showFavoritesOnly: true, albumId: 'album-child'),
      );

      expect(repository.queryFavoriteImagesCalls, 0);
      expect(query.effectiveFiles.map((file) => file.path), [
        childAlbumFavorite.path,
      ]);
    });

    test('keeps the favorites album on the shared filter pipeline', () async {
      await query.applyFilter(
        const FilterCriteria(showFavoritesOnly: true, albumId: 'favorites'),
      );

      expect(repository.queryFavoriteImagesCalls, 0);
      expect(filterService.applyFiltersCalls, 1);
      expect(
        query.effectiveFiles.map((file) => file.path),
        favorites.map((file) => file.path),
      );
    });

    test('leaves the album filter intact without the favorites flag', () async {
      await query.applyFilter(const FilterCriteria(albumId: 'album-parent'));

      expect(repository.queryFavoriteImagesCalls, 0);
      expect(query.effectiveFiles.map((file) => file.path), [
        parentAlbumFavorite.path,
        childAlbumFavorite.path,
        albumMemberWithoutFavorite.path,
      ]);
    });
  });

  group('isFavoriteOnlyFastFilter eligibility', () {
    final disqualifyingCriteria = <String, FilterCriteria>{
      'searchQuery': const FilterCriteria(
        showFavoritesOnly: true,
        searchQuery: 'sky',
      ),
      'dateStart': FilterCriteria(
        showFavoritesOnly: true,
        dateStart: DateTime(2026),
      ),
      'dateEnd': FilterCriteria(
        showFavoritesOnly: true,
        dateEnd: DateTime(2026, 2),
      ),
      'selectedTags': const FilterCriteria(
        showFavoritesOnly: true,
        selectedTags: ['1girl'],
      ),
      'filterModel': const FilterCriteria(
        showFavoritesOnly: true,
        filterModel: 'nai-diffusion-4-5-full',
      ),
      'filterSampler': const FilterCriteria(
        showFavoritesOnly: true,
        filterSampler: 'k_euler_ancestral',
      ),
      'filterMinSteps': const FilterCriteria(
        showFavoritesOnly: true,
        filterMinSteps: 10,
      ),
      'filterMaxSteps': const FilterCriteria(
        showFavoritesOnly: true,
        filterMaxSteps: 28,
      ),
      'filterMinCfg': const FilterCriteria(
        showFavoritesOnly: true,
        filterMinCfg: 4.5,
      ),
      'filterMaxCfg': const FilterCriteria(
        showFavoritesOnly: true,
        filterMaxCfg: 6.5,
      ),
      'filterResolution': const FilterCriteria(
        showFavoritesOnly: true,
        filterResolution: '832x1216',
      ),
      'minWidth': const FilterCriteria(showFavoritesOnly: true, minWidth: 512),
      'minHeight': const FilterCriteria(
        showFavoritesOnly: true,
        minHeight: 512,
      ),
      'maxWidth': const FilterCriteria(showFavoritesOnly: true, maxWidth: 2048),
      'maxHeight': const FilterCriteria(
        showFavoritesOnly: true,
        maxHeight: 2048,
      ),
      'minFileSize': const FilterCriteria(
        showFavoritesOnly: true,
        minFileSize: 1024,
      ),
      'maxFileSize': const FilterCriteria(
        showFavoritesOnly: true,
        maxFileSize: 4096,
      ),
      'metadataStatuses': const FilterCriteria(
        showFavoritesOnly: true,
        metadataStatuses: ['success'],
      ),
      'categoryId': const FilterCriteria(
        showFavoritesOnly: true,
        categoryId: 'category-1',
      ),
      'categoryFolderPath': const FilterCriteria(
        showFavoritesOnly: true,
        categoryFolderPath: 'characters',
      ),
      'albumId': const FilterCriteria(
        showFavoritesOnly: true,
        albumId: 'album-parent',
      ),
    };

    test('accepts only the bare favorites toggle', () {
      expect(
        isFavoriteOnlyFastFilter(const FilterCriteria(showFavoritesOnly: true)),
        isTrue,
      );
      expect(isFavoriteOnlyFastFilter(const FilterCriteria()), isFalse);
    });

    test('treats a blank search query as no filter', () {
      expect(
        isFavoriteOnlyFastFilter(
          const FilterCriteria(showFavoritesOnly: true, searchQuery: '   '),
        ),
        isTrue,
      );
    });

    test('rejects every other criteria field', () {
      for (final entry in disqualifyingCriteria.entries) {
        expect(
          isFavoriteOnlyFastFilter(entry.value),
          isFalse,
          reason: '${entry.key} must disqualify the favorites fast path',
        );
      }
    });

    test('covers every field carried by the cache key', () {
      final fullyPopulated = FilterCriteria(
        searchQuery: 'sky',
        dateStart: DateTime(2026),
        dateEnd: DateTime(2026, 2),
        showFavoritesOnly: true,
        selectedTags: const ['1girl'],
        filterModel: 'nai-diffusion-4-5-full',
        filterSampler: 'k_euler_ancestral',
        filterMinSteps: 10,
        filterMaxSteps: 28,
        filterMinCfg: 4.5,
        filterMaxCfg: 6.5,
        filterResolution: '832x1216',
        minWidth: 512,
        minHeight: 512,
        maxWidth: 2048,
        maxHeight: 2048,
        minFileSize: 1024,
        maxFileSize: 4096,
        metadataStatuses: const ['success'],
        categoryId: 'category-1',
        categoryFolderPath: 'characters',
        albumId: 'album-parent',
      );

      // cacheKey 承载 FilterCriteria 的相等性，新增字段必然出现在这里
      expect(
        fullyPopulated.cacheKey.split('|'),
        hasLength(disqualifyingCriteria.length + 1),
      );
    });
  });
}

Set<String> _pathKeys(Iterable<File> files) => {
  for (final file in files) galleryFilePathKey(file.path),
};

class _FakeLocalGalleryRepository extends Mock
    implements LocalGalleryRepository {
  _FakeLocalGalleryRepository({required this.favorites});

  final List<File> favorites;
  int queryFavoriteImagesCalls = 0;

  @override
  Future<List<GalleryImageRecord>> queryFavoriteImages({
    required int limit,
  }) async {
    queryFavoriteImagesCalls++;
    final timestamp = DateTime(2026);
    return favorites
        .take(limit)
        .map(
          (file) => GalleryImageRecord(
            filePath: file.path,
            fileName: p.basename(file.path),
            fileSize: 4,
            modifiedAt: timestamp,
            createdAt: timestamp,
            indexedAt: timestamp,
            dateYmd: 20260101,
            isFavorite: true,
          ),
        )
        .toList();
  }
}

/// Mirrors the favorites and album stages of the shared filter pipeline.
class _RecordingFilterService extends Mock implements GalleryFilterService {
  _RecordingFilterService({
    required List<File> favorites,
    required Map<String, List<File>> albumMembers,
  }) : _favoriteKeys = _pathKeys(favorites),
       _albumMemberKeys = {
         for (final entry in albumMembers.entries)
           entry.key: _pathKeys(entry.value),
       };

  final Set<String> _favoriteKeys;
  final Map<String, Set<String>> _albumMemberKeys;
  int applyFiltersCalls = 0;

  @override
  Future<FilterResult> applyFilters(
    List<File> allFiles,
    FilterCriteria criteria, {
    String? operationId,
    int fileListGeneration = 0,
  }) async {
    applyFiltersCalls++;
    var filtered = allFiles;
    if (criteria.showFavoritesOnly) {
      filtered = _retain(filtered, _favoriteKeys);
    }
    final albumId = criteria.albumId;
    if (albumId != null) {
      filtered = _retain(
        filtered,
        albumId == 'favorites'
            ? _favoriteKeys
            : _albumMemberKeys[albumId] ?? const <String>{},
      );
    }
    return FilterResult(
      files: filtered,
      totalCount: filtered.length,
      executionTime: Duration.zero,
      criteria: criteria,
    );
  }

  @override
  void cancelFilter(String operationId) {}

  List<File> _retain(List<File> files, Set<String> keys) => files
      .where((file) => keys.contains(galleryFilePathKey(file.path)))
      .toList();
}
