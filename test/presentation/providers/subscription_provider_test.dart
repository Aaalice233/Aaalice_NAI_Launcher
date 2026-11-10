import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/network/critical_network_activity.dart';
import 'package:nai_launcher/core/services/interactive_work_gate.dart';
import 'package:nai_launcher/data/datasources/remote/nai_user_info_api_service.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
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
  static const _subscriptionInfo = {
    'tier': 3,
    'active': true,
    'trainingStepsLeft': {
      'fixedTrainingStepsLeft': 100,
      'purchasedTrainingSteps': 0,
    },
  };

  @override
  AuthState build() {
    return const AuthState(
      status: AuthStatus.authenticated,
      accountId: 'test-account',
      subscriptionInfo: _subscriptionInfo,
    );
  }

  void updateSessionMetadataForTest() {
    state = state.copyWith(displayName: 'Updated');
  }

  void switchAccountForTest() {
    state = const AuthState(
      status: AuthStatus.authenticated,
      accountId: 'other-account',
      subscriptionInfo: _subscriptionInfo,
    );
  }

  void signOutForTest() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

class _ThirdPartyUnsupportedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(
      status: AuthStatus.authenticated,
      accountId: 'third-party-account',
      subscriptionUnsupported: true,
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
    await _waitForBalance(container, 73);
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
      final firstRequestStarted = Completer<void>();
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
          firstRequestStarted.complete();
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
      unawaited(
        container.read(subscriptionNotifierProvider.notifier).refreshBalance(),
      );
      await firstRequestStarted.future;
      expect(firstCancelToken, isNotNull);

      final activity = CriticalNetworkActivityCoordinator.instance;
      final lease = activity.acquire(
        CriticalNetworkActivityType.imageGeneration,
      );
      addTearDown(lease.release);
      expect(firstCancelToken?.isCancelled, isTrue);
      expect(requestCount, 1);

      lease.release();
      await _waitForBalance(container, 77);
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
    expect(requestCount, 0);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 250));
    expect(requestCount, 1);
    await tester.pump(const Duration(seconds: 59));
    expect(requestCount, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(requestCount, 2);
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
    expect(requestCount, 0);

    notifier.setAppVisible(false);
    await tester.pump(const Duration(minutes: 5));
    expect(requestCount, 0);

    notifier.setAppVisible(true);
    await tester.pump(const Duration(milliseconds: 250));
    expect(requestCount, 1);
    container.dispose();
  });

  testWidgets('a visible window without focus keeps the periodic refresh', (
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
    addTearDown(() {
      InteractiveWorkGate.instance.setWindowFocused(true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    container.read(subscriptionNotifierProvider);
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    InteractiveWorkGate.instance.setWindowFocused(false);
    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 250));

    expect(requestCount, 1);
    expect(container.read(subscriptionNotifierProvider).balance, 89);
    container.dispose();
  });

  testWidgets('a refresh queued behind an animation still runs once focus is '
      'lost', (tester) async {
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
    addTearDown(() {
      InteractiveWorkGate.instance.setWindowFocused(true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    container.read(subscriptionNotifierProvider);
    await tester.pump();
    // 生成时的光晕动画让闸门一直不空闲
    final generationGlow = Ticker((_) {})..start();

    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 2));
    expect(requestCount, 0, reason: 'the refresh is queued behind the glow');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    InteractiveWorkGate.instance.setWindowFocused(false);
    await tester.pump(const Duration(milliseconds: 250));

    expect(requestCount, 1);
    expect(container.read(subscriptionNotifierProvider).balance, 89);
    generationGlow.dispose();
    container.dispose();
  });

  testWidgets('post-billing refresh waits briefly and debounces bursts', (
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
    const delay = Duration(milliseconds: 10);
    notifier.schedulePostBillingRefresh(delay: delay);
    notifier.schedulePostBillingRefresh(delay: delay);

    await tester.pump(delay - const Duration(milliseconds: 1));
    expect(requestCount, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(requestCount, 1);
    expect(container.read(subscriptionNotifierProvider).balance, 70);

    await tester.pump(delay * 3);
    expect(requestCount, 1);
  });

  group('auth session updates', () {
    late _MockNAIUserInfoApiService apiService;
    late List<CancelToken> requests;
    late ProviderContainer container;
    late _HydratedAuthNotifier auth;
    late SubscriptionNotifier notifier;
    Completer<Map<String, dynamic>>? heldResponse;

    const refreshInterval = Duration(seconds: 30);
    const gateSettle = Duration(milliseconds: 250);
    const billingDelay = Duration(milliseconds: 10);

    setUp(() {
      apiService = _MockNAIUserInfoApiService();
      requests = [];
      heldResponse = null;
      when(
        () => apiService.getUserSubscription(
          receiveTimeout: any(named: 'receiveTimeout'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) {
        final cancelToken =
            invocation.namedArguments[#cancelToken] as CancelToken;
        requests.add(cancelToken);
        final held = heldResponse;
        if (held == null) {
          return Future.value(_subscriptionJson(balance: 90 - requests.length));
        }
        heldResponse = null;
        cancelToken.whenCancel.then((error) {
          if (!held.isCompleted) held.completeError(error);
        });
        return held.future;
      });
    });

    Future<void> start(WidgetTester tester) async {
      container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(_HydratedAuthNotifier.new),
          naiUserInfoApiServiceProvider.overrideWithValue(apiService),
        ],
      );
      container.listen(subscriptionNotifierProvider, (_, __) {});
      auth =
          container.read(authNotifierProvider.notifier)
              as _HydratedAuthNotifier;
      notifier = container.read(subscriptionNotifierProvider.notifier);
      await tester.pump();
      expect(container.read(subscriptionNotifierProvider).balance, 100);
    }

    // 计时器检查早于 tearDown，容器必须在用例体内释放
    void testSession(
      String description,
      Future<void> Function(WidgetTester tester) body,
    ) {
      testWidgets(description, (tester) async {
        try {
          await start(tester);
          await body(tester);
        } finally {
          container.dispose();
        }
      });
    }

    Future<void> applyAuthChange(
      WidgetTester tester,
      void Function() change,
    ) async {
      change();
      container.read(subscriptionNotifierProvider);
      // 不带时长的 pump 不推进计时器，Riverpod 排的零延迟刷新任务要靠它跑掉
      await tester.pump(Duration.zero);
    }

    Future<void> waitOneRefreshInterval(WidgetTester tester) async {
      await tester.pump(refreshInterval);
      await tester.pump(gateSettle);
    }

    testSession('a same-account update keeps a single periodic refresh', (
      tester,
    ) async {
      await applyAuthChange(tester, () => auth.updateSessionMetadataForTest());

      await waitOneRefreshInterval(tester);
      expect(requests, hasLength(1));
      await waitOneRefreshInterval(tester);
      expect(requests, hasLength(2));
      expect(container.read(subscriptionNotifierProvider).balance, 88);
    });

    testSession('a same-account update keeps a scheduled post-billing '
        'refresh', (tester) async {
      notifier.schedulePostBillingRefresh(delay: billingDelay);
      await applyAuthChange(tester, () => auth.updateSessionMetadataForTest());

      await tester.pump(billingDelay);
      await tester.pump();
      expect(requests, hasLength(1));
      expect(container.read(subscriptionNotifierProvider).balance, 89);
    });

    testSession('a same-account update lets an in-flight refresh land and '
        'keeps the cadence', (tester) async {
      final held = heldResponse = Completer<Map<String, dynamic>>();
      await waitOneRefreshInterval(tester);
      expect(requests, hasLength(1));

      await applyAuthChange(tester, () => auth.updateSessionMetadataForTest());
      expect(requests.single.isCancelled, isFalse);
      held.complete(_subscriptionJson(balance: 70));
      await tester.pump();
      expect(container.read(subscriptionNotifierProvider).balance, 70);

      await waitOneRefreshInterval(tester);
      expect(requests, hasLength(2));
    });

    testSession('switching accounts drops the old account post-billing '
        'refresh and keeps one periodic refresh', (tester) async {
      notifier.schedulePostBillingRefresh(delay: billingDelay);
      await applyAuthChange(tester, () => auth.switchAccountForTest());

      await tester.pump(billingDelay);
      expect(requests, isEmpty);

      await waitOneRefreshInterval(tester);
      expect(requests, hasLength(1));
      await waitOneRefreshInterval(tester);
      expect(requests, hasLength(2));
    });

    testSession('switching accounts cancels the old account in-flight '
        'refresh', (tester) async {
      final held = heldResponse = Completer<Map<String, dynamic>>();
      await waitOneRefreshInterval(tester);
      expect(requests, hasLength(1));

      await applyAuthChange(tester, () => auth.switchAccountForTest());
      expect(requests.single.isCancelled, isTrue);
      expect(held.isCompleted, isTrue);
      expect(container.read(subscriptionNotifierProvider).balance, 100);
    });

    testSession('signing out stops every pending refresh', (tester) async {
      notifier.schedulePostBillingRefresh(delay: billingDelay);
      await applyAuthChange(tester, () => auth.signOutForTest());

      await tester.pump(const Duration(minutes: 5));
      expect(requests, isEmpty);
    });
  });

  test('subscription-unsupported session never hits the endpoint', () async {
    final apiService = _MockNAIUserInfoApiService();
    when(
      () => apiService.getUserSubscription(
        receiveTimeout: any(named: 'receiveTimeout'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => _subscriptionJson(balance: 70));

    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(
          _ThirdPartyUnsupportedAuthNotifier.new,
        ),
        naiUserInfoApiServiceProvider.overrideWithValue(apiService),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(subscriptionNotifierProvider);
    expect(state.isUnsupported, isTrue);
    expect(state.balance, isNull);

    final notifier = container.read(subscriptionNotifierProvider.notifier);
    await notifier.fetchSubscription();
    expect(await notifier.refreshBalance(), isFalse);
    notifier.schedulePostBillingRefresh(delay: Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(container.read(subscriptionNotifierProvider).isUnsupported, isTrue);
    verifyNever(
      () => apiService.getUserSubscription(
        receiveTimeout: any(named: 'receiveTimeout'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
  });
}

Future<void> _waitForBalance(ProviderContainer container, int balance) {
  final reached = Completer<void>();
  final subscription = container.listen<SubscriptionState>(
    subscriptionNotifierProvider,
    (_, next) {
      if (next.balance == balance && !reached.isCompleted) reached.complete();
    },
    fireImmediately: true,
  );
  return reached.future.whenComplete(subscription.close);
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
