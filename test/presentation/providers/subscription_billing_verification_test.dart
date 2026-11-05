import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/critical_network_activity.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/cost_estimate_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_billing.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

import 'subscription_billing_harness.dart';

void main() {
  final harness = SubscriptionBillingHarness.register();

  test('a subscription from login is refreshed before the settled estimate, so '
      'an exhausted V5 quota is not free', () async {
    harness.answerSubscription(
      () => billingSubscriptionJson(quotaExhausted: true),
    );
    final container = harness.createContainer(HydratedOpusAuth.new);
    expect(container.read(estimatedCostProvider), 0);
    expect(container.read(isFreeGenerationProvider), isTrue);

    final cost = await readSettledEstimatedCost(container);

    expect(cost, greaterThan(0));
    expect(container.read(isFreeGenerationProvider), isFalse);
    expect(harness.requestCount(), 1);
  });

  test('a failed refresh of stale data is never priced as free', () async {
    harness.failSubscription(DioExceptionType.connectionError);
    final container = harness.createContainer(HydratedOpusAuth.new);
    final notifier = container.read(subscriptionNotifierProvider.notifier);

    expect(await notifier.ensureFreshForBilling(), isFalse);

    expect(notifier.billingView, SubscriptionBillingView.unverified);
    expect(await readSettledEstimatedCost(container), greaterThan(0));
    expect(container.read(isFreeGenerationProvider), isFalse);
    expect(container.read(isOpusSubscriptionProvider), isFalse);
  });

  test('a later successful refresh restores the Opus allowance', () async {
    final container = await harness.loadedContainer();
    harness.now = harness.now.add(const Duration(minutes: 5));
    harness.failSubscription(DioExceptionType.connectionTimeout);
    final notifier = container.read(subscriptionNotifierProvider.notifier);
    expect(await notifier.ensureFreshForBilling(), isFalse);
    expect(container.read(estimatedCostProvider), greaterThan(0));

    harness.answerSubscription(
      () => billingSubscriptionJson(quotaExhausted: false),
    );
    expect(await notifier.refreshBalance(), isTrue);

    expect(container.read(estimatedCostProvider), 0);
    expect(notifier.billingView.isOpus, isTrue);
  });

  test(
    'an unverified subscription does not carry over to another account',
    () async {
      harness.failSubscription(DioExceptionType.connectionError);
      final container = harness.createContainer(
        SwitchableOpusAuth.new,
        freeV5Request: false,
      );
      final notifier = container.read(subscriptionNotifierProvider.notifier);
      expect(await notifier.ensureFreshForBilling(), isFalse);
      expect(notifier.billingView, SubscriptionBillingView.unverified);

      (container.read(authNotifierProvider.notifier) as SwitchableOpusAuth)
          .switchToOtherAccount();
      container.read(subscriptionNotifierProvider);

      expect(notifier.billingView.isOpus, isTrue);
      expect(container.read(isOpusSubscriptionProvider), isTrue);
    },
  );

  test('a check that fails after an account switch leaves the new account '
      'verified', () async {
    final response = Completer<Map<String, dynamic>>();
    harness.answerSubscription(() => response.future);
    final container = harness.createContainer(
      SwitchableOpusAuth.new,
      freeV5Request: false,
    );
    final notifier = container.read(subscriptionNotifierProvider.notifier);
    final check = notifier.freshBillingView();
    await Future<void>.delayed(Duration.zero);

    (container.read(authNotifierProvider.notifier) as SwitchableOpusAuth)
        .switchToOtherAccount();
    container.read(subscriptionNotifierProvider);
    response.completeError(
      DioException(
        requestOptions: RequestOptions(path: '/user/subscription'),
        type: DioExceptionType.connectionError,
      ),
    );

    expect(await check, SubscriptionBillingView.unverified);
    expect(notifier.billingView.isOpus, isTrue);
    expect(container.read(isOpusSubscriptionProvider), isTrue);
  });

  test('a billed request that outlasts the wait is not assumed free until the '
      'next refresh', () {
    fakeAsync((async) {
      harness.answerSubscription(
        () => billingSubscriptionJson(quotaExhausted: false),
      );
      final container = harness.createContainer(
        HydratedOpusAuth.new,
        freeV5Request: false,
      );
      final notifier = container.read(subscriptionNotifierProvider.notifier);
      final lease = CriticalNetworkActivityCoordinator.instance.acquire(
        CriticalNetworkActivityType.imageGeneration,
      );

      try {
        bool? fresh;
        notifier.ensureFreshForBilling().then((value) => fresh = value);
        async.elapse(
          SubscriptionNotifier.billingRefreshTimeout +
              const Duration(seconds: 1),
        );

        expect(fresh, isFalse);
        expect(notifier.billingView, SubscriptionBillingView.unverified);
        harness.expectNoRequest();
      } finally {
        lease.release();
      }
      async.elapse(SubscriptionNotifier.postBillingRefreshDelay);

      expect(harness.requestCount(), 1);
      expect(notifier.billingView.isOpus, isTrue);
    });
  });

  test('a refresh that never answers times out as not free', () {
    fakeAsync((async) {
      final response = Completer<Map<String, dynamic>>();
      harness.answerSubscription(() => response.future);
      final container = harness.createContainer(
        HydratedOpusAuth.new,
        freeV5Request: false,
      );
      final notifier = container.read(subscriptionNotifierProvider.notifier);

      bool? fresh;
      notifier.ensureFreshForBilling().then((value) => fresh = value);
      async.elapse(
        SubscriptionNotifier.billingRefreshTimeout - const Duration(seconds: 1),
      );
      expect(fresh, isNull);
      async.elapse(const Duration(seconds: 2));

      expect(fresh, isFalse);
      expect(notifier.billingView, SubscriptionBillingView.unverified);
      expect(container.read(isOpusSubscriptionProvider), isFalse);
    });
  });
}
