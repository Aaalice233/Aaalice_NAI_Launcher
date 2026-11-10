import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/data/models/prompt/random_prompt_result.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_error_classifier.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/notification_settings_provider.dart';
import 'package:nai_launcher/presentation/providers/prompt_config_provider.dart';

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
    AuthNotifier Function() auth = AuthenticatedAuthNotifier.new,
    List<Override> overrides = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(auth),
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

    final outcome = await notifier.generate(paramsOf(container));

    final state = container.read(imageGenerationNotifierProvider);
    expect(state.status, GenerationStatus.error);
    expect(state.errorMessage, generationInternalErrorCode);
    expect(outcome, isA<GenerationRunFailed>());
    expect(
      (outcome as GenerationRunFailed).errorMessage,
      generationInternalErrorCode,
    );
    expect(state.isBusy, isFalse);
  });

  group('generate() returns the outcome of its own invocation', () {
    setUp(() => answerFallback(const [], const {}));

    test('a second call while one is submitting reports busy', () async {
      final container = await buildContainer();
      final notifier = container.read(imageGenerationNotifierProvider.notifier);

      final first = notifier.generate(paramsOf(container));
      expect(
        await notifier.generate(paramsOf(container)),
        isA<GenerationBusy>(),
      );
      notifier.cancel();
      await first;
    });

    test('an unauthenticated call reports login required and publishes the '
        'generation login prompt', () async {
      final container = await buildContainer(
        auth: _UnauthenticatedAuthNotifier.new,
      );
      final notifier = container.read(imageGenerationNotifierProvider.notifier);

      expect(
        await notifier.generate(paramsOf(container)),
        isA<GenerationAuthRequired>(),
      );
      expect(
        container.read(authPromptRequestProvider)?.reason,
        AuthPromptReason.imageGeneration,
      );
      expect(container.read(imageGenerationNotifierProvider).isBusy, isFalse);
    });

    test('an invalid resolution is rejected locally with the code written to '
        'the state', () async {
      final container = await buildContainer();
      final notifier = container.read(imageGenerationNotifierProvider.notifier);

      final outcome = await notifier.generate(
        paramsOf(container).copyWith(width: 513),
      );

      final state = container.read(imageGenerationNotifierProvider);
      expect(outcome, isA<GenerationRejected>());
      expect((outcome as GenerationRejected).errorCode, state.errorMessage);
      expect(state.status, GenerationStatus.error);
      expect(
        state.errorMessage,
        startsWith('GENERATION_ERROR_INVALID_RESOLUTION'),
      );
    });

    test('an unsupported random model is rejected locally with the code '
        'written to the state', () async {
      final container = await buildContainer(
        overrides: [
          randomPromptModeProvider.overrideWith(_RandomModeOn.new),
          promptConfigNotifierProvider.overrideWith(
            _UnsupportedModelPromptConfig.new,
          ),
        ],
      );
      final notifier = container.read(imageGenerationNotifierProvider.notifier);

      final outcome = await notifier.generate(paramsOf(container));

      final state = container.read(imageGenerationNotifierProvider);
      expect(outcome, isA<GenerationRejected>());
      expect((outcome as GenerationRejected).errorCode, state.errorMessage);
      expect(
        state.errorMessage,
        startsWith(UnsupportedRandomPromptModelException.errorCode),
      );
    });

    test(
      'an active cooldown reports cooldown without touching the state',
      () async {
        final container = await buildContainer(
          overrides: [
            generationCooldownProvider.overrideWith(_HeldCooldown.new),
          ],
        );
        final notifier = container.read(
          imageGenerationNotifierProvider.notifier,
        );

        expect(
          await notifier.generate(paramsOf(container)),
          isA<GenerationCooldownActive>(),
        );
        final state = container.read(imageGenerationNotifierProvider);
        expect(state.status, GenerationStatus.idle);
        expect(state.isBusy, isFalse);
      },
    );

    test('cancelling during preparation after a completed run reports '
        'cancelled and marks the state cancelled, keeping the last result on '
        'display', () async {
      final container = await buildContainer();
      final notifier = container.read(imageGenerationNotifierProvider.notifier);
      when(
        () => api.generateImageStream(
          any(),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
          cancellationLease: null,
        ),
      ).thenAnswer(
        (_) => Stream.value(ImageStreamChunk.complete(_png(512, 768))),
      );
      expect(
        await notifier.generate(paramsOf(container)),
        isA<GenerationRunCompleted>(),
      );
      final shown = container
          .read(imageGenerationNotifierProvider)
          .displayImages;
      expect(shown, hasLength(1));
      final changes = <GenerationStatus>[];
      final subscription = container.listen<GenerationStatus>(
        imageGenerationNotifierProvider.select((state) => state.status),
        (_, status) => changes.add(status),
      );
      addTearDown(subscription.close);

      final pending = notifier.generate(paramsOf(container));
      notifier.cancel();

      expect(await pending, isA<GenerationCancelledBeforeStart>());
      final state = container.read(imageGenerationNotifierProvider);
      expect(changes, [GenerationStatus.cancelled]);
      expect(state.isBusy, isFalse);
      expect(state.displayImages, shown);
    });

    test(
      'a call cancelled and replaced by a newer call reports superseded',
      () async {
        final container = await buildContainer();
        final notifier = container.read(
          imageGenerationNotifierProvider.notifier,
        );

        final replaced = notifier.generate(paramsOf(container));
        notifier.cancel();
        final newer = notifier.generate(paramsOf(container));

        expect(await replaced, isA<GenerationSuperseded>());
        expect((await newer).enteredGeneration, isTrue);
      },
    );

    test('a call on a disposed notifier reports disposed', () async {
      final container = await buildContainer();
      final notifier = container.read(imageGenerationNotifierProvider.notifier);
      container.dispose();

      expect(
        await notifier.generate(const ImageParams(prompt: '1girl')),
        isA<GenerationDisposed>(),
      );
    });

    test('a completed run reports completed', () async {
      final container = await buildContainer();
      final notifier = container.read(imageGenerationNotifierProvider.notifier);
      answerFallback([_png(512, 768)], const {});

      final outcome = await notifier.generate(paramsOf(container));

      expect(outcome, isA<GenerationRunCompleted>());
      expect(
        container.read(imageGenerationNotifierProvider).status,
        GenerationStatus.completed,
      );
    });

    test('a failed run reports the error written to the state', () async {
      final container = await buildContainer();
      final notifier = container.read(imageGenerationNotifierProvider.notifier);

      final outcome = await notifier.generate(paramsOf(container));

      final state = container.read(imageGenerationNotifierProvider);
      expect(state.status, GenerationStatus.error);
      expect(outcome, isA<GenerationRunFailed>());
      expect((outcome as GenerationRunFailed).errorMessage, state.errorMessage);
    });

    test('a run cancelled while generating reports cancelled', () async {
      final container = await buildContainer();
      final notifier = container.read(imageGenerationNotifierProvider.notifier);
      final stream = StreamController<ImageStreamChunk>();
      addTearDown(stream.close);
      when(
        () => api.generateImageStream(
          any(),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
          cancellationLease: null,
        ),
      ).thenAnswer((_) => stream.stream);

      final pending = notifier.generate(paramsOf(container));
      await pollUntil(
        () => container.read(imageGenerationNotifierProvider).isGenerating,
      );
      notifier.cancel();
      await stream.close();

      expect(await pending, isA<GenerationRunCancelled>());
      expect(
        container.read(imageGenerationNotifierProvider).status,
        GenerationStatus.cancelled,
      );
    });

    test(
      'a preparation that throws rethrows without entering generation',
      () async {
        final container = await buildContainer(
          overrides: [
            randomPromptModeProvider.overrideWith(_RandomModeOn.new),
            promptConfigNotifierProvider.overrideWith(_BrokenPromptConfig.new),
          ],
        );
        final notifier = container.read(
          imageGenerationNotifierProvider.notifier,
        );

        await expectLater(
          notifier.generate(paramsOf(container)),
          throwsA(isA<StateError>()),
        );
        final state = container.read(imageGenerationNotifierProvider);
        expect(state.status, GenerationStatus.idle);
        expect(state.isBusy, isFalse);
      },
    );
  });
}

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _RandomModeOn extends RandomPromptMode {
  @override
  bool build() => true;
}

class _UnsupportedModelPromptConfig extends PromptConfigNotifier {
  @override
  Future<RandomPromptResult> generateRandomPrompt({
    required String model,
    int? seed,
  }) async => throw UnsupportedRandomPromptModelException(model);
}

class _BrokenPromptConfig extends PromptConfigNotifier {
  @override
  Future<RandomPromptResult> generateRandomPrompt({
    required String model,
    int? seed,
  }) async => throw StateError('random preset failed to load');
}

class _HeldCooldown extends GenerationCooldownNotifier {
  @override
  GenerationCooldownState build() =>
      const GenerationCooldownState(remainingSeconds: 5);

  @override
  bool tryStartGeneration() => false;
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
