import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/data/models/auth/saved_account.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/screens/auth/login_screen.dart';

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _ControllableAuthNotifier extends _UnauthenticatedAuthNotifier {
  void authenticate() {
    state = const AuthState(status: AuthStatus.authenticated);
  }
}

class _SavedAccountManagerNotifier extends AccountManagerNotifier {
  @override
  AccountManagerState build() => AccountManagerState(
    accounts: [
      SavedAccount(
        id: 'account-1',
        email: 'alice@example.com',
        nickname: 'Alice',
        createdAt: DateTime(2026),
      ),
    ],
  );
}

Widget _buildApp(GoRouter router, {AuthNotifier? authNotifier}) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(
        () => authNotifier ?? _UnauthenticatedAuthNotifier(),
      ),
      accountManagerNotifierProvider.overrideWith(
        _SavedAccountManagerNotifier.new,
      ),
    ],
    child: MaterialApp.router(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

GoRoute _loginRoute() {
  return GoRoute(
    path: '/login',
    name: 'login',
    builder: (context, state) => const LoginScreen(),
  );
}

void main() {
  testWidgets('saved-account login page can continue to the main screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        _loginRoute(),
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) =>
              const Scaffold(body: Text('MAIN_SCREEN_OPENED')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router));
    await tester.pumpAndSettle();

    expect(find.text('一键登录'), findsOneWidget);
    expect(find.text('跳过登录，进入主界面'), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth-skip-login-button')));
    await tester.pumpAndSettle();

    expect(find.text('MAIN_SCREEN_OPENED'), findsOneWidget);
  });

  testWidgets('successful login returns to the screen that opened it', (
    tester,
  ) async {
    final authNotifier = _ControllableAuthNotifier();
    final router = GoRouter(
      initialLocation: '/settings-test',
      routes: [
        GoRoute(
          path: '/settings-test',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.pushNamed('login'),
              child: const Text('OPEN_LOGIN'),
            ),
          ),
        ),
        _loginRoute(),
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) =>
              const Scaffold(body: Text('MAIN_SCREEN_OPENED')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router, authNotifier: authNotifier));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN_LOGIN'));
    await tester.pumpAndSettle();

    authNotifier.authenticate();
    await tester.pumpAndSettle();

    expect(find.text('OPEN_LOGIN'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('skip login returns to the screen that opened it', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/settings-test',
      routes: [
        GoRoute(
          path: '/settings-test',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.pushNamed('login'),
              child: const Text('OPEN_LOGIN'),
            ),
          ),
        ),
        _loginRoute(),
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) =>
              const Scaffold(body: Text('MAIN_SCREEN_OPENED')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN_LOGIN'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('auth-skip-login-button')));
    await tester.pumpAndSettle();

    expect(find.text('OPEN_LOGIN'), findsOneWidget);
  });
}
