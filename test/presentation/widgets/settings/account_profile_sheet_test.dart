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

final _otherAccount = SavedAccount(
  id: 'account-2',
  email: 'second@example.com',
  nickname: '另一个用于验证多账号列表的超长昵称',
  createdAt: DateTime(2026),
);

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(status: AuthStatus.authenticated, accountId: 'account-1');
}

class _AccountManagerNotifier extends AccountManagerNotifier {
  @override
  AccountManagerState build() =>
      AccountManagerState(accounts: [_account, _otherAccount]);
}

class _SingleAccountManager extends AccountManagerNotifier {
  @override
  AccountManagerState build() => AccountManagerState(accounts: [_account]);
}

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(600, 800),
    const Size(840, 900),
    const Size(1180, 1000),
    const Size(1600, 1000),
    const Size(840, 360),
  ]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets(
        'profile fits content and keeps actions reachable: $size / $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authNotifierProvider.overrideWith(
                  _AuthenticatedAuthNotifier.new,
                ),
                accountManagerNotifierProvider.overrideWith(
                  _SingleAccountManager.new,
                ),
              ],
              child: MaterialApp(
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => AccountProfileBottomSheet.show(
                        context: context,
                        account: _account,
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final logout = find.byKey(const Key('account-profile-logout-button'));
          expect(logout.hitTestable(), findsOneWidget);
          final panel = find.byKey(
            ValueKey(
              size.width >= 600
                  ? 'adaptive-centered-form'
                  : 'adaptive-bottom-sheet',
            ),
          );
          expect(panel, findsOneWidget);
          if (size.height >= 900 && scale == 1) {
            expect(tester.getSize(panel).height, lessThan(650));
            expect(
              tester.getRect(panel).bottom - tester.getRect(logout).bottom,
              lessThan(50),
            );
          }
          if (size.width >= 600 && size.height >= 800 && scale == 1) {
            final nicknameIcon = tester.getCenter(
              find.byIcon(Icons.badge_outlined),
            );
            expect(
              tester.getCenter(find.text('Nickname')).dy,
              closeTo(nicknameIcon.dy, 0.1),
            );
            expect(
              tester.getCenter(find.text(_account.displayName)).dy,
              closeTo(nicknameIcon.dy, 0.1),
            );
            final typeIcon = tester.getCenter(
              find.byIcon(Icons.account_circle_outlined),
            );
            expect(
              tester.getCenter(find.text('Account Type')).dy,
              closeTo(typeIcon.dy, 0.1),
            );
            expect(
              tester.getCenter(find.text('Token Account')).dy,
              closeTo(typeIcon.dy, 0.1),
            );
          }
          final avatarAction = find.widgetWithText(TextButton, 'Change Avatar');
          await tester.scrollUntilVisible(
            avatarAction,
            80,
            scrollable: find
                .descendant(
                  of: find.byType(AccountProfileBottomSheet),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(avatarAction.hitTestable(), findsOneWidget);
          final error = tester.takeException();
          expect(
            error,
            isNull,
            reason: error is FlutterError ? error.toStringDeep() : '$error',
          );
        },
      );
    }
  }

  testWidgets('复杂账号资料在最窄屏、放大文字和键盘组合下使用全高 bottom sheet', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
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
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
              viewPadding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
              viewInsets: const EdgeInsets.only(bottom: 180),
              textScaler: const TextScaler.linear(3),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => AccountProfileBottomSheet.show(
                  context: context,
                  account: _account,
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.textContaining('token_'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Token 账号'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(AccountProfileBottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Token 账号'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    final logout = tester.widget<FilledButton>(
      find.byKey(const Key('account-profile-logout-button')),
    );
    final colors = Theme.of(
      tester.element(find.byKey(const Key('account-profile-logout-button'))),
    ).colorScheme;
    expect(logout.style?.backgroundColor?.resolve({}), colors.errorContainer);
    expect(tester.takeException(), isNull);
  });
}
