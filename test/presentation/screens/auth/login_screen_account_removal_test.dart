import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/data/models/auth/saved_account.dart';
import 'package:nai_launcher/data/services/account_manager_provider.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/data/services/saved_account_removal_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/auth/login_screen.dart';

final _alice = SavedAccount(
  id: 'account-1',
  email: 'alice@example.com',
  nickname: 'Alice',
  createdAt: DateTime(2026),
);

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _SavedAccountManagerNotifier extends AccountManagerNotifier {
  @override
  AccountManagerState build() => AccountManagerState(accounts: [_alice]);
}

class _RecordingRemovalService extends SavedAccountRemovalService {
  _RecordingRemovalService(super.ref, this._removedIds);

  final List<String> _removedIds;

  @override
  Future<void> remove(String accountId) async => _removedIds.add(accountId);
}

void main() {
  testWidgets('登录页账号选择面板的移除按钮带提示，确认后关闭面板并移除', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final removedIds = <String>[];
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
          accountManagerNotifierProvider.overrideWith(
            _SavedAccountManagerNotifier.new,
          ),
          savedAccountRemovalServiceProvider.overrideWith(
            (ref) => _RecordingRemovalService(ref, removedIds),
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

    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    final remove = find.byKey(ValueKey('login-account-remove-${_alice.id}'));
    expect(tester.widget<IconButton>(remove).tooltip, '移除账号');

    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.textContaining('NovelAI 账号本身不受影响'), findsOneWidget);
    expect(find.textContaining('确认后会先退出登录'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '移除'));
    await tester.pumpAndSettle();

    expect(removedIds, [_alice.id]);
    expect(remove, findsNothing);
    expect(find.text('选择账号'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
