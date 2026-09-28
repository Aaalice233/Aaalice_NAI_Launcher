import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nai_launcher/core/database/connection_pool_holder.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';
import 'package:nai_launcher/data/services/gallery/local_gallery_query.dart';
import 'package:nai_launcher/data/services/gallery/local_gallery_repository.dart';

/// Category filtering is pure path matching, so these cases isolate the cache
/// key from database state and the file system.
const String _root = '/gallery_cache_generation';
const String _category = 'tracked';
const FilterCriteria _criteria = FilterCriteria(categoryFolderPath: _category);

File _tracked(String name) => File('$_root/$_category/$name');

String _trackedPath(String name) => '$_root/$_category/$name';

List<String> _pathsOf(Iterable<File> files) =>
    files.map((file) => file.path).toList();

void main() {
  setUpAll(() async {
    await AppLogger.initialize(isTestEnvironment: true);
  });

  group('GalleryFilterService cache key', () {
    late GalleryFilterService filterService;

    setUp(() {
      filterService = GalleryFilterService(GalleryDataSource());
    });

    test('reuses the cached result for the same list and generation', () async {
      final files = [_tracked('a.png'), _tracked('b.png')];

      final first = await filterService.applyFilters(
        files,
        _criteria,
        fileListGeneration: 7,
      );
      final second = await filterService.applyFilters(
        files,
        _criteria,
        fileListGeneration: 7,
      );

      expect(first.fromCache, isFalse);
      expect(second.fromCache, isTrue);
      expect(_pathsOf(second.files), _pathsOf(files));
    });

    test('separates equally sized lists with different paths', () async {
      final first = [_tracked('a.png'), _tracked('b.png')];
      final second = [_tracked('c.png'), _tracked('d.png')];

      final firstResult = await filterService.applyFilters(
        first,
        _criteria,
        fileListGeneration: 1,
      );
      final secondResult = await filterService.applyFilters(
        second,
        _criteria,
        fileListGeneration: 2,
      );

      expect(firstResult.fromCache, isFalse);
      expect(_pathsOf(firstResult.files), _pathsOf(first));
      expect(secondResult.fromCache, isFalse);
      expect(_pathsOf(secondResult.files), _pathsOf(second));
    });

    test('separates a renamed file from its previous path', () async {
      final before = [_tracked('keep.png'), _tracked('old_name.png')];
      final after = [_tracked('keep.png'), _tracked('new_name.png')];

      await filterService.applyFilters(
        before,
        _criteria,
        fileListGeneration: 1,
      );
      final result = await filterService.applyFilters(
        after,
        _criteria,
        fileListGeneration: 2,
      );

      expect(result.fromCache, isFalse);
      expect(_pathsOf(result.files), [
        _trackedPath('keep.png'),
        _trackedPath('new_name.png'),
      ]);
    });

    test('separates a reordering of the same members', () async {
      final ordered = [_tracked('a.png'), _tracked('b.png')];
      final reordered = [_tracked('b.png'), _tracked('a.png')];

      await filterService.applyFilters(
        ordered,
        _criteria,
        fileListGeneration: 1,
      );
      final result = await filterService.applyFilters(
        reordered,
        _criteria,
        fileListGeneration: 2,
      );

      expect(result.fromCache, isFalse);
      expect(_pathsOf(result.files), [
        _trackedPath('b.png'),
        _trackedPath('a.png'),
      ]);
    });

    test('treats an omitted generation as generation zero', () async {
      final files = [_tracked('a.png')];

      final first = await filterService.applyFilters(files, _criteria);
      final second = await filterService.applyFilters(files, _criteria);
      final explicitZero = await filterService.applyFilters(
        files,
        _criteria,
        fileListGeneration: 0,
      );

      expect(first.fromCache, isFalse);
      expect(second.fromCache, isTrue);
      expect(explicitZero.fromCache, isTrue);
    });
  });

  group('LocalGalleryQuery file list generation', () {
    late GalleryFilterService filterService;
    late LocalGalleryQuery query;

    setUp(() {
      final dataSource = GalleryDataSource();
      filterService = GalleryFilterService(dataSource);
      query = LocalGalleryQuery(
        repository: LocalGalleryRepository(dataSource: dataSource),
        filterService: filterService,
      );
    });

    int cacheHits() => filterService.cacheStatistics['hitCount'] as int;

    test('re-filters an equally sized replacement list', () async {
      query.replaceAll([_tracked('a.png'), _tracked('b.png')]);
      await query.applyFilter(_criteria);
      final hitsAfterFirst = cacheHits();

      query.replaceAll([_tracked('c.png'), _tracked('d.png')]);
      await query.applyFilter(_criteria);

      expect(cacheHits(), hitsAfterFirst);
      expect(_pathsOf(query.effectiveFiles), [
        _trackedPath('c.png'),
        _trackedPath('d.png'),
      ]);
    });

    test('surfaces a renamed file instead of its previous path', () async {
      query.replaceAll([_tracked('keep.png'), _tracked('old_name.png')]);
      await query.applyFilter(_criteria);

      query.replaceAll([_tracked('keep.png'), _tracked('new_name.png')]);
      await query.applyFilter(_criteria);

      expect(_pathsOf(query.effectiveFiles), [
        _trackedPath('keep.png'),
        _trackedPath('new_name.png'),
      ]);
    });

    test('keeps the new order when only the ordering changed', () async {
      query.replaceAll([_tracked('a.png'), _tracked('b.png')]);
      await query.applyFilter(_criteria);
      final hitsAfterFirst = cacheHits();

      query.replaceAll([_tracked('b.png'), _tracked('a.png')]);
      await query.applyFilter(_criteria);

      expect(cacheHits(), hitsAfterFirst);
      expect(_pathsOf(query.effectiveFiles), [
        _trackedPath('b.png'),
        _trackedPath('a.png'),
      ]);
    });

    test('a scan-free refresh reports the replacement list', () async {
      query.replaceAll([_tracked('a.png'), _tracked('b.png')]);
      await query.applyFilter(_criteria);
      final hitsAfterFirst = cacheHits();

      // Mirrors the onFilesLoaded callback LocalGalleryServiceImpl.refresh
      // runs before any index scan starts.
      query.replaceAll([_tracked('c.png'), _tracked('d.png')]);
      await query.applyFilter(query.currentFilter);

      expect(cacheHits(), hitsAfterFirst);
      expect(query.filteredCount, 2);
      expect(query.getFilteredImagePaths(), [
        _trackedPath('c.png'),
        _trackedPath('d.png'),
      ]);
    });

    test('bumps the generation for every list mutation', () async {
      final initial = query.fileListGeneration;

      query.replaceAll([_tracked('a.png')]);
      final afterReplace = query.fileListGeneration;
      query.addFirst(_tracked('b.png'));
      final afterInsert = query.fileListGeneration;
      query.clear();

      expect(afterReplace, greaterThan(initial));
      expect(afterInsert, greaterThan(afterReplace));
      expect(query.fileListGeneration, greaterThan(afterInsert));
    });

    test('keeps the cache when addFirst skips a tracked path', () async {
      query.replaceAll([_tracked('a.png')]);
      await query.applyFilter(_criteria);
      final generation = query.fileListGeneration;
      final hitsAfterFirst = cacheHits();

      query.addFirst(_tracked('a.png'));
      await query.applyFilter(_criteria);

      expect(query.fileListGeneration, generation);
      expect(cacheHits(), hitsAfterFirst + 1);
      expect(_pathsOf(query.effectiveFiles), [_trackedPath('a.png')]);
    });
  });

  group('gallery filter cache against a real store', () {
    late Directory tempDir;
    late Directory trackedDir;
    late GalleryDataSource dataSource;
    late GalleryFilterService filterService;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'nai_launcher_filter_cache_generation_',
      );
      trackedDir = Directory(p.join(tempDir.path, _category));
      await trackedDir.create(recursive: true);

      await ConnectionPoolHolder.initialize(
        dbPath: p.join(tempDir.path, 'gallery.db'),
        maxConnections: 2,
      );
      dataSource = GalleryDataSource();
      await dataSource.initialize();
      filterService = GalleryFilterService(dataSource);
    });

    tearDown(() async {
      await dataSource.dispose();
      await ConnectionPoolHolder.dispose();
      if (await tempDir.exists()) {
        await _deleteDirectoryWithRetry(tempDir);
      }
    });

    Future<File> createTrackedImage(String name) async {
      final file = File(p.join(trackedDir.path, name));
      await file.writeAsBytes(<int>[137, 80, 78, 71]);
      return file;
    }

    test('a data revision change invalidates an unchanged list', () async {
      final files = [await createTrackedImage('a.png')];

      final first = await filterService.applyFilters(
        files,
        _criteria,
        fileListGeneration: 3,
      );
      final cached = await filterService.applyFilters(
        files,
        _criteria,
        fileListGeneration: 3,
      );

      await dataSource.upsertImage(
        filePath: files.single.path,
        fileName: p.basename(files.single.path),
        fileSize: await files.single.length(),
        createdAt: DateTime(2026),
        modifiedAt: DateTime(2026),
      );

      final afterRevision = await filterService.applyFilters(
        files,
        _criteria,
        fileListGeneration: 3,
      );

      expect(first.fromCache, isFalse);
      expect(cached.fromCache, isTrue);
      expect(afterRevision.fromCache, isFalse);
      expect(_pathsOf(afterRevision.files), _pathsOf(files));
    });

    test('an independent query page keys on its snapshot generation', () async {
      final query = LocalGalleryQuery(
        repository: LocalGalleryRepository(dataSource: dataSource),
        filterService: filterService,
      );
      final before = [
        await createTrackedImage('needle_a.png'),
        await createTrackedImage('needle_b.png'),
      ];
      final after = [
        await createTrackedImage('needle_c.png'),
        await createTrackedImage('needle_d.png'),
      ];

      query.replaceAll(before);
      await query.queryPage(page: 0, pageSize: 10, searchQuery: 'needle');
      final hitsAfterFirst = filterService.cacheStatistics['hitCount'] as int;
      await query.queryPage(page: 0, pageSize: 10, searchQuery: 'needle');
      final hitsAfterRepeat = filterService.cacheStatistics['hitCount'] as int;

      query.replaceAll(after);
      final replacedPage = await query.queryPage(
        page: 0,
        pageSize: 10,
        searchQuery: 'needle',
      );

      expect(hitsAfterRepeat, hitsAfterFirst + 1);
      expect(filterService.cacheStatistics['hitCount'], hitsAfterRepeat);
      expect(
        replacedPage.records.map((record) => record.path),
        _pathsOf(after),
      );
    });
  });
}

Future<void> _deleteDirectoryWithRetry(Directory directory) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      return;
    } on FileSystemException {
      if (attempt == 9) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
