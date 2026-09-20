import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/models/auth/saved_account.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/theme_provider.dart';
import 'package:nai_launcher/presentation/router/mobile_more_panel.dart';
import 'package:nai_launcher/presentation/themes/app_theme.dart';

import '../../helpers/light_theme_contrast.dart';

class _MockNavigationShell extends Mock implements StatefulNavigationShell {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockNavigationShell';
}

void main() {
  testWidgets(
    'mobile more panel exposes one single-line metadata entry and wires tap',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      tester.view.padding = const FakeViewPadding(bottom: 32);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
        tester.view.resetPadding();
      });

      final navigationShell = _MockNavigationShell();
      var importCalls = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountManagerNotifierProvider.overrideWith(
              _EmptyAccountManagerNotifier.new,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Consumer(
              builder: (context, ref, child) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showMobileMorePanel(
                      context: context,
                      ref: ref,
                      navigationShell: navigationShell,
                      onImportImageMetadata: (context, ref) async {
                        importCalls++;
                      },
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('mobile-more-account')), findsOneWidget);
      // 未登录时账号条目本身就是登录入口，不再额外挂「添加账号」。
      expect(
        find.byKey(const ValueKey('mobile-more-add-account')),
        findsNothing,
      );
      const entryKey = ValueKey('mobile-more-read-image-metadata');
      final entry = find.byKey(entryKey);
      expect(entry, findsOneWidget);
      expect(find.text('读取图片元数据'), findsOneWidget);

      final tile = tester.widget<ListTile>(
        find.descendant(of: entry, matching: find.byType(ListTile)),
      );
      expect(tile.subtitle, isNull);
      final title = tile.title! as Text;
      expect(title.maxLines, 1);
      expect(find.byType(Scrollbar), findsOneWidget);
      final settings = find.byKey(const ValueKey('mobile-more-settings'));
      await tester.scrollUntilVisible(
        settings,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(settings.hitTestable(), findsOneWidget);

      for (final key in const [
        ValueKey('mobile-more-discord'),
        ValueKey('mobile-more-github'),
      ]) {
        final button = find.byKey(key);
        expect(button.hitTestable(), findsOneWidget);
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(768));
      }

      await tester.scrollUntilVisible(
        entry,
        -100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(importCalls, 1);
      expect(find.byKey(entryKey), findsNothing);
    },
  );

  testWidgets('已登录时「更多」面板补出添加账号入口', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);

    final navigationShell = _MockNavigationShell();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountManagerNotifierProvider.overrideWith(
            _SingleAccountManagerNotifier.new,
          ),
          authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Consumer(
            builder: (context, ref, child) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showMobileMorePanel(
                    context: context,
                    ref: ref,
                    navigationShell: navigationShell,
                    onImportImageMetadata: (context, ref) async {},
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 上游移动端登录后没有任何添加第二账号的路径（入口只在桌面侧栏）。
    final addAccount = find.byKey(const ValueKey('mobile-more-add-account'));
    expect(addAccount, findsOneWidget);
    expect(
      find.descendant(of: addAccount, matching: find.text('添加账号')),
      findsOneWidget,
    );
  });

  testWidgets('「更多」面板的主题入口一键在深浅两套之间切换且不关闭面板', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);

    final navigationShell = _MockNavigationShell();
    final container = createStorageFreeContainer(
      overrides: [
        accountManagerNotifierProvider.overrideWith(
          _EmptyAccountManagerNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Consumer(
            builder: (context, ref, child) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showMobileMorePanel(
                    context: context,
                    ref: ref,
                    navigationShell: navigationShell,
                    onImportImageMetadata: (context, ref) async {},
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final themeEntry = find.byKey(const ValueKey('mobile-more-theme'));
    await tester.scrollUntilVisible(
      themeEntry,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(container.read(themeNotifierProvider), AppStyle.grungeCollage);
    await tester.tap(themeEntry);
    await tester.pumpAndSettle();
    expect(container.read(themeNotifierProvider), AppStyle.boldRetro);

    // 面板保持打开，可以连点比较两套配色。
    expect(themeEntry, findsOneWidget);
    await tester.tap(themeEntry);
    await tester.pumpAndSettle();
    expect(container.read(themeNotifierProvider), AppStyle.grungeCollage);
  });
}

class _EmptyAccountManagerNotifier extends AccountManagerNotifier {
  @override
  AccountManagerState build() => const AccountManagerState();
}

class _SingleAccountManagerNotifier extends AccountManagerNotifier {
  @override
  AccountManagerState build() => AccountManagerState(
    accounts: [
      SavedAccount(
        id: 'account-1',
        email: 'tester@example.com',
        nickname: '测试账号',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ],
  );
}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(status: AuthStatus.authenticated, accountId: 'account-1');
}
