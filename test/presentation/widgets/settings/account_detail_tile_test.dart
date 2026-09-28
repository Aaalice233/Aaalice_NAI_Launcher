import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/auth/saved_account.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';
import 'package:nai_launcher/presentation/widgets/settings/account_detail_tile.dart';

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(status: AuthStatus.authenticated, accountId: 'account-1');
}

class _AccountManagerNotifier extends AccountManagerNotifier {
  @override
  AccountManagerState build() => AccountManagerState(
    accounts: [
      SavedAccount(
        id: 'account-1',
        email: 'token_1787796794404',
        nickname: 'UI Audit',
        createdAt: DateTime(2026),
      ),
    ],
  );
}

class _LoadedSubscriptionNotifier extends SubscriptionNotifier {
  @override
  SubscriptionState build() => const SubscriptionState.loaded(
    UserSubscription(
      tier: 3,
      active: true,
      trainingStepsLeft: TrainingStepsInfo(fixedTrainingStepsLeft: 7419),
    ),
  );
}

class _Subscription extends SubscriptionNotifier {
  _Subscription(this.value);
  final UserSubscription value;
  @override
  SubscriptionState build() => SubscriptionState.loaded(value);
}

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('expiry is localized and wraps at 3x text: $locale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final expiry = DateTime(2030, 10, 21, 18, 30);
      for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(
          _expiryApp(
            locale,
            UserSubscription(
              tier: 3,
              expiresAt: expiry.millisecondsSinceEpoch ~/ 1000,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(AccountDetailTile)),
        )!;
        final text = find.text(l10n.settings_subscriptionExpiresOn(expiry));
        expect(text, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
          isFalse,
        );
        expect(tester.getRect(text).right, lessThanOrEqualTo(width));
        expect(find.text('Opus'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$locale at $width');
      }
    });
  }
  for (final subscription in [
    const UserSubscription(tier: 3),
    const UserSubscription(tier: 3, expiresAt: 0),
    const UserSubscription(tier: 0, expiresAt: 1900000000),
  ]) {
    testWidgets('omits unavailable membership expiry: $subscription', (
      tester,
    ) async {
      await tester.pumpWidget(_expiryApp(const Locale('en'), subscription));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('account-subscription-expiry')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('expired membership still shows its recorded expiry', (
    tester,
  ) async {
    final expiry = DateTime(2020, 1, 2);
    await tester.pumpWidget(
      _expiryApp(
        const Locale('en'),
        UserSubscription(
          tier: 3,
          expiresAt: expiry.millisecondsSinceEpoch ~/ 1000,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Subscription expiry: Jan 2, 2020'), findsOneWidget);
  });

  testWidgets('窄手机和大字号下账号摘要保持完整层级', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
          accountManagerNotifierProvider.overrideWith(
            _AccountManagerNotifier.new,
          ),
          subscriptionNotifierProvider.overrideWith(
            _LoadedSubscriptionNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const Scaffold(body: AccountDetailTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('UI Audit'), findsOneWidget);
    final nameParagraph = tester.renderObject<RenderParagraph>(
      find.text('UI Audit'),
    );
    expect(nameParagraph.didExceedMaxLines, isFalse);
    expect(find.text('Opus'), findsOneWidget);
    expect(find.text('Token 账号'), findsOneWidget);
    expect(find.textContaining('token_'), findsNothing);
    expect(
      find.byKey(const Key('account-settings-logout-button')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _expiryApp(Locale locale, UserSubscription subscription) =>
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        accountManagerNotifierProvider.overrideWith(
          _AccountManagerNotifier.new,
        ),
        subscriptionNotifierProvider.overrideWith(
          () => _Subscription(subscription),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(child: AccountDetailTile()),
        ),
      ),
    );
