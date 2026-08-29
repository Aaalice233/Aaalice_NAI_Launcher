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
