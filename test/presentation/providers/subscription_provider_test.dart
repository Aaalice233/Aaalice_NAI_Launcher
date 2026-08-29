import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/network/critical_network_activity.dart';
import 'package:nai_launcher/data/datasources/remote/nai_user_info_api_service.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

class _MockNAIUserInfoApiService extends Mock
    implements NAIUserInfoApiService {}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(
      status: AuthStatus.authenticated,
      accountId: 'test-account',
    );
  }

  void signOutForTest() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void switchAccountForTest() {
    state = const AuthState(
      status: AuthStatus.authenticated,
      accountId: 'other-account',
    );
  }

  void updateSessionMetadataForTest() {
    state = state.copyWith(displayName: 'Updated');
  }
}

class _HydratedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(
      status: AuthStatus.authenticated,
      accountId: 'test-account',
      subscriptionInfo: {
        'tier': 3,
        'active': true,
        'trainingStepsLeft': {
          'fixedTrainingStepsLeft': 100,
          'purchasedTrainingSteps': 0,
        },
      },
    );
  }
}

class _TestableSubscriptionNotifier extends SubscriptionNotifier {
  @override
  SubscriptionState build() {
    ref.keepAlive();
    return const SubscriptionState.loaded(
      UserSubscription(
        tier: 3,
        active: true,
        trainingStepsLeft: TrainingStepsInfo(fixedTrainingStepsLeft: 100),
      ),
    );
  }
}

void main() {
  test('initial subscription HTTP fetch waits for critical activity', () async {
    final apiService = _MockNAIUserInfoApiService();
    when(
      () => apiService.getUserSubscription(
        receiveTimeout: any(named: 'receiveTimeout'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => _subscriptionJson(balance: 73));
    final activity = CriticalNetworkActivityCoordinator.instance;
    final lease = activity.acquire(CriticalNetworkActivityType.imageGeneration);
    addTearDown(lease.release);

    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        naiUserInfoApiServiceProvider.overrideWithValue(apiService),
      ],
    );
    addTearDown(container.dispose);
    container.read(subscriptionNotifierProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    verifyNever(
      () => apiService.getUserSubscription(
        receiveTimeout: any(named: 'receiveTimeout'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );

    lease.release();
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (container.read(subscriptionNotifierProvider).balance == 73) break;
    }
    expect(container.read(subscriptionNotifierProvider).balance, 73);
    verify(
      () => apiService.getUserSubscription(
        receiveTimeout: any(named: 'receiveTimeout'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
  });

  test(
    'refresh queued during an in-flight refresh fetches the latest balance',
    () async {
      final apiService = _MockNAIUserInfoApiService();
      final firstResponse = Completer<Map<String, dynamic>>();
      var requestCount = 0;

      when(
        () => apiService.getUserSubscription(
          receiveTimeout: any(named: 'receiveTimeout'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) {
        requestCount += 1;
        if (requestCount == 1) {
          return firstResponse.future;
        }
        return Future.value(_subscriptionJson(balance: 80));
      });

      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
          naiUserInfoApiServiceProvider.overrideWithValue(apiService),
          subscriptionNotifierProvider.overrideWith(
            _TestableSubscriptionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(subscriptionNotifierProvider.notifier);
      final firstRefresh = notifier.refreshBalance();
      await Future<void>.delayed(Duration.zero);
      final queuedRefresh = notifier.refreshBalance();

      firstResponse.complete(_subscriptionJson(balance: 90));

      expect(await firstRefresh, isTrue);
      expect(await queuedRefresh, isTrue);
      expect(requestCount, 2);
      expect(container.read(subscriptionNotifierProvider).balance, 80);
    },
  );

  test(
    'critical activity cancels an in-flight balance request and resumes once',
    () async {
      final apiService = _MockNAIUserInfoApiService();
      final firstResponse = Completer<Map<String, dynamic>>();
      CancelToken? firstCancelToken;
      var requestCount = 0;
      when(
        () => apiService.getUserSubscription(
          receiveTimeout: any(named: 'receiveTimeout'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) {
        requestCount += 1;
        final cancelToken =
            invocation.namedArguments[#cancelToken] as CancelToken;
        if (requestCount == 1) {
          firstCancelToken = cancelToken;
          cancelToken.whenCancel.then((error) {
            if (!firstResponse.isCompleted) firstResponse.completeError(error);
          });
          return firstResponse.future;
        }
        return Future.value(_subscriptionJson(balance: 77));
      });

      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(_HydratedAuthNotifier.new),
          naiUserInfoApiServiceProvider.overrideWithValue(apiService),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(subscriptionNotifierProvider).balance, 100);
      for (var i = 0; i < 20 && firstCancelToken == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(firstCancelToken, isNotNull);

      final activity = CriticalNetworkActivityCoordinator.instance;
      final lease = activity.acquire(
        CriticalNetworkActivityType.imageGeneration,
      );
      addTearDown(lease.release);
      expect(firstCancelToken?.isCancelled, isTrue);
      expect(requestCount, 1);

      lease.release();
      for (
        var i = 0;
        i < 20 && container.read(subscriptionNotifierProvider).balance != 77;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(requestCount, 2);
      expect(container.read(subscriptionNotifierProvider).balance, 77);
    },
  );

  test('does not restore a stale balance after sign-out', () async {
    final apiService = _MockNAIUserInfoApiService();
    final response = Completer<Map<String, dynamic>>();
    when(
      () => apiService.getUserSubscription(
        receiveTimeout: any(named: 'receiveTimeout'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) => response.future);

    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        naiUserInfoApiServiceProvider.overrideWithValue(apiService),
        subscriptionNotifierProvider.overrideWith(
          _TestableSubscriptionNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final refresh = container
        .read(subscriptionNotifierProvider.notifier)
        .refreshBalance();
    await Future<void>.delayed(Duration.zero);
    final auth =
        container.read(authNotifierProvider.notifier)
            as _AuthenticatedAuthNotifier;
    auth.signOutForTest();
    response.complete(_subscriptionJson(balance: 70));

    expect(await refresh, isFalse);
    expect(container.read(subscriptionNotifierProvider).balance, 100);
  });

  test('does not apply an initial fetch from the previous account', () async {
    final apiService = _MockNAIUserInfoApiService();
    final response = Completer<Map<String, dynamic>>();
    when(
      () => apiService.getUserSubscription(
        receiveTimeout: any(named: 'receiveTimeout'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) => response.future);

    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        naiUserInfoApiServiceProvider.overrideWithValue(apiService),
        subscriptionNotifierProvider.overrideWith(
          _TestableSubscriptionNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final fetch = container
        .read(subscriptionNotifierProvider.notifier)
        .fetchSubscription();
    await Future<void>.delayed(Duration.zero);
    final auth =
        container.read(authNotifierProvider.notifier)
            as _AuthenticatedAuthNotifier;
    auth.switchAccountForTest();
    response.complete(_subscriptionJson(balance: 70));
    await fetch;

    expect(container.read(subscriptionNotifierProvider).balance, 100);
  });

  test(
    'account switch fetches the new balance without waiting for the old request',
    () async {
      final apiService = _MockNAIUserInfoApiService();
      final firstResponse = Completer<Map<String, dynamic>>();
      final secondResponse = Completer<Map<String, dynamic>>();
      var requestCount = 0;
      when(
        () => apiService.getUserSubscription(
          receiveTimeout: any(named: 'receiveTimeout'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) {
        requestCount += 1;
        return requestCount == 1 ? firstResponse.future : secondResponse.future;
      });

      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
          naiUserInfoApiServiceProvider.overrideWithValue(apiService),
        ],
      );
      addTearDown(container.dispose);

      container.read(subscriptionNotifierProvider);
      await Future<void>.delayed(Duration.zero);
      expect(requestCount, 1);

      final auth =
          container.read(authNotifierProvider.notifier)
              as _AuthenticatedAuthNotifier;
      auth.switchAccountForTest();
      container.read(subscriptionNotifierProvider);
      await Future<void>.delayed(Duration.zero);
      expect(requestCount, 2);

      secondResponse.complete(_subscriptionJson(balance: 80));
      await Future<void>.delayed(Duration.zero);
      firstResponse.complete(_subscriptionJson(balance: 90));
      await Future<void>.delayed(Duration.zero);

      expect(container.read(subscriptionNotifierProvider).balance, 80);
    },
  );

  test(
    'same-account auth metadata updates preserve the refreshed balance',
    () async {
      final apiService = _MockNAIUserInfoApiService();
      when(
        () => apiService.getUserSubscription(
          receiveTimeout: any(named: 'receiveTimeout'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => _subscriptionJson(balance: 80));

      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
          naiUserInfoApiServiceProvider.overrideWithValue(apiService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(subscriptionNotifierProvider.notifier);
      await notifier.fetchSubscription();
      expect(container.read(subscriptionNotifierProvider).balance, 80);

      final auth =
          container.read(authNotifierProvider.notifier)
              as _AuthenticatedAuthNotifier;
      auth.updateSessionMetadataForTest();

      expect(container.read(subscriptionNotifierProvider).balance, 80);
    },
  );

  testWidgets('periodic failures use exponential backoff over the HTTP path', (
    tester,
  ) async {
    final apiService = _MockNAIUserInfoApiService();
    var requestCount = 0;
    when(
      () => apiService.getUserSubscription(
        receiveTimeout: any(named: 'receiveTimeout'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {
      requestCount += 1;
      throw DioException(
        requestOptions: RequestOptions(path: '/user/subscription'),
        type: DioExceptionType.receiveTimeout,
      );
    });
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_HydratedAuthNotifier.new),
        naiUserInfoApiServiceProvider.overrideWithValue(apiService),
      ],
    );

    container.read(subscriptionNotifierProvider);
    await tester.pump();
    expect(requestCount, 1);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(requestCount, 2);
    await tester.pump(const Duration(seconds: 59));
    expect(requestCount, 2);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(requestCount, 3);
    expect(container.read(subscriptionNotifierProvider).balance, 100);
    container.dispose();
  });

  testWidgets('backgrounding stops periodic refresh until foreground', (
    tester,
  ) async {
    final apiService = _MockNAIUserInfoApiService();
    var requestCount = 0;
    when(
      () => apiService.getUserSubscription(
        receiveTimeout: any(named: 'receiveTimeout'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {
      requestCount += 1;
      return _subscriptionJson(balance: 90 - requestCount);
    });
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_HydratedAuthNotifier.new),
        naiUserInfoApiServiceProvider.overrideWithValue(apiService),
      ],
    );
    final notifier = container.read(subscriptionNotifierProvider.notifier);
    await tester.pump();
    expect(requestCount, 1);

    notifier.setAppForeground(false);
    await tester.pump(const Duration(minutes: 5));
    expect(requestCount, 1);

    notifier.setAppForeground(true);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(requestCount, 2);
    container.dispose();
  });

  test('post-billing refresh waits briefly and debounces bursts', () async {
    final apiService = _MockNAIUserInfoApiService();
    var requestCount = 0;
    when(
      () => apiService.getUserSubscription(
        receiveTimeout: any(named: 'receiveTimeout'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {
      requestCount += 1;
      return _subscriptionJson(balance: 70);
    });

    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        naiUserInfoApiServiceProvider.overrideWithValue(apiService),
        subscriptionNotifierProvider.overrideWith(
          _TestableSubscriptionNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(subscriptionNotifierProvider.notifier);
    notifier.schedulePostBillingRefresh(
      delay: const Duration(milliseconds: 10),
    );
    notifier.schedulePostBillingRefresh(
      delay: const Duration(milliseconds: 10),
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(requestCount, 1);
    expect(container.read(subscriptionNotifierProvider).balance, 70);
  });
}

Map<String, dynamic> _subscriptionJson({required int balance}) {
  return {
    'tier': 3,
    'active': true,
    'trainingStepsLeft': {
      'fixedTrainingStepsLeft': balance,
      'purchasedTrainingSteps': 0,
    },
  };
}
