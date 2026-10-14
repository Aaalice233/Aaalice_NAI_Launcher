import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/constants/app_version.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/data/services/account_manager_provider.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/router/app_branch.dart';
import 'package:nai_launcher/presentation/router/app_shell.dart';
import 'package:nai_launcher/presentation/widgets/shortcuts/shortcut_aware_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _Harness {
  _Harness(this.tester, this.router, this.container);

  final WidgetTester tester;
  final GoRouter router;
  final ProviderContainer container;
  int generations = 0;
  int refreshes = 0;

  String get location => router.routerDelegate.currentConfiguration.uri.path;

  Future<void> go(AppBranch branch) async {
    router.go(_path(branch));
    await tester.pumpAndSettle();
  }

  Future<void> press(LogicalKeyboardKey key, {bool control = false}) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  Future<void> pressGenerate() =>
      press(LogicalKeyboardKey.enter, control: true);

  Future<void> pressRefresh() => press(LogicalKeyboardKey.f5);
}

String _path(AppBranch branch) => '/branch/${branch.index}';

Widget _stubPage(
  AppBranch branch,
  ShortcutContext contextType,
  String shortcutId,
  VoidCallback onShortcut,
) {
  return Material(
    child: PageShortcuts(
      contextType: contextType,
      shortcuts: {shortcutId: onShortcut},
      child: Column(
        children: [
          SizedBox(
            width: 240,
            child: TextField(key: ValueKey('field-${branch.name}')),
          ),
          Expanded(
            child: SizedBox.expand(key: ValueKey('blank-${branch.name}')),
          ),
          TextButton(onPressed: () {}, child: Text('last-${branch.name}')),
        ],
      ),
    ),
  );
}

Future<_Harness> _pumpShell(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      accountManagerNotifierProvider.overrideWith(_TestAccountManager.new),
      authNotifierProvider.overrideWith(_UnauthenticatedAuth.new),
      shortcutConfigNotifierProvider.overrideWith(_DefaultShortcutConfig.new),
    ],
  );
  addTearDown(container.dispose);
  late final _Harness harness;
  final router = GoRouter(
    initialLocation: _path(AppBranch.generation),
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
                  path: _path(branch),
                  builder: (context, state) => switch (branch) {
                    AppBranch.generation => _stubPage(
                      branch,
                      ShortcutContext.generation,
                      ShortcutIds.generateImage,
                      () => harness.generations++,
                    ),
                    AppBranch.localGallery => _stubPage(
                      branch,
                      ShortcutContext.gallery,
                      ShortcutIds.refreshGallery,
                      () => harness.refreshes++,
                    ),
                    _ => const SizedBox.expand(),
                  },
                ),
              ],
            ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  harness = _Harness(tester, router, container);

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1400, 900);
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
  return harness;
}

FocusNode _focusOf(WidgetTester tester, Finder finder) =>
    Focus.of(tester.element(finder));

bool _focusInside(WidgetTester tester, Finder finder) {
  final primaryContext = FocusManager.instance.primaryFocus?.context;
  if (primaryContext == null) return false;
  final target = tester.element(finder);
  var inside = false;
  primaryContext.visitAncestorElements((element) {
    inside = identical(element, target);
    return !inside;
  });
  return inside || identical(primaryContext, target);
}

final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);

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

  testWidgets('切回已访问的分支后页面快捷键可用，隐藏分支的快捷键不触发', (tester) async {
    final harness = await _pumpShell(tester);
    await harness.go(AppBranch.localGallery);
    await harness.go(AppBranch.generation);

    await harness.pressGenerate();
    await harness.pressRefresh();
    expect(harness.generations, 1);
    expect(harness.refreshes, 0);

    await harness.go(AppBranch.localGallery);
    await harness.pressRefresh();
    await harness.pressGenerate();
    expect(harness.refreshes, 1);
    expect(harness.generations, 1);
  });

  testWidgets('关闭外壳面板后焦点回到当前页面', (tester) async {
    final harness = await _pumpShell(tester);

    harness.container.read(shellPanelProvider.notifier).state =
        ShellPanel.queue;
    await tester.pumpAndSettle();
    harness.container.read(shellPanelProvider.notifier).state = null;
    await tester.pumpAndSettle();

    await harness.pressGenerate();
    expect(harness.generations, 1);
  });

  testWidgets('离开时停在输入框的分支切回后不重新聚焦输入框，页面快捷键可用', (tester) async {
    final harness = await _pumpShell(tester);
    await harness.go(AppBranch.localGallery);
    final field = find.byKey(const ValueKey('field-localGallery'));
    await tester.tap(field, kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(_focusInside(tester, field), isTrue);

    await harness.go(AppBranch.generation);
    await harness.go(AppBranch.localGallery);

    expect(_focusInside(tester, field), isFalse);
    await harness.pressRefresh();
    expect(harness.refreshes, 1);
  }, variant: _desktop);

  testWidgets('焦点在导航栏时切换分支不把焦点抢回页面', (tester) async {
    final harness = await _pumpShell(tester);
    await harness.go(AppBranch.localGallery);
    final navItem = _focusOf(
      tester,
      find
          .descendant(
            of: find.byKey(const ValueKey('nav-branch-0')),
            matching: find.byType(Icon),
          )
          .first,
    );
    navItem.requestFocus();
    await tester.pump();
    expect(navItem.hasPrimaryFocus, isTrue);

    await harness.go(AppBranch.generation);

    expect(navItem.hasPrimaryFocus, isTrue);
  });

  testWidgets('Tab 能从页面末尾离开分支进入导航栏', (tester) async {
    await _pumpShell(tester);
    _focusOf(tester, find.text('last-generation')).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(
      _focusInside(tester, find.byKey(const ValueKey('main-nav-rail'))),
      isTrue,
    );
  });

  testWidgets('焦点在页面内时外壳的导航快捷键仍然生效', (tester) async {
    final harness = await _pumpShell(tester);

    await harness.press(LogicalKeyboardKey.digit2, control: true);

    expect(harness.location, _path(AppBranch.localGallery));
  });
}

class _TestAccountManager extends AccountManagerNotifier {
  @override
  AccountManagerState build() => const AccountManagerState();
}

class _UnauthenticatedAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _DefaultShortcutConfig extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}
