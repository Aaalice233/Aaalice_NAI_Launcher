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

  testWidgets('窄桌面侧栏动画不重建路由主体且主体保持可交互', (tester) async {
    await tester.binding.setSurfaceSize(const Size(620, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final navigationShell = _MockNavigationShell();
    final storage = _FakeMainNavStorage();
    final lifecycle = _ContentLifecycle();
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
          home: DesktopShell(
            navigationShell: navigationShell,
            content: _TrackedContent(lifecycle: lifecycle),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(lifecycle.initialized, 1);
    expect(lifecycle.built, 1);
    expect(find.text('content-0'), findsOneWidget);

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
    expect(lifecycle.initialized, 1);
    expect(lifecycle.built, 2);
    expect(lifecycle.disposed, 0);
    expect(tester.takeException(), isNull);
  });
}
