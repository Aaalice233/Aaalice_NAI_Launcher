import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/auth/saved_account.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/data/services/account_manager_provider.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/data/services/saved_account_removal_service.dart';
import 'package:nai_launcher/presentation/widgets/auth/account_avatar.dart';
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

class _RecordingRemovalService extends SavedAccountRemovalService {
  _RecordingRemovalService(super.ref, this._removedIds);

  final List<String> _removedIds;

  @override
  Future<void> remove(String accountId) async => _removedIds.add(accountId);
}

/// 打开当前账号的资料面板，返回记录移除请求的列表
Future<List<String>> _openProfileWithRemovalService(WidgetTester tester) async {
  final removedIds = <String>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        accountManagerNotifierProvider.overrideWith(
          _AccountManagerNotifier.new,
        ),
        savedAccountRemovalServiceProvider.overrideWith(
          (ref) => _RecordingRemovalService(ref, removedIds),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
  return removedIds;
}

Finder _profileScrollable() => find
    .descendant(
      of: find.byType(AccountProfileBottomSheet),
      matching: find.byType(Scrollable),
    )
    .first;

/// 按滚动位置推进直到目标被构建，避免拖动手势被 SelectableText 的内部滚动截走
Future<void> _revealInProfile(WidgetTester tester, Finder target) async {
  final position = tester.state<ScrollableState>(_profileScrollable()).position;
  while (target.evaluate().isEmpty &&
      position.pixels < position.maxScrollExtent) {
    position.jumpTo(math.min(position.pixels + 80, position.maxScrollExtent));
    await tester.pump();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _tapProfileAction(WidgetTester tester, Finder action) async {
  await _revealInProfile(tester, action);
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Future<void> _settleToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
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
          final removeAction = find.byKey(
            const Key('account-profile-remove-button'),
          );
          await _revealInProfile(tester, removeAction);
          expect(removeAction.hitTestable(), findsOneWidget);
          expect(tester.getSize(removeAction).height, greaterThanOrEqualTo(48));
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

  testWidgets('切换账号列表复用共享头像组件，不在 build 内探测文件', (tester) async {
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
          home: Scaffold(body: AccountProfileBottomSheet(account: _account)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _revealInProfile(tester, find.byType(AccountAvatarSmall));

    final avatar = tester.widget<AccountAvatarSmall>(
      find.byType(AccountAvatarSmall),
    );
    expect(avatar.account.id, _otherAccount.id);
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

  testWidgets('移除当前登录账号先提示会退出登录，确认后关闭面板', (tester) async {
    final removedIds = await _openProfileWithRemovalService(tester);

    await _tapProfileAction(
      tester,
      find.byKey(const Key('account-profile-remove-button')),
    );
    expect(find.textContaining('确认后会先退出登录'), findsOneWidget);
    expect(find.textContaining('NovelAI 账号本身不受影响'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '移除'));
    await tester.pumpAndSettle();

    expect(removedIds, [_account.id]);
    expect(find.byType(AccountProfileBottomSheet), findsNothing);
    expect(find.textContaining('已移除'), findsOneWidget);
    await _settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('从切换列表移除其他账号时不提示退出登录，面板保持打开', (tester) async {
    final removedIds = await _openProfileWithRemovalService(tester);
    final removeOther = find.byKey(
      ValueKey('account-profile-remove-${_otherAccount.id}'),
    );
    await _revealInProfile(tester, removeOther);
    expect(tester.getSize(removeOther).height, greaterThanOrEqualTo(40));
    expect(tester.widget<IconButton>(removeOther).tooltip, isNotNull);

    await _tapProfileAction(tester, removeOther);
    expect(find.textContaining('确认后会先退出登录'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '移除'));
    await tester.pumpAndSettle();

    expect(removedIds, [_otherAccount.id]);
    expect(find.byType(AccountProfileBottomSheet), findsOneWidget);
    await _settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('取消确认时不移除账号', (tester) async {
    final removedIds = await _openProfileWithRemovalService(tester);

    final removeAction = find.byKey(const Key('account-profile-remove-button'));
    await _tapProfileAction(tester, removeAction);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(removedIds, isEmpty);
    expect(find.byType(AccountProfileBottomSheet), findsOneWidget);
    expect(tester.widget<InkWell>(removeAction).onTap, isNotNull);
  });
}
