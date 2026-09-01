import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/router/app_branch.dart';
import 'package:nai_launcher/presentation/router/app_shell.dart';

void main() {
  testWidgets('MainShell retains visited branches and pauses hidden work', (
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

    expect(lifecycle[AppBranch.generation]!.created, 1);
    for (final branch in AppBranch.values.skip(1)) {
      expect(
        lifecycle[branch]!.created,
        0,
        reason: '${branch.name} must stay lazy until first navigation',
      );
    }

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
