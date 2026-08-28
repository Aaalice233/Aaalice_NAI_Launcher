import 'dart:convert';
import 'dart:io';

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
      final deleted = <VibeLibraryEntry>[];
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
        existingEntries: [stale],
        onUpsertEntry: (entry) async => upserts.add(entry),
        onDeleteEntry: (entry) async => deleted.add(entry),
      );

      expect(result.scannedCount, 1);
      expect(result.upsertedCount, 1);
      expect(result.deletedCount, 1);
      expect(upserts.single.filePath, file.path);
      expect(deleted.single.id, 'stale');
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
        existingEntries: [existing],
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
}
