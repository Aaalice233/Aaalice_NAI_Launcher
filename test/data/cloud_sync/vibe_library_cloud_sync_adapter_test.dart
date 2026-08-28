import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';

void main() {
  test(
    'keepBoth Vibe copy rewrites identity and applies complete resource',
    () async {
      final storage = _MemoryVibeStorage();
      final adapter = VibeLibraryCloudSyncAdapter(storage);
      final source = PortableSyncRecord(
        adapterId: adapter.id,
        id: 'entry:original',
        kind: 'entry',
        data: {
          'entryId': 'original',
          'name': 'Original',
          'categoryId': null,
          'tags': <String>[],
          'isFavorite': false,
          'usedCount': 0,
          'lastUsedAt': null,
          'createdAt': DateTime.utc(2025).toIso8601String(),
          'fileName': 'original.naiv4vibe',
        },
        resource: PortableSyncResource(
          relativePath: 'vibe/original/original.naiv4vibe',
          length: 4,
          openRead: () => Stream.value([1, 2, 3, 4]),
        ),
      );
      final copy = adapter.copyForConflict(
        source,
        newPortableId: 'entry:remote-copy',
      );

      expect(copy.id, 'entry:remote-copy');
      expect(copy.data['entryId'], 'remote-copy');
      expect(copy.data['fileName'], 'remote-copy.naiv4vibe');
      expect(
        copy.resource!.relativePath,
        'vibe/remote-copy/original.naiv4vibe',
      );
      await adapter.preflight([source, copy]);
      await adapter.apply([source, copy]);

      expect(storage.entries.map((entry) => entry.id), [
        'original',
        'remote-copy',
      ]);
      expect(storage.imported.values, everyElement([1, 2, 3, 4]));
    },
  );

  test('discards an imported file when metadata commit fails', () async {
    final storage = _MemoryVibeStorage()..failCommit = true;
    final adapter = VibeLibraryCloudSyncAdapter(storage);
    final record = PortableSyncRecord(
      adapterId: adapter.id,
      id: 'entry:broken',
      kind: 'entry',
      data: {
        'entryId': 'broken',
        'name': 'Broken',
        'categoryId': null,
        'tags': <String>[],
        'isFavorite': false,
        'usedCount': 0,
        'lastUsedAt': null,
        'createdAt': DateTime.utc(2025).toIso8601String(),
        'fileName': 'broken.naiv4vibe',
      },
      resource: PortableSyncResource(
        relativePath: 'vibe/broken/original.naiv4vibe',
        length: 1,
        openRead: () => Stream.value([1]),
      ),
    );

    await expectLater(adapter.apply([record]), throwsStateError);

    expect(storage.imported, isEmpty);
    expect(storage.entries, isEmpty);
  });
}

class _MemoryVibeStorage extends VibeLibraryStorageService {
  final Map<String, List<int>> imported = {};
  final List<VibeLibraryEntry> entries = [];
  var _index = 0;
  bool failCommit = false;

  @override
  Future<String> importPortableFile(
    Stream<List<int>> bytes, {
    required String fileName,
  }) async {
    final path = 'memory/${_index++}-$fileName';
    imported[path] = (await bytes.toList()).expand((chunk) => chunk).toList();
    return path;
  }

  @override
  Future<VibeReference?> loadPortableVibe(String filePath) async =>
      const VibeReference(
        displayName: 'Portable',
        vibeEncoding: 'encoding',
        sourceType: VibeSourceType.naiv4vibe,
      );

  @override
  Future<bool> entryExists(String id) async =>
      entries.any((entry) => entry.id == id);

  @override
  Future<bool> deleteEntry(String id) async {
    final before = entries.length;
    entries.removeWhere((entry) => entry.id == id);
    return entries.length != before;
  }

  @override
  Future<VibeLibraryEntry> saveEntry(VibeLibraryEntry entry) async {
    entries.add(entry);
    return entry;
  }

  @override
  Future<VibeLibraryEntry> commitPortableEntry(VibeLibraryEntry entry) async {
    if (failCommit) throw StateError('injected metadata failure');
    entries.add(entry);
    return entry;
  }

  @override
  Future<void> discardPortableFile(String filePath) async {
    imported.remove(filePath);
  }
}
