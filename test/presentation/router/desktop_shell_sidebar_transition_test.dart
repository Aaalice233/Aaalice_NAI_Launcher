import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/app_version.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/version/version_info.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/providers/update_provider.dart';
import 'package:nai_launcher/presentation/router/desktop_shell.dart';
import 'package:nai_launcher/presentation/router/shell_panels_overlay.dart';
import 'package:nai_launcher/presentation/widgets/navigation/main_nav_rail.dart';
import 'package:nai_launcher/presentation/widgets/common/update_notice_banner.dart';
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

class _FakeUpdateNotifier extends UpdateStateNotifier {
  @override
  UpdateState build() => const UpdateState();

  void showNotice() {
    state = const UpdateState(
      status: UpdateStatus.available,
      notificationVisible: true,
      versionInfo: VersionInfo(
        version: '2.0.0',
        currentVersion: '1.0.0',
        isNewer: true,
      ),
    );
  }

  @override
  Future<void> remindLater({Duration? delay}) async {
    state = state.copyWith(notificationVisible: false);
  }
}

class _FakeAccountManagerNotifier extends AccountManagerNotifier {
  @override
  AccountManagerState build() => const AccountManagerState();
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

class _ContentLifecycle {
  int initialized = 0;
  int built = 0;
  int disposed = 0;
  final List<double> constraintWidths = [];

  void recordWidth(double width) {
    if (constraintWidths.isEmpty || constraintWidths.last != width) {
      constraintWidths.add(width);
    }
  }
}

class _TrackedContent extends StatefulWidget {
  const _TrackedContent({required this.lifecycle});

  final _ContentLifecycle lifecycle;

  @override
  State<_TrackedContent> createState() => _TrackedContentState();
}

class _TrackedContentState extends State<_TrackedContent> {
  int value = 0;

  @override
  void initState() {
    super.initState();
    widget.lifecycle.initialized++;
  }

  @override
  void dispose() {
    widget.lifecycle.disposed++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.lifecycle.built++;
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.lifecycle.recordWidth(constraints.maxWidth);
        return Center(
          child: FilledButton(
            key: const Key('tracked-content-button'),
            onPressed: () => setState(() => value++),
            child: Text('content-$value'),
          ),
        );
      },
    );
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

  testWidgets('侧栏跨 Medium 断点收起并保持路由主体状态', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final navigationShell = _MockNavigationShell();
    final storage = _FakeMainNavStorage();
    final lifecycle = _ContentLifecycle();
    final updates = _FakeUpdateNotifier();
    final textScaler = ValueNotifier<TextScaler>(TextScaler.noScaling);
    addTearDown(textScaler.dispose);
    when(() => navigationShell.currentIndex).thenReturn(0);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateStateNotifierProvider.overrideWith(() => updates),
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
          home: ValueListenableBuilder<TextScaler>(
            valueListenable: textScaler,
            builder: (context, scaler, _) => MediaQuery(
              data: MediaQueryData(
                padding: const EdgeInsets.only(top: 24, bottom: 16),
                textScaler: scaler,
              ),
              child: DesktopShell(
                navigationShell: navigationShell,
                content: _TrackedContent(lifecycle: lifecycle),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(lifecycle.initialized, 1);
    expect(lifecycle.built, 1);
    expect(lifecycle.constraintWidths, [840]);
    expect(find.text('content-0'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(MainNavRail)).dy, 24);
    expect(tester.getBottomRight(find.byType(MainNavRail)).dy, 584);

    final contentRect = tester.getRect(find.byType(_TrackedContent));
    updates.showNotice();
    await tester.pump();
    expect(find.text('新版本 v2.0.0 可用'), findsOneWidget);
    expect(tester.getRect(find.byType(_TrackedContent)), contentRect);
    expect(lifecycle.built, 1);
    await tester.tap(
      find.descendant(
        of: find.byType(UpdateNoticeBanner),
        matching: find.byIcon(Icons.close_rounded),
      ),
    );
    await tester.pump();
    expect(find.text('新版本 v2.0.0 可用'), findsNothing);
    expect(tester.getRect(find.byType(_TrackedContent)), contentRect);

    final secondaryScrollable = find.descendant(
      of: find.byKey(const Key('main-nav-secondary-scroll')),
      matching: find.byType(Scrollable),
    );
    expect(secondaryScrollable, findsOneWidget);
    tester
        .state<ScrollableState>(secondaryScrollable)
        .position
        .jumpTo(
          tester
              .state<ScrollableState>(secondaryScrollable)
              .position
              .maxScrollExtent,
        );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('main-nav-toggle')), findsOneWidget);
    await tester.tap(find.byKey(const Key('main-nav-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(lifecycle.built, 1);
    expect(lifecycle.constraintWidths, [
      840,
      704,
    ], reason: '导航动画期间工作区只接收最终约束，不逐帧触发布局重建');

    await tester.pump(const Duration(milliseconds: 40));
    expect(lifecycle.constraintWidths, [840, 704]);

    await tester.tap(find.byKey(const Key('tracked-content-button')));
    await tester.pump();
    expect(find.text('content-1'), findsOneWidget);
    expect(lifecycle.built, 2);

    await tester.pumpAndSettle();
    expect(storage.isExpanded, isTrue);
    expect(tester.getSize(find.byType(MainNavRail)).width, 196);

    await tester.binding.setSurfaceSize(const Size(700, 600));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('main-nav-toggle')), findsNothing);
    expect(tester.getSize(find.byType(MainNavRail)).width, 60);
    expect(find.text('content-1'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(900, 600));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('main-nav-toggle')), findsOneWidget);
    expect(tester.getSize(find.byType(MainNavRail)).width, 196);

    for (final width in [840.0, 1180.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final closedPrimaryRect = tester.getRect(
        find.byKey(const Key('desktop-primary-workspace')),
      );

      await tester.tap(find.byKey(const Key('queue-nav-item')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final queuePrimaryRect = tester.getRect(
        find.byKey(const Key('desktop-primary-workspace')),
      );
      final queuePanelRect = tester.getRect(
        find.byKey(const Key('shell-panel-surface')),
      );
      expect(queuePrimaryRect, closedPrimaryRect, reason: 'queue width=$width');
      expect(queuePanelRect.overlaps(queuePrimaryRect), isTrue);
      expect(queuePanelRect.right, closeTo(queuePrimaryRect.right, 0.01));
      expect(
        find.byKey(const Key('desktop-panel-overlay-layer')),
        findsOneWidget,
      );
      final workspaceStack = tester.widget<Stack>(
        find.byKey(const Key('desktop-workspace-stack')),
      );
      expect(
        workspaceStack.children.last.key,
        const ValueKey('desktop-panel-overlay-layer'),
      );
      expect(find.byKey(const Key('shell-panel-scrim')), findsNothing);

      await tester.tap(find.byKey(const Key('queue-nav-item')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final hiddenPointerGate = tester.widget<IgnorePointer>(
        find
            .descendant(
              of: find.byType(ShellPanelsOverlay),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(hiddenPointerGate.ignoring, isTrue);
      expect(
        tester.getRect(find.byKey(const Key('desktop-primary-workspace'))),
        closedPrimaryRect,
      );

      await tester.tap(find.byKey(const Key('agent-nav-item')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final agentPrimaryRect = tester.getRect(
        find.byKey(const Key('desktop-primary-workspace')),
      );
      final agentPanelRect = tester.getRect(
        find.byKey(const Key('shell-panel-surface')),
      );
      expect(agentPrimaryRect, closedPrimaryRect, reason: 'agent width=$width');
      expect(agentPanelRect.overlaps(agentPrimaryRect), isTrue);
      expect(agentPanelRect.right, closeTo(agentPrimaryRect.right, 0.01));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.getRect(find.byKey(const Key('desktop-primary-workspace'))),
        closedPrimaryRect,
      );
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
    await tester.binding.setSurfaceSize(const Size(900, 600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    textScaler.value = const TextScaler.linear(3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(find.byType(MainNavRail)).width, 280);
    expect(
      tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .every((tooltip) => tooltip.message?.isNotEmpty ?? true),
      isTrue,
    );
    expect(lifecycle.initialized, 1);
    expect(lifecycle.built, greaterThanOrEqualTo(2));
    expect(lifecycle.disposed, 0);
    expect(tester.takeException(), isNull);
  });
}
