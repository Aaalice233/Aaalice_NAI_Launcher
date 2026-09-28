import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/constants/app_version.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/core/windowing/desktop_window_controller.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/router/app_shell.dart';
import 'package:nai_launcher/presentation/widgets/common/desktop_window_frame.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';

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

  testWidgets('最小化尺寸不切换 MainShell 或销毁当前路由状态', (tester) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    addTearDown(() => PlatformCapabilities.debugOverride = null);
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final lifecycle = _RouteProbeLifecycle();
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
      initialLocation: '/detail',
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
                  routes: [
                    GoRoute(
                      path: 'detail',
                      builder: (context, state) => _RouteStateProbe(lifecycle),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => DesktopWindowFrame(
            enabled: true,
            controller: _NoopDesktopWindowController(),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DesktopShell), findsOneWidget);
    expect(find.byType(MobileShell), findsNothing);
    expect(lifecycle.initCalls, 1);
    expect(router.routeInformationProvider.value.uri.path, '/detail');

    for (final size in [Size.zero, const Size(144, 19)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pump();
      expect(find.byType(DesktopShell), findsOneWidget);
      expect(find.byType(MobileShell), findsNothing);
      expect(lifecycle.initCalls, 1);
      expect(lifecycle.disposeCalls, 0);
      expect(router.routeInformationProvider.value.uri.path, '/detail');
      expect(tester.takeException(), isNull);
    }

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('route-state-probe')));
    await tester.pump();

    expect(lifecycle.initCalls, 1);
    expect(lifecycle.disposeCalls, 0);
    expect(lifecycle.tapCalls, 1);
    expect(router.routeInformationProvider.value.uri.path, '/detail');
    expect(tester.takeException(), isNull);
  });
}

class _RouteProbeLifecycle {
  int initCalls = 0;
  int disposeCalls = 0;
  int tapCalls = 0;
}

class _RouteStateProbe extends StatefulWidget {
  const _RouteStateProbe(this.lifecycle);

  final _RouteProbeLifecycle lifecycle;

  @override
  State<_RouteStateProbe> createState() => _RouteStateProbeState();
}

class _RouteStateProbeState extends State<_RouteStateProbe> {
  @override
  void initState() {
    super.initState();
    widget.lifecycle.initCalls++;
  }

  @override
  void dispose() {
    widget.lifecycle.disposeCalls++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        key: const ValueKey('route-state-probe'),
        onPressed: () => widget.lifecycle.tapCalls++,
        child: const Text('detail'),
      ),
    );
  }
}

class _NoopDesktopWindowController implements DesktopWindowController {
  @override
  void addListener(WindowListener listener) {}

  @override
  void removeListener(WindowListener listener) {}

  @override
  Future<bool> isMaximized() async => false;

  @override
  Future<void> startDragging() async {}

  @override
  Future<void> minimize() async {}

  @override
  Future<void> maximize() async {}

  @override
  Future<void> unmaximize() async {}

  @override
  Future<void> close() async {}
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
