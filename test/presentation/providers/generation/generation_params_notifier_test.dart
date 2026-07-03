import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/utils/nai_api_utils.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveTempDir;

  setUpAll(() async {
    hiveTempDir = await Directory.systemTemp.createTemp(
      'generation_params_notifier_test_',
    );
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
    await Hive.openBox(StorageKeys.historyBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  tearDown(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
    await Hive.box(StorageKeys.historyBox).clear();
  });

  test('build should restore persisted variety plus state', () async {
    final storage = LocalStorageService();
    await storage.setLastVarietyPlus(true);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final params = container.read(generationParamsNotifierProvider);

    expect(params.varietyPlus, isTrue);
  });

  test('updateVarietyPlus should persist new value', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(generationParamsNotifierProvider.notifier)
        .updateVarietyPlus(true);

    final storage = LocalStorageService();
    expect(storage.getLastVarietyPlus(), isTrue);
  });

  test('encodeVibeWithCache 会区分 model 和 informationExtracted', () async {
    final apiService = _FakeEnhancementApiService();
    final container = ProviderContainer(
      overrides: [
        naiImageEnhancementApiServiceProvider.overrideWithValue(apiService),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(generationParamsNotifierProvider.notifier);
    final imageData = Uint8List.fromList([1, 2, 3, 4]);

    final first = await notifier.encodeVibeWithCache(
      imageData,
      model: 'nai-diffusion-4-full',
      informationExtracted: 0.2,
      vibeName: 'vibe-a',
    );
    final second = await notifier.encodeVibeWithCache(
      imageData,
      model: 'nai-diffusion-4-full',
      informationExtracted: 0.5,
      vibeName: 'vibe-a',
    );
    final third = await notifier.encodeVibeWithCache(
      imageData,
      model: 'nai-diffusion-4-curated',
      informationExtracted: 0.5,
      vibeName: 'vibe-a',
    );
    final repeatFirst = await notifier.encodeVibeWithCache(
      imageData,
      model: 'nai-diffusion-4-full',
      informationExtracted: 0.2,
      vibeName: 'vibe-a',
    );

    expect(first, 'nai-diffusion-4-full|0.2|1');
    expect(second, 'nai-diffusion-4-full|0.5|2');
    expect(third, 'nai-diffusion-4-curated|0.5|3');
    expect(repeatFirst, first);
    expect(apiService.callCount, 3);
    expect(apiService.requestedInformationExtracted, [0.2, 0.5, 0.5]);
  });

  test('更新信息提取后，可重新编码的 Vibe 会回到待编码状态', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(generationParamsNotifierProvider.notifier);
    notifier.addVibeReference(
      VibeReference(
        displayName: 'Library Vibe',
        vibeEncoding: 'encoded-before',
        rawImageData: Uint8List.fromList([9, 8, 7]),
        thumbnail: Uint8List.fromList([9, 8, 7]),
        strength: 0.6,
        infoExtracted: 0.2,
        sourceType: VibeSourceType.naiv4vibe,
      ),
    );

    notifier.updateVibeReference(0, infoExtracted: 0.3);

    final updated = container
        .read(generationParamsNotifierProvider)
        .vibeReferencesV4
        .single;
    expect(updated.infoExtracted, 0.3);
    expect(updated.vibeEncoding, isEmpty);
  });

  test('信息提取切回已有缓存值时，会直接恢复缓存编码', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(generationParamsNotifierProvider.notifier);
    final model = container.read(generationParamsNotifierProvider).model;
    final raw = Uint8List.fromList([9, 8, 7]);

    notifier.storeVibeEncodingInCache(
      raw,
      'encoded-0.2',
      model: model,
      informationExtracted: 0.2,
    );
    notifier.storeVibeEncodingInCache(
      raw,
      'encoded-0.5',
      model: model,
      informationExtracted: 0.5,
    );

    notifier.addVibeReference(
      VibeReference(
        displayName: 'Cached Vibe',
        vibeEncoding: 'encoded-0.2',
        rawImageData: raw,
        thumbnail: raw,
        strength: 0.6,
        infoExtracted: 0.2,
        sourceType: VibeSourceType.naiv4vibe,
      ),
    );

    notifier.updateVibeReference(0, infoExtracted: 0.5);
    var updated = container
        .read(generationParamsNotifierProvider)
        .vibeReferencesV4
        .single;
    expect(updated.infoExtracted, 0.5);
    expect(updated.vibeEncoding, 'encoded-0.5');

    notifier.updateVibeReference(0, infoExtracted: 0.2);
    updated = container
        .read(generationParamsNotifierProvider)
        .vibeReferencesV4
        .single;
    expect(updated.infoExtracted, 0.2);
    expect(updated.vibeEncoding, 'encoded-0.2');
  });

  test('导入时自带的预编码 Vibe 会自动记住原始编码参数', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(generationParamsNotifierProvider.notifier);
    final raw = Uint8List.fromList([6, 5, 4]);

    notifier.addVibeReference(
      VibeReference(
        displayName: 'Imported Encoded Vibe',
        vibeEncoding: 'original-encoding',
        rawImageData: raw,
        thumbnail: raw,
        strength: 0.6,
        infoExtracted: 0.2,
        sourceType: VibeSourceType.naiv4vibe,
      ),
    );

    notifier.updateVibeReference(0, infoExtracted: 0.5);
    var updated = container
        .read(generationParamsNotifierProvider)
        .vibeReferencesV4
        .single;
    expect(updated.vibeEncoding, isEmpty);

    notifier.updateVibeReference(0, infoExtracted: 0.2);
    updated = container
        .read(generationParamsNotifierProvider)
        .vibeReferencesV4
        .single;
    expect(updated.vibeEncoding, 'original-encoding');
  });

  test('没有原图数据的预编码 Vibe 改信息提取时不会错误清空编码', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(generationParamsNotifierProvider.notifier);
    notifier.addVibeReference(
      const VibeReference(
        displayName: 'Encoded Only',
        vibeEncoding: 'encoded-before',
        strength: 0.6,
        infoExtracted: 0.2,
        sourceType: VibeSourceType.naiv4vibe,
      ),
    );

    notifier.updateVibeReference(0, infoExtracted: 0.1);

    final updated = container
        .read(generationParamsNotifierProvider)
        .vibeReferencesV4
        .single;
    expect(updated.infoExtracted, 0.1);
    expect(updated.vibeEncoding, 'encoded-before');
  });

  test('更新参考强度时允许负值', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(generationParamsNotifierProvider.notifier);
    notifier.addVibeReference(
      const VibeReference(
        displayName: 'Strength Test',
        vibeEncoding: 'encoded-before',
        strength: 0.6,
        infoExtracted: 0.2,
        sourceType: VibeSourceType.naiv4vibe,
      ),
    );

    notifier.updateVibeReference(0, strength: -0.4);

    final updated = container
        .read(generationParamsNotifierProvider)
        .vibeReferencesV4
        .single;
    expect(updated.strength, -0.4);
  });

  test('显式保存参数时，可重新编码的 Vibe 会生成持久化编码', () async {
    final apiService = _FakeEnhancementApiService();
    final container = ProviderContainer(
      overrides: [
        naiImageEnhancementApiServiceProvider.overrideWithValue(apiService),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(generationParamsNotifierProvider.notifier);
    final prepared = await notifier.prepareVibeForLibraryParamSave(
      VibeReference(
        displayName: 'Persisted Vibe',
        vibeEncoding: 'encoded-before',
        rawImageData: Uint8List.fromList([1, 3, 5, 7]),
        thumbnail: Uint8List.fromList([1, 3, 5, 7]),
        strength: 0.6,
        infoExtracted: 0.2,
        sourceType: VibeSourceType.naiv4vibe,
      ),
      strength: 0.6,
      infoExtracted: 0.5,
    );

    expect(prepared, isNotNull);
    expect(prepared!.infoExtracted, 0.5);
    expect(prepared.vibeEncoding, 'nai-diffusion-4-5-full|0.5|1');
    expect(apiService.callCount, 1);
    expect(apiService.requestedInformationExtracted, [0.5]);
  });

  test('生成前自动编码会把原图 Vibe 提升为预编码状态', () async {
    final apiService = _FakeEnhancementApiService();
    final container = ProviderContainer(
      overrides: [
        naiImageEnhancementApiServiceProvider.overrideWithValue(apiService),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(generationParamsNotifierProvider.notifier);
    final raw = Uint8List.fromList([2, 4, 6, 8]);
    final vibes = [
      VibeReference(
        displayName: 'Raw Vibe',
        vibeEncoding: '',
        rawImageData: raw,
        thumbnail: raw,
        strength: 0.6,
        infoExtracted: 0.3,
        sourceType: VibeSourceType.rawImage,
      ),
    ];

    final prepared = await notifier.ensureVibeReferencesEncoded(
      vibes,
      model: 'nai-diffusion-4-full',
      syncCurrentState: false,
    );

    expect(prepared.single.vibeEncoding, 'nai-diffusion-4-full|0.3|1');
    expect(prepared.single.sourceType, VibeSourceType.naiv4vibe);
    expect(prepared.single.rawImageData, raw);
  });

  test('手动写入编码时会把原图 Vibe 提升为预编码状态', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(generationParamsNotifierProvider.notifier);
    final raw = Uint8List.fromList([8, 6, 4, 2]);
    notifier.addVibeReference(
      VibeReference(
        displayName: 'Manual Encode Vibe',
        vibeEncoding: '',
        rawImageData: raw,
        thumbnail: raw,
        strength: 0.6,
        infoExtracted: 0.3,
        sourceType: VibeSourceType.rawImage,
      ),
    );

    notifier.updateVibeReference(0, vibeEncoding: 'manual-encoding');

    final updated = container
        .read(generationParamsNotifierProvider)
        .vibeReferencesV4
        .single;
    expect(updated.vibeEncoding, 'manual-encoding');
    expect(updated.sourceType, VibeSourceType.naiv4vibe);
    expect(updated.rawImageData, raw);
  });

  test('生成状态保存与恢复会保留完整 Vibe 和 Precise Reference 数据', () async {
    final storage = _FakeGenerationStateStorage();
    final container = ProviderContainer(
      overrides: [vibeLibraryStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(generationParamsNotifierProvider.notifier);
    final imageBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    final preciseBytes = Uint8List.fromList([9, 8, 7, 6]);

    notifier.addVibeReferences([
      VibeReference(
        displayName: 'State Vibe',
        vibeEncoding: 'encoded-state-vibe',
        thumbnail: imageBytes,
        rawImageData: imageBytes,
        strength: -0.25,
        infoExtracted: 0.35,
        sourceType: VibeSourceType.naiv4vibe,
        bundleSource: 'bundle-a',
        enabled: false,
      ),
    ], recordUsage: false);
    notifier.addPreciseReference(
      preciseBytes,
      type: PreciseRefType.style,
      strength: 0.4,
      fidelity: 0.8,
      isNormalizedPng: true,
    );
    notifier.updatePreciseReference(0, enabled: false);
    await notifier.saveGenerationState();

    expect(storage.generationStateJson, isNotNull);

    final restoreContainer = ProviderContainer(
      overrides: [vibeLibraryStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(restoreContainer.dispose);

    await restoreContainer
        .read(generationParamsNotifierProvider.notifier)
        .restoreGenerationState();

    final restored = restoreContainer.read(generationParamsNotifierProvider);
    final restoredVibe = restored.vibeReferencesV4.single;
    expect(restoredVibe.displayName, 'State Vibe');
    expect(restoredVibe.vibeEncoding, 'encoded-state-vibe');
    expect(restoredVibe.thumbnail, imageBytes);
    expect(restoredVibe.rawImageData, imageBytes);
    expect(restoredVibe.strength, -0.25);
    expect(restoredVibe.infoExtracted, 0.35);
    expect(restoredVibe.sourceType, VibeSourceType.naiv4vibe);
    expect(restoredVibe.bundleSource, 'bundle-a');
    expect(restoredVibe.enabled, isFalse);

    final restoredPrecise = restored.preciseReferences.single;
    expect(restoredPrecise.image, preciseBytes);
    expect(restoredPrecise.type, PreciseRefType.style);
    expect(restoredPrecise.strength, 0.4);
    expect(restoredPrecise.fidelity, 0.8);
    expect(restoredPrecise.enabled, isFalse);
    expect(
      NAIApiUtils.isKnownNormalizedPreciseReferencePng(restoredPrecise.image),
      isTrue,
    );
  });

  test(
    'addPreciseReferenceFromImage stores request-ready normalized PNG',
    () async {
      final container = ProviderContainer(
        overrides: [
          vibeLibraryStorageServiceProvider.overrideWithValue(
            _FakeGenerationStateStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        generationParamsNotifierProvider.notifier,
      );

      await notifier.addPreciseReferenceFromImage(
        _validPngBytes(width: 8, height: 4),
        type: PreciseRefType.character,
        strength: 0.7,
        fidelity: 0.9,
      );

      final reference = container
          .read(generationParamsNotifierProvider)
          .preciseReferences
          .single;
      final decoded = img.decodeImage(reference.image);

      expect(
        NAIApiUtils.isKnownNormalizedPreciseReferencePng(reference.image),
        isTrue,
      );
      expect(decoded, isNotNull);
      expect('${decoded!.width}x${decoded.height}', '1536x1024');
      expect(reference.type, PreciseRefType.character);
      expect(reference.strength, 0.7);
      expect(reference.fidelity, 0.9);
    },
  );
}

Uint8List _validPngBytes({required int width, required int height}) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

class _FakeEnhancementApiService extends NAIImageEnhancementApiService {
  _FakeEnhancementApiService() : super(Dio());

  int callCount = 0;
  final List<double> requestedInformationExtracted = [];

  @override
  Future<String> encodeVibe(
    Uint8List image, {
    required String model,
    double informationExtracted = 1.0,
  }) async {
    callCount++;
    requestedInformationExtracted.add(informationExtracted);
    return '$model|$informationExtracted|$callCount';
  }
}

class _FakeGenerationStateStorage extends VibeLibraryStorageService {
  String? generationStateJson;

  @override
  Future<void> saveGenerationStateJson(String stateJson) async {
    generationStateJson = stateJson;
  }

  @override
  Future<String?> loadGenerationStateJson() async => generationStateJson;
}
