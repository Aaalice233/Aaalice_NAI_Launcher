import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/database_manager.dart';
import 'package:nai_launcher/core/database/database_providers.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';
import 'package:nai_launcher/data/services/gallery/local_gallery_query.dart';
import 'package:nai_launcher/data/services/gallery/local_gallery_repository.dart';
import 'package:nai_launcher/data/services/gallery/unified_gallery_service.dart';
import 'package:nai_launcher/presentation/agent_chat/services/local_gallery_toolbox.dart';
import 'package:nai_launcher/presentation/providers/gallery_category_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';

class _Files extends Fake implements LocalGalleryRepository {
  @override
  Future<List<LocalImageRecord>> loadRecords(
    List<File> files, {
    bool includeErrorPlaceholders = true,
  }) async => [
    for (final f in files)
      LocalImageRecord(path: f.path, size: 1, modifiedAt: DateTime(2026)),
  ];
}

class _Filters extends Fake implements GalleryFilterService {
  final operations = <String>[];
  Completer<void>? pageGate;
  late FilterCriteria agentCriteria;
  late List<File> input;

  @override
  Future<FilterResult> applyFilters(
    List<File> files,
    FilterCriteria criteria, {
    String? operationId,
    int fileListGeneration = 0,
  }) async {
    operations.add(operationId!);
    if (criteria.categoryId != null) {
      await pageGate?.future;
    } else {
      input = files;
      agentCriteria = criteria;
    }
    final matches = files
        .where(
          (f) =>
              f.path.contains(criteria.searchQuery) &&
              (criteria.categoryId == null || f.path.startsWith('folder/')),
        )
        .toList();
    return FilterResult(
      files: matches,
      totalCount: matches.length,
      executionTime: Duration.zero,
      criteria: criteria,
    );
  }
}

class _Service extends Fake implements LocalGalleryService {
  _Service(this.query);
  final LocalGalleryQuery query;
  @override
  Future<List<File>> initialize() async => query.allFiles;
  @override
  bool get isInitialized => true;
  @override
  int get totalCount => query.totalCount;
  @override
  int get filteredCount => query.filteredCount;
  @override
  FilterCriteria get currentFilter => query.currentFilter;
  @override
  Future<void> setPageSize(int size) async => query.setPageSize(size);
  @override
  Future<void> applyFilter(FilterCriteria criteria) =>
      query.applyFilter(criteria);
  @override
  Future<List<LocalImageRecord>> getPage(int page, {int? pageSize}) =>
      query.getPage(page, pageSize: pageSize);
  @override
  Future<LocalGalleryQueryPage> queryPage({
    required int page,
    int pageSize = 50,
    FilterCriteria criteria = const FilterCriteria(),
    bool includeFilePathMatches = false,
  }) => query.queryPage(
    page: page,
    pageSize: pageSize,
    criteria: criteria,
    includeFilePathMatches: includeFilePathMatches,
  );
  @override
  Future<void> dispose() async {}
}

class _Ids extends Fake implements GalleryDataSource {
  @override
  Future<Map<String, int>> getImageIdsByPaths(List<String> paths) async => {
    for (final (i, p) in paths.indexed) p: i + 1,
  };
}

class _Database extends Fake implements DatabaseManager {
  @override
  final galleryDataSource = _Ids();
}

void main() {
  for (final grouped in [false, true]) {
    test('工具跨文件夹查询，保留页面范围、搜索与${grouped ? "分组" : "第二页"}，不取消在途筛选', () async {
      final filters = _Filters();
      final query =
          LocalGalleryQuery(repository: _Files(), filterService: filters)
            ..replaceAll([
              File('folder/ui-hit.png'),
              File('other/hit.png'),
              File('folder/ui2.png'),
            ]);
      final service = _Service(query);
      final container = ProviderContainer(
        overrides: [
          galleryServiceProvider.overrideWith(
            () => GalleryService(createService: () => service),
          ),
          databaseManagerProvider.overrideWith((_) async => _Database()),
          galleryCategoryNotifierProvider.overrideWithBuild(
            (_, _) => const GalleryCategoryState(selectedCategoryId: 'folder'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final gallery = container.read(localGalleryNotifierProvider.notifier);
      await gallery.initialize();
      await gallery.setSelectedCategory('folder', 'folder');
      await gallery.setSearchQuery('ui');
      await gallery.setPageSize(1);
      await gallery.loadPage(1);
      if (grouped) await gallery.setGroupedView(true);
      final state = container.read(localGalleryNotifierProvider);
      expect(state.currentPage, 1);
      expect(state.currentImages.single.path, 'folder/ui2.png');
      if (grouped) expect(state.groupedImages.length, 2);
      final visible = query.effectiveFiles;
      final tool = container.read(
        Provider((ref) => LocalGalleryToolbox(ref).tools().first),
      );
      final args = {
        'query': ' hit ',
        'limit': 2,
        'tags': ['cat'],
        'favorites_only': true,
        'model': 'V4',
        'min_steps': 12,
        'date_start': '2026-01-01',
        'min_width': 512,
        'max_file_size': 20000,
        'metadata_statuses': ['success'],
      };
      final result = (await tool.execute('a', args)).details as Map;
      expect(result['total'], 2);
      expect(result['page'], 0);
      expect(result['page_size'], 2);
      expect((result['items'] as List).map((i) => i['name']), [
        'ui-hit.png',
        'hit.png',
      ]);
      final criteria = filters.agentCriteria;
      expect(criteria.searchQuery, 'hit');
      expect(criteria.selectedTags, ['cat']);
      expect(criteria.showFavoritesOnly, isTrue);
      expect(criteria.filterModel, 'V4');
      expect(criteria.filterMinSteps, 12);
      expect(criteria.dateStart, DateTime(2026));
      expect(criteria.minWidth, 512);
      expect(criteria.maxFileSize, 20000);
      expect(criteria.metadataStatuses, ['success']);
      expect(filters.input, same(query.allFiles));
      expect(query.effectiveFiles, same(visible));
      expect(container.read(localGalleryNotifierProvider), same(state));
      expect(
        container.read(galleryCategoryNotifierProvider).selectedCategoryId,
        'folder',
      );
      filters.pageGate = Completer<void>();
      final inFlight = gallery.setSearchQuery('ui2');
      await Future<void>.value();
      await tool.execute('b', args);
      filters.pageGate!.complete();
      await inFlight;
      expect(query.effectiveFiles.single.path, 'folder/ui2.png');
      expect(filters.operations.toSet().length, filters.operations.length);
      expect(container.read(localGalleryNotifierProvider).error, isNull);
    });
  }
}
