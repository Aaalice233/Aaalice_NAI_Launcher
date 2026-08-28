import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../data/models/vibe/vibe_library_category.dart';
import '../../data/models/vibe/vibe_library_entry.dart';
import '../../data/models/vibe/vibe_reference.dart';
import '../../data/services/vibe_bulk_operation_types.dart';
import '../../data/services/vibe_file_storage_service.dart';
import '../../data/services/vibe_library_command_service.dart';
import '../../data/services/vibe_library_storage_service.dart';

part 'vibe_library_provider.freezed.dart';
part 'vibe_library_provider.g.dart';

@freezed
class VibeLibraryState with _$VibeLibraryState {
  const factory VibeLibraryState({
    @Default([]) List<VibeLibraryEntry> entries,
    @Default([]) List<VibeLibraryCategory> categories,
    @Default(0) int currentPage,
    @Default(50) int pageSize,
    @Default('') String searchQuery,
    String? selectedCategoryId,
    @Default(false) bool favoritesOnly,
    @Default(VibeLibrarySortOrder.createdAt) VibeLibrarySortOrder sortOrder,
    @Default(true) bool sortDescending,
    @Default(false) bool isLoading,
    @Default(false) bool isInitializing,
    String? error,
    @Default(false) bool isBulkOperating,
    @Default(0.0) double bulkOperationProgress,
    @Default(VibeLibraryBulkOperationType.none)
    VibeLibraryBulkOperationType bulkOperationType,
  }) = _VibeLibraryState;

  const VibeLibraryState._();

  List<VibeLibraryEntry> get filteredEntries {
    var result = List<VibeLibraryEntry>.of(entries);
    if (searchQuery.isNotEmpty) result = result.search(searchQuery);
    if (selectedCategoryId != null) {
      result = result.getByCategory(selectedCategoryId!);
    }
    if (favoritesOnly) result = result.favorites;
    final sorted = switch (sortOrder) {
      VibeLibrarySortOrder.createdAt => result.sortedByCreatedAt(),
      VibeLibrarySortOrder.lastUsed => result.sortedByLastUsed(),
      VibeLibrarySortOrder.usedCount => result.sortedByUsedCount(),
      VibeLibrarySortOrder.name => result.sortedByName(),
    };
    return List.unmodifiable(sortDescending ? sorted : sorted.reversed);
  }

  List<VibeLibraryEntry> get currentEntries {
    final filtered = filteredEntries;
    final start = currentPage * pageSize;
    if (start < 0 || start >= filtered.length) return const [];
    return List.unmodifiable(
      filtered.sublist(start, min(start + pageSize, filtered.length)),
    );
  }

  int get totalPages =>
      filteredCount == 0 ? 0 : (filteredCount / pageSize).ceil();
  int get totalCount => entries.length;
  int get filteredCount => filteredEntries.length;
  bool get hasFilters =>
      searchQuery.isNotEmpty || selectedCategoryId != null || favoritesOnly;
  VibeLibraryCategory? get selectedCategory => selectedCategoryId == null
      ? null
      : categories.cast<VibeLibraryCategory?>().firstWhere(
          (category) => category?.id == selectedCategoryId,
          orElse: () => null,
        );
  int get favoriteCount => entries.where((entry) => entry.isFavorite).length;
  Set<String> get allTags => {for (final entry in entries) ...entry.tags};
}

enum VibeLibrarySortOrder { createdAt, lastUsed, usedCount, name }

enum VibeLibraryBulkOperationType {
  none,
  import,
  export,
  delete,
  favorite,
  moveCategory,
  updateTags,
}

@Riverpod(keepAlive: true)
class VibeLibraryNotifier extends _$VibeLibraryNotifier {
  VibeLibraryStorageService get _storage =>
      ref.read(vibeLibraryStorageServiceProvider);
  VibeLibraryCommandService get _commands =>
      VibeLibraryCommandService(_storage);
  Future<void>? _activeLoad;

  @override
  VibeLibraryState build() {
    ref.watch(vibeLibraryStorageServiceProvider);
    return const VibeLibraryState();
  }

  Future<void> initialize() async {
    if (state.entries.isNotEmpty || state.isInitializing) return;
    await _load(isInitializing: true, showLoading: true);
  }

  Future<void> reload({
    bool syncFileSystem = false,
    bool showLoading = false,
  }) async {
    if (syncFileSystem) await syncWithFileSystem();
    await _load(isInitializing: false, showLoading: showLoading);
  }

  Future<void> loadFromCache({bool showLoading = false}) =>
      _load(isInitializing: false, showLoading: showLoading);

  Future<VibeFolderSyncResult> syncWithFileSystem() async {
    try {
      final result = await _storage.syncWithFileSystem(
        removeMissingEntries: true,
      );
      if (result.upsertedCount > 0 || result.deletedCount > 0) {
        await loadFromCache();
      }
      return result;
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to sync Vibe library',
        error,
        stackTrace,
        'VibeLibrary',
      );
      return VibeFolderSyncResult(
        scannedCount: 0,
        upsertedCount: 0,
        deletedCount: 0,
        failedCount: 1,
        errors: [error.toString()],
      );
    }
  }

  Future<void> _load({
    required bool isInitializing,
    required bool showLoading,
  }) async {
    final active = _activeLoad;
    if (active != null) return active;
    final operation = _performLoad(
      isInitializing: isInitializing,
      showLoading: showLoading,
    );
    _activeLoad = operation;
    try {
      await operation;
    } finally {
      if (identical(_activeLoad, operation)) _activeLoad = null;
    }
  }

  Future<void> _performLoad({
    required bool isInitializing,
    required bool showLoading,
  }) async {
    state = state.copyWith(
      isLoading: showLoading,
      isInitializing: isInitializing,
      error: null,
    );
    try {
      final values = await Future.wait([
        _storage.getDisplayEntries(),
        _storage.getAllCategories(),
      ]);
      state = state.copyWith(
        entries: values[0] as List<VibeLibraryEntry>,
        categories: values[1] as List<VibeLibraryCategory>,
        currentPage: 0,
        isLoading: false,
        isInitializing: false,
        error: null,
      );
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to load Vibe library',
        error,
        stackTrace,
        'VibeLibrary',
      );
      state = state.copyWith(
        isLoading: false,
        isInitializing: false,
        error: error.toString(),
      );
    }
  }

  Future<void> loadPage(int page) async {
    if (state.filteredCount == 0) {
      state = state.copyWith(currentPage: 0);
    } else if (page >= 0 && page < state.totalPages) {
      state = state.copyWith(currentPage: page);
    }
  }

  Future<void> loadNextPage() => loadPage(state.currentPage + 1);
  Future<void> loadPreviousPage() => loadPage(state.currentPage - 1);
  Future<void> setSearchQuery(String query) =>
      _setCriteria(searchQuery: query.trim());
  Future<void> clearSearch() => _setCriteria(searchQuery: '');
  Future<void> setCategoryFilter(String? categoryId) => _setCriteria(
    categoryId: categoryId,
    updateCategory: true,
    favoritesOnly: false,
  );
  Future<void> clearCategoryFilter() =>
      _setCriteria(categoryId: null, updateCategory: true);
  Future<void> setFavoritesOnly(bool value) => _setCriteria(
    categoryId: value ? null : state.selectedCategoryId,
    updateCategory: value,
    favoritesOnly: value,
  );
  Future<void> toggleFavoritesOnly() => setFavoritesOnly(!state.favoritesOnly);

  Future<void> _setCriteria({
    String? searchQuery,
    String? categoryId,
    bool updateCategory = false,
    bool? favoritesOnly,
  }) async {
    state = state.copyWith(
      searchQuery: searchQuery ?? state.searchQuery,
      selectedCategoryId: updateCategory
          ? categoryId
          : state.selectedCategoryId,
      favoritesOnly: favoritesOnly ?? state.favoritesOnly,
      currentPage: 0,
    );
  }

  Future<void> setSortOrder(VibeLibrarySortOrder order) async {
    state = order == state.sortOrder
        ? state.copyWith(sortDescending: !state.sortDescending, currentPage: 0)
        : state.copyWith(
            sortOrder: order,
            sortDescending: true,
            currentPage: 0,
          );
  }

  Future<void> setSortDescending(bool value) async {
    state = state.copyWith(sortDescending: value, currentPage: 0);
  }

  Future<void> setPageSize(int size) async {
    if (size > 0) state = state.copyWith(pageSize: size, currentPage: 0);
  }

  Future<void> clearAllFilters() => _setCriteria(
    searchQuery: '',
    categoryId: null,
    updateCategory: true,
    favoritesOnly: false,
  );

  void _upsert(VibeLibraryEntry entry) {
    final display = entry.toDisplayEntry();
    final entries = List<VibeLibraryEntry>.of(state.entries);
    final index = entries.indexWhere((candidate) => candidate.id == entry.id);
    index < 0 ? entries.add(display) : entries[index] = display;
    state = _withValidCurrentPage(state.copyWith(entries: entries));
  }

  VibeLibraryState _withValidCurrentPage(VibeLibraryState next) {
    final lastPage = max(0, next.totalPages - 1);
    return next.currentPage <= lastPage
        ? next
        : next.copyWith(currentPage: lastPage);
  }

  Future<VibeLibraryEntry?> _dispatchEntry(
    Future<VibeLibraryEntry?> Function() command,
  ) async {
    try {
      final entry = await command();
      if (entry != null) _upsert(entry);
      return entry;
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to write Vibe library entry',
        error,
        stackTrace,
        'VibeLibrary',
      );
      state = state.copyWith(error: error.toString());
      return null;
    }
  }

  Future<VibeLibraryEntry?> saveEntry(VibeLibraryEntry entry) =>
      _dispatchEntry(() => _storage.saveEntry(entry));
  Future<VibeLibraryEntry?> saveEntryParams(
    String id, {
    required double strength,
    required double infoExtracted,
    VibeReference? persistedVibeData,
  }) => _dispatchEntry(
    () => _storage.saveEntryParams(
      id,
      strength: strength,
      infoExtracted: infoExtracted,
      persistedVibeData: persistedVibeData,
    ),
  );
  Future<VibeLibraryEntry?> saveBundleChildParams(
    String id, {
    required int childIndex,
    required double strength,
    required double infoExtracted,
    VibeReference? persistedVibeData,
  }) => _dispatchEntry(
    () => _storage.saveBundleChildParams(
      id,
      childIndex: childIndex,
      strength: strength,
      infoExtracted: infoExtracted,
      persistedVibeData: persistedVibeData,
    ),
  );
  Future<VibeLibraryEntry?> saveBundleEntry(
    List<VibeReference> vibes, {
    required String name,
    String? categoryId,
    List<String>? tags,
  }) => _dispatchEntry(
    () => _storage.saveBundleEntry(
      vibes,
      name: name,
      categoryId: categoryId,
      tags: tags,
    ),
  );
  Future<VibeLibraryEntry?> saveImportedEntry(VibeLibraryEntry entry) =>
      _dispatchEntry(() => _storage.saveEntry(entry));
  Future<VibeLibraryEntry?> saveImportedBundle(
    List<VibeReference> vibes, {
    required String name,
    String? categoryId,
    List<String>? tags,
    VibeLibraryEntry? replaceEntry,
  }) => _dispatchEntry(
    () => _storage.saveBundleEntry(
      vibes,
      name: name,
      categoryId: categoryId,
      tags: tags,
      replaceEntry: replaceEntry,
    ),
  );

  Future<bool> deleteEntry(String id) async {
    try {
      final deleted = await _storage.deleteEntry(id);
      if (deleted) {
        state = _withValidCurrentPage(
          state.copyWith(
            entries: state.entries.where((entry) => entry.id != id).toList(),
          ),
        );
      }
      return deleted;
    } catch (error, stackTrace) {
      AppLogger.e('Failed to delete entry', error, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: error.toString());
      return false;
    }
  }

  Future<int> deleteEntries(List<String> ids) async {
    try {
      final count = await _storage.deleteEntries(ids);
      final removed = ids.toSet();
      state = _withValidCurrentPage(
        state.copyWith(
          entries: state.entries
              .where((entry) => !removed.contains(entry.id))
              .toList(),
        ),
      );
      return count;
    } catch (error, stackTrace) {
      AppLogger.e('Failed to delete entries', error, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: error.toString());
      return 0;
    }
  }

  Future<VibeLibraryEntry?> toggleFavorite(String id) =>
      _dispatchEntry(() => _storage.toggleFavorite(id));
  Future<VibeLibraryEntry?> updateEntryCategory(
    String id,
    String? categoryId,
  ) => _dispatchEntry(() => _storage.updateEntryCategory(id, categoryId));
  Future<VibeLibraryEntry?> updateEntryEncodingModel(String id, String model) =>
      _dispatchEntry(() => _storage.updateEntryEncodingModel(id, model));
  Future<VibeLibraryEntry?> updateEntryTags(String id, List<String> tags) =>
      _dispatchEntry(() => _storage.updateEntryTags(id, tags));
  Future<VibeLibraryEntry?> updateEntryThumbnail(String id, Uint8List? value) =>
      _dispatchEntry(() => _storage.updateEntryThumbnail(id, value));
  Future<VibeLibraryEntry?> recordUsage(String id) =>
      _dispatchEntry(() => _storage.incrementUsedCount(id));

  Future<VibeEntryRenameResult> renameEntry(String id, String name) async {
    try {
      final result = await _storage.renameEntry(id, name);
      if (result.entry != null) _upsert(result.entry!);
      return result;
    } catch (error, stackTrace) {
      AppLogger.e('Failed to rename entry', error, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: error.toString());
      return const VibeEntryRenameResult.failure(
        VibeEntryRenameError.fileRenameFailed,
      );
    }
  }

  Future<VibeLibraryCategory?> saveCategory(
    VibeLibraryCategory category,
  ) async {
    try {
      final saved = await _storage.saveCategory(category);
      final categories = List<VibeLibraryCategory>.of(state.categories);
      final index = categories.indexWhere((item) => item.id == saved.id);
      index < 0 ? categories.add(saved) : categories[index] = saved;
      state = state.copyWith(categories: categories);
      return saved;
    } catch (error, stackTrace) {
      AppLogger.e('Failed to save category', error, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: error.toString());
      return null;
    }
  }

  Future<bool> deleteCategory(
    String id, {
    bool moveEntriesToParent = true,
  }) async {
    try {
      final deleted = await _storage.deleteCategory(
        id,
        moveEntriesToParent: moveEntriesToParent,
      );
      if (deleted) {
        if (state.selectedCategoryId == id) {
          state = state.copyWith(selectedCategoryId: null);
        }
        await loadFromCache();
      }
      return deleted;
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to delete category',
        error,
        stackTrace,
        'VibeLibrary',
      );
      state = state.copyWith(error: error.toString());
      return false;
    }
  }

  Future<VibeLibraryCategory?> updateCategoryName(
    String id,
    String name,
  ) async {
    try {
      final category = await _storage.updateCategoryName(id, name);
      if (category != null) _replaceCategory(category);
      return category;
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to update category name',
        error,
        stackTrace,
        'VibeLibrary',
      );
      state = state.copyWith(error: error.toString());
      return null;
    }
  }

  Future<VibeLibraryCategory?> moveCategory(String id, String? parentId) async {
    try {
      final category = await _storage.moveCategory(id, parentId);
      if (category != null) _replaceCategory(category);
      return category;
    } catch (error, stackTrace) {
      AppLogger.e('Failed to move category', error, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: error.toString());
      return null;
    }
  }

  void _replaceCategory(VibeLibraryCategory category) {
    state = state.copyWith(
      categories: state.categories
          .map((item) => item.id == category.id ? category : item)
          .toList(),
    );
  }

  Future<List<VibeLibraryEntry>> resolveEntriesByIds(
    Iterable<String> ids,
  ) async {
    final result = <VibeLibraryEntry>[];
    for (final id in ids) {
      final entry = await _storage.getEntry(id);
      if (entry != null) result.add(entry);
    }
    return result;
  }

  Future<List<VibeLibraryEntry>> getAllFullEntries() =>
      _storage.getAllEntries();
  Future<VibeLibraryEntry?> findFullEntryByName(String name) =>
      _storage.findEntryByName(name);
  VibeLibraryEntry? getEntryById(String id) => state.entries
      .cast<VibeLibraryEntry?>()
      .firstWhere((entry) => entry?.id == id, orElse: () => null);
  VibeLibraryCategory? getCategoryById(String id) => state.categories
      .cast<VibeLibraryCategory?>()
      .firstWhere((category) => category?.id == id, orElse: () => null);
  int getEntryCountByCategory(String? id) =>
      state.entries.where((entry) => entry.categoryId == id).length;
  List<VibeLibraryEntry> getRecentEntries({int limit = 10}) =>
      state.entries.sortedByLastUsed().take(limit).toList();
  List<VibeLibraryEntry> getMostUsedEntries({int limit = 10}) =>
      state.entries.sortedByUsedCount().take(limit).toList();
  Map<String?, List<VibeLibraryCategory>> get categoryTree =>
      state.categories.buildTree();

  Future<int> bulkToggleFavorite(Iterable<String> ids) async {
    final entryIds = ids.toList(growable: false);
    if (entryIds.isEmpty) return 0;
    _startBulkOperation(VibeLibraryBulkOperationType.favorite);
    try {
      var updated = 0;
      for (var index = 0; index < entryIds.length; index++) {
        if (await toggleFavorite(entryIds[index]) != null) updated++;
        _updateBulkProgress(index + 1, entryIds.length);
      }
      return updated;
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to toggle favorites',
        error,
        stackTrace,
        'VibeLibrary',
      );
      state = state.copyWith(error: error.toString());
      return 0;
    } finally {
      _endBulkOperation();
    }
  }

  Future<VibeBulkOperationResult> bulkUpdateEncodingModel(
    Iterable<String> ids,
    String model,
  ) async {
    final result = await _commands.updateEncodingModel(ids, model);
    if (result.successCount > 0) await loadFromCache();
    return result;
  }

  Future<int> bulkDeleteEntries(
    List<String> ids, {
    void Function(int completed, int total)? onProgress,
  }) async {
    if (ids.isEmpty) return 0;
    _startBulkOperation(VibeLibraryBulkOperationType.delete);
    try {
      var successCount = 0;
      for (var index = 0; index < ids.length; index++) {
        if (await deleteEntry(ids[index])) successCount++;
        final processed = index + 1;
        _updateBulkProgress(processed, ids.length);
        onProgress?.call(processed, ids.length);
        if (processed % 10 == 0) await Future<void>.delayed(Duration.zero);
      }
      return successCount;
    } catch (error, stackTrace) {
      AppLogger.e('Failed to bulk delete', error, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: error.toString());
      return 0;
    } finally {
      _endBulkOperation();
    }
  }

  Future<int> bulkMoveToCategory(
    List<String> ids,
    String? categoryId, {
    void Function(int completed, int total)? onProgress,
  }) async {
    if (ids.isEmpty) return 0;
    _startBulkOperation(VibeLibraryBulkOperationType.moveCategory);
    try {
      var successCount = 0;
      for (var index = 0; index < ids.length; index++) {
        if (await updateEntryCategory(ids[index], categoryId) != null) {
          successCount++;
        }
        final processed = index + 1;
        _updateBulkProgress(processed, ids.length);
        onProgress?.call(processed, ids.length);
        if (processed % 10 == 0) await Future<void>.delayed(Duration.zero);
      }
      await loadFromCache();
      return successCount;
    } catch (error, stackTrace) {
      AppLogger.e('Failed to bulk move', error, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: error.toString());
      return 0;
    } finally {
      _endBulkOperation();
    }
  }

  Future<List<String>> bulkExportEntries(
    List<String> ids, {
    String? exportDirectory,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (ids.isEmpty) return const [];
    _startBulkOperation(VibeLibraryBulkOperationType.export);
    final exportedPaths = <String>[];
    try {
      for (var index = 0; index < ids.length; index++) {
        final entry = getEntryById(ids[index]);
        final filePath = entry?.filePath;
        if (filePath != null && filePath.isNotEmpty) {
          if (exportDirectory == null || exportDirectory.isEmpty) {
            exportedPaths.add(filePath);
          } else {
            try {
              final source = File(filePath);
              if (await source.exists()) {
                final fileName = filePath.split(RegExp(r'[/\\]')).last;
                final target =
                    '$exportDirectory${Platform.pathSeparator}$fileName';
                await source.copy(target);
                exportedPaths.add(target);
              }
            } catch (error) {
              AppLogger.w('Failed to export entry: $filePath', 'VibeLibrary');
            }
          }
        }
        final completed = index + 1;
        _updateBulkProgress(completed, ids.length);
        onProgress?.call(completed, ids.length);
        if (completed % 5 == 0) await Future<void>.delayed(Duration.zero);
      }
      return exportedPaths;
    } catch (error, stackTrace) {
      AppLogger.e('Failed to bulk export', error, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: error.toString());
      return exportedPaths;
    } finally {
      _endBulkOperation();
    }
  }

  Future<int> bulkEditTags(
    List<String> ids, {
    List<String> tagsToAdd = const [],
    List<String> tagsToRemove = const [],
    bool replaceAll = false,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (ids.isEmpty) return 0;
    _startBulkOperation(VibeLibraryBulkOperationType.updateTags);
    try {
      var successCount = 0;
      for (var index = 0; index < ids.length; index++) {
        final id = ids[index];
        final entry = getEntryById(id);
        if (entry != null) {
          final tags = replaceAll
              ? List<String>.of(tagsToAdd)
              : (Set<String>.of(entry.tags)
                      ..addAll(tagsToAdd)
                      ..removeAll(tagsToRemove))
                    .toList();
          if (await updateEntryTags(id, tags) != null) successCount++;
        }
        final processed = index + 1;
        _updateBulkProgress(processed, ids.length);
        onProgress?.call(processed, ids.length);
        if (processed % 10 == 0) await Future<void>.delayed(Duration.zero);
      }
      await loadFromCache();
      return successCount;
    } catch (error, stackTrace) {
      AppLogger.e('Failed to bulk edit tags', error, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: error.toString());
      return 0;
    } finally {
      _endBulkOperation();
    }
  }

  void _startBulkOperation(VibeLibraryBulkOperationType type) {
    state = state.copyWith(
      isBulkOperating: true,
      bulkOperationProgress: 0,
      bulkOperationType: type,
      error: null,
    );
  }

  void _updateBulkProgress(int completed, int total) {
    state = state.copyWith(
      bulkOperationProgress: total == 0
          ? 0
          : (completed / total).clamp(0.0, 1.0),
    );
  }

  void _endBulkOperation() {
    state = state.copyWith(
      isBulkOperating: false,
      bulkOperationProgress: 0,
      bulkOperationType: VibeLibraryBulkOperationType.none,
    );
  }
}
