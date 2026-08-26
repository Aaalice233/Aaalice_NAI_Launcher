import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/core/services/anlas_calculator.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/utils/nai_api_utils.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';
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

  test('alpha mode should default to straight and persist changes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(generationParamsNotifierProvider).straightAlpha,
      isTrue,
    );

    container
        .read(generationParamsNotifierProvider.notifier)
        .updateStraightAlpha(false);

    expect(
      container.read(generationParamsNotifierProvider).straightAlpha,
      isFalse,
    );
    expect(LocalStorageService().getImageStraightAlpha(), isFalse);
  });

  test('encodeVibeWithCache 会区分 model 和 informationExtracted', () async {
    final apiService = _FakeEnhancementApiService();
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        naiImageEnhancementApiServiceProvider.overrideWithValue(apiService),
        subscriptionNotifierProvider.overrideWith(
          _TestSubscriptionNotifier.new,
        ),
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

  for (final status in [AuthStatus.unauthenticated, AuthStatus.loading]) {
    test('Vibe cache miss 在 $status 时拒绝 API 调用', () async {
      final apiService = _FakeEnhancementApiService();
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _TestAuthNotifier(status)),
          naiImageEnhancementApiServiceProvider.overrideWithValue(apiService),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        generationParamsNotifierProvider.notifier,
      );

      final encoding = await notifier.encodeVibeWithCache(
        Uint8List.fromList([7, 8, 9]),
        model: ImageModels.animeDiffusionV4Full,
        informationExtracted: 0.7,
        vibeName: 'private-vibe',
      );

      expect(encoding, isNull);
      expect(apiService.callCount, 0);
      expect(notifier.vibeEncodingCacheSize, 0);
      expect(
        container.read(authPromptRequestProvider)?.reason,
        AuthPromptReason.vibeEncoding,
      );
    });
  }

  test('Vibe cache hit 可在未登录时匿名复用', () async {
    final apiService = _FakeEnhancementApiService();
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
        naiImageEnhancementApiServiceProvider.overrideWithValue(apiService),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(generationParamsNotifierProvider.notifier);
    final image = Uint8List.fromList([4, 3, 2, 1]);
    notifier.storeVibeEncodingInCache(
      image,
      'cached-encoding',
      model: ImageModels.animeDiffusionV4Full,
      informationExtracted: 0.7,
    );

    final encoding = await notifier.encodeVibeWithCache(
      image,
      model: ImageModels.animeDiffusionV4Full,
      informationExtracted: 0.7,
      vibeName: 'cached-vibe',
    );

    expect(encoding, 'cached-encoding');
    expect(apiService.callCount, 0);
    expect(container.read(authPromptRequestProvider), isNull);
  });

  test('V3 原图 Vibe 不调用预编码接口', () async {
    final apiService = _FakeEnhancementApiService();
    final container = ProviderContainer(
      overrides: [
        naiImageEnhancementApiServiceProvider.overrideWithValue(apiService),
      ],
    );
    addTearDown(container.dispose);

    final encoding = await container
        .read(generationParamsNotifierProvider.notifier)
        .encodeVibeWithCache(
          Uint8List.fromList([1, 2, 3]),
          model: ImageModels.animeDiffusionV3,
          vibeName: 'v3-raw',
        );

    expect(encoding, isNull);
    expect(apiService.callCount, 0);
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

  test('V3 下修改信息提取会使旧 V4 编码失效', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(generationParamsNotifierProvider.notifier);
    notifier.addVibeReference(
      VibeReference(
        displayName: 'V4 encoded vibe',
        vibeEncoding: 'encoded-for-v4',
        encodingModel: ImageModels.animeDiffusionV4Full,
        rawImageData: Uint8List.fromList([9, 8, 7]),
        infoExtracted: 0.7,
        sourceType: VibeSourceType.naiv4vibe,
      ),
    );
    notifier.updateModel(ImageModels.animeDiffusionV3);

    notifier.updateVibeReference(0, infoExtracted: 0.3);
    notifier.updateModel(ImageModels.animeDiffusionV4Full);

    final updated = container
        .read(generationParamsNotifierProvider)
        .vibeReferencesV4
        .single;
    expect(updated.vibeEncoding, isEmpty);
    expect(updated.encodingModel, isNull);
    expect(
      updated.needsEncodingForModel(ImageModels.animeDiffusionV4Full),
      isTrue,
    );
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

  test('缺少编码模型的预编码 Vibe 会补齐为当前模型，不再虚报编码费', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(generationParamsNotifierProvider.notifier);
    notifier.updateModel(ImageModels.animeDiffusionV45Full, persist: false);

    final raw = Uint8List.fromList([4, 5, 6]);
    // 只带 iTXt 编码的 PNG 解析不出编码模型，encodingModel 会是 null。
    notifier.addVibeReferences([
      VibeReference(
        displayName: 'PNG Vibe',
        vibeEncoding: 'encoding-without-model',
        rawImageData: raw,
        thumbnail: raw,
        sourceType: VibeSourceType.png,
      ),
    ], recordUsage: false);

    final params = container.read(generationParamsNotifierProvider);
    final vibe = params.vibeReferencesV4.single;

    expect(vibe.encodingModel, ImageModels.animeDiffusionV45Full);
    expect(vibe.needsEncodingForModel(params.model), isFalse);
    expect(AnlasCalculator.usesVibeReferences(params), isTrue);
    expect(AnlasCalculator.resolveVibeEncodingCost(params), 0);
  });

  test('setVibeReferences 替换导入时同样补齐编码模型', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(generationParamsNotifierProvider.notifier);
    notifier.updateModel(ImageModels.animeDiffusionV45Full, persist: false);

    final raw = Uint8List.fromList([1, 1, 2]);
    // Shift+点击库条目走的是替换而不是追加。
    notifier.setVibeReferences([
      VibeReference(
        displayName: 'Library Vibe',
        vibeEncoding: 'encoding-without-model',
        rawImageData: raw,
        thumbnail: raw,
        sourceType: VibeSourceType.naiv4vibe,
      ),
    ]);

    final params = container.read(generationParamsNotifierProvider);
    expect(
      params.vibeReferencesV4.single.encodingModel,
      ImageModels.animeDiffusionV45Full,
    );
    expect(AnlasCalculator.resolveVibeEncodingCost(params), 0);
  });

  test('已经记录编码模型的 Vibe 不会被改写，换模型仍会计费', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(generationParamsNotifierProvider.notifier);
    notifier.updateModel(ImageModels.animeDiffusionV45Full, persist: false);

    final raw = Uint8List.fromList([7, 7, 7]);
    notifier.addVibeReferences([
      VibeReference(
        displayName: 'V4 Vibe',
        vibeEncoding: 'encoded-for-v4',
        rawImageData: raw,
        thumbnail: raw,
        encodingModel: ImageModels.animeDiffusionV4Full,
        sourceType: VibeSourceType.naiv4vibe,
      ),
    ], recordUsage: false);

    final params = container.read(generationParamsNotifierProvider);
    final vibe = params.vibeReferencesV4.single;

    expect(vibe.encodingModel, ImageModels.animeDiffusionV4Full);
    expect(vibe.needsEncodingForModel(params.model), isTrue);
    expect(AnlasCalculator.resolveVibeEncodingCost(params), 2);
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
        authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        naiImageEnhancementApiServiceProvider.overrideWithValue(apiService),
        subscriptionNotifierProvider.overrideWith(
          _TestSubscriptionNotifier.new,
        ),
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

  test('V3 下显式保存新的信息提取值会清除旧 V4 编码', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final prepared = await container
        .read(generationParamsNotifierProvider.notifier)
        .prepareVibeForLibraryParamSave(
          VibeReference(
            displayName: 'Persisted V4 Vibe',
            vibeEncoding: 'encoded-before',
            encodingModel: ImageModels.animeDiffusionV4Full,
            rawImageData: Uint8List.fromList([1, 3, 5, 7]),
            infoExtracted: 0.2,
            sourceType: VibeSourceType.naiv4vibe,
          ),
          strength: 0.6,
          infoExtracted: 0.5,
          model: ImageModels.animeDiffusionV3,
        );

    expect(prepared, isNotNull);
    expect(prepared!.infoExtracted, 0.5);
    expect(prepared.vibeEncoding, isEmpty);
    expect(prepared.encodingModel, isNull);
  });

  test('生成前自动编码会把原图 Vibe 提升为预编码状态', () async {
    final apiService = _FakeEnhancementApiService();
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        naiImageEnhancementApiServiceProvider.overrideWithValue(apiService),
        subscriptionNotifierProvider.overrideWith(
          _TestSubscriptionNotifier.new,
        ),
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

  test('切换模型后会重新编码仍有原图来源的 Vibe', () async {
    final apiService = _FakeEnhancementApiService();
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        naiImageEnhancementApiServiceProvider.overrideWithValue(apiService),
        subscriptionNotifierProvider.overrideWith(
          _TestSubscriptionNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(generationParamsNotifierProvider.notifier);
    final raw = Uint8List.fromList([2, 4, 6, 8]);
    final prepared = await notifier.ensureVibeReferencesEncoded(
      [
        VibeReference(
          displayName: 'Stale Vibe',
          vibeEncoding: 'encoded-for-v4',
          rawImageData: raw,
          thumbnail: raw,
          infoExtracted: 0.3,
          encodingModel: 'nai-diffusion-4-full',
          sourceType: VibeSourceType.naiv4vibe,
        ),
      ],
      model: 'nai-diffusion-4-5-full',
      syncCurrentState: false,
    );

    expect(prepared.single.vibeEncoding, 'nai-diffusion-4-5-full|0.3|1');
    expect(prepared.single.encodingModel, 'nai-diffusion-4-5-full');
    expect(apiService.callCount, 1);
  });

  test('生成前不会编码已禁用的原图 Vibe', () async {
    final apiService = _FakeEnhancementApiService();
    final container = ProviderContainer(
      overrides: [
        naiImageEnhancementApiServiceProvider.overrideWithValue(apiService),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(generationParamsNotifierProvider.notifier);
    final raw = Uint8List.fromList([9, 7, 5, 3]);
    final prepared = await notifier.ensureVibeReferencesEncoded(
      [
        VibeReference(
          displayName: 'Disabled Raw Vibe',
          vibeEncoding: '',
          rawImageData: raw,
          thumbnail: raw,
          sourceType: VibeSourceType.rawImage,
          enabled: false,
        ),
      ],
      model: 'nai-diffusion-4-full',
      syncCurrentState: false,
    );

    expect(prepared.single.vibeEncoding, isEmpty);
    expect(apiService.callCount, 0);
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

  group('updateModel default follow-up', () {
    test('should adopt the new model defaults when untouched', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        generationParamsNotifierProvider.notifier,
      );
      notifier.updateModel(ImageModels.animeDiffusionV4Full);
      notifier.updateScale(5.5);

      notifier.updateModel(ImageModels.animeDiffusionV45Full);

      final params = container.read(generationParamsNotifierProvider);
      expect(params.model, ImageModels.animeDiffusionV45Full);
      expect(params.scale, 5.0);
    });

    test('should adopt V5 defaults from V4.5 when untouched', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        generationParamsNotifierProvider.notifier,
      );
      notifier.updateModel(ImageModels.animeDiffusionV45Full);
      notifier.updateScale(5.0);

      notifier.updateModel(ImageModels.v5StagingKey);

      final params = container.read(generationParamsNotifierProvider);
      expect(params.model, ImageModels.v5StagingKey);
      // 正式版 V5 的出厂默认 CFG 是 7（测试期是 10）。
      expect(params.scale, 7.0);
    });

    test('should keep a scale the user adjusted', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        generationParamsNotifierProvider.notifier,
      );
      notifier.updateModel(ImageModels.animeDiffusionV4Full);
      notifier.updateScale(7.5);

      notifier.updateModel(ImageModels.animeDiffusionV45Full);

      expect(container.read(generationParamsNotifierProvider).scale, 7.5);
    });

    test('should turn Variety+ off when switching to V5', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        generationParamsNotifierProvider.notifier,
      );
      notifier.updateModel(ImageModels.animeDiffusionV45Full);
      notifier.updateVarietyPlus(true);

      notifier.updateModel(ImageModels.animeDiffusionV5Curated);

      expect(
        container.read(generationParamsNotifierProvider).varietyPlus,
        isFalse,
      );
    });

    test(
      'should keep Variety+ on when switching between V4 and V4.5',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(
          generationParamsNotifierProvider.notifier,
        );
        notifier.updateModel(ImageModels.animeDiffusionV4Full);
        notifier.updateVarietyPlus(true);

        notifier.updateModel(ImageModels.animeDiffusionV45Full);

        expect(
          container.read(generationParamsNotifierProvider).varietyPlus,
          isTrue,
        );
      },
    );

    test('should drop a stored Variety+ when restoring a V5 session', () async {
      // 恢复走的是 build 而不是 updateModel，存档里可能留着别的模型开的开关。
      final seed = ProviderContainer();
      final storage = seed.read(localStorageServiceProvider);
      final previousModel = storage.getDefaultModel();
      final previousVarietyPlus = storage.getLastVarietyPlus();
      addTearDown(() async {
        await storage.setDefaultModel(previousModel);
        await storage.setLastVarietyPlus(previousVarietyPlus);
        seed.dispose();
      });

      await storage.setDefaultModel(ImageModels.animeDiffusionV5Curated);
      await storage.setLastVarietyPlus(true);

      final restored = ProviderContainer();
      addTearDown(restored.dispose);

      final params = restored.read(generationParamsNotifierProvider);
      expect(params.model, ImageModels.animeDiffusionV5Curated);
      expect(params.varietyPlus, isFalse);
    });

    test('should keep an adjusted V4.5 scale when switching to V5', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        generationParamsNotifierProvider.notifier,
      );
      notifier.updateModel(ImageModels.animeDiffusionV45Full);
      notifier.updateScale(7.5);

      notifier.updateModel(ImageModels.v5StagingKey);

      expect(container.read(generationParamsNotifierProvider).scale, 7.5);
    });

    test('should skip the follow-up for metadata imports', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        generationParamsNotifierProvider.notifier,
      );
      notifier.updateModel(ImageModels.animeDiffusionV4Full);
      notifier.updateScale(5.5);

      notifier.updateModel(
        ImageModels.animeDiffusionV45Full,
        followDefaults: false,
      );

      expect(container.read(generationParamsNotifierProvider).scale, 5.5);
    });

    test('should skip the V5 follow-up for metadata imports', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        generationParamsNotifierProvider.notifier,
      );
      notifier.updateModel(ImageModels.animeDiffusionV45Full);
      notifier.updateScale(5.0);

      notifier.updateModel(ImageModels.v5StagingKey, followDefaults: false);

      expect(container.read(generationParamsNotifierProvider).scale, 5.0);
    });
  });
}

Uint8List _validPngBytes({required int width, required int height}) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this.authStatus);

  final AuthStatus authStatus;

  @override
  AuthState build() => AuthState(status: authStatus);
}

class _AuthenticatedAuthNotifier extends _TestAuthNotifier {
  _AuthenticatedAuthNotifier() : super(AuthStatus.authenticated);
}

class _UnauthenticatedAuthNotifier extends _TestAuthNotifier {
  _UnauthenticatedAuthNotifier() : super(AuthStatus.unauthenticated);
}

class _TestSubscriptionNotifier extends SubscriptionNotifier {
  @override
  SubscriptionState build() {
    return const SubscriptionState.loaded(
      UserSubscription(tier: 1, active: true),
    );
  }

  @override
  void schedulePostBillingRefresh({Duration delay = Duration.zero}) {}
}

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
