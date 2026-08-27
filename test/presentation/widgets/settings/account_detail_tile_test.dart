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

void main() {
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
