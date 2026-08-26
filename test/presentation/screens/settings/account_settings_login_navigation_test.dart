import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/data/models/auth/saved_account.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';
import 'package:nai_launcher/presentation/router/app_router.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/account_settings_section.dart';
import 'package:nai_launcher/presentation/widgets/settings/account_profile_sheet.dart';

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _EmptyAccountManagerNotifier extends AccountManagerNotifier {
  @override
  AccountManagerState build() => const AccountManagerState();
}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  bool logoutCalled = false;

  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    accountId: 'account-1',
    displayName: 'Alice',
  );

  @override
  Future<void> logout({AuthErrorCode? errorCode, int? httpStatusCode}) async {
    logoutCalled = true;
    state = const AuthState(status: AuthStatus.unauthenticated);
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

class _InitialSubscriptionNotifier extends SubscriptionNotifier {
  @override
  SubscriptionState build() => const SubscriptionState.initial();
}

void main() {
  testWidgets('narrow account settings opens the login route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/settings-test',
      routes: [
        GoRoute(
          path: '/settings-test',
          builder: (context, state) => const Scaffold(
            body: AccountSettingsSection(),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const Scaffold(
            body: Text('LOGIN_ROUTE_OPENED'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
          accountManagerNotifierProvider.overrideWith(
            _EmptyAccountManagerNotifier.new,
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('去登录'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN_ROUTE_OPENED'), findsOneWidget);
  });

  testWidgets('authenticated account settings exposes direct logout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late _AuthenticatedAuthNotifier authNotifier;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(
            () => authNotifier = _AuthenticatedAuthNotifier(),
          ),
          accountManagerNotifierProvider.overrideWith(
            _SavedAccountManagerNotifier.new,
          ),
          subscriptionNotifierProvider.overrideWith(
            _InitialSubscriptionNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AccountSettingsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('account-settings-logout-button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('account-settings-logout-button')));
    await tester.pumpAndSettle();

    expect(authNotifier.logoutCalled, isTrue);
    expect(find.text('去登录'), findsOneWidget);
  });

  testWidgets('account profile sheet keeps logout visible in its footer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
          accountManagerNotifierProvider.overrideWith(
            _SavedAccountManagerNotifier.new,
          ),
          subscriptionNotifierProvider.overrideWith(
            _InitialSubscriptionNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AccountSettingsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountProfileBottomSheet), findsOneWidget);
    expect(
      find.byKey(const Key('account-profile-logout-button')),
      findsOneWidget,
    );
  });
}
