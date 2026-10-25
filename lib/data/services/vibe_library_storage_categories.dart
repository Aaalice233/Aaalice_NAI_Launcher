import '../../core/utils/app_logger.dart';
import '../models/vibe/vibe_library_category.dart';
import '../models/vibe/vibe_library_entry.dart';
import 'vibe_library_storage_protocol.dart';

/// Category and tag application logic backed by the shared Hive repository.
class VibeLibraryCategoryRepository {
  VibeLibraryCategoryRepository(
    this._repository, {
    required this.updateEntryCategory,
  });

  final VibeLibraryRepositoryProtocol _repository;
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

  Future<void> saveAll(List<VibeLibraryCategory> categories) =>
      _repository.putCategories(categories);

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
          final entryIds = <String>[];
          await _repository.forEachEntry((entry) async {
            if (entry.categoryId == id) entryIds.add(entry.id);
          });
          for (final entryId in entryIds) {
            await updateEntryCategory(
              entryId,
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
