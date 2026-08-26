import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/presentation/providers/generation/novel_ai_upscale_task_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/image_save_settings_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

void main() {
  test(
    'continues and registers the result after UI listeners are removed',
    () async {
      final apiService = _BlockingEnhancementApiService();
      final container = _createContainer(apiService);
      addTearDown(container.dispose);

      final subscription = container.listen(
        novelAiUpscaleTaskProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final task = container
          .read(novelAiUpscaleTaskProvider.notifier)
          .execute(
            params: const ImageParams(width: 640, height: 832),
            sourceImage: Uint8List.fromList([1, 2, 3]),
          );

      expect(container.read(novelAiUpscaleTaskProvider).isRunning, isTrue);
      expect(apiService.requestedScale, 2);

      subscription.close();
      apiService.complete(Uint8List.fromList([9, 8, 7]));
      await task;

      final state = container.read(novelAiUpscaleTaskProvider);
      final imageGeneration =
          container.read(imageGenerationNotifierProvider.notifier)
              as _RecordingImageGenerationNotifier;
      final subscriptionNotifier =
          container.read(subscriptionNotifierProvider.notifier)
              as _TestSubscriptionNotifier;

      expect(state.status, NovelAiUpscaleTaskStatus.completed);
      expect(imageGeneration.registeredBytes, Uint8List.fromList([9, 8, 7]));
      expect(imageGeneration.registeredParams?.width, 640);
      expect(imageGeneration.saveToLocal, isFalse);
      expect(imageGeneration.replaceCurrentDisplay, isTrue);
      expect(subscriptionNotifier.refreshScheduleCount, 1);
    },
  );

  test('retains a failure state after UI listeners are removed', () async {
    final apiService = _BlockingEnhancementApiService();
    final container = _createContainer(apiService);
    addTearDown(container.dispose);

    final subscription = container.listen(
      novelAiUpscaleTaskProvider,
      (_, _) {},
      fireImmediately: true,
    );
    final task = container
        .read(novelAiUpscaleTaskProvider.notifier)
        .execute(
          params: const ImageParams(),
          sourceImage: Uint8List.fromList([1, 2, 3]),
        );

    subscription.close();
    apiService.fail(StateError('upscale failed'));
    await task;

    final state = container.read(novelAiUpscaleTaskProvider);
    final imageGeneration =
        container.read(imageGenerationNotifierProvider.notifier)
            as _RecordingImageGenerationNotifier;

    expect(state.status, NovelAiUpscaleTaskStatus.failed);
    expect(state.errorMessage, contains('upscale failed'));
    expect(imageGeneration.registeredBytes, isNull);
  });
}

ProviderContainer _createContainer(_BlockingEnhancementApiService apiService) {
  return ProviderContainer(
    overrides: [
      naiImageEnhancementApiServiceProvider.overrideWithValue(apiService),
      imageGenerationNotifierProvider.overrideWith(
        _RecordingImageGenerationNotifier.new,
      ),
      imageSaveSettingsNotifierProvider.overrideWith(
        _TestImageSaveSettingsNotifier.new,
      ),
      subscriptionNotifierProvider.overrideWith(_TestSubscriptionNotifier.new),
    ],
  );
}

class _BlockingEnhancementApiService extends NAIImageEnhancementApiService {
  _BlockingEnhancementApiService() : super(Dio());

  final Completer<Uint8List> _completer = Completer<Uint8List>();
  int? requestedScale;

  @override
  Future<Uint8List> upscaleImage(
    Uint8List image, {
    int scale = 2,
    void Function(int, int)? onProgress,
  }) {
    requestedScale = scale;
    return _completer.future;
  }

  void complete(Uint8List bytes) => _completer.complete(bytes);

  void fail(Object error) => _completer.completeError(error);
}

class _RecordingImageGenerationNotifier extends ImageGenerationNotifier {
  Uint8List? registeredBytes;
  ImageParams? registeredParams;
  bool? saveToLocal;
  bool? replaceCurrentDisplay;

  @override
  ImageGenerationState build() => const ImageGenerationState();

  @override
  Future<String?> registerExternalImage(
    Uint8List imageBytes, {
    required ImageParams params,
    int? width,
    int? height,
    bool saveToLocal = false,
    String? saveDirectoryPath,
    bool syncToGalleryIndex = true,
    bool addToDisplay = false,
    bool replaceCurrentDisplay = false,
    bool embedNaiMetadata = true,
  }) async {
    registeredBytes = imageBytes;
    registeredParams = params;
    this.saveToLocal = saveToLocal;
    this.replaceCurrentDisplay = replaceCurrentDisplay;
    return null;
  }
}

class _TestImageSaveSettingsNotifier extends ImageSaveSettingsNotifier {
  @override
  ImageSaveSettings build() => const ImageSaveSettings(autoSave: false);
}

class _TestSubscriptionNotifier extends SubscriptionNotifier {
  int refreshScheduleCount = 0;

  @override
  SubscriptionState build() => const SubscriptionState.initial();

  @override
  void schedulePostBillingRefresh({
    Duration delay = SubscriptionNotifier.postBillingRefreshDelay,
  }) {
    refreshScheduleCount++;
  }
}
