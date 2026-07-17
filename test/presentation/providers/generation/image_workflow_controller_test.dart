import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';

void main() {
  late Directory hiveTempDir;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    hiveTempDir = await Directory.systemTemp.createTemp(
      'nai_launcher_workflow_hive_',
    );
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  group('ImageWorkflowController', () {
    late ProviderContainer container;

    setUp(() async {
      await Hive.box(StorageKeys.settingsBox).clear();
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'enterEnhanceMode should project source dimensions into generation params',
      () {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final paramsNotifier = container.read(
          generationParamsNotifierProvider.notifier,
        );

        paramsNotifier.updateSize(832, 1216, persist: false);
        paramsNotifier.updateStrength(0.7);
        paramsNotifier.updateNoise(0.0);
        paramsNotifier.setSourceImage(Uint8List.fromList([1, 2, 3]));

        controller.setSourceImageDimensions(768, 1024);
        controller.enterEnhanceMode();
        controller.updateEnhanceUpscaleFactor(1.5);
        controller.updateEnhanceIndividualSettings(strength: 0.42, noise: 0.16);

        final workflow = container.read(imageWorkflowControllerProvider);
        final params = container.read(generationParamsNotifierProvider);

        expect(workflow.mode, ImageWorkflowMode.enhance);
        expect(params.action, ImageGenerationAction.img2img);
        expect(params.width, equals(1152));
        expect(params.height, equals(1536));
        expect(params.strength, equals(0.42));
        expect(params.noise, equals(0.16));
      },
    );

    test('exitEnhanceMode should restore original img2img params', () {
      final controller = container.read(
        imageWorkflowControllerProvider.notifier,
      );
      final paramsNotifier = container.read(
        generationParamsNotifierProvider.notifier,
      );

      paramsNotifier.updateSize(832, 1216, persist: false);
      paramsNotifier.updateStrength(0.63);
      paramsNotifier.updateNoise(0.04);
      paramsNotifier.setSourceImage(Uint8List.fromList([1, 2, 3]));

      controller.setSourceImageDimensions(768, 1024);
      controller.enterEnhanceMode();
      controller.updateEnhanceUpscaleFactor(1.5);
      controller.exitEnhanceMode();

      final workflow = container.read(imageWorkflowControllerProvider);
      final params = container.read(generationParamsNotifierProvider);

      expect(workflow.mode, ImageWorkflowMode.base);
      expect(params.width, equals(832));
      expect(params.height, equals(1216));
      expect(params.strength, equals(0.63));
      expect(params.noise, equals(0.04));
    });

    test(
      'replaceSourceImageInInpaintMode should restore base workflow before generating with the new source',
      () {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final paramsNotifier = container.read(
          generationParamsNotifierProvider.notifier,
        );

        paramsNotifier.updateModel(
          ImageModels.animeDiffusionV45Full,
          persist: false,
        );
        paramsNotifier.setSourceImage(Uint8List.fromList([1, 2, 3]));
        paramsNotifier.setMaskImage(Uint8List.fromList([9, 9, 9]));
        controller.enterInpaintMode();

        controller.replaceSourceImage(
          _validImageBytes(width: 512, height: 768),
          sourceWidth: 512,
          sourceHeight: 768,
        );

        final workflow = container.read(imageWorkflowControllerProvider);
        final params = container.read(generationParamsNotifierProvider);

        expect(workflow.mode, ImageWorkflowMode.base);
        expect(params.maskImage, isNull);
        expect(params.action, ImageGenerationAction.img2img);
        expect(params.model, ImageModels.animeDiffusionV45Full);
        expect(params.width, equals(512));
        expect(params.height, equals(768));
      },
    );

    test(
      'replaceSourceImage should keep import bytes while applying the official web bucket',
      () {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final paramsNotifier = container.read(
          generationParamsNotifierProvider.notifier,
        );

        paramsNotifier.updateModel(
          ImageModels.animeDiffusionV45Curated,
          persist: false,
        );
        paramsNotifier.updateSize(832, 1216, persist: false);

        final original = _validImageBytes(width: 1500, height: 900);

        controller.replaceSourceImage(original);

        final workflow = container.read(imageWorkflowControllerProvider);
        final params = container.read(generationParamsNotifierProvider);
        final source = img.decodeImage(params.sourceImage!);

        expect(workflow.sourceWidth, equals(1472));
        expect(workflow.sourceHeight, equals(896));
        expect(workflow.sourceImageWidth, equals(1500));
        expect(workflow.sourceImageHeight, equals(900));
        expect(params.width, equals(1472));
        expect(params.height, equals(896));
        expect(params.sourceImage, same(original));
        expect(source!.width, equals(1500));
        expect(source.height, equals(900));
        expect(params.action, ImageGenerationAction.img2img);
      },
    );

    test(
      'replaceSourceImageAsync should keep import bytes while applying the official web bucket',
      () async {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final paramsNotifier = container.read(
          generationParamsNotifierProvider.notifier,
        );

        paramsNotifier.updateModel(
          ImageModels.animeDiffusionV45Curated,
          persist: false,
        );
        paramsNotifier.updateSize(832, 1216, persist: false);

        final original = _validImageBytes(width: 1500, height: 900);

        await controller.replaceSourceImageAsync(original);

        final workflow = container.read(imageWorkflowControllerProvider);
        final params = container.read(generationParamsNotifierProvider);
        final source = img.decodeImage(params.sourceImage!);

        expect(workflow.sourceWidth, equals(1472));
        expect(workflow.sourceHeight, equals(896));
        expect(workflow.sourceImageWidth, equals(1500));
        expect(workflow.sourceImageHeight, equals(900));
        expect(params.width, equals(1472));
        expect(params.height, equals(896));
        expect(params.sourceImage, same(original));
        expect(source!.width, equals(1500));
        expect(source.height, equals(900));
        expect(params.action, ImageGenerationAction.img2img);
      },
    );

    test(
      'updateEnhanceUpscaleFactor should clamp unsupported values to web range',
      () {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final paramsNotifier = container.read(
          generationParamsNotifierProvider.notifier,
        );

        paramsNotifier.setSourceImage(Uint8List.fromList([1, 2, 3]));
        controller.setSourceImageDimensions(768, 1024);
        controller.enterEnhanceMode();

        controller.updateEnhanceUpscaleFactor(4.0);

        final workflow = container.read(imageWorkflowControllerProvider);

        expect(workflow.enhance.upscaleFactor, equals(1.5));
      },
    );

    test('enterBaseMode from enhance should restore base workflow', () {
      final controller = container.read(
        imageWorkflowControllerProvider.notifier,
      );
      final paramsNotifier = container.read(
        generationParamsNotifierProvider.notifier,
      );

      paramsNotifier.setSourceImage(Uint8List.fromList([1, 2, 3]));
      controller.enterEnhanceMode();

      controller.enterBaseMode();

      final workflow = container.read(imageWorkflowControllerProvider);

      expect(workflow.mode, ImageWorkflowMode.base);
      expect(workflow.isPanelExpanded, isTrue);
    });

    test(
      'focused inpaint settings should expose web-aligned defaults and updates',
      () {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );

        var workflow = container.read(imageWorkflowControllerProvider);
        expect(workflow.focusedInpaintEnabled, isFalse);
        expect(workflow.minimumContextMegaPixels, equals(88.0));

        controller.setFocusedSelectionRect(
          const Rect.fromLTWH(100, 120, 200, 220),
        );
        controller.setFocusedInpaintEnabled(false);
        controller.setMinimumContextMegaPixels(120);

        workflow = container.read(imageWorkflowControllerProvider);
        expect(workflow.focusedInpaintEnabled, isFalse);
        expect(workflow.minimumContextMegaPixels, equals(120.0));
        expect(workflow.focusedSelectionRect, isNull);
      },
    );

    test(
      'focused inpaint minimum context should clamp to safe lower bound',
      () {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final paramsNotifier = container.read(
          generationParamsNotifierProvider.notifier,
        );

        controller.setMinimumContextMegaPixels(0);

        var workflow = container.read(imageWorkflowControllerProvider);
        expect(workflow.minimumContextMegaPixels, equals(16.0));

        paramsNotifier.setSourceImage(
          _validImageBytes(width: 768, height: 1024),
        );
        controller.applyInpaintEditorResult(
          maskImage: Uint8List.fromList([9, 9, 9]),
          focusedInpaintEnabled: true,
          focusedSelectionRect: const Rect.fromLTWH(120, 160, 240, 320),
          minimumContextMegaPixels: 0,
        );

        workflow = container.read(imageWorkflowControllerProvider);
        expect(workflow.minimumContextMegaPixels, equals(16.0));
      },
    );

    test(
      'focused selection rect should persist and clear with workflow resets',
      () {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final paramsNotifier = container.read(
          generationParamsNotifierProvider.notifier,
        );

        paramsNotifier.setSourceImage(
          _validImageBytes(width: 768, height: 1024),
        );
        controller.setFocusedSelectionRect(
          const Rect.fromLTWH(120, 160, 240, 320),
        );

        var workflow = container.read(imageWorkflowControllerProvider);
        expect(
          workflow.focusedSelectionRect,
          const Rect.fromLTWH(120, 160, 240, 320),
        );

        controller.enterBaseMode(clearMask: true);
        workflow = container.read(imageWorkflowControllerProvider);
        expect(workflow.focusedSelectionRect, isNull);
      },
    );

    test(
      'enterInpaintMode should sync request size to source image dimensions',
      () {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final paramsNotifier = container.read(
          generationParamsNotifierProvider.notifier,
        );

        paramsNotifier.updateSize(832, 1216, persist: false);

        controller.replaceSourceImage(
          _validImageBytes(width: 768, height: 1024),
        );
        controller.enterInpaintMode();
        controller.onMaskChanged(Uint8List.fromList([9, 9, 9]));

        final params = container.read(generationParamsNotifierProvider);

        expect(params.width, equals(768));
        expect(params.height, equals(1024));
        expect(params.action, ImageGenerationAction.infill);
      },
    );

    test(
      'applyInpaintEditorResult should commit focused inpaint state in one coherent transition',
      () {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final paramsNotifier = container.read(
          generationParamsNotifierProvider.notifier,
        );

        paramsNotifier.updateModel(
          ImageModels.animeDiffusionV45Full,
          persist: false,
        );
        paramsNotifier.updateSize(832, 1216, persist: false);
        controller.replaceSourceImage(
          _validImageBytes(width: 1536, height: 2304),
        );
        controller.enterEnhanceMode();

        controller.applyInpaintEditorResult(
          maskImage: Uint8List.fromList([9, 9, 9]),
          focusedInpaintEnabled: true,
          focusedSelectionRect: const Rect.fromLTWH(120, 160, 360, 420),
          minimumContextMegaPixels: 120,
        );

        final workflow = container.read(imageWorkflowControllerProvider);
        final params = container.read(generationParamsNotifierProvider);

        expect(workflow.mode, ImageWorkflowMode.inpaint);
        expect(workflow.isPanelExpanded, isTrue);
        expect(workflow.focusedInpaintEnabled, isTrue);
        expect(
          workflow.focusedSelectionRect,
          const Rect.fromLTWH(120, 160, 360, 420),
        );
        expect(workflow.minimumContextMegaPixels, equals(120.0));
        expect(params.width, equals(896));
        expect(params.height, equals(1344));
        expect(params.maskImage, isNotNull);
        expect(params.isOutpaint, isFalse);
        expect(params.action, ImageGenerationAction.infill);
        expect(
          params.model,
          equals(ImageModels.animeDiffusionV45FullInpainting),
        );
      },
    );

    test(
      'applyInpaintEditorResult can atomically replace source and mask for outpaint',
      () {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );

        controller.replaceSourceImage(
          _validImageBytes(width: 1024, height: 1216),
        );

        final expandedSource = _validImageBytes(width: 1472, height: 1664);
        final expandedMask = _validMaskBytes(width: 1472, height: 1664);

        controller.applyInpaintEditorResult(
          sourceImage: expandedSource,
          sourceWidth: 1472,
          sourceHeight: 1664,
          maskImage: expandedMask,
          focusedInpaintEnabled: true,
          focusedSelectionRect: const Rect.fromLTWH(64, 96, 512, 640),
          minimumContextMegaPixels: 88,
          forceDisableFocusedInpaint: true,
        );

        final workflow = container.read(imageWorkflowControllerProvider);
        final params = container.read(generationParamsNotifierProvider);

        expect(workflow.mode, ImageWorkflowMode.inpaint);
        expect(workflow.sourceWidth, equals(1472));
        expect(workflow.sourceHeight, equals(1664));
        expect(workflow.sourceImageWidth, equals(1472));
        expect(workflow.sourceImageHeight, equals(1664));
        expect(workflow.isOutpaint, isTrue);
        expect(workflow.focusedInpaintEnabled, isFalse);
        expect(workflow.focusedSelectionRect, isNull);
        expect(params.sourceImage, same(expandedSource));
        expect(params.maskImage, same(expandedMask));
        expect(params.width, equals(1472));
        expect(params.height, equals(1664));
        expect(params.isOutpaint, isTrue);
        expect(params.action, ImageGenerationAction.infill);
      },
    );

    test(
      'applyInpaintEditorResult stores working source dimensions separately from request dimensions',
      () {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final workingSource = _validImageBytes(width: 1500, height: 900);
        final workingMask = _validMaskBytes(width: 1500, height: 900);

        controller.applyInpaintEditorResult(
          sourceImage: workingSource,
          sourceWidth: 1500,
          sourceHeight: 900,
          sourceIsOutpaint: false,
          maskImage: workingMask,
          focusedInpaintEnabled: true,
          focusedSelectionRect: const Rect.fromLTWH(120, 160, 900, 500),
          minimumContextMegaPixels: 88,
        );

        final workflow = container.read(imageWorkflowControllerProvider);
        final params = container.read(generationParamsNotifierProvider);

        expect((workflow.sourceWidth, workflow.sourceHeight), (1472, 896));
        expect(
          (workflow.sourceImageWidth, workflow.sourceImageHeight),
          (1500, 900),
        );
        expect(params.sourceImage, same(workingSource));
        expect((params.width, params.height), (1472, 896));
        expect(params.isOutpaint, isFalse);
        expect(workflow.focusedInpaintEnabled, isTrue);
      },
    );

    test(
      'applyInpaintEditorResult preserves an explicit editor compression target',
      () {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final source = _validImageBytes(width: 1344, height: 640);
        final mask = _validMaskBytes(width: 1344, height: 640);

        controller.applyInpaintEditorResult(
          sourceImage: source,
          sourceWidth: 1344,
          sourceHeight: 640,
          sourceIsOutpaint: false,
          useExactSourceDimensions: true,
          maskImage: mask,
          focusedInpaintEnabled: true,
          focusedSelectionRect: const Rect.fromLTWH(128, 64, 640, 320),
          minimumContextMegaPixels: 88,
        );

        final workflow = container.read(imageWorkflowControllerProvider);
        final params = container.read(generationParamsNotifierProvider);
        expect((workflow.sourceWidth, workflow.sourceHeight), (1344, 640));
        expect(
          (workflow.sourceImageWidth, workflow.sourceImageHeight),
          (1344, 640),
        );
        expect((params.width, params.height), (1344, 640));
        expect(params.sourceImage, same(source));
        expect(params.maskImage, same(mask));
        expect(workflow.focusedInpaintEnabled, isTrue);
      },
    );

    test(
      'applyInpaintEditorResult requires dimensions with outpaint source',
      () {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );

        expect(
          () => controller.applyInpaintEditorResult(
            sourceImage: _validImageBytes(width: 1472, height: 1664),
            sourceWidth: 1472,
            maskImage: _validMaskBytes(width: 1472, height: 1664),
            focusedInpaintEnabled: false,
            focusedSelectionRect: null,
            minimumContextMegaPixels: 88,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.message,
              'message',
              'Outpaint source dimensions are required',
            ),
          ),
        );
      },
    );

    test(
      'applyInpaintEditorResult rejects non 64-compatible outpaint source dimensions',
      () {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );

        expect(
          () => controller.applyInpaintEditorResult(
            sourceImage: _validImageBytes(width: 1473, height: 1664),
            sourceWidth: 1473,
            sourceHeight: 1664,
            maskImage: _validMaskBytes(width: 1472, height: 1664),
            focusedInpaintEnabled: false,
            focusedSelectionRect: null,
            minimumContextMegaPixels: 88,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.message,
              'message',
              'Outpaint source dimensions must be 64-compatible',
            ),
          ),
        );
      },
    );

    test(
      'enterInpaintMode should switch v4.5 full to inpainting model and restore base model on exit',
      () {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final paramsNotifier = container.read(
          generationParamsNotifierProvider.notifier,
        );

        paramsNotifier.updateModel(
          ImageModels.animeDiffusionV45Full,
          persist: false,
        );
        controller.replaceSourceImage(
          _validImageBytes(width: 768, height: 1024),
        );

        controller.enterInpaintMode();
        controller.onMaskChanged(Uint8List.fromList([9, 9, 9]));

        var params = container.read(generationParamsNotifierProvider);
        expect(
          params.model,
          equals(ImageModels.animeDiffusionV45FullInpainting),
        );

        controller.enterBaseMode();

        params = container.read(generationParamsNotifierProvider);
        expect(params.model, equals(ImageModels.animeDiffusionV45Full));
      },
    );

    test(
      'clearSourceImage should restore base request state after an inpaint session',
      () {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final paramsNotifier = container.read(
          generationParamsNotifierProvider.notifier,
        );

        paramsNotifier.updateModel(
          ImageModels.animeDiffusionV45Full,
          persist: false,
        );
        paramsNotifier.updateSize(1024, 1536, persist: false);
        controller.replaceSourceImage(
          _validImageBytes(width: 768, height: 1024),
        );

        controller.enterInpaintMode();
        controller.onMaskChanged(Uint8List.fromList([9, 9, 9]));
        controller.clearSourceImage();

        final workflow = container.read(imageWorkflowControllerProvider);
        final params = container.read(generationParamsNotifierProvider);

        expect(workflow.mode, ImageWorkflowMode.base);
        expect(workflow.sourceWidth, isNull);
        expect(workflow.sourceHeight, isNull);
        expect(params.sourceImage, isNull);
        expect(params.maskImage, isNull);
        expect(params.action, ImageGenerationAction.generate);
        expect(params.model, ImageModels.animeDiffusionV45Full);
        expect(params.width, 1024);
        expect(params.height, 1536);
      },
    );

    test(
      'onMaskChanged should keep model and action aligned while toggling inpaint mode',
      () {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final paramsNotifier = container.read(
          generationParamsNotifierProvider.notifier,
        );

        paramsNotifier.updateModel(
          ImageModels.animeDiffusionV4Full,
          persist: false,
        );
        controller.replaceSourceImage(
          _validImageBytes(width: 768, height: 1024),
        );

        controller.enterInpaintMode();

        var params = container.read(generationParamsNotifierProvider);
        expect(params.action, ImageGenerationAction.img2img);
        expect(params.model, ImageModels.animeDiffusionV4Full);

        controller.onMaskChanged(Uint8List.fromList([9, 9, 9]));

        params = container.read(generationParamsNotifierProvider);
        expect(params.action, ImageGenerationAction.infill);
        expect(params.model, ImageModels.animeDiffusionV4FullInpainting);

        controller.onMaskChanged(null);

        params = container.read(generationParamsNotifierProvider);
        expect(params.action, ImageGenerationAction.img2img);
        expect(params.model, ImageModels.animeDiffusionV4Full);
      },
    );

    test(
      'upscale settings should persist comfy model and scale across rebuilds',
      () async {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );

        controller.updateUpscaleComfyScale(1.8);
        controller.updateUpscaleComfyModel('4x-ClearRealityV1.pth');
        await Hive.box(StorageKeys.settingsBox).flush();

        container.dispose();
        container = ProviderContainer();

        final workflow = container.read(imageWorkflowControllerProvider);

        expect(workflow.upscale.comfyScale, equals(1.8));
        expect(workflow.upscale.comfyModel, equals('4x-ClearRealityV1.pth'));
      },
    );

    test(
      'upscale settings should persist comfy module and SeedVR2 tile controls across rebuilds',
      () async {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );

        controller.updateComfyUpscaleModule(ComfyUpscaleModule.seedvr2);
        controller.updateSeedvr2VaeTileSize(768);
        controller.updateSeedvr2Tiled(true);
        controller.updateSeedvr2TileSize(1280);
        await Hive.box(StorageKeys.settingsBox).flush();

        container.dispose();
        container = ProviderContainer();

        final workflow = container.read(imageWorkflowControllerProvider);

        expect(
          workflow.upscale.comfyModule,
          equals(ComfyUpscaleModule.seedvr2),
        );
        expect(workflow.upscale.seedvr2VaeTileSize, equals(768));
        expect(workflow.upscale.seedvr2Tiled, isTrue);
        expect(workflow.upscale.seedvr2TileSize, equals(1280));
      },
    );

    test('build should default upscale settings to safe local defaults', () {
      final workflow = container.read(imageWorkflowControllerProvider);

      expect(workflow.upscale.backend, equals(UpscaleBackend.comfyui));
      expect(workflow.upscale.comfyModule, equals(ComfyUpscaleModule.seedvr2));
      expect(workflow.upscale.comfyScale, equals(1.5));
      expect(
        workflow.upscale.comfyModel,
        equals(UpscaleWorkflowSettings.defaultComfyModel),
      );
    });

    test(
      'workflow settings should persist enhance settings and upscale backend across rebuilds',
      () async {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final paramsNotifier = container.read(
          generationParamsNotifierProvider.notifier,
        );

        paramsNotifier.setSourceImage(
          _validImageBytes(width: 768, height: 1024),
        );
        controller.setSourceImageDimensions(768, 1024);
        controller.enterEnhanceMode();
        controller.updateEnhanceMagnitude(0.72);
        controller.toggleEnhanceIndividualSettings(true);
        controller.updateEnhanceUpscaleFactor(1.5);
        controller.updateEnhanceIndividualSettings(strength: 0.38, noise: 0.14);
        controller.updateUpscaleBackend(UpscaleBackend.novelai);
        await Hive.box(StorageKeys.settingsBox).flush();

        container.dispose();
        container = ProviderContainer();

        final workflow = container.read(imageWorkflowControllerProvider);

        expect(workflow.enhance.magnitude, equals(0.72));
        expect(workflow.enhance.showIndividualSettings, isTrue);
        expect(workflow.enhance.upscaleFactor, equals(1.5));
        expect(workflow.enhance.strength, equals(0.38));
        expect(workflow.enhance.noise, equals(0.14));
        expect(workflow.upscale.backend, equals(UpscaleBackend.novelai));
      },
    );

    test(
      'upscale settings should clamp persisted comfy scale to safe max',
      () async {
        await Hive.box(
          StorageKeys.settingsBox,
        ).put(StorageKeys.comfyuiUpscaleScale, 3.4);

        container.dispose();
        container = ProviderContainer();

        final workflow = container.read(imageWorkflowControllerProvider);

        expect(workflow.upscale.comfyScale, equals(2.0));
      },
    );

    test('selectPreferredUpscaleModel should prefer 3b q4 variants', () {
      expect(
        selectPreferredUpscaleModel(const [
          'seedvr2_ema_7b_fp16.safetensors',
          'seedvr2_ema_3b_q4_k_m.safetensors',
        ]),
        equals('seedvr2_ema_3b_q4_k_m.safetensors'),
      );
    });

    test(
      'clearSourceImage should preserve workflow setting preferences',
      () async {
        final controller = container.read(
          imageWorkflowControllerProvider.notifier,
        );

        controller.updateUpscaleBackend(UpscaleBackend.novelai);
        controller.updateUpscaleComfyScale(1.7);
        controller.updateUpscaleComfyModel('seedvr2_ema_3b_q4_k_m.safetensors');
        controller.updateEnhanceMagnitude(0.66);
        controller.toggleEnhanceIndividualSettings(true);
        controller.updateEnhanceIndividualSettings(strength: 0.41, noise: 0.12);
        controller.replaceSourceImage(
          _validImageBytes(width: 768, height: 1024),
        );

        controller.clearSourceImage();

        final workflow = container.read(imageWorkflowControllerProvider);
        expect(workflow.upscale.backend, equals(UpscaleBackend.novelai));
        expect(workflow.upscale.comfyScale, equals(1.7));
        expect(
          workflow.upscale.comfyModel,
          equals('seedvr2_ema_3b_q4_k_m.safetensors'),
        );
        expect(workflow.enhance.magnitude, equals(0.66));
        expect(workflow.enhance.showIndividualSettings, isTrue);
        expect(workflow.enhance.strength, equals(0.41));
        expect(workflow.enhance.noise, equals(0.12));
      },
    );
  });
}

Uint8List _validImageBytes({required int width, required int height}) {
  return Uint8List.fromList(
    img.encodePng(img.Image(width: width, height: height)),
  );
}

Uint8List _validMaskBytes({required int width, required int height}) {
  return Uint8List.fromList(
    img.encodePng(img.Image(width: width, height: height)),
  );
}
