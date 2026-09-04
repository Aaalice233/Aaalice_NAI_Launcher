import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/constants/app_version.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/router/app_branch.dart';
import 'package:nai_launcher/presentation/router/app_shell.dart';
import 'package:nai_launcher/presentation/router/shell_panels_overlay.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Aaalice NAI Launcher',
      packageName: 'nai_launcher',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await AppVersion.initialize();
  });

  testWidgets('MainShell retains visited branches and adaptive panel state', (
    tester,
  ) async {
    final lifecycle = <AppBranch, _BranchLifecycle>{
      for (final branch in AppBranch.values) branch: _BranchLifecycle(),
    };
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
    final router = _buildRouter(lifecycle);
    addTearDown(router.dispose);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 820);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(lifecycle[AppBranch.generation]!.created, 1);
    for (final branch in AppBranch.values.skip(1)) {
      expect(
        lifecycle[branch]!.created,
        0,
        reason: '${branch.name} must stay lazy until first navigation',
      );
    }

    container.read(shellPanelProvider.notifier).state = ShellPanel.queue;
    await tester.pumpAndSettle();
    final overlayState = tester.state(find.byType(ShellPanelsOverlay));
    tester.widget<TabBar>(find.byType(TabBar)).controller!.animateTo(1);
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(1200, 820);
    await tester.pumpAndSettle();
    expect(
      MediaQuery.sizeOf(tester.element(find.byType(MainShell))).width,
      1200,
    );
    expect(find.byType(DesktopShell), findsOneWidget);
    expect(tester.state(find.byType(ShellPanelsOverlay)), same(overlayState));
    expect(
      tester
          .widget<ShellPanelsOverlay>(find.byType(ShellPanelsOverlay))
          .desktop,
      isTrue,
    );
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    expect(lifecycle[AppBranch.generation]!.created, 1);
    expect(lifecycle[AppBranch.generation]!.disposed, 0);

    tester.view.physicalSize = const Size(390, 820);
    await tester.pumpAndSettle();
    expect(find.byType(MobileShell), findsOneWidget);
    expect(tester.state(find.byType(ShellPanelsOverlay)), same(overlayState));
    expect(lifecycle[AppBranch.generation]!.created, 1);
    expect(lifecycle[AppBranch.generation]!.disposed, 0);
    container.read(shellPanelProvider.notifier).state = null;
    await tester.pumpAndSettle();

    for (final branch in keptAliveAppBranches) {
      router.go('/branch/${branch.index}');
      await tester.pumpAndSettle();
      final fallback = branch == AppBranch.generation
          ? AppBranch.localGallery
          : AppBranch.generation;
      router.go('/branch/${fallback.index}');
      await tester.pumpAndSettle();

      expect(lifecycle[branch]!.created, 1, reason: branch.name);
      expect(lifecycle[branch]!.disposed, 0, reason: branch.name);
      final tickerModes = tester.widgetList<TickerMode>(
        find.ancestor(
          of: find.byKey(
            ValueKey('branch-${branch.index}'),
            skipOffstage: false,
          ),
          matching: find.byType(TickerMode, skipOffstage: false),
        ),
      );
      expect(
        tickerModes.any((tickerMode) => !tickerMode.enabled),
        isTrue,
        reason: branch.name,
      );
    }

    for (final branch in AppBranch.values) {
      expect(lifecycle[branch]!.created, 1, reason: branch.name);
      expect(lifecycle[branch]!.disposed, 0, reason: branch.name);
      expect(
        find.byKey(ValueKey('branch-${branch.index}'), skipOffstage: false),
        findsOneWidget,
        reason: branch.name,
      );
    }
  });
}

GoRouter _buildRouter(Map<AppBranch, _BranchLifecycle> lifecycle) {
  return GoRouter(
    initialLocation: '/branch/0',
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
          for (final branch in AppBranch.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/branch/${branch.index}',
                  builder: (context, state) => _TrackedBranch(
                    key: ValueKey('branch-${branch.index}'),
                    lifecycle: lifecycle[branch]!,
                  ),
                ),
              ],
            ),
        ],
      ),
    ],
  );
}

class _BranchLifecycle {
  int created = 0;
  int disposed = 0;
}

class _TrackedBranch extends StatefulWidget {
  const _TrackedBranch({super.key, required this.lifecycle});

  final _BranchLifecycle lifecycle;

  @override
  State<_TrackedBranch> createState() => _TrackedBranchState();
}

class _TrackedBranchState extends State<_TrackedBranch> {
  @override
  void initState() {
    super.initState();
    widget.lifecycle.created++;
  }

  @override
  void dispose() {
    widget.lifecycle.disposed++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _TestAccountManagerNotifier extends AccountManagerNotifier {
  @override
  AccountManagerState build() => const AccountManagerState();
}

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _TestShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}
