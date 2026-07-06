import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/utils/vibe_library_path_helper.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_category.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_file_storage_service.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveTempDir;
  late VibeLibraryStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    hiveTempDir = await Directory.systemTemp.createTemp(
      'vibe_library_storage_test_',
    );
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
    storage = VibeLibraryStorageService();
  });

  tearDown(() async {
    await storage.close();
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  test(
      'getAllEntries returns persisted entries as the current UI source of truth',
      () async {
    final entry = VibeLibraryEntry(
      id: 'entry-1',
      name: 'spring vibe',
      vibeDisplayName: 'Spring Vibe',
      vibeEncoding: 'encoded-payload',
      vibeThumbnail: Uint8List.fromList([1, 2, 3]),
      rawImageData: Uint8List.fromList([4, 5, 6]),
      strength: 0.65,
      infoExtracted: 0.75,
      sourceTypeIndex: VibeSourceType.naiv4vibe.index,
      categoryId: 'cat-1',
      tags: const ['flower'],
      isFavorite: true,
      usedCount: 3,
      lastUsedAt: DateTime(2026, 4, 14, 9),
      createdAt: DateTime(2026, 4, 14, 8),
      thumbnail: Uint8List.fromList([7, 8, 9]),
      filePath: r'G:\AIdarw\vibes\spring.naiv4vibe',
      bundledVibeNames: const ['a', 'b'],
      bundledVibePreviews: [
        Uint8List.fromList([10, 11, 12]),
      ],
      bundledVibeEncodings: const ['bundle-enc'],
      bundledVibeStrengths: const [0.12],
      bundledVibeInfoExtracted: const [0.34],
    );

    await storage.saveEntry(entry);

    final entries = await storage.getAllEntries();

    expect(entries, hasLength(1));
    expect(entries.single.id, entry.id);
    expect(entries.single.vibeEncoding, entry.vibeEncoding);
    expect(entries.single.rawImageData, entry.rawImageData);
    expect(entries.single.bundledVibeEncodings, entry.bundledVibeEncodings);
    expect(entries.single.bundledVibeStrengths, entry.bundledVibeStrengths);
    expect(
      entries.single.bundledVibeInfoExtracted,
      entry.bundledVibeInfoExtracted,
    );
    expect(entries.single.thumbnail, isNotNull);
    expect(entries.single.vibeThumbnail, isNotNull);
    expect(entries.single.filePath, entry.filePath);
    expect(entries.single.usedCount, entry.usedCount);
  });

  test(
      'getAllEntries reads legacy entries directly from entries box without extra cache migration',
      () async {
    if (!Hive.isAdapterRegistered(23)) {
      Hive.registerAdapter(VibeLibraryEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(21)) {
      Hive.registerAdapter(VibeLibraryCategoryAdapter());
    }

    final entry = VibeLibraryEntry(
      id: 'entry-legacy',
      name: 'legacy vibe',
      vibeDisplayName: 'Legacy Vibe',
      vibeEncoding: 'legacy-encoded-payload',
      vibeThumbnail: Uint8List.fromList([1, 2, 3]),
      rawImageData: Uint8List.fromList([4, 5, 6]),
      strength: 0.55,
      infoExtracted: 0.45,
      sourceTypeIndex: VibeSourceType.naiv4vibe.index,
      tags: const ['legacy'],
      usedCount: 7,
      lastUsedAt: DateTime(2026, 4, 14, 10),
      createdAt: DateTime(2026, 4, 14, 9),
      thumbnail: Uint8List.fromList([7, 8, 9]),
      filePath: r'G:\AIdarw\vibes\legacy.naiv4vibe',
    );

    final entriesBox =
        await Hive.openBox<VibeLibraryEntry>('vibe_library_entries');
    await entriesBox.put(entry.id, entry);
    await entriesBox.close();

    final entries = await storage.getAllEntries();

    expect(entries, hasLength(1));
    expect(entries.single.id, entry.id);
    expect(entries.single.vibeEncoding, entry.vibeEncoding);
    expect(entries.single.rawImageData, entry.rawImageData);
    expect(entries.single.filePath, entry.filePath);
  });

  test('getDisplayEntries strips heavy payload into non-destructive cache',
      () async {
    final entry = VibeLibraryEntry(
      id: 'entry-display',
      name: 'display vibe',
      vibeDisplayName: 'Display Vibe',
      vibeEncoding: 'heavy-encoded-payload',
      vibeThumbnail: Uint8List.fromList([1, 2, 3]),
      rawImageData: Uint8List.fromList([4, 5, 6]),
      strength: 0.6,
      infoExtracted: 0.7,
      sourceTypeIndex: VibeSourceType.naiv4vibe.index,
      tags: const ['cached'],
      createdAt: DateTime(2026, 4, 23, 10),
      thumbnail: Uint8List.fromList([7, 8, 9]),
      filePath: r'G:\AIdarw\vibes\display.naiv4vibe',
      bundledVibeNames: const ['a', 'b'],
      bundledVibePreviews: [
        Uint8List.fromList([10, 11, 12]),
      ],
      bundledVibeEncodings: const ['bundle-enc'],
      bundledVibeStrengths: const [0.12],
      bundledVibeInfoExtracted: const [0.34],
    );

    await storage.saveEntry(entry);

    final displayEntries = await storage.getDisplayEntries();
    final fullEntries = await storage.getAllEntries();

    expect(displayEntries, hasLength(1));
    expect(displayEntries.single.id, entry.id);
    expect(displayEntries.single.vibeEncoding, isEmpty);
    expect(displayEntries.single.vibeThumbnail, isNull);
    expect(displayEntries.single.rawImageData, isNull);
    expect(displayEntries.single.thumbnail, isNull);
    expect(displayEntries.single.bundledVibePreviews, isNull);
    expect(displayEntries.single.bundledVibeEncodings, isNull);
    expect(displayEntries.single.bundledVibeStrengths, isNull);
    expect(displayEntries.single.bundledVibeInfoExtracted, isNull);
    expect(displayEntries.single.filePath, entry.filePath);
    expect(displayEntries.single.bundledVibeNames, entry.bundledVibeNames);

    expect(fullEntries, hasLength(1));
    expect(fullEntries.single.vibeEncoding, entry.vibeEncoding);
    expect(fullEntries.single.vibeThumbnail, entry.vibeThumbnail);
    expect(fullEntries.single.rawImageData, entry.rawImageData);
    expect(fullEntries.single.thumbnail, entry.thumbnail);
    expect(fullEntries.single.bundledVibePreviews, entry.bundledVibePreviews);
    expect(fullEntries.single.bundledVibeEncodings, entry.bundledVibeEncodings);
    expect(fullEntries.single.bundledVibeStrengths, entry.bundledVibeStrengths);
    expect(
      fullEntries.single.bundledVibeInfoExtracted,
      entry.bundledVibeInfoExtracted,
    );

    final displayThumbnail = await storage.getDisplayThumbnail(entry.id);
    expect(displayThumbnail, entry.thumbnail);
  });

  test('getAllEntries 会优先用文件里的参数纠正 Hive 旧快照', () async {
    final vibeDirectory =
        '${hiveTempDir.path}${Platform.pathSeparator}vibes_params_sync';
    await VibeLibraryPathHelper.instance.setPath(vibeDirectory);
    addTearDown(() async {
      await VibeLibraryPathHelper.instance.resetToDefault();
    });

    final fileStorage = VibeFileStorageService();
    final filePath = await fileStorage.saveVibeToFile(
      VibeReference(
        displayName: 'Param Sync',
        vibeEncoding: 'file-encoded',
        thumbnail: Uint8List.fromList([1, 2, 3, 4]),
        rawImageData: Uint8List.fromList([5, 6, 7, 8]),
        strength: 0.18,
        infoExtracted: 0.3,
        sourceType: VibeSourceType.naiv4vibe,
      ),
      customName: 'param_sync',
    );

    if (!Hive.isAdapterRegistered(23)) {
      Hive.registerAdapter(VibeLibraryEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(21)) {
      Hive.registerAdapter(VibeLibraryCategoryAdapter());
    }

    final staleEntry = VibeLibraryEntry(
      id: 'entry-param-sync',
      name: 'param sync',
      vibeDisplayName: 'Param Sync',
      vibeEncoding: 'file-encoded',
      vibeThumbnail: Uint8List.fromList([1, 2, 3]),
      rawImageData: Uint8List.fromList([5, 6, 7, 8]),
      strength: 0.6,
      infoExtracted: 0.7,
      sourceTypeIndex: VibeSourceType.naiv4vibe.index,
      createdAt: DateTime(2026, 4, 15, 10),
      filePath: filePath,
    );

    final entriesBox =
        await Hive.openBox<VibeLibraryEntry>('vibe_library_entries');
    await entriesBox.put(staleEntry.id, staleEntry);
    await entriesBox.close();

    final entries = await storage.getAllEntries();

    expect(entries, hasLength(1));
    expect(entries.single.strength, 0.18);
    expect(entries.single.infoExtracted, 0.3);
  });

  test(
      'getEntry preserves rawImageData from Hive entry when file payload lacks image',
      () async {
    final vibeDirectory =
        '${hiveTempDir.path}${Platform.pathSeparator}vibes_under_test';
    await VibeLibraryPathHelper.instance.setPath(vibeDirectory);
    addTearDown(() async {
      await VibeLibraryPathHelper.instance.resetToDefault();
    });

    final fileStorage = VibeFileStorageService();
    final filePath = await fileStorage.saveVibeToFile(
      VibeReference(
        displayName: 'Legacy Preserve',
        vibeEncoding: 'file-encoded',
        thumbnail: Uint8List.fromList([1, 2, 3, 4]),
        strength: 0.21,
        infoExtracted: 0.42,
        sourceType: VibeSourceType.naiv4vibe,
      ),
      customName: 'legacy_preserve',
    );

    final existingRaw = Uint8List.fromList([9, 8, 7, 6]);
    final entry = VibeLibraryEntry(
      id: 'entry-preserve-raw',
      name: 'legacy preserve',
      vibeDisplayName: 'Legacy Preserve',
      vibeEncoding: 'box-encoded',
      vibeThumbnail: Uint8List.fromList([1, 2, 3]),
      rawImageData: existingRaw,
      strength: 0.6,
      infoExtracted: 0.7,
      sourceTypeIndex: VibeSourceType.naiv4vibe.index,
      createdAt: DateTime(2026, 4, 15, 9),
      thumbnail: Uint8List.fromList([4, 5, 6]),
      filePath: filePath,
    );

    await storage.saveEntry(entry);

    final loaded = await storage.getEntry(entry.id);

    expect(loaded, isNotNull);
    expect(loaded!.vibeEncoding, 'file-encoded');
    expect(loaded.infoExtracted, 0.42);
    expect(loaded.strength, 0.21);
    expect(loaded.rawImageData, isNotNull);
    expect(loaded.rawImageData, existingRaw);
    expect(loaded.toVibeReference().canReencodeFromRawSource, isTrue);
  });

  test(
      'getEntry preserves Hive encoding when stale file was written as type=image',
      () async {
    final vibeDirectory =
        '${hiveTempDir.path}${Platform.pathSeparator}vibes_stale_image_file';
    await VibeLibraryPathHelper.instance.setPath(vibeDirectory);
    addTearDown(() async {
      await VibeLibraryPathHelper.instance.resetToDefault();
    });

    final directory = Directory(vibeDirectory);
    await directory.create(recursive: true);
    final rawBytes = Uint8List.fromList([7, 7, 7, 7]);
    final filePath =
        '${directory.path}${Platform.pathSeparator}stale_image.naiv4vibe';
    await File(filePath).writeAsString(
      jsonEncode({
        'identifier': 'novelai-vibe-transfer',
        'version': 1,
        'type': 'image',
        'name': 'Stale Image',
        'encodings': <String, dynamic>{},
        'image': base64Encode(rawBytes),
        'importInfo': {
          'model': 'nai-diffusion-4-full',
          'information_extracted': 0.31,
          'strength': 0.22,
        },
      }),
    );

    final entry = VibeLibraryEntry(
      id: 'entry-stale-image-file',
      name: 'stale image',
      vibeDisplayName: 'Stale Image',
      vibeEncoding: 'hive-encoding',
      vibeThumbnail: rawBytes,
      rawImageData: rawBytes,
      strength: 0.6,
      infoExtracted: 0.7,
      sourceTypeIndex: VibeSourceType.rawImage.index,
      createdAt: DateTime(2026, 5, 3, 20),
      filePath: filePath,
    );

    await storage.saveEntry(entry);

    final loaded = await storage.getEntry(entry.id);

    expect(loaded, isNotNull);
    expect(loaded!.vibeEncoding, 'hive-encoding');
    expect(loaded.sourceType, VibeSourceType.naiv4vibe);
    expect(loaded.rawImageData, rawBytes);
    expect(loaded.strength, 0.22);
    expect(loaded.infoExtracted, 0.31);
  });

  test('saveEntryParams 会把显式保存的参数写回文件并持久化', () async {
    final vibeDirectory =
        '${hiveTempDir.path}${Platform.pathSeparator}vibes_param_save';
    await VibeLibraryPathHelper.instance.setPath(vibeDirectory);
    addTearDown(() async {
      await VibeLibraryPathHelper.instance.resetToDefault();
    });

    final fileStorage = VibeFileStorageService();
    final filePath = await fileStorage.saveVibeToFile(
      VibeReference(
        displayName: 'Saved Param',
        vibeEncoding: 'saved-encoding',
        thumbnail: Uint8List.fromList([1, 2, 3, 4]),
        rawImageData: Uint8List.fromList([5, 6, 7, 8]),
        strength: 0.6,
        infoExtracted: 0.7,
        sourceType: VibeSourceType.naiv4vibe,
      ),
      customName: 'saved_param',
    );

    final entry = VibeLibraryEntry(
      id: 'entry-save-params',
      name: 'saved param',
      vibeDisplayName: 'Saved Param',
      vibeEncoding: 'saved-encoding',
      vibeThumbnail: Uint8List.fromList([1, 2, 3, 4]),
      rawImageData: Uint8List.fromList([5, 6, 7, 8]),
      strength: 0.6,
      infoExtracted: 0.7,
      sourceTypeIndex: VibeSourceType.naiv4vibe.index,
      createdAt: DateTime(2026, 4, 15, 11),
      filePath: filePath,
    );

    await storage.saveEntry(entry);

    final saved = await storage.saveEntryParams(
      entry.id,
      strength: 0.12,
      infoExtracted: 0.34,
    );

    expect(saved, isNotNull);
    expect(saved!.strength, 0.12);
    expect(saved.infoExtracted, 0.34);

    final reloaded = await storage.getEntry(entry.id);
    expect(reloaded, isNotNull);
    expect(reloaded!.strength, 0.12);
    expect(reloaded.infoExtracted, 0.34);

    final fileReference = await fileStorage.loadVibeFromFile(filePath);
    expect(fileReference, isNotNull);
    expect(fileReference!.strength, 0.12);
    expect(fileReference.infoExtracted, 0.34);
  });

  test('saveEntryParams 提供持久化编码时，会把新编码一起写回文件', () async {
    final vibeDirectory =
        '${hiveTempDir.path}${Platform.pathSeparator}vibes_param_encode_save';
    await VibeLibraryPathHelper.instance.setPath(vibeDirectory);
    addTearDown(() async {
      await VibeLibraryPathHelper.instance.resetToDefault();
    });

    final fileStorage = VibeFileStorageService();
    final rawBytes = Uint8List.fromList([8, 6, 4, 2]);
    final filePath = await fileStorage.saveVibeToFile(
      VibeReference(
        displayName: 'Raw Persist',
        vibeEncoding: '',
        thumbnail: rawBytes,
        rawImageData: rawBytes,
        strength: 0.6,
        infoExtracted: 0.7,
        sourceType: VibeSourceType.rawImage,
      ),
      customName: 'raw_persist',
    );

    final entry = VibeLibraryEntry(
      id: 'entry-save-encoded-params',
      name: 'raw persist',
      vibeDisplayName: 'Raw Persist',
      vibeEncoding: '',
      vibeThumbnail: rawBytes,
      rawImageData: rawBytes,
      strength: 0.6,
      infoExtracted: 0.7,
      sourceTypeIndex: VibeSourceType.rawImage.index,
      createdAt: DateTime(2026, 4, 15, 12),
      filePath: filePath,
    );

    await storage.saveEntry(entry);

    final saved = await storage.saveEntryParams(
      entry.id,
      strength: 0.22,
      infoExtracted: 0.44,
      persistedVibeData: VibeReference(
        displayName: 'Raw Persist',
        vibeEncoding: 'persisted-encoding',
        thumbnail: rawBytes,
        rawImageData: rawBytes,
        strength: 0.22,
        infoExtracted: 0.44,
        sourceType: VibeSourceType.naiv4vibe,
      ),
    );

    expect(saved, isNotNull);
    expect(saved!.vibeEncoding, 'persisted-encoding');
    expect(saved.strength, 0.22);
    expect(saved.infoExtracted, 0.44);

    final fileReference = await fileStorage.loadVibeFromFile(filePath);
    expect(fileReference, isNotNull);
    expect(fileReference!.vibeEncoding, 'persisted-encoding');
    expect(fileReference.strength, 0.22);
    expect(fileReference.infoExtracted, 0.44);
  });

  test('saveEntry 保存整体 bundle 时保留每个子 Vibe 的独立参数', () async {
    final vibeDirectory =
        '${hiveTempDir.path}${Platform.pathSeparator}vibes_bundle_params';
    await VibeLibraryPathHelper.instance.setPath(vibeDirectory);
    addTearDown(() async {
      await VibeLibraryPathHelper.instance.resetToDefault();
    });

    final entry = VibeLibraryEntry.fromVibeReference(
      name: 'bundle params',
      vibeData: const VibeReference(
        displayName: 'Bundle Params',
        vibeEncoding: 'encoding-1',
        strength: 0.11,
        infoExtracted: 0.22,
        sourceType: VibeSourceType.naiv4vibebundle,
      ),
    ).copyWith(
      bundledVibeNames: const ['first', 'second'],
      bundledVibeEncodings: const ['encoding-1', 'encoding-2'],
      bundledVibeStrengths: const [0.11, -0.33],
      bundledVibeInfoExtracted: const [0.22, 0.77],
    );

    final saved = await storage.saveEntry(entry);
    expect(saved.filePath, isNotNull);

    final fileStorage = VibeFileStorageService();
    final extracted = await fileStorage.extractVibesFromBundle(saved.filePath!);

    expect(extracted, hasLength(2));
    expect(extracted.map((v) => v.strength), [0.11, -0.33]);
    expect(extracted.map((v) => v.infoExtracted), [0.22, 0.77]);
  });

  test('saveBundleChildParams 只更新指定子 Vibe 参数', () async {
    final vibeDirectory =
        '${hiveTempDir.path}${Platform.pathSeparator}vibes_bundle_child_params';
    await VibeLibraryPathHelper.instance.setPath(vibeDirectory);
    addTearDown(() async {
      await VibeLibraryPathHelper.instance.resetToDefault();
    });

    final saved = await storage.saveBundleEntry(
      const [
        VibeReference(
          displayName: 'first',
          vibeEncoding: 'encoding-1',
          strength: 0.11,
          infoExtracted: 0.22,
          sourceType: VibeSourceType.naiv4vibebundle,
        ),
        VibeReference(
          displayName: 'second',
          vibeEncoding: 'encoding-2',
          strength: -0.33,
          infoExtracted: 0.77,
          sourceType: VibeSourceType.naiv4vibebundle,
        ),
      ],
      name: 'bundle child params',
    );

    final updated = await storage.saveBundleChildParams(
      saved.id,
      childIndex: 1,
      strength: 0.44,
      infoExtracted: 0.55,
    );

    expect(updated, isNotNull);
    expect(updated!.bundledVibeStrengths, [0.11, 0.44]);
    expect(updated.bundledVibeInfoExtracted, [0.22, 0.55]);

    final fileStorage = VibeFileStorageService();
    final extracted = await fileStorage.extractVibesFromBundle(saved.filePath!);

    expect(extracted.map((v) => v.strength), [0.11, 0.44]);
    expect(extracted.map((v) => v.infoExtracted), [0.22, 0.55]);
  });

  test('saveBundleEntry 会把每个子 Vibe 的原图写入 bundle 文件', () async {
    final vibeDirectory =
        '${hiveTempDir.path}${Platform.pathSeparator}vibes_bundle_raw_images';
    await VibeLibraryPathHelper.instance.setPath(vibeDirectory);
    addTearDown(() async {
      await VibeLibraryPathHelper.instance.resetToDefault();
    });

    final firstRaw = Uint8List.fromList([11, 22, 33]);
    final secondRaw = Uint8List.fromList([44, 55, 66]);
    final saved = await storage.saveBundleEntry(
      [
        VibeReference(
          displayName: 'first raw',
          vibeEncoding: 'encoding-first',
          thumbnail: Uint8List.fromList([1, 2, 3]),
          rawImageData: firstRaw,
          strength: 0.12,
          infoExtracted: 0.34,
          sourceType: VibeSourceType.naiv4vibebundle,
        ),
        VibeReference(
          displayName: 'second raw',
          vibeEncoding: 'encoding-second',
          thumbnail: Uint8List.fromList([4, 5, 6]),
          rawImageData: secondRaw,
          strength: -0.56,
          infoExtracted: 0.78,
          sourceType: VibeSourceType.naiv4vibebundle,
        ),
      ],
      name: 'bundle raw images',
    );

    final fileStorage = VibeFileStorageService();
    final extracted = await fileStorage.extractVibesFromBundle(saved.filePath!);

    expect(extracted, hasLength(2));
    expect(extracted[0].rawImageData, firstRaw);
    expect(extracted[1].rawImageData, secondRaw);
    expect(extracted[0].canReencodeFromRawSource, isTrue);
    expect(extracted[1].canReencodeFromRawSource, isTrue);

    final secondChild = await storage.loadBundleChildVibe(saved.id, 1);
    expect(secondChild, isNotNull);
    expect(secondChild!.rawImageData, secondRaw);
    expect(secondChild.canReencodeFromRawSource, isTrue);
  });
}
