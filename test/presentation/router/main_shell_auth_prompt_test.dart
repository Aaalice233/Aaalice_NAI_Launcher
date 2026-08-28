import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/mobile_shell_overlay_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/router/app_router.dart';
import 'package:nai_launcher/presentation/router/queue_shell_overlay.dart';

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

  testWidgets('认证恢复提示在桌面和手机保持紧凑并可关闭', (tester) async {
    final container = ProviderContainer(
      overrides: [
        accountManagerNotifierProvider.overrideWith(
          _TestAccountManagerNotifier.new,
        ),
        authNotifierProvider.overrideWith(_ErrorAuthNotifier.new),
        shortcutConfigNotifierProvider.overrideWith(
          _TestShortcutConfigNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

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

    await tester.binding.setSurfaceSize(const Size(1580, 900));
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

    expect(find.byType(DesktopShell), findsOneWidget);
    expect(find.byType(MobileShell), findsNothing);
    final banner = find.byKey(const ValueKey('auth-recovery-banner'));
    expect(banner, findsOneWidget);
    expect(tester.getSize(banner).width, lessThanOrEqualTo(440));
    expect(tester.getSize(banner).height, lessThan(72));
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(390, 820));
    await tester.pumpAndSettle();
    expect(find.byType(DesktopShell), findsNothing);
    expect(find.byType(MobileShell), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.getSize(banner).width, lessThanOrEqualTo(366));
    expect(tester.getSize(banner).height, lessThan(120));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('auth-recovery-dismiss')));
    await tester.pumpAndSettle();
    expect(banner, findsNothing);

    final moreDestination = find.byWidgetPredicate(
      (widget) => widget is NavigationDestination && widget.label == '更多',
    );
    await tester.tap(moreDestination);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mobile-more-discord')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-more-github')), findsOneWidget);
    expect(tester.takeException(), isNull);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mobile-more-discord')), findsNothing);

    final queueOverlay = find.byType(QueueShellOverlay);
    expect(queueOverlay, findsOneWidget);
    container.read(queueManagementVisibleProvider.notifier).state = true;
    await tester.pumpAndSettle();
    final queuePointerGate = tester.widget<IgnorePointer>(
      find
          .descendant(of: queueOverlay, matching: find.byType(IgnorePointer))
          .first,
    );
    final queueTranslation = tester.widget<FractionalTranslation>(
      find
          .descendant(
            of: queueOverlay,
            matching: find.byType(FractionalTranslation),
          )
          .first,
    );
    expect(queuePointerGate.ignoring, isFalse);
    expect(queueTranslation.translation, Offset.zero);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('MainShell 将系统返回交给当前分支的 PopScope', (tester) async {
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
                  builder: (context, state) => const _BranchDetailPage(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.binding.setSurfaceSize(const Size(390, 820));
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

    expect(find.byType(NavigationBar), findsOneWidget);
    container
        .read(mobileShellOverlayNotifierProvider.notifier)
        .setActive(MobileShellOverlay.agentChat, true);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    container
        .read(mobileShellOverlayNotifierProvider.notifier)
        .setActive(MobileShellOverlay.agentChat, false);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('打开详情'));
    await tester.pumpAndSettle();
    expect(find.text('分支详情'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('分支详情'), findsNothing);
    expect(find.text('打开详情'), findsOneWidget);
  });
}

class _BranchDetailPage extends StatefulWidget {
  const _BranchDetailPage();

  @override
  State<_BranchDetailPage> createState() => _BranchDetailPageState();
}

class _BranchDetailPageState extends State<_BranchDetailPage> {
  bool _showDetail = false;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !_showDetail,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showDetail) {
          setState(() => _showDetail = false);
        }
      },
      child: Center(
        child: _showDetail
            ? const Text('分支详情')
            : FilledButton(
                onPressed: () => setState(() => _showDetail = true),
                child: const Text('打开详情'),
              ),
      ),
    );
  }
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

class _ErrorAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.error,
    errorCode: AuthErrorCode.authFailed,
    httpStatusCode: 401,
  );
}
