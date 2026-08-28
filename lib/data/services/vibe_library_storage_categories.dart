import '../../core/utils/app_logger.dart';
import '../models/vibe/vibe_library_category.dart';
import '../models/vibe/vibe_library_entry.dart';
import 'vibe_library_storage_protocol.dart';

/// Category and tag application logic backed by the shared Hive repository.
class VibeLibraryCategoryRepository {
  VibeLibraryCategoryRepository(
    this._repository, {
    required this.getEntriesByCategory,
    required this.updateEntryCategory,
  });

  final VibeLibraryRepositoryProtocol _repository;
  final Future<List<VibeLibraryEntry>> Function(String? categoryId)
  getEntriesByCategory;
  final Future<VibeLibraryEntry?> Function(String id, String? categoryId)
  updateEntryCategory;

  Future<VibeLibraryCategory> save(VibeLibraryCategory category) async {
    try {
      await _repository.putCategory(category);
      AppLogger.d('Category saved: ${category.name}', 'VibeLibrary');
      return category;
    } catch (error, stackTrace) {
      AppLogger.e('Failed to save category', error, stackTrace, 'VibeLibrary');
      rethrow;
    }
  }

  Future<VibeLibraryCategory?> get(String id) =>
      _withFallback(() => _repository.readCategory(id), null, 'get category');

  Future<List<VibeLibraryCategory>> getAll() => _withFallback(
    _repository.readCategories,
    const <VibeLibraryCategory>[],
    'get all categories',
  );

  Future<List<VibeLibraryCategory>> getRoots() async =>
      (await getAll()).where((category) => category.parentId == null).toList();

  Future<List<VibeLibraryCategory>> getChildren(String parentId) async =>
      (await getAll())
          .where((category) => category.parentId == parentId)
          .toList();

  Future<bool> delete(String id, {bool moveEntriesToParent = true}) =>
      _withFallback(
        () async {
          final category = await get(id);
          if (category == null) return false;
          for (final entry in await getEntriesByCategory(id)) {
            await updateEntryCategory(
              entry.id,
              moveEntriesToParent ? category.parentId : null,
            );
          }
          for (final child in await getChildren(id)) {
            await save(child.moveTo(category.parentId));
          }
          await _repository.deleteCategory(id);
          return true;
        },
        false,
        'delete category',
      );

  Future<VibeLibraryCategory?> updateName(String id, String newName) =>
      _withFallback(
        () async {
          final category = await get(id);
          if (category == null) return null;
          final updated = category.updateName(newName);
          await _repository.putCategory(updated);
          return updated;
        },
        null,
        'update category name',
      );

  Future<VibeLibraryCategory?> move(String id, String? newParentId) =>
      _withFallback(
        () async {
          final category = await get(id);
          if (category == null) return null;
          if (newParentId != null &&
              (await getAll()).wouldCreateCycle(id, newParentId)) {
            throw ArgumentError('Cannot move category: would create cycle');
          }
          final updated = category.moveTo(newParentId);
          await _repository.putCategory(updated);
          return updated;
        },
        null,
        'move category',
      );

  Future<Set<String>> getAllTags() => _withFallback(
    () async => {
      for (final entry in await _repository.readAllEntries()) ...entry.tags,
    },
    <String>{},
    'get all tags',
  );

  Future<List<VibeLibraryEntry>> getEntriesByTag(String tag) => _withFallback(
    () async => (await _repository.readAllEntries())
        .where((entry) => entry.tags.contains(tag))
        .toList(),
    const <VibeLibraryEntry>[],
    'get entries by tag',
  );

  Future<List<VibeLibraryEntry>> getEntriesByUsage({int limit = 20}) =>
      _withFallback(
        () async {
          final entries = await _repository.readAllEntries();
          entries.sort((a, b) => b.usedCount.compareTo(a.usedCount));
          return entries.take(limit).toList();
        },
        const <VibeLibraryEntry>[],
        'get entries by usage',
      );

  Future<T> _withFallback<T>(
    Future<T> Function() operation,
    T fallback,
    String name,
  ) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      AppLogger.e('Failed to $name', error, stackTrace, 'VibeLibrary');
      return fallback;
    }
  }
}
