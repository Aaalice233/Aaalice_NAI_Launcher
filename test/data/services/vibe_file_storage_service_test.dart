import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/utils/novelai_vibe_codec.dart';
import 'package:nai_launcher/core/utils/vibe_library_path_helper.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_file_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'saveVibeToFile keeps raw image when saving encoded single vibe',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'vibe_file_storage_test_',
      );
      final hiveDir = await Directory.systemTemp.createTemp(
        'vibe_file_storage_hive_',
      );
      Hive.init(hiveDir.path);
      await Hive.openBox(StorageKeys.settingsBox);
      final service = VibeFileStorageService();

      await VibeLibraryPathHelper.instance.setPath(tempDir.path);
      addTearDown(() async {
        await VibeLibraryPathHelper.instance.resetToDefault();
        await Hive.close();
        if (await hiveDir.exists()) {
          await hiveDir.delete(recursive: true);
        }
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final vibe = VibeReference(
        displayName: 'test-vibe',
        vibeEncoding: 'encoded-payload',
        thumbnail: Uint8List.fromList([1, 2, 3]),
        rawImageData: Uint8List.fromList([9, 8, 7, 6]),
        strength: 0.25,
        infoExtracted: 0.45,
        encodingModel: ImageModels.animeDiffusionV45Full,
        sourceType: VibeSourceType.naiv4vibe,
      );

      final filePath = await service.saveVibeToFile(
        vibe,
        customName: 'test-vibe',
      );

      final saved =
          jsonDecode(await File(filePath).readAsString())
              as Map<String, dynamic>;

      expect(NovelAiVibeCodec.validateSingleMap(saved), isTrue);
      expect(saved['type'], 'image');
      expect(saved.containsKey('image'), isTrue);
      expect(saved['image'], isNotEmpty);
      expect(saved['id'], matches(RegExp(r'^[\da-f]{64}$')));
      final encodings = saved['encodings'] as Map<String, dynamic>;
      final modelEncoding = encodings['v4-5full'] as Map<String, dynamic>;
      final vibePayload = modelEncoding.values.single as Map<String, dynamic>;
      expect(vibePayload['encoding'], 'encoded-payload');
      expect(
        (saved['importInfo'] as Map<String, dynamic>)['information_extracted'],
        0.45,
      );
    },
  );

  test(
    'saveVibeToFile treats non-empty encoding as encoded even if source is stale rawImage',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'vibe_file_storage_test_',
      );
      final hiveDir = await Directory.systemTemp.createTemp(
        'vibe_file_storage_hive_',
      );
      Hive.init(hiveDir.path);
      await Hive.openBox(StorageKeys.settingsBox);
      final service = VibeFileStorageService();

      await VibeLibraryPathHelper.instance.setPath(tempDir.path);
      addTearDown(() async {
        await VibeLibraryPathHelper.instance.resetToDefault();
        await Hive.close();
        if (await hiveDir.exists()) {
          await hiveDir.delete(recursive: true);
        }
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final staleRawEncodedVibe = VibeReference(
        displayName: 'stale-raw-encoded',
        vibeEncoding: 'encoded-payload',
        thumbnail: Uint8List.fromList([1, 2, 3]),
        rawImageData: Uint8List.fromList([9, 8, 7, 6]),
        strength: 0.25,
        infoExtracted: 0.45,
        sourceType: VibeSourceType.rawImage,
      );

      final filePath = await service.saveVibeToFile(
        staleRawEncodedVibe,
        customName: 'stale-raw-encoded',
        defaultModel: ImageModels.animeDiffusionV4Full,
      );

      final saved =
          jsonDecode(await File(filePath).readAsString())
              as Map<String, dynamic>;

      expect(NovelAiVibeCodec.validateSingleMap(saved), isTrue);
      expect(saved['type'], 'image');

      final encodings = saved['encodings'] as Map<String, dynamic>;
      final modelEncoding = encodings['v4full'] as Map<String, dynamic>;
      final vibePayload = modelEncoding.values.single as Map<String, dynamic>;

      expect(vibePayload['encoding'], 'encoded-payload');
      expect(saved.containsKey('image'), isTrue);
    },
  );

  test('saveVibeToFile 缺少编码模型时跟随用户默认模型', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'vibe_file_storage_test_',
    );
    final hiveDir = await Directory.systemTemp.createTemp(
      'vibe_file_storage_hive_',
    );
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
    await LocalStorageService().setDefaultModel(
      ImageModels.animeDiffusionV45Full,
    );
    final service = VibeFileStorageService();

    await VibeLibraryPathHelper.instance.setPath(tempDir.path);
    addTearDown(() async {
      await VibeLibraryPathHelper.instance.resetToDefault();
      await Hive.close();
      if (await hiveDir.exists()) {
        await hiveDir.delete(recursive: true);
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    // encodingModel 为空的 Vibe 以前会被硬编码兜底成 v4full，回读后变成
    // “明确的 V4 编码”，在 V4.5 下每次生成都会重新编码扣 Anlas。
    final filePath = await service.saveVibeToFile(
      VibeReference(
        displayName: 'model-less',
        vibeEncoding: 'encoded-payload',
        thumbnail: Uint8List.fromList([1, 2, 3]),
        rawImageData: Uint8List.fromList([9, 8, 7, 6]),
        sourceType: VibeSourceType.png,
      ),
      customName: 'model-less',
    );

    final saved =
        jsonDecode(await File(filePath).readAsString())
            as Map<String, dynamic>;
    final encodings = saved['encodings'] as Map<String, dynamic>;

    expect(encodings.keys.single, 'v4-5full');
    expect(
      (saved['importInfo'] as Map<String, dynamic>)['model'],
      ImageModels.animeDiffusionV45Full,
    );
  });

  test('loadVibeFromFile 支持读取 type=image 的单个 Vibe 文件', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'vibe_file_storage_test_',
    );
    final hiveDir = await Directory.systemTemp.createTemp(
      'vibe_file_storage_hive_',
    );
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
    final service = VibeFileStorageService();

    await VibeLibraryPathHelper.instance.setPath(tempDir.path);
    addTearDown(() async {
      await VibeLibraryPathHelper.instance.resetToDefault();
      await Hive.close();
      if (await hiveDir.exists()) {
        await hiveDir.delete(recursive: true);
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final rawVibe = VibeReference(
      displayName: 'raw-vibe',
      vibeEncoding: '',
      thumbnail: Uint8List.fromList([1, 2, 3]),
      rawImageData: Uint8List.fromList([9, 8, 7, 6]),
      strength: 0.52,
      infoExtracted: 0.34,
      sourceType: VibeSourceType.rawImage,
    );

    final filePath = await service.saveVibeToFile(
      rawVibe,
      customName: 'raw-vibe',
    );

    final loaded = await service.loadVibeFromFile(filePath);

    expect(loaded, isNotNull);
    expect(loaded!.vibeEncoding, isEmpty);
    expect(loaded.sourceType, VibeSourceType.rawImage);
    expect(loaded.canReencodeFromRawSource, isTrue);
    expect(loaded.rawImageData, rawVibe.rawImageData);
    expect(loaded.infoExtracted, 0.34);
    expect(loaded.strength, 0.52);
  });

  test(
    'saveBundleToFile preserves per-vibe strength and info extracted',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'vibe_file_bundle_storage_test_',
      );
      final hiveDir = await Directory.systemTemp.createTemp(
        'vibe_file_bundle_storage_hive_',
      );
      Hive.init(hiveDir.path);
      await Hive.openBox(StorageKeys.settingsBox);
      final service = VibeFileStorageService();

      await VibeLibraryPathHelper.instance.setPath(tempDir.path);
      addTearDown(() async {
        await VibeLibraryPathHelper.instance.resetToDefault();
        await Hive.close();
        if (await hiveDir.exists()) {
          await hiveDir.delete(recursive: true);
        }
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final filePath = await service.saveBundleToFile(const [
        VibeReference(
          displayName: 'first',
          vibeEncoding: 'encoding-1',
          strength: 0.18,
          infoExtracted: 0.28,
          sourceType: VibeSourceType.naiv4vibebundle,
        ),
        VibeReference(
          displayName: 'second',
          vibeEncoding: 'encoding-2',
          strength: -0.42,
          infoExtracted: 0.88,
          sourceType: VibeSourceType.naiv4vibebundle,
        ),
      ], bundleName: 'bundle-params');

      final extracted = await service.extractVibesFromBundle(filePath);

      expect(extracted, hasLength(2));
      expect(extracted[0].strength, 0.18);
      expect(extracted[0].infoExtracted, 0.28);
      expect(extracted[1].strength, -0.42);
      expect(extracted[1].infoExtracted, 0.88);
    },
  );
}
