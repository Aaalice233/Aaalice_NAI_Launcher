import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/constants/app_version.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/mobile_shell_overlay_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/router/app_router.dart';
import 'package:nai_launcher/presentation/router/shell_panels_overlay.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'NAI Launcher',
      packageName: 'nai_launcher',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await AppVersion.initialize();
  });

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
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/gallery',
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

    final shellOverlay = find.byType(ShellPanelsOverlay);
    expect(shellOverlay, findsOneWidget);
    container.read(shellPanelProvider.notifier).state = ShellPanel.queue;
    await tester.pumpAndSettle();
    final queuePointerGate = tester.widget<IgnorePointer>(
      find
          .descendant(of: shellOverlay, matching: find.byType(IgnorePointer))
          .first,
    );
    final queueTranslation = tester.widget<FractionalTranslation>(
      find
          .descendant(
            of: shellOverlay,
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

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(container.read(shellPanelProvider), isNull);

    await tester.tap(moreDestination);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mobile-more-agent')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mobile-more-agent')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(shellPanelProvider), ShellPanel.agent);
    expect(
      find.byKey(const ValueKey('agent-drawer-chat-panel')),
      findsOneWidget,
    );
    expect(_panelPointerGate(tester, shellOverlay).ignoring, isFalse);
    expect(find.byKey(const ValueKey('queue-shell-panel')), findsNothing);

    await tester.binding.setSurfaceSize(const Size(360, 640));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.getSize(find.byKey(const ValueKey('shell-panel-surface'))).width,
      360,
    );
    expect(tester.takeException(), isNull);

    final galleryDestination = find.byWidgetPredicate(
      (widget) => widget is NavigationDestination && widget.label == '图库',
    );
    await tester.tap(galleryDestination);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(shellPanelProvider), ShellPanel.agent);
    expect(
      find.byKey(const ValueKey('agent-drawer-chat-panel')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(moreDestination);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('mobile-more-queue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(shellPanelProvider), ShellPanel.queue);
    expect(_panelPointerGate(tester, shellOverlay).ignoring, isFalse);
    expect(find.byKey(const ValueKey('queue-shell-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-shell-panel')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(shellPanelProvider), isNull);

    await tester.tap(moreDestination);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('mobile-more-agent')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(shellPanelProvider), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('桌面智能体抽屉跨分支保持并由 Escape 关闭后恢复入口焦点', (tester) async {
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
                  builder: (context, state) => const SizedBox.expand(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/gallery',
                  builder: (context, state) => const SizedBox.expand(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.binding.setSurfaceSize(const Size(1200, 800));
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
    await tester.pump();

    final agentEntry = find.byKey(const Key('agent-nav-item'));
    final queueEntry = find.byKey(const Key('queue-nav-item'));
    await tester.tap(
      find.descendant(of: agentEntry, matching: find.byType(Icon)).first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(shellPanelProvider), ShellPanel.agent);
    expect(find.byKey(const ValueKey('agent-shell-panel')), findsOneWidget);
    final agentPanelElement = tester.element(
      find.byKey(const ValueKey('agent-drawer-chat-panel')),
    );
    expect(FocusScope.of(agentPanelElement).hasFocus, isTrue);
    container.read(agentChatNotifierProvider.notifier).setComposerText('跨分支草稿');
    expect(
      tester.getSize(find.byKey(const ValueKey('shell-panel-surface'))).width,
      520,
    );

    await tester.tap(find.byIcon(Icons.folder));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routeInformationProvider.value.uri.path, '/gallery');
    expect(container.read(shellPanelProvider), ShellPanel.agent);
    expect(
      tester.element(find.byKey(const ValueKey('agent-drawer-chat-panel'))),
      same(agentPanelElement),
    );
    expect(container.read(agentChatNotifierProvider).composerText, '跨分支草稿');

    await tester.tap(
      find.descendant(of: queueEntry, matching: find.byType(Icon)).first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(shellPanelProvider), ShellPanel.queue);
    expect(find.byKey(const ValueKey('queue-shell-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-shell-panel')), findsNothing);

    await tester.tap(
      find.descendant(of: agentEntry, matching: find.byType(Icon)).first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(shellPanelProvider), ShellPanel.agent);
    expect(find.byKey(const ValueKey('queue-shell-panel')), findsNothing);
    expect(find.byKey(const ValueKey('agent-shell-panel')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(shellPanelProvider), isNull);
    final agentInkWell = tester.widget<InkWell>(
      find.descendant(of: agentEntry, matching: find.byType(InkWell)),
    );
    expect(agentInkWell.focusNode?.hasFocus, isTrue);

    await tester.tap(
      find.descendant(of: agentEntry, matching: find.byType(Icon)).first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.element(find.byKey(const ValueKey('agent-drawer-chat-panel'))),
      same(agentPanelElement),
    );
    expect(container.read(agentChatNotifierProvider).composerText, '跨分支草稿');

    await tester.tap(find.byKey(const ValueKey('shell-panel-scrim')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(shellPanelProvider), isNull);
    expect(agentInkWell.focusNode?.hasFocus, isTrue);
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

IgnorePointer _panelPointerGate(WidgetTester tester, Finder overlay) {
  return tester.widget<IgnorePointer>(
    find.descendant(of: overlay, matching: find.byType(IgnorePointer)).first,
  );
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
