import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/cost_estimate_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';
import 'package:nai_launcher/presentation/widgets/anlas/anlas_balance_chip.dart';
import 'package:nai_launcher/presentation/widgets/common/surface_ink_well.dart';

import '../../../helpers/ink_expectations.dart';

class _SubscriptionStub extends SubscriptionNotifier {
  _SubscriptionStub(this._state);

  final SubscriptionState _state;
  final refreshPriorities = <SubscriptionRefreshPriority>[];
  var fetches = 0;

  @override
  SubscriptionState build() => _state;

  @override
  Future<bool> refreshBalance({
    SubscriptionRefreshPriority priority =
        SubscriptionRefreshPriority.background,
  }) async {
    refreshPriorities.add(priority);
    return true;
  }

  @override
  Future<void> fetchSubscription() async {
    fetches++;
  }
}

void main() {
  testWidgets('余额芯片的悬停与按压反馈画在芯片底色之上，点击刷新余额', (tester) async {
    final stub = _SubscriptionStub(
      const SubscriptionState.loaded(
        UserSubscription(
          tier: 1,
          active: true,
          trainingStepsLeft: TrainingStepsInfo(fixedTrainingStepsLeft: 7384),
        ),
      ),
    );
    await _pumpChip(tester, stub);
    final chip = find.byType(SurfaceInkWell);
    final theme = Theme.of(tester.element(chip));
    final fill = theme.colorScheme.surfaceContainerHigh;

    await hoverOver(tester, chip);
    expectInkOnTop(tester, chip, ink: theme.hoverColor, below: fill);

    final press = await pressAndHold(tester, chip);
    expectInkOnTop(tester, chip, ink: theme.highlightColor, below: fill);
    await press.up();
    await tester.pump();
    expect(stub.refreshPriorities, [SubscriptionRefreshPriority.userInitiated]);
  });

  testWidgets('加载失败的芯片按压反馈画在错误底色之上，点击重新获取', (tester) async {
    final stub = _SubscriptionStub(const SubscriptionState.error('offline'));
    await _pumpChip(tester, stub);
    final chip = find.byType(SurfaceInkWell);
    final theme = Theme.of(tester.element(chip));

    final press = await pressAndHold(tester, chip);
    expectInkOnTop(
      tester,
      chip,
      ink: theme.highlightColor,
      below: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
    );
    await press.up();
    await tester.pump();
    expect(stub.fetches, 1);
  });

  testWidgets('加载中的芯片不响应悬停', (tester) async {
    await _pumpChip(
      tester,
      _SubscriptionStub(const SubscriptionState.loading()),
    );
    final chip = find.byType(SurfaceInkWell);
    final theme = Theme.of(tester.element(chip));

    await hoverOver(tester, chip);
    expect(tester.renderObject(chip), isNot(inkOnTop(ink: theme.hoverColor)));
  });
}

Future<void> _pumpChip(WidgetTester tester, _SubscriptionStub stub) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        subscriptionNotifierProvider.overrideWith(() => stub),
        estimatedCostProvider.overrideWith((ref) => 0),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: AnlasBalanceChip())),
      ),
    ),
  );
}
