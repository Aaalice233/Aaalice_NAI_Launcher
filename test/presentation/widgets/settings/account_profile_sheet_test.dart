import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/auth/saved_account.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/widgets/settings/account_profile_sheet.dart';

final _account = SavedAccount(
  id: 'account-1',
  email: 'token_1787796794404',
  nickname: '一个用于验证窄屏布局的较长账号昵称',
  createdAt: DateTime(2026),
);

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(status: AuthStatus.authenticated, accountId: 'account-1');
}

class _AccountManagerNotifier extends AccountManagerNotifier {
  @override
  AccountManagerState build() => AccountManagerState(accounts: [_account]);
}

void main() {
  testWidgets('Token 账号资料在窄屏隐藏内部标识并保留退出入口', (tester) async {
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
          home: Scaffold(body: AccountProfileBottomSheet(account: _account)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('token_'), findsNothing);
    expect(find.text('Token 账号'), findsOneWidget);
    expect(
      find.byKey(const Key('account-profile-logout-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
