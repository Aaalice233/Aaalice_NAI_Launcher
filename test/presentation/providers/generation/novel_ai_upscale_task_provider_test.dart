import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/novel_ai_upscale_task_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

void main() {
  test(
    'continues and adopts the result after UI listeners are removed',
    () async {
      final apiService = _BlockingEnhancementApiService();
      final container = _createContainer(apiService);
      addTearDown(container.dispose);
      Uint8List? adopted;
      bool? runningWhileAdopting;

      final subscription = container.listen(
        novelAiUpscaleTaskProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final task = container
          .read(novelAiUpscaleTaskProvider.notifier)
          .execute(
            sourceImage: Uint8List.fromList([1, 2, 3]),
            adopt: (result) async {
              adopted = result;
              runningWhileAdopting = container
                  .read(novelAiUpscaleTaskProvider)
                  .isRunning;
            },
          );

      expect(container.read(novelAiUpscaleTaskProvider).isRunning, isTrue);
      expect(apiService.requestedScale, 2);

      subscription.close();
      apiService.complete(Uint8List.fromList([9, 8, 7]));
      final outcome = await task;

      final subscriptionNotifier =
          container.read(subscriptionNotifierProvider.notifier)
              as _TestSubscriptionNotifier;
      expect(
        outcome,
        isA<NovelAiUpscaleCompleted>().having(
          (completed) => completed.bytes,
          'bytes',
          Uint8List.fromList([9, 8, 7]),
        ),
      );
      expect(adopted, Uint8List.fromList([9, 8, 7]));
      expect(runningWhileAdopting, isTrue);
      expect(
        container.read(novelAiUpscaleTaskProvider).status,
        NovelAiUpscaleTaskStatus.completed,
      );
      expect(subscriptionNotifier.refreshScheduleCount, 1);
    },
  );

  for (final status in [AuthStatus.unauthenticated, AuthStatus.loading]) {
    test('blocks NovelAI upscale while auth is $status', () async {
      final apiService = _BlockingEnhancementApiService();
      final container = _createContainer(apiService, authStatus: status);
      addTearDown(container.dispose);
      const initialState = NovelAiUpscaleTaskState();
      var adoptCalls = 0;

      final outcome = await container
          .read(novelAiUpscaleTaskProvider.notifier)
          .execute(
            sourceImage: Uint8List.fromList([1, 2, 3]),
            adopt: (_) async => adoptCalls++,
          );

      final state = container.read(novelAiUpscaleTaskProvider);
      expect(
        outcome,
        isA<NovelAiUpscaleSkipped>().having(
          (skipped) => skipped.reason,
          'reason',
          NovelAiUpscaleSkipReason.unauthenticated,
        ),
      );
      expect(state.status, initialState.status);
      expect(state.errorMessage, initialState.errorMessage);
      expect(state.isRunning, isFalse);
      expect(apiService.requestedScale, isNull);
      expect(adoptCalls, 0);
      expect(
        container.read(authPromptRequestProvider)?.reason,
        AuthPromptReason.novelAiUpscale,
      );
    });
  }

  test('a second request while one is running is skipped as busy', () async {
    final apiService = _BlockingEnhancementApiService();
    final container = _createContainer(apiService);
    addTearDown(container.dispose);
    final notifier = container.read(novelAiUpscaleTaskProvider.notifier);
    final first = notifier.execute(
      sourceImage: Uint8List.fromList([1]),
      adopt: (_) async {},
    );

    final second = await notifier.execute(
      sourceImage: Uint8List.fromList([2]),
      adopt: (_) async => fail('a skipped request must not adopt'),
    );

    expect(
      second,
      isA<NovelAiUpscaleSkipped>().having(
        (skipped) => skipped.reason,
        'reason',
        NovelAiUpscaleSkipReason.busy,
      ),
    );
    expect(apiService.requestCount, 1);
    apiService.complete(Uint8List.fromList([9]));
    expect(await first, isA<NovelAiUpscaleCompleted>());
  });

  test('retains a failure state after UI listeners are removed', () async {
    final apiService = _BlockingEnhancementApiService();
    final container = _createContainer(apiService);
    addTearDown(container.dispose);
    var adoptCalls = 0;

    final subscription = container.listen(
      novelAiUpscaleTaskProvider,
      (_, _) {},
      fireImmediately: true,
    );
    final task = container
        .read(novelAiUpscaleTaskProvider.notifier)
        .execute(
          sourceImage: Uint8List.fromList([1, 2, 3]),
          adopt: (_) async => adoptCalls++,
        );

    subscription.close();
    apiService.fail(StateError('upscale failed'));
    final outcome = await task;

    final state = container.read(novelAiUpscaleTaskProvider);
    expect(
      outcome,
      isA<NovelAiUpscaleFailed>().having(
        (failed) => failed.message,
        'message',
        contains('upscale failed'),
      ),
    );
    expect(state.status, NovelAiUpscaleTaskStatus.failed);
    expect(state.errorMessage, contains('upscale failed'));
    expect(adoptCalls, 0);
  });

  test('a result that cannot be registered is a failure', () async {
    final apiService = _BlockingEnhancementApiService();
    final container = _createContainer(apiService);
    addTearDown(container.dispose);

    final task = container
        .read(novelAiUpscaleTaskProvider.notifier)
        .execute(
          sourceImage: Uint8List.fromList([1, 2, 3]),
          adopt: (_) async => throw StateError('history unavailable'),
        );
    apiService.complete(Uint8List.fromList([9, 8, 7]));

    expect(await task, isA<NovelAiUpscaleFailed>());
    expect(
      container.read(novelAiUpscaleTaskProvider).status,
      NovelAiUpscaleTaskStatus.failed,
    );
  });
}

ProviderContainer _createContainer(
  _BlockingEnhancementApiService apiService, {
  AuthStatus authStatus = AuthStatus.authenticated,
}) {
  return ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(() => _TestAuthNotifier(authStatus)),
      naiImageEnhancementApiServiceProvider.overrideWithValue(apiService),
      subscriptionNotifierProvider.overrideWith(_TestSubscriptionNotifier.new),
    ],
  );
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this.authStatus);

  final AuthStatus authStatus;

  @override
  AuthState build() => AuthState(status: authStatus);
}

class _BlockingEnhancementApiService extends NAIImageEnhancementApiService {
  _BlockingEnhancementApiService() : super(Dio());

  final Completer<Uint8List> _completer = Completer<Uint8List>();
  int? requestedScale;
  int requestCount = 0;

  @override
  Future<Uint8List> upscaleImage(
    Uint8List image, {
    int scale = 2,
    void Function(int, int)? onProgress,
  }) {
    requestCount++;
    requestedScale = scale;
    return _completer.future;
  }

  void complete(Uint8List bytes) => _completer.complete(bytes);

  void fail(Object error) => _completer.completeError(error);
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
