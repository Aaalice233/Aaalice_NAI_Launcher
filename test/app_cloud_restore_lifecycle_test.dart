import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/app.dart';
import 'package:nai_launcher/core/cache/local_gallery_thumbnail_provider.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

import 'helpers/app_bootstrap_effects_harness.dart';

final class _IdleSubscription extends SubscriptionNotifier {
  @override
  SubscriptionState build() => const SubscriptionState.initial();

  @override
  void setAppVisible(bool isVisible) {}
}

void main() {
  testWidgets('the cloud backup connection is restored on start and after the '
      'window was hidden, never on a focus switch', (tester) async {
    var restores = 0;
    final inert = Provider<int>((ref) => 0);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appBackgroundLifecycleOverrides(),
          subscriptionNotifierProvider.overrideWith(_IdleSubscription.new),
        ],
        child: MaterialApp(
          home: AppBootstrapEffects(
            anlasWatcher: inert,
            kritaBridge: inert,
            mcpServer: inert,
            cooccurrenceDataPack: inert,
            cloudSyncLifecycle: () async => restores++,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    addTearDown(
      () => LocalGalleryThumbnailProvider.setAppLifecycleState(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pump();
    expect(restores, 1);

    Future<void> enter(List<AppLifecycleState> states) async {
      for (final state in states) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }
    }

    for (var round = 0; round < 3; round++) {
      await enter(const [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
    }
    expect(restores, 1);

    // 从最小化恢复但还没拿到焦点
    await enter(const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
    ]);
    expect(restores, 2);

    await enter(const [AppLifecycleState.resumed]);
    expect(restores, 2);
  });
}
