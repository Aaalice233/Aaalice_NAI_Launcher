import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/local_gallery_thumbnail_provider.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

import 'helpers/app_bootstrap_effects_harness.dart';

// 自动释放的 provider 每次读取都可能新建，记录放在实例之外
final class _RecordingSubscription extends SubscriptionNotifier {
  _RecordingSubscription(this.visibility);

  final List<bool> visibility;

  @override
  SubscriptionState build() => const SubscriptionState.initial();

  @override
  void setAppVisible(bool isVisible) => visibility.add(isVisible);
}

void main() {
  late List<bool> subscriptionVisibility;

  Future<void> pumpEffects(WidgetTester tester) async {
    subscriptionVisibility = [];
    await pumpAppBootstrapEffects(
      tester,
      overrides: [
        subscriptionNotifierProvider.overrideWith(
          () => _RecordingSubscription(subscriptionVisibility),
        ),
      ],
    );
    // 组件树卸载后观察者收不到生命周期，静态调度器要直接还原
    addTearDown(
      () => LocalGalleryThumbnailProvider.setAppLifecycleState(
        AppLifecycleState.resumed,
      ),
    );
  }

  void enter(WidgetTester tester, List<AppLifecycleState> states) {
    for (final state in states) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  testWidgets('a visible window that lost focus keeps decoding images', (
    tester,
  ) async {
    await pumpEffects(tester);

    enter(tester, const [AppLifecycleState.inactive]);
    await tester.pump();

    expect(LocalGalleryThumbnailProvider.decodesAppVisible, isTrue);
  });

  testWidgets('switching focus never pauses the subscription refresh', (
    tester,
  ) async {
    await pumpEffects(tester);

    for (var round = 0; round < 3; round++) {
      enter(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
    }
    enter(tester, const [AppLifecycleState.inactive, AppLifecycleState.hidden]);
    await tester.pump();

    expect(subscriptionVisibility, [
      for (var i = 0; i < 7; i++) isTrue,
      isFalse,
    ]);
  });

  testWidgets('a hidden window pauses decoding until it is visible again', (
    tester,
  ) async {
    await pumpEffects(tester);

    enter(tester, const [AppLifecycleState.inactive, AppLifecycleState.hidden]);
    await tester.pump();
    expect(LocalGalleryThumbnailProvider.decodesAppVisible, isFalse);

    enter(tester, const [AppLifecycleState.inactive]);
    await tester.pump();
    expect(LocalGalleryThumbnailProvider.decodesAppVisible, isTrue);
  });

  testWidgets('a paused app pauses decoding', (tester) async {
    await pumpEffects(tester);

    enter(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    await tester.pump();

    expect(LocalGalleryThumbnailProvider.decodesAppVisible, isFalse);
  });

  test('a later test starts with decoding resumed', () {
    expect(LocalGalleryThumbnailProvider.decodesAppVisible, isTrue);
  });
}
