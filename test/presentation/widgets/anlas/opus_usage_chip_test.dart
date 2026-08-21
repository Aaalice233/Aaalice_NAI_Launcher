import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';
import 'package:nai_launcher/presentation/widgets/anlas/opus_usage_chip.dart';

class _SubscriptionStub extends SubscriptionNotifier {
  _SubscriptionStub(this._state);

  final SubscriptionState _state;

  @override
  SubscriptionState build() => _state;

  @override
  void schedulePostBillingRefresh({Duration delay = Duration.zero}) {}
}

Future<void> _pumpChip(
  WidgetTester tester,
  SubscriptionState subscription,
  String model,
) async {
  final container = ProviderContainer(
    overrides: [
      subscriptionNotifierProvider.overrideWith(
        () => _SubscriptionStub(subscription),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: OpusUsageChip())),
      ),
    ),
  );
  // pumpWidget 之后再切模型，避免 auto-dispose 调度的 Timer 悬挂在帧外。
  container
      .read(generationParamsNotifierProvider.notifier)
      .updateModel(model, persist: false, followDefaults: false);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const opusWithUsage = SubscriptionState.loaded(
    UserSubscription(
      tier: 3,
      active: true,
      usage: OpusUsageInfo(percent: 98, timeUntilNextPercent: 4800),
    ),
  );

  testWidgets('shows the remaining percent on V5 for Opus accounts', (
    tester,
  ) async {
    await _pumpChip(tester, opusWithUsage, ImageModels.animeDiffusionV5Curated);

    expect(find.text('98%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('stays hidden on models without the quota pool', (tester) async {
    await _pumpChip(tester, opusWithUsage, ImageModels.animeDiffusionV45Full);

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('stays hidden when the subscription has no usage info', (
    tester,
  ) async {
    const opusWithoutUsage = SubscriptionState.loaded(
      UserSubscription(tier: 3, active: true),
    );

    await _pumpChip(tester, opusWithoutUsage, ImageModels.animeDiffusionV5Curated);

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('switches to the exhausted style when the quota is negative', (
    tester,
  ) async {
    const exhausted = SubscriptionState.loaded(
      UserSubscription(
        tier: 3,
        active: true,
        usage: OpusUsageInfo(percent: -2, isNegative: true),
      ),
    );

    await _pumpChip(tester, exhausted, ImageModels.animeDiffusionV5Curated);

    expect(find.text('0%'), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_bottom_rounded), findsOneWidget);
  });

  testWidgets('stays hidden for non-Opus tiers', (tester) async {
    const scroll = SubscriptionState.loaded(
      UserSubscription(
        tier: 2,
        active: true,
        usage: OpusUsageInfo(percent: 50),
      ),
    );

    await _pumpChip(tester, scroll, ImageModels.animeDiffusionV5Curated);

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
