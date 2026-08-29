import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/mobile_generation_controller.dart';

void main() {
  testWidgets('未登录且提示词为空时直接进入登录页', (tester) async {
    final storage = _MemoryLocalStorageService({
      StorageKeys.mobileGenerationGestureHintCompleted: true,
    });
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const _ControllerHarness(),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) =>
              const Scaffold(body: Text('LOGIN_SCREEN_OPENED')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
          localStorageServiceProvider.overrideWith((ref) => storage),
        ],
        child: MaterialApp.router(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('MOBILE_GENERATE'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN_SCREEN_OPENED'), findsOneWidget);
    expect(find.text('请输入提示词'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _ControllerHarness extends ConsumerStatefulWidget {
  const _ControllerHarness();

  @override
  ConsumerState<_ControllerHarness> createState() => _ControllerHarnessState();
}

class _ControllerHarnessState extends ConsumerState<_ControllerHarness> {
  late final MobileGenerationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileGenerationController(ref);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => unawaited(_controller.generate(context)),
          child: const Text('MOBILE_GENERATE'),
        ),
      ),
    );
  }
}

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _MemoryLocalStorageService extends LocalStorageService {
  _MemoryLocalStorageService(this.values);

  final Map<String, Object?> values;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    return values.containsKey(key) ? values[key] as T? : defaultValue;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}
