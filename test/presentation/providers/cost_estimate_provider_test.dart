import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/services/anlas_calculator.dart';
import 'package:nai_launcher/core/utils/focused_inpaint_utils.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/cost_estimate_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

void main() {
  late Directory hiveTempDir;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    hiveTempDir = await Directory.systemTemp.createTemp(
      'nai_launcher_cost_estimate_hive_',
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

  group('estimatedCostProvider', () {
    late ProviderContainer container;

    setUp(() async {
      await Hive.box(StorageKeys.settingsBox).clear();
      await Hive.box(StorageKeys.historyBox).clear();
      container = ProviderContainer(
        overrides: [authNotifierProvider.overrideWith(_TestAuthNotifier.new)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should return zero for comfyui local upscale', () {
      final workflow = container.read(imageWorkflowControllerProvider.notifier);
      final subscription = container.read(
        subscriptionNotifierProvider.notifier,
      );

      subscription.state = const SubscriptionState.loaded(
        UserSubscription(tier: 1),
      );

      workflow.replaceSourceImage(_buildPng(width: 768, height: 1024));
      workflow.enterUpscaleMode();
      workflow.updateUpscaleBackend(UpscaleBackend.comfyui);

      expect(container.read(estimatedCostProvider), equals(0));
    });

    test(
      'should estimate novelai upscale from upscale request instead of img2img',
      () {
        final workflow = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final subscription = container.read(
          subscriptionNotifierProvider.notifier,
        );

        subscription.state = const SubscriptionState.loaded(
          UserSubscription(tier: 1),
        );

        workflow.replaceSourceImage(_buildPng(width: 512, height: 768));
        workflow.enterUpscaleMode();
        workflow.updateUpscaleBackend(UpscaleBackend.novelai);

        expect(container.read(estimatedCostProvider), equals(2));
      },
    );

    test('should charge Opus img2img requests with redraw strength', () {
      final subscription = container.read(
        subscriptionNotifierProvider.notifier,
      );
      final paramsNotifier = container.read(
        generationParamsNotifierProvider.notifier,
      );

      subscription.state = const SubscriptionState.loaded(
        UserSubscription(tier: AnlasCalculator.opusTier, active: true),
      );
      paramsNotifier.updateAction(ImageGenerationAction.img2img);
      paramsNotifier.setSourceImage(_buildPng(width: 1024, height: 1024));
      paramsNotifier.updateSize(1024, 1024);
      paramsNotifier.updateStrength(0.5);

      final params = container.read(generationParamsNotifierProvider);
      final expected = AnlasCalculator.calculateRequestCost(
        width: 1024,
        height: 1024,
        steps: params.steps,
        batchCount: params.nSamples,
        batchSize: container.read(imagesPerRequestProvider),
        smea: params.effectiveSmea,
        smeaDyn: params.effectiveSmeaDyn,
        model: params.model,
        subscriptionTier: AnlasCalculator.opusTier,
        hasBaseImage: true,
        strength: 0.5,
      );

      expect(expected, greaterThan(0));
      expect(container.read(estimatedCostProvider), expected);
    });

    test(
      'should estimate focused inpaint from actual cropped request size',
      () {
        final workflow = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final subscription = container.read(
          subscriptionNotifierProvider.notifier,
        );

        subscription.state = const SubscriptionState.loaded(
          UserSubscription(tier: 1),
        );

        final source = _buildPng(width: 2048, height: 2048);
        final mask = _buildMask(
          width: 2048,
          height: 2048,
          rect: const Rect.fromLTWH(900, 900, 160, 160),
        );

        workflow.replaceSourceImage(
          source,
          sourceWidth: 2048,
          sourceHeight: 2048,
          autoAdapt: false,
        );
        workflow.enterInpaintMode();
        workflow.setFocusedInpaintEnabled(true);
        workflow.setMinimumContextMegaPixels(1.0);
        workflow.setFocusedSelectionRect(
          const Rect.fromLTWH(900, 900, 160, 160),
        );
        workflow.onMaskChanged(mask);
        container
            .read(generationParamsNotifierProvider.notifier)
            .updateInpaintStrength(0.5);

        final params = container.read(generationParamsNotifierProvider);
        final focusedRequest = FocusedInpaintUtils.prepareRequest(
          sourceImage: source,
          maskImage: mask,
          focusedSelectionRect: const Rect.fromLTWH(900, 900, 160, 160),
          minContextMegaPixels: 1.0,
        );

        expect(focusedRequest, isNotNull);

        final expected = AnlasCalculator.calculateRequestCost(
          width: focusedRequest!.targetWidth,
          height: focusedRequest.targetHeight,
          steps: params.steps,
          batchCount: params.nSamples,
          batchSize: 1,
          model: params.model,
          subscriptionTier:
              container.read(subscriptionNotifierProvider).subscription?.tier ??
              0,
          smea: params.effectiveSmea,
          smeaDyn: params.effectiveSmeaDyn,
          strength: params.inpaintStrength,
          extraPerSampleCost: 0,
        );

        expect(container.read(estimatedCostProvider), equals(expected));
      },
    );

    test(
      'should estimate mask-only focused inpaint from lightweight mask bounds',
      () {
        final workflow = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final subscription = container.read(
          subscriptionNotifierProvider.notifier,
        );

        subscription.state = const SubscriptionState.loaded(
          UserSubscription(tier: 1),
        );

        final source = _buildPng(width: 2048, height: 2048);
        final mask = _buildMask(
          width: 2048,
          height: 2048,
          rect: const Rect.fromLTWH(700, 800, 220, 180),
        );

        workflow.replaceSourceImage(
          source,
          sourceWidth: 2048,
          sourceHeight: 2048,
          autoAdapt: false,
        );
        workflow.enterInpaintMode();
        workflow.setFocusedInpaintEnabled(true);
        workflow.setMinimumContextMegaPixels(1.0);
        workflow.onMaskChanged(mask);

        final params = container.read(generationParamsNotifierProvider);
        final focusedRequest = FocusedInpaintUtils.prepareRequest(
          sourceImage: source,
          maskImage: mask,
          minContextMegaPixels: 1.0,
        );

        expect(focusedRequest, isNotNull);
        final maskGeometry = container.read(
          focusedInpaintMaskRequestSizeProvider,
        );
        expect(maskGeometry, isNotNull);
        expect(maskGeometry!.requestWidth, focusedRequest!.targetWidth);
        expect(maskGeometry.requestHeight, focusedRequest.targetHeight);

        final expected = AnlasCalculator.calculateRequestCost(
          width: focusedRequest.targetWidth,
          height: focusedRequest.targetHeight,
          steps: params.steps,
          batchCount: params.nSamples,
          batchSize: 1,
          model: params.model,
          subscriptionTier:
              container.read(subscriptionNotifierProvider).subscription?.tier ??
              0,
          smea: params.effectiveSmea,
          smeaDyn: params.effectiveSmeaDyn,
          strength: 1.0,
          extraPerSampleCost: 0,
        );

        expect(container.read(estimatedCostProvider), equals(expected));
      },
    );

    test('should use regular inpaint strength for the base price', () {
      final subscription = container.read(
        subscriptionNotifierProvider.notifier,
      );
      subscription.state = const SubscriptionState.loaded(
        UserSubscription(tier: 1),
      );

      final params = container.read(generationParamsNotifierProvider.notifier);
      params.updateSize(1024, 1024, persist: false);
      params.updateSteps(28);
      params.updateSmea(false);
      params.updateSmeaDyn(false);
      params.updateAction(ImageGenerationAction.infill);
      params.setSourceImage(_buildPng(width: 1024, height: 1024));
      params.setMaskImage(
        _buildMask(
          width: 1024,
          height: 1024,
          rect: const Rect.fromLTWH(256, 256, 512, 512),
        ),
      );
      params.updateInpaintStrength(0.5);

      expect(container.read(estimatedCostProvider), 10);
    });

    test(
      'should price the same auto-SMEA flags sent by the request builder',
      () {
        final subscription = container.read(
          subscriptionNotifierProvider.notifier,
        );
        subscription.state = const SubscriptionState.loaded(
          UserSubscription(tier: 1),
        );

        final params = container.read(
          generationParamsNotifierProvider.notifier,
        );
        params.updateModel('nai-diffusion-3', persist: false);
        params.updateSize(1536, 1536, persist: false);
        params.updateSteps(28);
        params.updateSmeaAuto(true);

        expect(container.read(estimatedCostProvider), 54);
      },
    );

    test('should include only enabled uncached Vibe encoding fees', () {
      final subscription = container.read(
        subscriptionNotifierProvider.notifier,
      );
      subscription.state = const SubscriptionState.loaded(
        UserSubscription(tier: 3, active: true),
      );

      final rawImage = Uint8List.fromList([1, 2, 3]);
      final params = container.read(generationParamsNotifierProvider.notifier);
      params.updateSize(512, 768, persist: false);
      params.updateSteps(28);
      params.setVibeReferences([
        VibeReference(
          displayName: 'enabled',
          vibeEncoding: '',
          rawImageData: rawImage,
          sourceType: VibeSourceType.rawImage,
        ),
        VibeReference(
          displayName: 'disabled',
          vibeEncoding: '',
          rawImageData: rawImage,
          sourceType: VibeSourceType.rawImage,
          enabled: false,
        ),
      ]);

      expect(container.read(estimatedCostProvider), 2);
    });

    test('should include the per-request fee after four Vibes', () {
      final subscription = container.read(
        subscriptionNotifierProvider.notifier,
      );
      subscription.state = const SubscriptionState.loaded(
        UserSubscription(tier: 3, active: true),
      );

      final params = container.read(generationParamsNotifierProvider.notifier);
      params.updateSize(512, 768, persist: false);
      params.updateSteps(28);
      params.setVibeReferences(
        List.generate(
          5,
          (index) => VibeReference(
            displayName: 'vibe-$index',
            vibeEncoding: 'encoded-$index',
            sourceType: VibeSourceType.naiv4vibe,
          ),
        ),
      );

      expect(container.read(estimatedCostProvider), 2);
    });

    test(
      'focused estimate uses source byte dimensions instead of import size',
      () {
        final workflow = container.read(
          imageWorkflowControllerProvider.notifier,
        );
        final subscription = container.read(
          subscriptionNotifierProvider.notifier,
        );
        subscription.state = const SubscriptionState.loaded(
          UserSubscription(tier: 1),
        );

        final source = _buildPng(width: 3000, height: 1000);
        final mask = _buildMask(
          width: 3000,
          height: 1000,
          rect: const Rect.fromLTWH(2500, 200, 400, 400),
        );
        workflow.replaceSourceImage(source);
        workflow.enterInpaintMode();
        workflow.setFocusedInpaintEnabled(true);
        workflow.setFocusedSelectionRect(
          const Rect.fromLTWH(2500, 200, 400, 400),
        );
        workflow.onMaskChanged(mask);

        final state = container.read(imageWorkflowControllerProvider);
        final params = container.read(generationParamsNotifierProvider);
        expect((state.sourceImageWidth, state.sourceImageHeight), (3000, 1000));
        expect((state.sourceWidth, state.sourceHeight), isNot((3000, 1000)));

        final geometry = FocusedInpaintUtils.resolveGeometryForSelection(
          sourceWidth: 3000,
          sourceHeight: 1000,
          selectionRect: const Rect.fromLTWH(2500, 200, 400, 400),
          minContextMegaPixels: state.minimumContextMegaPixels,
        )!;
        final expected = AnlasCalculator.calculateRequestCost(
          width: geometry.requestWidth,
          height: geometry.requestHeight,
          steps: params.steps,
          batchCount: params.nSamples,
          batchSize: 1,
          model: params.model,
          subscriptionTier:
              container.read(subscriptionNotifierProvider).subscription?.tier ??
              0,
          smea: params.effectiveSmea,
          smeaDyn: params.effectiveSmeaDyn,
          strength: 1.0,
          extraPerSampleCost: 0,
        );

        expect(container.read(estimatedCostProvider), expected);
      },
    );
  });
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(status: AuthStatus.unauthenticated);
  }
}

Uint8List _buildPng({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _buildMask({
  required int width,
  required int height,
  required Rect rect,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 255));
  for (var y = rect.top.toInt(); y < rect.bottom.toInt(); y++) {
    for (var x = rect.left.toInt(); x < rect.right.toInt(); x++) {
      image.setPixelRgba(x, y, 255, 255, 255, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}
