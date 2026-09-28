import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/presentation/providers/auth_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults login mode to API Token', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(authModeProvider), AuthMode.token);
  });

  test('defaults auto login to enabled when no preference exists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      authModeNotifierProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(container.read(autoLoginProvider), isTrue);

    await Future<void>.delayed(Duration.zero);

    expect(container.read(autoLoginProvider), isTrue);
  });

  test('loads persisted auto login preference', () async {
    SharedPreferences.setMockInitialValues({'auto_login': false});

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      authModeNotifierProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await Future<void>.delayed(Duration.zero);

    expect(container.read(autoLoginProvider), isFalse);
  });

  test('setAutoLogin persists and updates state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      authModeNotifierProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(authModeNotifierProvider.notifier).setAutoLogin(false);

    expect(container.read(autoLoginProvider), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('auto_login'), isFalse);
  });
}
