import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
  test(
    'refresh queued during an in-flight refresh fetches the latest balance',
    () async {
      final apiService = _MockNAIUserInfoApiService();
      final firstResponse = Completer<Map<String, dynamic>>();
      var requestCount = 0;

      when(
        () => apiService.getUserSubscription(
          receiveTimeout: any(named: 'receiveTimeout'),
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

  test('does not restore a stale balance after sign-out', () async {
    final apiService = _MockNAIUserInfoApiService();
    final response = Completer<Map<String, dynamic>>();
    when(
      () => apiService.getUserSubscription(
        receiveTimeout: any(named: 'receiveTimeout'),
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

  test('post-billing refresh waits briefly and debounces bursts', () async {
    final apiService = _MockNAIUserInfoApiService();
    var requestCount = 0;
    when(
      () => apiService.getUserSubscription(
        receiveTimeout: any(named: 'receiveTimeout'),
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
