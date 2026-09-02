import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/app_version.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/auth/saved_account.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/widgets/navigation/main_nav_rail.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _MockNavigationShell extends Mock implements StatefulNavigationShell {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockNavigationShell';
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

class _FakeAccountManagerNotifier extends AccountManagerNotifier {
  @override
  AccountManagerState build() => const AccountManagerState();
}

class _SavedAccountManagerNotifier extends AccountManagerNotifier {
  @override
  AccountManagerState build() => AccountManagerState(
    accounts: [
      SavedAccount.create(email: 'saved@example.com', nickname: 'Saved Alice'),
    ],
  );
}

class _FakeQueueExecutionNotifier extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() => const QueueExecutionState();
}

class _FakeReplicationQueueNotifier extends ReplicationQueueNotifier {
  @override
  ReplicationQueueState build() => const ReplicationQueueState();
}

class _FakeMainNavStorage extends LocalStorageService {
  bool isExpanded = false;

  @override
  bool getMainNavRailExpanded() => isExpanded;

  @override
  Future<void> setMainNavRailExpanded(bool expanded) async {
    isExpanded = expanded;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('600px 高度下主导航可滚动且不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final navigationShell = _MockNavigationShell();
    final storage = _FakeMainNavStorage();
    when(() => navigationShell.currentIndex).thenReturn(0);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          accountManagerNotifierProvider.overrideWith(
            _FakeAccountManagerNotifier.new,
          ),
          queueExecutionNotifierProvider.overrideWith(
            _FakeQueueExecutionNotifier.new,
          ),
          replicationQueueNotifierProvider.overrideWith(
            _FakeReplicationQueueNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MainNavRail(navigationShell: navigationShell)),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('main-nav-primary-scroll')), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_double_arrow_right), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const Key('main-nav-toggle'))).dy,
      greaterThan(tester.getCenter(find.byIcon(Icons.settings)).dy),
    );
    expect(
      tester.getSize(find.byKey(const Key('main-nav-rail'))).width,
      MainNavRail.collapsedWidth,
    );
    expect(_labelOpacity(tester, '画布'), 0);

    final agentIcon = find.byIcon(Icons.smart_toy_outlined);
    final agentTooltip = find.ancestor(
      of: agentIcon,
      matching: find.byType(Tooltip),
    );
    expect(agentTooltip, findsOneWidget);
    expect(tester.getSize(agentTooltip), const Size.square(48));
    expect(tester.getCenter(agentTooltip), tester.getCenter(agentIcon));
    final tooltip = tester.widget<Tooltip>(agentTooltip);
    expect(tooltip.message, '智能体');
    expect(tooltip.verticalOffset, 24);

    await tester.scrollUntilVisible(
      find.byKey(const Key('main-nav-toggle')),
      120,
      scrollable: find.descendant(
        of: find.byKey(const Key('main-nav-secondary-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const Key('main-nav-toggle')));
    await tester.pumpAndSettle();

    expect(storage.isExpanded, isTrue);
    expect(
      tester.getSize(find.byKey(const Key('main-nav-rail'))).width,
      MainNavRail.expandedWidth,
    );
    expect(find.text('画布'), findsOneWidget);
    expect(find.text('本地图库'), findsOneWidget);
    expect(find.text('在线画廊'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('Discord 社群'), findsOneWidget);
    expect(find.text('GitHub 仓库'), findsOneWidget);
    expect(find.text('智能体'), findsOneWidget);
    expect(find.text('队列管理'), findsOneWidget);
    expect(find.text('收起侧边栏'), findsOneWidget);
    expect(find.text('v${AppVersion.versionName}'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_double_arrow_left), findsOneWidget);

    await tester.tap(find.byKey(const Key('main-nav-toggle')));
    await tester.pumpAndSettle();

    expect(storage.isExpanded, isFalse);
    expect(
      tester.getSize(find.byKey(const Key('main-nav-rail'))).width,
      MainNavRail.collapsedWidth,
    );
    expect(_labelOpacity(tester, '画布'), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('高侧栏下次级操作组锚定底部', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAuthenticatedRail(tester);

    final railBottom = tester
        .getBottomRight(find.byKey(const Key('main-nav-rail')))
        .dy;
    final toggleBottom = tester
        .getBottomRight(find.byKey(const Key('main-nav-toggle')))
        .dy;
    expect(toggleBottom, closeTo(railBottom - 6, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('展开动画保持内容布局稳定且快速反向切换连续', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final navigationShell = _MockNavigationShell();
    final storage = _FakeMainNavStorage();
    when(() => navigationShell.currentIndex).thenReturn(0);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          accountManagerNotifierProvider.overrideWith(
            _FakeAccountManagerNotifier.new,
          ),
          queueExecutionNotifierProvider.overrideWith(
            _FakeQueueExecutionNotifier.new,
          ),
          replicationQueueNotifierProvider.overrideWith(
            _FakeReplicationQueueNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MainNavRail(navigationShell: navigationShell)),
        ),
      ),
    );
    await tester.pump();

    final collapsedIconCenter = tester.getCenter(find.byIcon(Icons.brush));
    await tester.tap(find.byKey(const Key('main-nav-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final expandingWidth = _railWidth(tester);
    expect(
      expandingWidth,
      inExclusiveRange(MainNavRail.collapsedWidth, MainNavRail.expandedWidth),
    );
    expect(_railContentWidth(tester), MainNavRail.expandedWidth);
    expect(tester.getCenter(find.byIcon(Icons.brush)), collapsedIconCenter);
    final sharedLabelAnimation = _labelFade(tester, '画布').opacity;
    final sharedFadeCount = tester
        .widgetList<FadeTransition>(
          find.byType(FadeTransition, skipOffstage: false),
        )
        .where((fade) => identical(fade.opacity, sharedLabelAnimation))
        .length;
    expect(sharedFadeCount, greaterThan(5));
    expect(find.byType(AnimatedOpacity), findsNothing);

    await tester.tap(find.byKey(const Key('main-nav-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final reversingWidth = _railWidth(tester);
    expect(reversingWidth, lessThan(expandingWidth));

    await tester.tap(find.byKey(const Key('main-nav-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(_railWidth(tester), greaterThan(reversingWidth));
    expect(_railContentWidth(tester), MainNavRail.expandedWidth);
    expect(tester.getCenter(find.byIcon(Icons.brush)), collapsedIconCenter);

    await tester.pumpAndSettle();
    expect(_railWidth(tester), MainNavRail.expandedWidth);
    expect(_labelOpacity(tester, '画布'), 1);
    expect(storage.isExpanded, isTrue);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('main-nav-toggle')));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('disableAnimations 下切换首帧到达终态', (tester) async {
    await tester.binding.setSurfaceSize(const Size(620, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final navigationShell = _MockNavigationShell();
    final storage = _FakeMainNavStorage();
    when(() => navigationShell.currentIndex).thenReturn(1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          accountManagerNotifierProvider.overrideWith(
            _FakeAccountManagerNotifier.new,
          ),
          queueExecutionNotifierProvider.overrideWith(
            _FakeQueueExecutionNotifier.new,
          ),
          replicationQueueNotifierProvider.overrideWith(
            _FakeReplicationQueueNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(620, 600),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: MainNavRail(navigationShell: navigationShell),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final selectedBefore = tester.widget<Icon>(find.byIcon(Icons.folder)).color;
    await tester.scrollUntilVisible(
      find.byKey(const Key('main-nav-toggle')),
      120,
      scrollable: find.descendant(
        of: find.byKey(const Key('main-nav-secondary-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const Key('main-nav-toggle')));
    await tester.pump();

    expect(_railWidth(tester), MainNavRail.expandedWidth);
    expect(_labelOpacity(tester, '画布'), 1);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.folder)).color,
      selectedBefore,
    );
    verifyNever(() => navigationShell.goBranch(any()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px、3x 字号、IME 与 SafeArea 下添加账号表单可滚动并正确返回', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mediaQuery = ValueNotifier(
      const MediaQueryData(
        size: Size(320, 900),
        padding: EdgeInsets.fromLTRB(12, 24, 12, 20),
        viewPadding: EdgeInsets.fromLTRB(12, 24, 12, 20),
      ),
    );
    addTearDown(mediaQuery.dispose);
    await _pumpAuthenticatedRail(tester, mediaQuery: mediaQuery);
    await _openAddAccountForm(tester);

    final surface = find.byKey(const ValueKey('adaptive-full-screen-form'));
    expect(surface, findsOneWidget);
    expect(find.byKey(const Key('main-nav-add-account-form')), findsOneWidget);
    var rect = tester.getRect(surface);
    expect(rect.left, greaterThanOrEqualTo(12));
    expect(rect.top, greaterThanOrEqualTo(24));
    expect(rect.right, lessThanOrEqualTo(308));
    expect(rect.bottom, lessThanOrEqualTo(880));
    expect(
      tester.widget<ListView>(find.byType(ListView).last).controller,
      isNotNull,
    );
    expect(tester.takeException(), isNull);

    mediaQuery.value = mediaQuery.value.copyWith(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
      viewInsets: const EdgeInsets.only(bottom: 260),
      textScaler: const TextScaler.linear(3),
    );
    await tester.pumpAndSettle();

    rect = tester.getRect(surface);
    expect(rect.top, greaterThanOrEqualTo(24));
    expect(rect.bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
  });

  for (final width in <double>[700, 1000]) {
    testWidgets('${width.toInt()}px 下添加账号表单保持有界', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mediaQuery = ValueNotifier(MediaQueryData(size: Size(width, 760)));
      addTearDown(mediaQuery.dispose);
      await _pumpAuthenticatedRail(tester, mediaQuery: mediaQuery);
      await _openAddAccountForm(tester);

      final surfaceKey = width < 840
          ? const ValueKey('adaptive-centered-form')
          : const ValueKey('adaptive-side-sheet');
      final surface = find.byKey(surfaceKey);
      expect(surface, findsOneWidget);
      expect(tester.getSize(surface).width, lessThanOrEqualTo(450));
      expect(tester.getSize(surface).width, lessThan(width));
      expect(
        find.byKey(const Key('main-nav-add-account-form')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('未认证时侧栏及账号菜单不显示本地保存身份', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final navigationShell = _MockNavigationShell();
    final storage = _FakeMainNavStorage()..isExpanded = true;
    when(() => navigationShell.currentIndex).thenReturn(0);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          accountManagerNotifierProvider.overrideWith(
            _SavedAccountManagerNotifier.new,
          ),
          queueExecutionNotifierProvider.overrideWith(
            _FakeQueueExecutionNotifier.new,
          ),
          replicationQueueNotifierProvider.overrideWith(
            _FakeReplicationQueueNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MainNavRail(navigationShell: navigationShell)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved Alice'), findsNothing);
    expect(find.text('登录'), findsOneWidget);

    await tester.tap(find.byKey(const Key('main-nav-account-menu-button')));
    await tester.pumpAndSettle();

    expect(find.text('Saved Alice'), findsNothing);
    expect(find.text('登录'), findsNWidgets(2));
    expect(find.text('添加账号'), findsNothing);
  });
}

Future<void> _pumpAuthenticatedRail(
  WidgetTester tester, {
  ValueNotifier<MediaQueryData>? mediaQuery,
}) async {
  final navigationShell = _MockNavigationShell();
  final storage = _FakeMainNavStorage()..isExpanded = true;
  when(() => navigationShell.currentIndex).thenReturn(0);

  final rail = Scaffold(body: MainNavRail(navigationShell: navigationShell));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWith((ref) => storage),
        authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        accountManagerNotifierProvider.overrideWith(
          _FakeAccountManagerNotifier.new,
        ),
        queueExecutionNotifierProvider.overrideWith(
          _FakeQueueExecutionNotifier.new,
        ),
        replicationQueueNotifierProvider.overrideWith(
          _FakeReplicationQueueNotifier.new,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: mediaQuery == null
            ? null
            : (context, child) => ValueListenableBuilder<MediaQueryData>(
                valueListenable: mediaQuery,
                builder: (context, data, _) =>
                    MediaQuery(data: data, child: child!),
              ),
        home: rail,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openAddAccountForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('main-nav-account-menu-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('添加账号'));
  await tester.pumpAndSettle();
}

double _railWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(const Key('main-nav-rail'))).width;

double _railContentWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(const Key('main-nav-rail-content'))).width;

FadeTransition _labelFade(WidgetTester tester, String label) {
  final fade = find.ancestor(
    of: find.text(label),
    matching: find.byType(FadeTransition),
  );
  return tester.widget<FadeTransition>(fade.first);
}

double _labelOpacity(WidgetTester tester, String label) =>
    _labelFade(tester, label).opacity.value;
