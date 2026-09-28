import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';
import '../utils/library_sidebar_sort.dart';

enum LibrarySidebarSection {
  folders(
    StorageKeys.localGalleryFolderSort,
    LibrarySidebarSort.nameDescending,
  ),
  albums(StorageKeys.localGalleryAlbumSort, LibrarySidebarSort.original),
  tagCategories(
    StorageKeys.tagLibraryCategorySort,
    LibrarySidebarSort.original,
  ),
  vibeCategories(
    StorageKeys.vibeLibraryCategorySort,
    LibrarySidebarSort.original,
  );

  const LibrarySidebarSection(this.storageKey, this.defaultSort);

  final String storageKey;
  final LibrarySidebarSort defaultSort;
}

class LibrarySidebarSortState {
  const LibrarySidebarSortState(this.sort, {this.isSaving = false});

  final LibrarySidebarSort sort;
  final bool isSaving;
}

class SidebarSortPreferenceSaveException implements Exception {
  const SidebarSortPreferenceSaveException(this.cause);
  final Object cause;

  @override
  String toString() =>
      'Manual order committed but its preference was not saved: $cause';
}

final librarySidebarSortProvider =
    NotifierProvider.family<
      LibrarySidebarSortNotifier,
      LibrarySidebarSortState,
      LibrarySidebarSection
    >(LibrarySidebarSortNotifier.new);

class LibrarySidebarSortNotifier
    extends FamilyNotifier<LibrarySidebarSortState, LibrarySidebarSection> {
  late LocalStorageService _storage;
  late LibrarySidebarSection _section;

  @override
  LibrarySidebarSortState build(LibrarySidebarSection arg) {
    _section = arg;
    _storage = ref.watch(localStorageServiceProvider);
    final saved = _storage.getSetting<String>(arg.storageKey);
    return LibrarySidebarSortState(
      saved == null ? arg.defaultSort : LibrarySidebarSort.values.byName(saved),
    );
  }

  /// Keep a committed move visible even if persisting the display preference
  /// fails; the caller reports that error rather than pretending it was saved.
  Future<bool> applyManualMove(
    Future<bool> Function(LibrarySidebarSort currentSort) move,
  ) async {
    if (state.isSaving) {
      throw StateError('Sidebar order change already in progress');
    }
    final previous = state;
    var changed = false;
    state = LibrarySidebarSortState(previous.sort, isSaving: true);
    try {
      changed = await move(previous.sort);
      if (changed && previous.sort != LibrarySidebarSort.original) {
        try {
          await _storage.setSetting(
            _section.storageKey,
            LibrarySidebarSort.original.name,
          );
        } catch (error, stack) {
          Error.throwWithStackTrace(
            SidebarSortPreferenceSaveException(error),
            stack,
          );
        }
      }
      return changed;
    } finally {
      state = LibrarySidebarSortState(
        changed ? LibrarySidebarSort.original : previous.sort,
      );
    }
  }

  Future<void> setSort(LibrarySidebarSort sort) async {
    if (state.isSaving) {
      throw StateError('Sidebar sort save already in progress');
    }
    if (state.sort == sort) return;
    final previous = state;
    state = LibrarySidebarSortState(previous.sort, isSaving: true);
    try {
      await _storage.setSetting(_section.storageKey, sort.name);
      state = LibrarySidebarSortState(sort);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}
