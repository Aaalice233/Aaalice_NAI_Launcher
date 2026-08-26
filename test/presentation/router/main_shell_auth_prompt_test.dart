import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/router/app_router.dart';

void main() {
  testWidgets('MainShell 消费启动前 pending 提示并顺序处理后续提示', (tester) async {
    final container = ProviderContainer(
      overrides: [
        accountManagerNotifierProvider.overrideWith(
          _TestAccountManagerNotifier.new,
        ),
        authNotifierProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
        shortcutConfigNotifierProvider.overrideWith(
          _TestShortcutConfigNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    final promptNotifier = container.read(authPromptRequestProvider.notifier);
    promptNotifier.publish(AuthPromptReason.kritaBridge);

    final router = GoRouter(
      routes: [
        StatefulShellRoute(
          navigatorContainerBuilder: (context, navigationShell, children) {
            return MainShell(
              navigationShell: navigationShell,
              children: children,
            );
          },
          builder: (context, state, navigationShell) => navigationShell,
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const SizedBox.expand(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.binding.setSurfaceSize(const Size(600, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('请先登录，再通过 Krita Bridge 生成图片。'), findsOneWidget);

    promptNotifier.publish(AuthPromptReason.vibeEncoding);
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('请先登录，再通过 Krita Bridge 生成图片。'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('请先登录，再使用 NovelAI 编码 Vibe 图片。'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(container.read(authPromptRequestProvider), isNull);

    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
  });
}

class _TestAccountManagerNotifier extends AccountManagerNotifier {
  @override
  AccountManagerState build() => const AccountManagerState();
}

class _TestShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}
