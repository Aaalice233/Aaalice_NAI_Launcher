import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/network/critical_network_activity.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/cost_estimate_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_billing.dart';
import 'package:nai_launcher/presentation/providers/subscription_billing_freshness.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

import 'subscription_billing_harness.dart';

void main() {
  final harness = SubscriptionBillingHarness.register();

  test('generation uses the login quota immediately during and after a '
      'billed request without a subscription request', () {
    final container = harness.createContainer(HydratedOpusAuth.new);
    final request = readGenerationPageRequest(container);
    fakeAsync((async) {
      void expectImmediateEstimate() {
        GenerationCostEstimate? estimate;
        readSettledEstimatedCost(container, request).then((v) => estimate = v);
        async.flushMicrotasks();
        expect(estimate, (knownCost: 0, confirmationCost: 0));
        harness.expectNoRequest();
      }

      final lease = CriticalNetworkActivityCoordinator.instance.acquire(
        CriticalNetworkActivityType.imageGeneration,
      );
      try {
        expectImmediateEstimate();
      } finally {
        lease.release();
      }
      expectImmediateEstimate();
    });
  });

  const combinedQuota = OpusUsageInfo(percent: 3, purchasedPercent: 2);
  const overdrawn = OpusUsageInfo(isNegative: true);
  for (final (label, usage, known, confirmation)
      in <(String, OpusUsageInfo?, int, int)>[
        ('5% across both pools', combinedQuota, 0, 0),
        ('just below 5%', const OpusUsageInfo(percent: 4.99), 0, 30),
        ('overdrawn quota', overdrawn, 30, 30),
        ('no quota pool', null, 0, 0),
      ]) {
    test('generation prices stale $label without refreshing', () async {
      final container = harness.createContainer(
        () => HydratedOpusAuth({
          ...billingSubscriptionJson(quotaExhausted: false),
          'usage': usage?.toJson(),
        }),
      );
      final estimate = await readSettledEstimatedCost(
        container,
        readGenerationPageRequest(container),
      );
      expect(estimate, (knownCost: known, confirmationCost: confirmation));
      harness.expectNoRequest();
    });
  }

  test('a model outside the quota pool stays free on a low stale '
      'quota', () async {
    final container = harness.createContainer(
      () => HydratedOpusAuth({
        ...billingSubscriptionJson(quotaExhausted: false),
        'usage': const OpusUsageInfo(percent: 1).toJson(),
      }),
    );
    container
        .read(generationParamsNotifierProvider.notifier)
        .updateModel(
          ImageModels.animeDiffusionV45Full,
          persist: false,
          followDefaults: false,
        );

    expect(
      await readSettledEstimatedCost(
        container,
        readGenerationPageRequest(container),
      ),
      (knownCost: 0, confirmationCost: 0),
    );
  });

  test('fresh low quota is trusted up to the freshness boundary', () async {
    final lowQuota = {
      ...billingSubscriptionJson(quotaExhausted: false),
      'usage': const OpusUsageInfo(percent: 1).toJson(),
    };
    harness.answerSubscription(() => lowQuota);
    final container = harness.createContainer(() => HydratedOpusAuth(lowQuota));
    final request = readGenerationPageRequest(container);
    final notifier = container.read(subscriptionNotifierProvider.notifier);
    expect(await notifier.ensureFreshForBilling(), isTrue);
    harness.now = harness.now.add(SubscriptionBillingFreshness.window);
    expect(await readSettledEstimatedCost(container, request), (
      knownCost: 0,
      confirmationCost: 0,
    ));
    harness.now = harness.now.add(const Duration(milliseconds: 1));
    expect(await readSettledEstimatedCost(container, request), (
      knownCost: 0,
      confirmationCost: 30,
    ));
    expect(harness.requestCount(), 1);
  });

  test('failed verification keeps the displayed V5 cost at zero and returns '
      'the worst case only to the caller', () async {
    harness.failSubscription(DioExceptionType.connectionError);
    final container = harness.createContainer(HydratedOpusAuth.new);
    final notifier = container.read(subscriptionNotifierProvider.notifier);
    final known = container.read(subscriptionBillingViewProvider);
    expect(container.read(estimatedCostProvider), 0);

    expect(
      await notifier.freshBillingView(),
      SubscriptionBillingView.unverified,
    );

    expect(notifier.billingView, known);
    expect(container.read(subscriptionBillingViewProvider), known);
    expect(container.read(estimatedCostProvider), 0);
    expect(container.read(isFreeGenerationProvider), isTrue);
    expect(container.read(isOpusSubscriptionProvider), isTrue);
    expect(
      await readSettledEstimatedCost(
        container,
        readGenerationPageRequest(container),
      ),
      (knownCost: 0, confirmationCost: 0),
    );
    expect(harness.requestCount(), 1);
  });

  test('the displayed cost changes when a later refresh reports an exhausted '
      'quota', () async {
    final container = await harness.loadedContainer();
    harness.now = harness.now.add(const Duration(minutes: 5));
    harness.failSubscription(DioExceptionType.connectionTimeout);
    final notifier = container.read(subscriptionNotifierProvider.notifier);
    expect(await notifier.ensureFreshForBilling(), isFalse);
    expect(container.read(estimatedCostProvider), 0);

    harness.answerSubscription(
      () => billingSubscriptionJson(quotaExhausted: true),
    );
    expect(await notifier.refreshBalance(), isTrue);

    expect(container.read(estimatedCostProvider), 30);
    expect(container.read(isFreeGenerationProvider), isFalse);
    expect(notifier.billingView.isOpus, isTrue);
  });

  test(
    'an account switch prices the new account from its own login quota',
    () async {
      harness.failSubscription(DioExceptionType.connectionError);
      final container = harness.createContainer(SwitchableOpusAuth.new);
      final notifier = container.read(subscriptionNotifierProvider.notifier);
      expect(
        await notifier.freshBillingView(),
        SubscriptionBillingView.unverified,
      );
      expect(container.read(estimatedCostProvider), 0);

      (container.read(authNotifierProvider.notifier) as SwitchableOpusAuth)
          .switchToOtherAccount();
      container.read(subscriptionNotifierProvider);

      expect(container.read(estimatedCostProvider), 30);
      expect(notifier.billingView.opusQuotaExhausted, isTrue);
      expect(container.read(isOpusSubscriptionProvider), isTrue);
    },
  );

  test('a check that fails after an account switch leaves the new quota '
      'intact', () async {
    final started = Completer<void>();
    final response = Completer<Map<String, dynamic>>();
    harness.answerSubscription(() {
      started.complete();
      return response.future;
    });
    final container = harness.createContainer(
      SwitchableOpusAuth.new,
      freeV5Request: false,
    );
    final notifier = container.read(subscriptionNotifierProvider.notifier);
    final check = notifier.freshBillingView();
    await started.future;

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
    expect(notifier.billingView.opusQuotaExhausted, isTrue);
    expect(container.read(isOpusSubscriptionProvider), isTrue);
  });

  test('a billing check waiting for a charge does not refresh the next '
      'account', () {
    fakeAsync((async) {
      final container = harness.createContainer(
        SwitchableOpusAuth.new,
        freeV5Request: false,
      );
      final notifier = container.read(subscriptionNotifierProvider.notifier);
      CriticalNetworkActivityCoordinator.instance
          .acquire(CriticalNetworkActivityType.imageGeneration)
          .release();
      SubscriptionBillingView? result;
      notifier.freshBillingView().then((view) => result = view);
      async.flushMicrotasks();
      expect(result, isNull);

      (container.read(authNotifierProvider.notifier) as SwitchableOpusAuth)
          .switchToOtherAccount();
      container.read(subscriptionNotifierProvider);
      async.elapse(SubscriptionNotifier.postBillingRefreshDelay);

      expect(result, SubscriptionBillingView.unverified);
      expect(notifier.billingView.opusQuotaExhausted, isTrue);
      harness.expectNoRequest();
    });
  });

  test('an active billed request times out at three seconds', () {
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
        SubscriptionBillingView? result;
        notifier.freshBillingView().then((value) => result = value);
        async.elapse(const Duration(milliseconds: 2999));
        expect(result, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(result, SubscriptionBillingView.unverified);
        expect(notifier.billingView.isOpus, isTrue);
        harness.expectNoRequest();
      } finally {
        lease.release();
      }
      async.elapse(SubscriptionNotifier.postBillingRefreshDelay);

      expect(harness.requestCount(), 1);
      expect(notifier.billingView.isOpus, isTrue);
    });
  });

  test('a slow subscription response times out at three seconds', () {
    fakeAsync((async) {
      final response = Completer<Map<String, dynamic>>();
      harness.answerSubscription(() => response.future);
      final container = harness.createContainer(
        HydratedOpusAuth.new,
        freeV5Request: false,
      );
      final notifier = container.read(subscriptionNotifierProvider.notifier);

      SubscriptionBillingView? result;
      notifier.freshBillingView().then((value) => result = value);
      async.elapse(const Duration(milliseconds: 2999));
      expect(result, isNull);
      async.elapse(const Duration(milliseconds: 1));
      expect(result, SubscriptionBillingView.unverified);
      expect(container.read(isOpusSubscriptionProvider), isTrue);
      response.complete(billingSubscriptionJson(quotaExhausted: true));
      async.flushMicrotasks();
      expect(notifier.billingView.opusQuotaExhausted, isTrue);
    });
  });
}
