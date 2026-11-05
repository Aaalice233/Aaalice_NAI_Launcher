import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/app_lifecycle_visibility.dart';

void main() {
  test('a window that only lost focus is still visible', () {
    expect(AppLifecycleVisibility.isVisible(AppLifecycleState.resumed), isTrue);
    expect(
      AppLifecycleVisibility.isVisible(AppLifecycleState.inactive),
      isTrue,
    );
    expect(AppLifecycleVisibility.isVisible(null), isTrue);
  });

  test('hidden, paused and detached are not visible', () {
    for (final state in const [
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      expect(
        AppLifecycleVisibility.isVisible(state),
        isFalse,
        reason: '$state',
      );
    }
  });
}
