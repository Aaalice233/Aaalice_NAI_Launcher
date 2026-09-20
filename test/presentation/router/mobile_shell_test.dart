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

  testWidgets('底栏重按当前 Tab 回到分支根，切换 Tab 仍恢复该分支上次位置', (tester) async {
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
    final router = _buildRouter();
    addTearDown(router.dispose);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 820);
    addTearDown(tester.view.reset);

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

    const galleryIndex = 1; // AppBranch.localGallery
    expect(AppBranch.localGallery.index, galleryIndex);

    // 进入图库分支的深层子页。
    router.go('/branch/$galleryIndex/detail');
    await tester.pumpAndSettle();
    expect(find.text('branch-$galleryIndex-detail'), findsOneWidget);

    // 重按已选中的图库 Tab：上游只有 goBranch(index)，这里应回到分支根。
    await tester.tap(find.byIcon(Icons.photo_library));
    await tester.pumpAndSettle();
    expect(find.text('branch-$galleryIndex-root'), findsOneWidget);
    expect(find.text('branch-$galleryIndex-detail'), findsNothing);

    // 切换到别的 Tab 再切回来仍是上游语义：恢复该分支上次的位置。
    router.go('/branch/$galleryIndex/detail');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();
    expect(find.text('branch-0-root'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    expect(find.text('branch-$galleryIndex-detail'), findsOneWidget);
  });
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/branch/0',
    routes: [
      StatefulShellRoute(
        navigatorContainerBuilder: (context, navigationShell, children) =>
            MainShell(navigationShell: navigationShell, children: children),
        builder: (context, state, navigationShell) => navigationShell,
        branches: [
          for (final branch in AppBranch.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/branch/${branch.index}',
                  builder: (context, state) =>
                      Center(child: Text('branch-${branch.index}-root')),
                  routes: [
                    GoRoute(
                      path: 'detail',
                      builder: (context, state) =>
                          Center(child: Text('branch-${branch.index}-detail')),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    ],
  );
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
