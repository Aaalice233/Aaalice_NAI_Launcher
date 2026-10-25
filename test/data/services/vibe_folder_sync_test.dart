import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_file_storage_protocol.dart';
import 'package:nai_launcher/data/services/vibe_folder_sync.dart';

class _FileRepository extends Mock implements VibeFileRepositoryProtocol {}

void main() {
  test(
    'sync is orchestrated against the file protocol without repository cycle',
    () async {
      final repository = _FileRepository();
      final file = File('C:/vibes/new.naiv4vibe');
      when(repository.listVibeFiles).thenAnswer((_) async => [file]);
      when(() => repository.loadVibeFromFile(file.path)).thenAnswer(
        (_) async => const VibeReference(
          displayName: 'new',
          vibeEncoding: 'encoded',
          sourceType: VibeSourceType.naiv4vibe,
        ),
      );

      final upserts = <VibeLibraryEntry>[];
      final deleted = <String>[];
      final stale = VibeLibraryEntry(
        id: 'stale',
        name: 'stale',
        vibeDisplayName: 'stale',
        vibeEncoding: 'old',
        strength: 0.6,
        infoExtracted: 0.7,
        sourceTypeIndex: VibeSourceType.naiv4vibe.index,
        filePath: 'C:/vibes/stale.naiv4vibe',
        createdAt: DateTime(2026),
      );

      final result = await VibeFolderSync(repository).syncFolderToHive(
        existingFilePathsById: {stale.id: stale.filePath!},
        loadExistingEntry: (id) async =>
            fail('unmatched files must not load existing entries'),
        onUpsertEntry: (entry) async => upserts.add(entry),
        onDeleteEntry: (id) async => deleted.add(id),
      );

      expect(result.scannedCount, 1);
      expect(result.upsertedCount, 1);
      expect(result.deletedCount, 1);
      expect(upserts.single.filePath, file.path);
      expect(deleted.single, 'stale');
    },
  );

  test(
    'bundle resync replaces file-derived data and preserves user data',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'vibe_folder_sync_bundle_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final file = File('${tempDir.path}/updated.naiv4vibebundle');
      await file.writeAsString(
        jsonEncode({
          'identifier': 'novelai-vibe-transfer-bundle',
          'version': 1,
          'vibes': [
            {
              'name': 'fresh child',
              'encodings': {
                'nai-diffusion-4-full': {
                  'vibe': {'encoding': 'fresh-encoding'},
                },
              },
              'importInfo': {
                'model': 'nai-diffusion-4-full',
                'strength': -0.25,
                'information_extracted': 0.45,
              },
            },
          ],
        }),
      );

      final repository = _FileRepository();
      when(repository.listVibeFiles).thenAnswer((_) async => [file]);
      when(
        () => repository.extractPreviewsFromBundle(file.path),
      ).thenAnswer((_) async => []);
      final existing = VibeLibraryEntry(
        id: 'stable-id',
        name: 'old',
        vibeDisplayName: 'old child',
        vibeEncoding: 'old-encoding',
        strength: 0.9,
        infoExtracted: 0.8,
        sourceTypeIndex: VibeSourceType.naiv4vibebundle.index,
        categoryId: 'user-category',
        tags: const ['user-tag'],
        isFavorite: true,
        usedCount: 7,
        createdAt: DateTime(2026),
        filePath: file.path,
        bundleId: 'old-bundle',
        bundledVibeNames: const ['old child'],
        bundledVibeEncodings: const ['old-encoding'],
        bundledVibeStrengths: const [0.9],
        bundledVibeInfoExtracted: const [0.8],
        bundledVibeEncodingModels: const ['old-model'],
      );
      final upserts = <VibeLibraryEntry>[];

      await VibeFolderSync(repository).syncFolderToHive(
        existingFilePathsById: {existing.id: file.path},
        loadExistingEntry: (id) async => id == existing.id ? existing : null,
        onUpsertEntry: (entry) async => upserts.add(entry),
      );

      final updated = upserts.single;
      expect(updated.id, existing.id);
      expect(updated.categoryId, existing.categoryId);
      expect(updated.tags, existing.tags);
      expect(updated.isFavorite, isTrue);
      expect(updated.usedCount, 7);
      expect(updated.bundleId, 'updated');
      expect(updated.bundledVibeNames, ['fresh child']);
      expect(updated.bundledVibeEncodings, ['fresh-encoding']);
      expect(updated.bundledVibeStrengths, [-0.25]);
      expect(updated.bundledVibeInfoExtracted, [0.45]);
      expect(updated.bundledVibeEncodingModels, ['nai-diffusion-4-full']);
    },
  );

  group('existing entries indexed by file path', () {
    final file = File('C:/vibes/kept.naiv4vibe');
    final customThumbnail = Uint8List.fromList([9, 9, 9]);
    late _FileRepository repository;
    late VibeLibraryEntry full;

    setUp(() {
      repository = _FileRepository();
      when(repository.listVibeFiles).thenAnswer((_) async => [file]);
      when(() => repository.loadVibeFromFile(file.path)).thenAnswer(
        (_) async => VibeReference(
          displayName: 'kept',
          vibeEncoding: 'file-encoding',
          thumbnail: Uint8List.fromList([1, 2, 3]),
          sourceType: VibeSourceType.naiv4vibe,
        ),
      );
      full = VibeLibraryEntry(
        id: 'kept-id',
        name: 'kept',
        vibeDisplayName: 'kept',
        vibeEncoding: 'stored-encoding',
        strength: 0.6,
        infoExtracted: 0.7,
        sourceTypeIndex: VibeSourceType.naiv4vibe.index,
        categoryId: 'category',
        isFavorite: true,
        createdAt: DateTime(2026),
        thumbnail: customThumbnail,
        filePath: file.path,
      );
    });

    test(
      'merge reads the full entry so the custom thumbnail survives',
      () async {
        final loaded = <String>[];
        final upserts = <VibeLibraryEntry>[];

        await VibeFolderSync(repository).syncFolderToHive(
          existingFilePathsById: {full.id: file.path},
          loadExistingEntry: (id) async {
            loaded.add(id);
            return full;
          },
          onUpsertEntry: (entry) async => upserts.add(entry),
        );

        expect(loaded, ['kept-id']);
        expect(upserts.single.id, 'kept-id');
        expect(upserts.single.thumbnail, customThumbnail);
        expect(upserts.single.categoryId, 'category');
        expect(upserts.single.isFavorite, isTrue);
      },
    );

    test('an entry removed after the path scan is not recreated', () async {
      final upserts = <VibeLibraryEntry>[];
      final deleted = <String>[];

      await VibeFolderSync(repository).syncFolderToHive(
        existingFilePathsById: {full.id: file.path},
        loadExistingEntry: (_) async => null,
        onUpsertEntry: (entry) async => upserts.add(entry),
        onDeleteEntry: (id) async => deleted.add(id),
      );

      expect(upserts, isEmpty);
      expect(deleted, isEmpty);
    });

    test('an entry already matching its file is not rewritten', () async {
      final firstPass = <VibeLibraryEntry>[];
      await VibeFolderSync(repository).syncFolderToHive(
        existingFilePathsById: {full.id: file.path},
        loadExistingEntry: (_) async => full,
        onUpsertEntry: (entry) async => firstPass.add(entry),
      );
      final stored = firstPass.single;
      final secondPass = <VibeLibraryEntry>[];

      final result = await VibeFolderSync(repository).syncFolderToHive(
        existingFilePathsById: {stored.id: file.path},
        loadExistingEntry: (_) async => stored,
        onUpsertEntry: (entry) async => secondPass.add(entry),
      );

      expect(secondPass, isEmpty);
      expect(result.scannedCount, 1);
      expect(result.upsertedCount, 0);
      expect(result.unchangedCount, 1);
      expect(result.errors, isEmpty);
    });

    test(
      'replacing the encoding drops the original image from the old encoding',
      () async {
        final stored = full.copyWith(
          rawImageData: Uint8List.fromList([4, 5, 6]),
        );
        when(() => repository.loadVibeFromFile(file.path)).thenAnswer(
          (_) async => VibeReference(
            displayName: 'kept',
            vibeEncoding: 'edited-encoding',
            thumbnail: Uint8List.fromList([1, 2, 3]),
            sourceType: VibeSourceType.naiv4vibe,
          ),
        );
        final secondPass = <VibeLibraryEntry>[];

        final result = await VibeFolderSync(repository).syncFolderToHive(
          existingFilePathsById: {stored.id: file.path},
          loadExistingEntry: (_) async => stored,
          onUpsertEntry: (entry) async => secondPass.add(entry),
        );

        expect(secondPass.single.vibeEncoding, 'edited-encoding');
        expect(secondPass.single.rawImageData, isNull);
        expect(secondPass.single.thumbnail, customThumbnail);
        expect(result.upsertedCount, 1);
        expect(result.unchangedCount, 0);
      },
    );

    test('a failed full read skips that file and reports it', () async {
      final upserts = <VibeLibraryEntry>[];
      final deleted = <String>[];

      final result = await VibeFolderSync(repository).syncFolderToHive(
        existingFilePathsById: {full.id: file.path},
        loadExistingEntry: (_) async => throw StateError('hive read failed'),
        onUpsertEntry: (entry) async => upserts.add(entry),
        onDeleteEntry: (id) async => deleted.add(id),
      );

      expect(upserts, isEmpty);
      expect(deleted, isEmpty);
      expect(result.errors, hasLength(1));
    });
  });
}
