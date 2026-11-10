import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_error_classifier.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/notification_settings_provider.dart';

import '../../../helpers/image_generation_test_environment.dart';

void main() {
  setUpImageGenerationTestEnvironment();

  late MockNAIImageGenerationApiService api;

  setUp(() {
    api = MockNAIImageGenerationApiService();
    when(
      () => api.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
        focusedContextCrop: any(named: 'focusedContextCrop'),
        cancellationLease: null,
      ),
    ).thenAnswer((_) => const Stream<ImageStreamChunk>.empty());
    when(() => api.cancelGeneration(any())).thenReturn(null);
  });

  void answerFallback(List<Uint8List> images, Map<int, String> encodings) {
    when(
      () => api.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
        focusedContextCrop: any(named: 'focusedContextCrop'),
        cancellationLease: null,
      ),
    ).thenAnswer((_) async => (images, encodings));
  }

  Future<ProviderContainer> buildContainer({
    List<Override> overrides = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(AuthenticatedAuthNotifier.new),
        naiImageGenerationApiServiceProvider.overrideWithValue(api),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationSettingsNotifierProvider.notifier)
        .setSoundEnabled(false);
    return container;
  }

  ImageParams paramsOf(ProviderContainer container) => container
      .read(generationParamsNotifierProvider)
      .copyWith(prompt: '1girl', width: 512, height: 768, nSamples: 1);

  test('a run that throws while generating ends as failed and frees the '
      'notifier', () async {
    answerFallback([_png(512, 768)], {0: 'encoded vibe'});
    final container = await buildContainer(
      overrides: [
        generationParamsNotifierProvider.overrideWith(
          _ThrowingVibeParamsNotifier.new,
        ),
      ],
    );
    final notifier = container.read(imageGenerationNotifierProvider.notifier);

    await notifier.generate(paramsOf(container));

    final state = container.read(imageGenerationNotifierProvider);
    expect(state.status, GenerationStatus.error);
    expect(state.errorMessage, generationInternalErrorCode);
    expect(state.isBusy, isFalse);
  });
}

class _ThrowingVibeParamsNotifier extends GenerationParamsNotifier {
  @override
  void updateVibeReference(
    int index, {
    double? strength,
    double? infoExtracted,
    String? vibeEncoding,
    bool? enabled,
  }) => throw StateError('reducer bug');
}

Uint8List _png(int width, int height) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));
