import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/app_version.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/router/desktop_shell.dart';
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
    return Center(
      child: FilledButton(
        key: const Key('tracked-content-button'),
        onPressed: () => setState(() => value++),
        child: Text('content-$value'),
      ),
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
    final textScaler = ValueNotifier<TextScaler>(TextScaler.noScaling);
    addTearDown(textScaler.dispose);
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
    expect(find.text('content-0'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(MainNavRail)).dy, 24);
    expect(tester.getBottomRight(find.byType(MainNavRail)).dy, 584);

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

    await tester.tap(find.byKey(const Key('queue-nav-item')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shell-panel-scrim')), findsNothing);
    for (final width in [840.0, 1180.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 600));
      await tester.pumpAndSettle();
      final primaryRect = tester.getRect(
        find.byKey(const Key('desktop-primary-workspace')),
      );
      final panelRect = tester.getRect(
        find.byKey(const Key('desktop-parallel-panel-slot')),
      );
      expect(primaryRect.width, greaterThanOrEqualTo(320));
      expect(primaryRect.right, lessThanOrEqualTo(panelRect.left + 0.01));
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
    await tester.binding.setSurfaceSize(const Size(900, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('queue-nav-item')));
    await tester.pumpAndSettle();

    textScaler.value = const TextScaler.linear(3);
    await tester.pumpAndSettle();
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
