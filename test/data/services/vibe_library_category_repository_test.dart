import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_category.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_categories.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_protocol.dart';

class _Repository extends Mock implements VibeLibraryRepositoryProtocol {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      VibeLibraryCategory(
        id: 'fallback',
        name: 'Fallback',
        createdAt: DateTime(2026),
      ),
    );
  });

  test(
    'deleting a category reparents entries and children before deletion',
    () async {
      final repository = _Repository();
      final parent = VibeLibraryCategory(
        id: 'parent',
        name: 'Parent',
        createdAt: DateTime(2026),
      );
      final category = VibeLibraryCategory(
        id: 'category',
        name: 'Category',
        parentId: parent.id,
        createdAt: DateTime(2026),
      );
      final child = VibeLibraryCategory(
        id: 'child',
        name: 'Child',
        parentId: category.id,
        createdAt: DateTime(2026),
      );
      final movedEntries = <String, String?>{};
      when(
        () => repository.readCategory(category.id),
      ).thenAnswer((_) async => category);
      when(
        repository.readCategories,
      ).thenAnswer((_) async => [parent, category, child]);
      when(() => repository.putCategory(any())).thenAnswer((_) async {});
      when(
        () => repository.deleteCategory(category.id),
      ).thenAnswer((_) async {});
      final service = VibeLibraryCategoryRepository(
        repository,
        getEntriesByCategory: (_) async => [_entry('entry', category.id)],
        updateEntryCategory: (id, categoryId) async {
          movedEntries[id] = categoryId;
          return _entry(id, categoryId);
        },
      );

      expect(await service.delete(category.id), isTrue);
      expect(movedEntries, {'entry': parent.id});
      final savedChild =
          verify(() => repository.putCategory(captureAny())).captured.single
              as VibeLibraryCategory;
      expect(savedChild.parentId, parent.id);
      verify(() => repository.deleteCategory(category.id)).called(1);
    },
  );
}

VibeLibraryEntry _entry(String id, String? categoryId) => VibeLibraryEntry(
  id: id,
  name: id,
  vibeDisplayName: id,
  vibeEncoding: 'encoding',
  strength: 0.6,
  infoExtracted: 0.7,
  sourceTypeIndex: 0,
  categoryId: categoryId,
  createdAt: DateTime(2026),
);
