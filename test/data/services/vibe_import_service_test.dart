import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_file_storage_service.dart';
import 'package:nai_launcher/data/services/vibe_import_service.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_selector_dialog.dart';

import '../../helpers/log_capture.dart';

class _FakeVibeLibraryImportRepository implements VibeLibraryImportRepository {
  final List<VibeLibraryEntry> savedEntries = <VibeLibraryEntry>[];
  List<VibeReference> savedBundleVibes = const [];
  int getAllEntriesCalls = 0;
  int findEntryByNameCalls = 0;

  @override
  Future<List<VibeLibraryEntry>> getAllEntries() async {
    getAllEntriesCalls++;
    return savedEntries;
  }

  @override
  Future<VibeLibraryEntry?> findEntryByName(String name) async {
    findEntryByNameCalls++;
    final normalized = name.trim().toLowerCase();
    for (final entry in savedEntries) {
      if (entry.name.trim().toLowerCase() == normalized) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<VibeLibraryEntry> saveEntry(VibeLibraryEntry entry) async {
    savedEntries.add(entry);
    return entry;
  }

  @override
  Future<VibeLibraryEntry> saveBundleEntry(
    List<VibeReference> vibes, {
    required String name,
    String? categoryId,
    List<String>? tags,
    VibeLibraryEntry? replaceEntry,
  }) async {
    savedBundleVibes = vibes;
    final entry = VibeLibraryEntry.fromVibeReference(
      name: name,
      vibeData: vibes.first,
      categoryId: categoryId,
      tags: tags,
    ).copyWith(
      bundledVibeNames: vibes.map((vibe) => vibe.displayName).toList(),
      bundledVibeEncodings: vibes.map((vibe) => vibe.vibeEncoding).toList(),
      bundledVibeStrengths: vibes.map((vibe) => vibe.strength).toList(),
      bundledVibeInfoExtracted:
          vibes.map((vibe) => vibe.infoExtracted).toList(),
    );
    savedEntries.add(entry);
    return entry;
  }
}

void main() {
  group('VibeImportService.importFromFile', () {
    test('整体导入 bundle 时用完整子 Vibe 列表保存原图数据', () async {
      final repository = _FakeVibeLibraryImportRepository();
      final service = VibeImportService(repository: repository);
      final firstImage = Uint8List.fromList([1, 2, 3, 4]);
      final secondImage = Uint8List.fromList([5, 6, 7, 8]);
      final bundleBytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'identifier': 'novelai-vibe-transfer-bundle',
            'version': 1,
            'vibes': [
              {
                'name': 'first',
                'encodings': {
                  'nai-diffusion-4-full': {
                    'vibe': {'encoding': 'encoding-first'},
                  },
                },
                'image': base64Encode(firstImage),
                'importInfo': {
                  'strength': 0.35,
                  'information_extracted': 0.7,
                },
              },
              {
                'name': 'second',
                'encodings': {
                  'nai-diffusion-4-full': {
                    'vibe': {'encoding': 'encoding-second'},
                  },
                },
                'image': base64Encode(secondImage),
                'importInfo': {
                  'strength': -0.25,
                  'information_extracted': 0.5,
                },
              },
            ],
          }),
        ),
      );

      final result = await service.importFromFile(
        files: [
          PlatformFile(
            name: 'bundle.naiv4vibebundle',
            size: bundleBytes.length,
            bytes: bundleBytes,
          ),
        ],
        onBundleOption: (bundleName, vibes) async {
          return BundleImportOption.keepAsBundle(
            configuredReferences: vibes,
          );
        },
      );

      expect(result.successCount, 1);
      expect(repository.savedBundleVibes, hasLength(2));
      expect(repository.savedBundleVibes[0].rawImageData, firstImage);
      expect(repository.savedBundleVibes[1].rawImageData, secondImage);
      expect(repository.savedBundleVibes[0].strength, 0.35);
      expect(repository.savedBundleVibes[1].strength, -0.25);
      expect(repository.savedBundleVibes[0].infoExtracted, 0.7);
      expect(repository.savedBundleVibes[1].infoExtracted, 0.5);
    });
  });

  group('VibeImportService.importFromImage', () {
    test('should import jpg images as raw-image vibes instead of failing',
        () async {
      final repository = _FakeVibeLibraryImportRepository();
      final service = VibeImportService(repository: repository);
      final image = img.Image(width: 4, height: 4);
      final jpgBytes = Uint8List.fromList(img.encodeJpg(image));

      final result = await service.importFromImage(
        images: const <VibeImageImportItem>[].followedBy([
          VibeImageImportItem(
            source: 'sample.jpg',
            bytes: jpgBytes,
          ),
        ]).toList(),
      );

      expect(result.successCount, 1);
      expect(result.failCount, 0);
      expect(repository.savedEntries, hasLength(1));
      expect(
        repository.savedEntries.single.sourceType,
        equals(VibeSourceType.rawImage),
      );
      expect(
        repository.savedEntries.single.rawImageData,
        isNotEmpty,
      );
      expect(repository.getAllEntriesCalls, 0);
      expect(repository.findEntryByNameCalls, greaterThan(0));
    });
  });

  group('VibeImportService.importFromEncoding', () {
    test('pasted JSON that fails to parse is not quoted into the log',
        () async {
      final service = VibeImportService(
        repository: _FakeVibeLibraryImportRepository(),
      );

      late VibeImportResult result;
      final logs = await captureLogs(() async {
        result = await service.importFromEncoding(
          items: const [
            VibeEncodingImportItem(
              source: 'clipboard',
              encoding: '{"name":"secret lighthouse keeper",',
            ),
          ],
        );
      });

      expect(result.failCount, 1);
      expect(
        logs.where((line) => line.contains('Failed to parse vibe encoding')),
        hasLength(1),
      );
      expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
    });
  });

  group('VibeFileStorageService.extractVibesFromBundle', () {
    test('returns the requested child vibe range from a bundle file', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'vibe_bundle_extract_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      Map<String, dynamic> bundleItem(
        String name,
        String encoding,
        double strength,
      ) {
        return {
          'name': name,
          'encodings': {
            'nai-diffusion-4-full': {
              'vibe': {'encoding': encoding},
            },
          },
          'importInfo': {
            'strength': strength,
            'information_extracted': 0.5,
          },
        };
      }

      final bundleFile = File('${tempDir.path}/batch.naiv4vibebundle');
      await bundleFile.writeAsString(
        jsonEncode({
          'identifier': 'novelai-vibe-transfer-bundle',
          'version': 1,
          'vibes': [
            bundleItem('First', 'first-encoded', 0.1),
            bundleItem('Second', 'second-encoded', 0.2),
            bundleItem('Third', 'third-encoded', 0.3),
          ],
        }),
      );

      final service = VibeFileStorageService();

      final references = await service.extractVibesFromBundle(
        bundleFile.path,
        startIndex: 1,
        limit: 2,
      );

      expect(references.map((item) => item.displayName), [
        'Second',
        'Third',
      ]);
      expect(references.map((item) => item.vibeEncoding), [
        'second-encoded',
        'third-encoded',
      ]);
    });
  });

  group('VibeSelectorDialog selection result', () {
    test('keeps normal library entries lightweight during confirmation',
        () async {
      var hydrateCalls = 0;
      var recordUsageCalls = 0;
      final lightEntry = VibeLibraryEntry(
        id: 'entry-1',
        name: 'Light Entry',
        vibeDisplayName: 'Light Entry',
        vibeEncoding: '',
        strength: 0.6,
        infoExtracted: 0.7,
        sourceTypeIndex: VibeSourceType.naiv4vibe.index,
        tags: const ['light'],
        createdAt: DateTime(2026, 4, 14),
        filePath: r'C:\vibes\entry-1.naiv4vibe',
      );

      final result = await buildLightweightVibeSelectionResult(
        selectedIds: {'entry-1'},
        entries: [lightEntry],
        shouldReplace: false,
        hydrateBundleChild: (bundleEntry, index) async {
          hydrateCalls++;
          return null;
        },
        recordUsage: (id) async {
          recordUsageCalls++;
        },
      );

      expect(result.selectedEntries, [lightEntry]);
      expect(result.shouldReplace, isFalse);
      expect(
        hydrateCalls,
        0,
        reason: '普通条目确认阶段不应在 selector 内读取完整 Vibe 文件',
      );
      expect(
        recordUsageCalls,
        0,
        reason: '使用次数应由真正添加成功的外层导入 handler 统一记录一次',
      );
    });
  });
}
