import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;

import '../../../core/exceptions/gallery_exceptions.dart';
import '../../models/gallery/local_image_record.dart';
import 'gallery_filter_service.dart';
import 'gallery_folder_counts.dart';
import 'gallery_path_utils.dart';
import 'local_gallery_repository.dart';
import 'local_gallery_service.dart';

bool isFavoriteOnlyFastFilter(FilterCriteria criteria) {
  if (!criteria.showFavoritesOnly) return false;
  // Derived from hasFilters: new fields disqualify it, a blank query does not.
  final withoutFavorites = criteria.copyWith(
    showFavoritesOnly: false,
    searchQuery: criteria.searchQuery.trim(),
  );
  return !withoutFavorites.hasFilters;
}

/// Owns the authoritative in-memory file ordering and derived query results.
class LocalGalleryQuery {
  LocalGalleryQuery({
    required LocalGalleryRepository repository,
    required GalleryFilterService filterService,
  }) : _repository = repository,
       _filterService = filterService;

  final LocalGalleryRepository _repository;
  final GalleryFilterService _filterService;

  List<File> _allFiles = [];
  final folderCounts = GalleryFolderCounts();
  List<File> _filteredFiles = [];
  FilterCriteria _currentFilter = const FilterCriteria();
  int _fileListGeneration = 0;
  int _filterGeneration = 0;
  int _independentQueryGeneration = 0;
  String? _activeFilterOperationId;
  int _pageSize = 50;

  List<File> get allFiles => _allFiles;
  List<File> get effectiveFiles =>
      _currentFilter.hasFilters ? _filteredFiles : _allFiles;
  int get totalCount => _allFiles.length;
  int get filteredCount =>
      _currentFilter.hasFilters ? _filteredFiles.length : totalCount;
  FilterCriteria get currentFilter => _currentFilter;

  /// Bumped whenever the membership or ordering of [allFiles] changes.
  int get fileListGeneration => _fileListGeneration;

  void replaceAll(List<File> files) {
    _allFiles = files;
    folderCounts.replaceFiles(files);
    _fileListGeneration++;
    if (!_currentFilter.hasFilters) _filteredFiles = files;
  }

  String resolveTrackedPath(String filePath) {
    final normalized = normalizeGalleryFilePath(filePath);
    final key = galleryFilePathKey(normalized);
    for (final file in _allFiles) {
      if (galleryFilePathKey(file.path) == key) return file.path;
    }
    return normalized;
  }

  bool containsPath(String filePath) {
    final key = galleryFilePathKey(filePath);
    return _allFiles.any((file) => galleryFilePathKey(file.path) == key);
  }

  void addFirst(File file) {
    if (containsPath(file.path)) return;
    // 异步查询仍持有旧版本的列表。
    _allFiles = [file, ..._allFiles];
    folderCounts.addToFolder(p.dirname(file.path), 1);
    _fileListGeneration++;
  }

  Future<void> syncAfterMutation(File file) async {
    addFirst(file);
    if (_currentFilter.hasFilters) {
      await applyFilter(_currentFilter);
    } else {
      _filteredFiles = _allFiles;
    }
  }

  /// Drops [filePaths] from both the full and the filtered ordering and
  /// returns the tracked spellings that were removed.
  List<String> removePaths(Iterable<String> filePaths) {
    final keys = {for (final path in filePaths) galleryFilePathKey(path)};
    final removed = <String>[];
    final remaining = <File>[];
    for (final file in _allFiles) {
      if (keys.contains(galleryFilePathKey(file.path))) {
        removed.add(file.path);
        folderCounts.addToFolder(p.dirname(file.path), -1);
      } else {
        remaining.add(file);
      }
    }
    if (removed.isEmpty) return removed;

    _allFiles = remaining;
    _fileListGeneration++;
    // Removing members keeps every surviving file's filter verdict valid.
    _filteredFiles = _currentFilter.hasFilters
        ? [
            for (final file in _filteredFiles)
              if (!keys.contains(galleryFilePathKey(file.path))) file,
          ]
        : _allFiles;
    return removed;
  }

  Future<void> applyFilter(FilterCriteria criteria) async {
    final generation = ++_filterGeneration;
    final previousOperationId = _activeFilterOperationId;
    if (previousOperationId != null) {
      _filterService.cancelFilter(previousOperationId);
      _activeFilterOperationId = null;
    }
    _currentFilter = criteria;

    if (!criteria.hasFilters) {
      if (generation == _filterGeneration) _filteredFiles = _allFiles;
      return;
    }

    if (isFavoriteOnlyFastFilter(criteria)) {
      final records = await _repository.queryFavoriteImages(
        limit: max(1, _allFiles.length),
      );
      if (generation != _filterGeneration || _currentFilter != criteria) return;
      final pathToFile = {
        for (final file in _allFiles) galleryFilePathKey(file.path): file,
      };
      _filteredFiles = [
        for (final record in records)
          if (pathToFile[galleryFilePathKey(record.filePath)] != null)
            pathToFile[galleryFilePathKey(record.filePath)]!,
      ];
      return;
    }

    final operationId = 'local_gallery_filter_$generation';
    _activeFilterOperationId = operationId;
    try {
      final result = await _filterService.applyFilters(
        _allFiles,
        criteria,
        operationId: operationId,
        fileListGeneration: _fileListGeneration,
      );
      if (generation != _filterGeneration || _currentFilter != criteria) return;
      _filteredFiles = result.files;
    } on FilterCancelledException {
      if (generation == _filterGeneration) rethrow;
    } catch (error) {
      throw GalleryFilterException(
        filterCriteria: criteria.toString(),
        message: 'Failed to apply filter',
        cause: error,
      );
    } finally {
      if (_activeFilterOperationId == operationId) {
        _activeFilterOperationId = null;
      }
    }
  }

  Future<List<LocalImageRecord>> getPage(int page, {int? pageSize}) async {
    final effectivePageSize = pageSize ?? _pageSize;
    final totalPages = (effectiveFiles.length / effectivePageSize).ceil();
    if (page < 0 || (totalPages > 0 && page >= totalPages)) return [];
    final start = page * effectivePageSize;
    final end = min(start + effectivePageSize, effectiveFiles.length);
    return _repository.loadRecords(effectiveFiles.sublist(start, end));
  }

  Future<LocalGalleryQueryPage> queryPage({
    required int page,
    required int pageSize,
    FilterCriteria criteria = const FilterCriteria(),
    bool includeFilePathMatches = false,
  }) async {
    if (page < 0) throw RangeError.range(page, 0, null, 'page');
    if (pageSize <= 0) throw RangeError.range(pageSize, 1, null, 'pageSize');

    final filesSnapshot = _allFiles;
    final snapshotGeneration = _fileListGeneration;
    var matchingFiles = filesSnapshot;
    if (criteria.hasFilters) {
      final queryGeneration = ++_independentQueryGeneration;
      final result = await _filterService.applyFilters(
        filesSnapshot,
        criteria,
        operationId: 'local_gallery_query_$queryGeneration',
        fileListGeneration: snapshotGeneration,
      );
      matchingFiles = result.files;
      if (includeFilePathMatches &&
          criteria.searchQuery.isNotEmpty &&
          !criteria.copyWith(searchQuery: '').hasFilters) {
        final databaseMatches = {
          for (final file in matchingFiles) galleryFilePathKey(file.path),
        };
        final text = criteria.searchQuery.toLowerCase();
        matchingFiles = filesSnapshot
            .where(
              (file) =>
                  databaseMatches.contains(galleryFilePathKey(file.path)) ||
                  file.path.toLowerCase().contains(text),
            )
            .toList(growable: false);
      }
    }

    final start = page * pageSize;
    final pageFiles = matchingFiles.sublist(
      min(start, matchingFiles.length),
      min(start + pageSize, matchingFiles.length),
    );
    final records = await _repository.loadRecords(pageFiles);
    return LocalGalleryQueryPage(
      records: records,
      page: page,
      pageSize: pageSize,
      totalCount: matchingFiles.length,
    );
  }

  Future<List<LocalImageRecord>> getRecordsByPaths(List<String> paths) async {
    if (paths.isEmpty) return [];
    final existing = <File>[];
    for (final path in paths) {
      final file = File(resolveTrackedPath(path));
      if (await file.exists()) existing.add(file);
    }
    return _repository.loadRecords(existing, includeErrorPlaceholders: false);
  }

  List<String> getFilteredImagePaths() =>
      effectiveFiles.map((file) => file.path).toList(growable: false);

  void setPageSize(int size) => _pageSize = size;

  void clear() {
    _filterGeneration++;
    final operationId = _activeFilterOperationId;
    if (operationId != null) _filterService.cancelFilter(operationId);
    _activeFilterOperationId = null;
    _allFiles = [];
    folderCounts.replaceFiles(const []);
    _filteredFiles = [];
    _fileListGeneration++;
    _currentFilter = const FilterCriteria();
  }
}
