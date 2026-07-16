import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/utils/image_save_utils.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/image_save_settings_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';
import 'package:nai_launcher/presentation/providers/notification_settings_provider.dart';

class MockNAIImageGenerationApiService extends Mock
    implements NAIImageGenerationApiService {}

class FakeNAIImageEnhancementApiService extends Mock
    implements NAIImageEnhancementApiService {}

class TestSubscriptionNotifier extends SubscriptionNotifier {
  @override
  SubscriptionState build() {
    return const SubscriptionState.loaded(
      UserSubscription(
        tier: 3,
        active: true,
        trainingStepsLeft: TrainingStepsInfo(fixedTrainingStepsLeft: 10000),
      ),
    );
  }

  @override
  Future<bool> refreshBalance() async => true;
}

class TestLocalGalleryNotifier extends LocalGalleryNotifier {
  @override
  LocalGalleryState build() => const LocalGalleryState(isInitialized: true);

  @override
  Future<int> addNewlySavedImages(List<String> filePaths) async =>
      filePaths.length;
}

void main() {
  late Directory hiveTempDir;
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    registerFallbackValue(const ImageParams());
    registerFallbackValue(Uint8List(0));
    hiveTempDir = await Directory.systemTemp.createTemp('nai_launcher_hive_');
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
    await Hive.openBox(StorageKeys.historyBox);
    await Hive.openBox(StorageKeys.statisticsCacheBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (!await hiveTempDir.exists()) return;

    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        await hiveTempDir.delete(recursive: true);
        return;
      } on FileSystemException {
        if (attempt == 4) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });

  group('ImageGenerationNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() async {
      container.dispose();
      await Hive.box(StorageKeys.settingsBox).clear();
    });

    test(
      'GeneratedImage should prefer encoded dimensions over request hints',
      () {
        final image = GeneratedImage.create(
          _validImageBytes(width: 640, height: 960),
          width: 1792,
          height: 896,
        );

        expect(image.width, equals(640));
        expect(image.height, equals(960));
      },
    );

    test('failed stream snapshot images should be read-only', () {
      const metadata = NaiImageMetadata(
        prompt: '1girl',
        negativePrompt: 'bad anatomy',
        width: 512,
        height: 768,
      );
      final image = GeneratedImage.create(
        _validImageBytes(width: 512, height: 768),
        width: 512,
        height: 768,
        kind: GeneratedImageKind.failedStreamSnapshot,
        metadata: metadata,
      );

      expect(image.kind, GeneratedImageKind.failedStreamSnapshot);
      expect(image.metadata, same(metadata));
      expect(image.isFailedStreamSnapshot, isTrue);
      expect(image.canSave, isFalse);
      expect(image.canFavorite, isFalse);
      expect(image.canUseAsGenerationInput, isFalse);
      expect(image.canBulkSelect, isFalse);
      expect(image.canDrag, isFalse);

      final savedCopy = image.copyWithFilePath('C:/tmp/should-not-happen.png');
      expect(savedCopy.kind, GeneratedImageKind.failedStreamSnapshot);
      expect(savedCopy.metadata, same(metadata));
      expect(savedCopy.canSave, isFalse);
    });

    test(
      'generate applies positive and negative fixed tags before request',
      () async {
        final mockApiService = MockNAIImageGenerationApiService();
        ImageParams? capturedParams;

        when(
          () => mockApiService.generateImage(
            any(),
            onProgress: any(named: 'onProgress'),
            focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
            minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
            focusedSelectionRect: any(named: 'focusedSelectionRect'),
          ),
        ).thenAnswer((invocation) async {
          capturedParams = invocation.positionalArguments.first as ImageParams;
          return ([_validImageBytes(width: 512, height: 768)], <int, String>{});
        });
        when(
          () => mockApiService.generateImageStream(
            any(),
            focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
            minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
            focusedSelectionRect: any(named: 'focusedSelectionRect'),
          ),
        ).thenAnswer((_) => const Stream.empty());

        final fixedEntries = [
          FixedTagEntry.create(
            name: 'positive-prefix',
            content: 'masterpiece',
            position: FixedTagPosition.prefix,
            sortOrder: 0,
          ),
          FixedTagEntry.create(
            name: 'positive-suffix',
            content: 'cinematic lighting',
            position: FixedTagPosition.suffix,
            sortOrder: 1,
          ),
          FixedTagEntry.create(
            name: 'negative-prefix',
            content: 'bad anatomy',
            position: FixedTagPosition.prefix,
            promptType: FixedTagPromptType.negative,
            sortOrder: 2,
          ),
          FixedTagEntry.create(
            name: 'negative-suffix',
            content: 'text',
            position: FixedTagPosition.suffix,
            promptType: FixedTagPromptType.negative,
            sortOrder: 3,
          ),
        ];
        await Hive.box(StorageKeys.settingsBox).put(
          StorageKeys.fixedTagsData,
          jsonEncode(fixedEntries.map((entry) => entry.toJson()).toList()),
        );

        container.dispose();
        container = ProviderContainer(
          overrides: [
            naiImageGenerationApiServiceProvider.overrideWithValue(
              mockApiService,
            ),
          ],
        );
        await container
            .read(notificationSettingsNotifierProvider.notifier)
            .setSoundEnabled(false);

        final params = container
            .read(generationParamsNotifierProvider)
            .copyWith(prompt: '1girl', negativePrompt: 'bad hands');
        await container
            .read(imageGenerationNotifierProvider.notifier)
            .generate(params);

        expect(capturedParams, isNotNull);
        expect(
          capturedParams!.prompt,
          equals('masterpiece, 1girl, cinematic lighting'),
        );
        expect(
          capturedParams!.negativePrompt,
          equals('bad anatomy, bad hands, text'),
        );
      },
    );

    test(
      'imagesPerRequest sends one multi-sample request per repeat',
      () async {
        final mockApiService = MockNAIImageGenerationApiService();
        final firstImage = _validImageBytes(width: 512, height: 768);
        final secondImage = _validImageBytes(width: 512, height: 768);
        final thirdImage = _validImageBytes(width: 512, height: 768);
        final requestSampleCounts = <int>[];

        when(
          () => mockApiService.generateImage(
            any(),
            onProgress: any(named: 'onProgress'),
            focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
            minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
            focusedSelectionRect: any(named: 'focusedSelectionRect'),
          ),
        ).thenAnswer((_) async => fail('non-stream fallback was not expected'));
        when(
          () => mockApiService.generateImageCancellable(
            any(),
            onProgress: any(named: 'onProgress'),
            focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
            minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
            focusedSelectionRect: any(named: 'focusedSelectionRect'),
          ),
        ).thenAnswer(
          (_) async => fail('cancellable fallback was not expected'),
        );
        when(
          () => mockApiService.generateImageStream(
            any(),
            focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
            minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
            focusedSelectionRect: any(named: 'focusedSelectionRect'),
          ),
        ).thenAnswer((invocation) {
          final params = invocation.positionalArguments.first as ImageParams;
          requestSampleCounts.add(params.nSamples);
          return Stream<ImageStreamChunk>.fromIterable([
            ImageStreamChunk.complete(firstImage, sampleIndex: 0),
            ImageStreamChunk.complete(secondImage, sampleIndex: 1),
            ImageStreamChunk.complete(thirdImage, sampleIndex: 2),
          ]);
        });

        container.dispose();
        container = ProviderContainer(
          overrides: [
            naiImageGenerationApiServiceProvider.overrideWithValue(
              mockApiService,
            ),
            subscriptionNotifierProvider.overrideWith(
              TestSubscriptionNotifier.new,
            ),
          ],
        );
        await container
            .read(notificationSettingsNotifierProvider.notifier)
            .setSoundEnabled(false);
        await container
            .read(imageSaveSettingsNotifierProvider.notifier)
            .setAutoSave(false);
        container.read(imagesPerRequestProvider.notifier).set(3);

        final params = container
            .read(generationParamsNotifierProvider)
            .copyWith(
              prompt: 'multi sample',
              width: 512,
              height: 768,
              nSamples: 2,
            );

        await container
            .read(imageGenerationNotifierProvider.notifier)
            .generate(params);

        final state = container.read(imageGenerationNotifierProvider);
        expect(requestSampleCounts, equals([3, 3]));
        expect(state.status, GenerationStatus.completed);
        expect(state.currentImages, hasLength(6));
        expect(state.displayImages, hasLength(6));
      },
    );
    test(
      'registerExternalImage should prepend external result to history',
      () async {
        final notifier = container.read(
          imageGenerationNotifierProvider.notifier,
        );
        final params = container.read(generationParamsNotifierProvider);

        await notifier.registerExternalImage(
          _validImageBytes(width: 640, height: 960),
          params: params,
        );

        final state = container.read(imageGenerationNotifierProvider);

        expect(state.history, hasLength(1));
        expect(state.history.first.width, equals(640));
        expect(state.history.first.height, equals(960));
        expect(state.currentImages, isEmpty);
        expect(state.displayImages, isEmpty);
      },
    );

    test(
      'registerExternalImage should save image locally when requested',
      () async {
        final notifier = container.read(
          imageGenerationNotifierProvider.notifier,
        );
        final params = container.read(generationParamsNotifierProvider);
        final tempDir = await Directory.systemTemp.createTemp(
          'nai_launcher_director_',
        );
        addTearDown(() => tempDir.delete(recursive: true));

        await notifier.registerExternalImage(
          _validImageBytes(width: 512, height: 768),
          params: params,
          saveToLocal: true,
          saveDirectoryPath: tempDir.path,
          syncToGalleryIndex: false,
        );

        final savedImage = container
            .read(imageGenerationNotifierProvider)
            .history
            .first;
        expect(savedImage.filePath, isNotNull);
        expect(File(savedImage.filePath!).existsSync(), isTrue);
      },
    );

    test(
      'registerExternalImage should prepend external result to current display',
      () async {
        final notifier = container.read(
          imageGenerationNotifierProvider.notifier,
        );
        final params = container.read(generationParamsNotifierProvider);
        final existing = GeneratedImage.create(
          _validImageBytes(width: 640, height: 960),
          width: 640,
          height: 960,
        );

        notifier.state = notifier.state.copyWith(
          currentImages: [existing],
          history: [existing],
          displayImages: [existing],
        );

        await notifier.registerExternalImage(
          _validImageBytes(width: 1280, height: 1920),
          params: params,
          width: 1280,
          height: 1920,
          addToDisplay: true,
        );

        final state = container.read(imageGenerationNotifierProvider);

        expect(state.currentImages, hasLength(2));
        expect(state.currentImages.first.width, equals(1280));
        expect(state.currentImages.first.height, equals(1920));
        expect(state.currentImages[1].id, equals(existing.id));
        expect(state.history.first.id, equals(state.currentImages.first.id));
        expect(
          state.displayImages.first.id,
          equals(state.currentImages.first.id),
        );
        expect(state.displayWidth, equals(1280));
        expect(state.displayHeight, equals(1920));
      },
    );

    test(
      'registerExternalImage should replace current display for upscale results',
      () async {
        final notifier = container.read(
          imageGenerationNotifierProvider.notifier,
        );
        final params = container.read(generationParamsNotifierProvider);
        final existing = GeneratedImage.create(
          _validImageBytes(width: 640, height: 960),
          width: 640,
          height: 960,
        );

        notifier.state = notifier.state.copyWith(
          currentImages: [existing],
          history: [existing],
          displayImages: [existing],
        );

        await notifier.registerExternalImage(
          _validImageBytes(width: 1280, height: 1920),
          params: params,
          width: 1280,
          height: 1920,
          replaceCurrentDisplay: true,
        );

        final state = container.read(imageGenerationNotifierProvider);

        expect(state.currentImages, hasLength(1));
        expect(state.displayImages, hasLength(1));
        expect(state.currentImages.single.width, equals(1280));
        expect(state.currentImages.single.height, equals(1920));
        expect(
          state.displayImages.single.id,
          equals(state.currentImages.single.id),
        );
        expect(state.history, hasLength(2));
        expect(state.history.first.id, equals(state.currentImages.single.id));
        expect(state.history.last.id, equals(existing.id));
        expect(state.displayWidth, equals(1280));
        expect(state.displayHeight, equals(1920));
      },
    );

    test(
      'registerExternalImage should rewrite embedded metadata resolution',
      () async {
        final notifier = container.read(
          imageGenerationNotifierProvider.notifier,
        );
        final params = container
            .read(generationParamsNotifierProvider)
            .copyWith(
              prompt: 'source prompt',
              negativePrompt: 'source negative',
              width: 640,
              height: 960,
              seed: 123456,
              qualityToggle: false,
              ucPreset: 3,
            );
        final upscaledBytes = await _buildImageWithEmbeddedMetadata(
          imageWidth: 1280,
          imageHeight: 1920,
          metadataWidth: 640,
          metadataHeight: 960,
          prompt: 'source prompt',
          negativePrompt: 'source negative',
          seed: 123456,
          qualityToggle: false,
          ucPreset: 3,
        );

        await notifier.registerExternalImage(
          upscaledBytes,
          params: params,
          width: 1280,
          height: 1920,
        );

        final storedBytes = container
            .read(imageGenerationNotifierProvider)
            .history
            .first
            .bytes;
        final parsed = UnifiedMetadataParser.parseFromPng(storedBytes);

        expect(parsed.success, isTrue);
        expect(parsed.metadata?.width, equals(1280));
        expect(parsed.metadata?.height, equals(1920));
        expect(parsed.metadata?.prompt, equals('source prompt'));
      },
    );

    test('generate should保留重绘会话状态并使用流式 focused inpaint', () async {
      final mockApiService = MockNAIImageGenerationApiService();
      final originalSource = _validImageBytes(width: 640, height: 960);
      final originalMask = _validMaskBytes(width: 640, height: 960);
      when(
        () => mockApiService.generateImage(
          any(),
          onProgress: any(named: 'onProgress'),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer((_) async => fail('focused inpaint should use stream'));
      when(
        () => mockApiService.generateImageStream(
          any(),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer(
        (_) => Stream<ImageStreamChunk>.fromIterable([
          ImageStreamChunk.complete(_validImageBytes(width: 640, height: 960)),
        ]),
      );

      container.dispose();
      container = ProviderContainer(
        overrides: [
          naiImageGenerationApiServiceProvider.overrideWithValue(
            mockApiService,
          ),
          localGalleryNotifierProvider.overrideWith(
            TestLocalGalleryNotifier.new,
          ),
        ],
      );

      final workflowNotifier = container.read(
        imageWorkflowControllerProvider.notifier,
      );
      final notifier = container.read(imageGenerationNotifierProvider.notifier);
      await container
          .read(notificationSettingsNotifierProvider.notifier)
          .setSoundEnabled(false);
      final tempDir = await Directory.systemTemp.createTemp(
        'nai_launcher_focus_output_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      await container
          .read(imageSaveSettingsNotifierProvider.notifier)
          .setCustomPath(tempDir.path);
      await container
          .read(imageSaveSettingsNotifierProvider.notifier)
          .setAutoSave(true);

      workflowNotifier.replaceSourceImage(originalSource);
      workflowNotifier.enterInpaintMode();
      workflowNotifier.onMaskChanged(originalMask);
      workflowNotifier.setFocusedInpaintEnabled(true);
      workflowNotifier.setMinimumContextMegaPixels(120);
      workflowNotifier.setFocusedSelectionRect(
        const Rect.fromLTWH(120, 140, 280, 320),
      );

      final params = container
          .read(generationParamsNotifierProvider)
          .copyWith(width: 1792, height: 896);
      await notifier.generate(params);

      final updatedParams = container.read(generationParamsNotifierProvider);
      final workflow = container.read(imageWorkflowControllerProvider);
      final generationState = container.read(imageGenerationNotifierProvider);

      expect(updatedParams.maskImage, equals(originalMask));
      expect(updatedParams.sourceImage, equals(originalSource));
      expect(workflow.mode, ImageWorkflowMode.inpaint);
      expect(generationState.history.single.width, equals(640));
      expect(generationState.history.single.height, equals(960));
      expect(generationState.displayWidth, equals(640));
      expect(generationState.displayHeight, equals(960));
      expect(generationState.history.single.filePath, isNotNull);
      final savedResult = UnifiedMetadataParser.parseFromPng(
        await File(generationState.history.single.filePath!).readAsBytes(),
      );
      expect(savedResult.success, isTrue);
      expect(savedResult.metadata?.width, equals(640));
      expect(savedResult.metadata?.height, equals(960));

      verify(
        () => mockApiService.generateImageStream(
          any(),
          focusedInpaintEnabled: true,
          minimumContextMegaPixels: 120,
          focusedSelectionRect: const Rect.fromLTWH(120, 140, 280, 320),
        ),
      ).called(1);
      verifyNever(
        () => mockApiService.generateImage(
          any(),
          onProgress: any(named: 'onProgress'),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      );
    });

    test(
      'focused inpaint batch should use stream instead of direct fallback',
      () async {
        final mockApiService = MockNAIImageGenerationApiService();
        final originalSource = _validImageBytes(width: 640, height: 960);
        final originalMask = _validMaskBytes(width: 640, height: 960);
        final requestSampleCounts = <int>[];

        when(
          () => mockApiService.generateImage(
            any(),
            onProgress: any(named: 'onProgress'),
            focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
            minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
            focusedSelectionRect: any(named: 'focusedSelectionRect'),
          ),
        ).thenAnswer(
          (_) async => fail('focused inpaint batch should use stream'),
        );
        when(
          () => mockApiService.generateImageCancellable(
            any(),
            onProgress: any(named: 'onProgress'),
            focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
            minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
            focusedSelectionRect: any(named: 'focusedSelectionRect'),
          ),
        ).thenAnswer(
          (_) async => fail('focused inpaint batch should not use fallback'),
        );
        when(
          () => mockApiService.generateImageStream(
            any(),
            focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
            minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
            focusedSelectionRect: any(named: 'focusedSelectionRect'),
          ),
        ).thenAnswer((invocation) {
          final params = invocation.positionalArguments.first as ImageParams;
          requestSampleCounts.add(params.nSamples);
          return Stream<ImageStreamChunk>.fromIterable([
            ImageStreamChunk.complete(
              _validImageBytes(width: 640, height: 960),
              sampleIndex: 0,
            ),
            ImageStreamChunk.complete(
              _validImageBytes(width: 640, height: 960),
              sampleIndex: 1,
            ),
          ]);
        });

        container.dispose();
        container = ProviderContainer(
          overrides: [
            naiImageGenerationApiServiceProvider.overrideWithValue(
              mockApiService,
            ),
            subscriptionNotifierProvider.overrideWith(
              TestSubscriptionNotifier.new,
            ),
          ],
        );

        final workflowNotifier = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        await container
            .read(notificationSettingsNotifierProvider.notifier)
            .setSoundEnabled(false);
        await container
            .read(imageSaveSettingsNotifierProvider.notifier)
            .setAutoSave(false);
        container.read(imagesPerRequestProvider.notifier).set(2);

        workflowNotifier.replaceSourceImage(originalSource);
        workflowNotifier.enterInpaintMode();
        workflowNotifier.onMaskChanged(originalMask);
        workflowNotifier.setFocusedInpaintEnabled(true);
        workflowNotifier.setMinimumContextMegaPixels(96);
        workflowNotifier.setFocusedSelectionRect(
          const Rect.fromLTWH(100, 120, 240, 280),
        );

        final params = container.read(generationParamsNotifierProvider);
        await container
            .read(imageGenerationNotifierProvider.notifier)
            .generate(params.copyWith(nSamples: 1));

        final state = container.read(imageGenerationNotifierProvider);
        expect(requestSampleCounts, equals([2]));
        expect(state.status, GenerationStatus.completed);
        expect(state.currentImages, hasLength(2));

        verify(
          () => mockApiService.generateImageStream(
            any(),
            focusedInpaintEnabled: true,
            minimumContextMegaPixels: 96,
            focusedSelectionRect: const Rect.fromLTWH(100, 120, 240, 280),
          ),
        ).called(1);
        verifyNever(
          () => mockApiService.generateImage(
            any(),
            onProgress: any(named: 'onProgress'),
            focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
            minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
            focusedSelectionRect: any(named: 'focusedSelectionRect'),
          ),
        );
        verifyNever(
          () => mockApiService.generateImageCancellable(
            any(),
            onProgress: any(named: 'onProgress'),
            focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
            minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
            focusedSelectionRect: any(named: 'focusedSelectionRect'),
          ),
        );
      },
    );

    test(
      'focused stream preview placement should clear after final image',
      () async {
        final mockApiService = MockNAIImageGenerationApiService();
        final controller = StreamController<ImageStreamChunk>();
        addTearDown(() async {
          if (!controller.isClosed) {
            await controller.close();
          }
        });

        when(
          () => mockApiService.generateImage(
            any(),
            onProgress: any(named: 'onProgress'),
            focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
            minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
            focusedSelectionRect: any(named: 'focusedSelectionRect'),
          ),
        ).thenAnswer((_) async => fail('focused preview should use stream'));
        when(
          () => mockApiService.generateImageStream(
            any(),
            focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
            minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
            focusedSelectionRect: any(named: 'focusedSelectionRect'),
          ),
        ).thenAnswer((_) => controller.stream);

        container.dispose();
        container = ProviderContainer(
          overrides: [
            naiImageGenerationApiServiceProvider.overrideWithValue(
              mockApiService,
            ),
          ],
        );
        await container
            .read(notificationSettingsNotifierProvider.notifier)
            .setSoundEnabled(false);

        final source = _validImageBytes(width: 640, height: 960);
        final preview = _validImageBytes(width: 320, height: 320);
        final finalImage = _validImageBytes(width: 640, height: 960);
        final placement = FocusedStreamPreviewPlacement(
          sourceImage: source,
          xPercent: 0.25,
          yPercent: 0.125,
          widthPercent: 0.5,
          heightPercent: 0.375,
        );
        final params = container
            .read(generationParamsNotifierProvider)
            .copyWith(width: 640, height: 960, nSamples: 1);

        final generationFuture = container
            .read(imageGenerationNotifierProvider.notifier)
            .generate(params);
        await Future<void>.delayed(Duration.zero);
        controller.add(
          ImageStreamChunk.progress(
            progress: 0.4,
            previewImage: preview,
            focusedPreviewPlacement: placement,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        final streamingState = container.read(imageGenerationNotifierProvider);
        expect(streamingState.streamPreview, orderedEquals(preview));
        expect(streamingState.focusedPreviewPlacement, same(placement));

        controller.add(ImageStreamChunk.complete(finalImage));
        await controller.close();
        await generationFuture;

        final completedState = container.read(imageGenerationNotifierProvider);
        expect(completedState.status, GenerationStatus.completed);
        expect(completedState.focusedPreviewPlacement, isNull);
        expect(completedState.streamPreviewSlots, isEmpty);
      },
    );

    test('generate 会在请求前自动编码待编码 Vibe 并回写当前状态', () async {
      final mockApiService = MockNAIImageGenerationApiService();
      final mockEnhancementApiService = FakeNAIImageEnhancementApiService();
      ImageParams? capturedParams;

      when(
        () => mockEnhancementApiService.encodeVibe(
          any(),
          model: any(named: 'model'),
          informationExtracted: any(named: 'informationExtracted'),
        ),
      ).thenAnswer((invocation) async {
        final model = invocation.namedArguments[#model] as String;
        final info = invocation.namedArguments[#informationExtracted] as double;
        return '$model|$info|encoded';
      });

      when(
        () => mockApiService.generateImage(
          any(),
          onProgress: any(named: 'onProgress'),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer((invocation) async {
        capturedParams = invocation.positionalArguments.first as ImageParams;
        return ([_validImageBytes(width: 512, height: 768)], <int, String>{});
      });
      when(
        () => mockApiService.generateImageStream(
          any(),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer((_) => const Stream.empty());

      container.dispose();
      container = ProviderContainer(
        overrides: [
          naiImageGenerationApiServiceProvider.overrideWithValue(
            mockApiService,
          ),
          naiImageEnhancementApiServiceProvider.overrideWithValue(
            mockEnhancementApiService,
          ),
        ],
      );

      await container
          .read(notificationSettingsNotifierProvider.notifier)
          .setSoundEnabled(false);

      final paramsNotifier = container.read(
        generationParamsNotifierProvider.notifier,
      );
      final rawImage = _validImageBytes(width: 256, height: 256);
      paramsNotifier.addVibeReference(
        VibeReference(
          displayName: 'Pending Vibe',
          vibeEncoding: '',
          rawImageData: rawImage,
          thumbnail: rawImage,
          strength: 0.6,
          infoExtracted: 0.3,
          sourceType: VibeSourceType.rawImage,
        ),
      );

      final params = container.read(generationParamsNotifierProvider);
      await container
          .read(imageGenerationNotifierProvider.notifier)
          .generate(params);

      expect(capturedParams, isNotNull);
      expect(
        capturedParams!.vibeReferencesV4.single.vibeEncoding,
        '${params.model}|0.3|encoded',
      );
      expect(
        container
            .read(generationParamsNotifierProvider)
            .vibeReferencesV4
            .single
            .vibeEncoding,
        '${params.model}|0.3|encoded',
      );
      verify(
        () => mockEnhancementApiService.encodeVibe(
          any(),
          model: params.model,
          informationExtracted: 0.3,
        ),
      ).called(1);
    });

    test('已编码 Vibe 修改信息提取后，generate 会按新值自动重新编码', () async {
      final mockApiService = MockNAIImageGenerationApiService();
      final mockEnhancementApiService = FakeNAIImageEnhancementApiService();
      ImageParams? capturedParams;

      when(
        () => mockEnhancementApiService.encodeVibe(
          any(),
          model: any(named: 'model'),
          informationExtracted: any(named: 'informationExtracted'),
        ),
      ).thenAnswer((invocation) async {
        final model = invocation.namedArguments[#model] as String;
        final info = invocation.namedArguments[#informationExtracted] as double;
        return '$model|$info|reencoded';
      });

      when(
        () => mockApiService.generateImage(
          any(),
          onProgress: any(named: 'onProgress'),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer((invocation) async {
        capturedParams = invocation.positionalArguments.first as ImageParams;
        return ([_validImageBytes(width: 512, height: 768)], <int, String>{});
      });
      when(
        () => mockApiService.generateImageStream(
          any(),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer((_) => const Stream.empty());

      container.dispose();
      container = ProviderContainer(
        overrides: [
          naiImageGenerationApiServiceProvider.overrideWithValue(
            mockApiService,
          ),
          naiImageEnhancementApiServiceProvider.overrideWithValue(
            mockEnhancementApiService,
          ),
        ],
      );

      await container
          .read(notificationSettingsNotifierProvider.notifier)
          .setSoundEnabled(false);

      final paramsNotifier = container.read(
        generationParamsNotifierProvider.notifier,
      );
      final rawImage = _validImageBytes(width: 256, height: 256);
      paramsNotifier.addVibeReference(
        VibeReference(
          displayName: 'Imported Encoded Vibe',
          vibeEncoding: 'original-encoding',
          rawImageData: rawImage,
          thumbnail: rawImage,
          strength: 0.6,
          infoExtracted: 0.3,
          sourceType: VibeSourceType.naiv4vibe,
        ),
      );
      paramsNotifier.updateVibeReference(0, infoExtracted: 0.8);

      final params = container.read(generationParamsNotifierProvider);
      expect(params.vibeReferencesV4.single.vibeEncoding, isEmpty);

      await container
          .read(imageGenerationNotifierProvider.notifier)
          .generate(params);

      expect(capturedParams, isNotNull);
      expect(
        capturedParams!.vibeReferencesV4.single.vibeEncoding,
        '${params.model}|0.8|reencoded',
      );
      expect(
        container
            .read(generationParamsNotifierProvider)
            .vibeReferencesV4
            .single
            .vibeEncoding,
        '${params.model}|0.8|reencoded',
      );
      verify(
        () => mockEnhancementApiService.encodeVibe(
          any(),
          model: params.model,
          informationExtracted: 0.8,
        ),
      ).called(1);
    });
  });
}

Uint8List _validImageBytes({required int width, required int height}) {
  return Uint8List.fromList(
    img.encodePng(img.Image(width: width, height: height)),
  );
}

Uint8List _validMaskBytes({required int width, required int height}) {
  final mask = img.Image(width: width, height: height);
  img.fill(mask, color: img.ColorRgb8(0, 0, 0));
  for (var y = 100; y < 180; y++) {
    for (var x = 200; x < 280; x++) {
      mask.setPixelRgb(x, y, 255, 255, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(mask));
}

Future<Uint8List> _buildImageWithEmbeddedMetadata({
  required int imageWidth,
  required int imageHeight,
  required int metadataWidth,
  required int metadataHeight,
  required String prompt,
  required String negativePrompt,
  required int seed,
  bool qualityToggle = false,
  int ucPreset = 3,
}) async {
  final params = ImageParams(
    prompt: prompt,
    negativePrompt: negativePrompt,
    width: metadataWidth,
    height: metadataHeight,
    seed: seed,
    qualityToggle: qualityToggle,
    ucPreset: ucPreset,
  );

  return ImageSaveUtils.rebuildImageBytesWithMetadata(
    imageBytes: _validImageBytes(width: imageWidth, height: imageHeight),
    params: params,
    actualSeed: seed,
  );
}
