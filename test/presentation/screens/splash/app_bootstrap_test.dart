import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/app_version.dart';
import 'package:nai_launcher/core/services/data_migration_service.dart';
import 'package:nai_launcher/core/services/update_check_service.dart';
import 'package:nai_launcher/core/services/update_installer_service.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/version/version_info.dart';
import 'package:nai_launcher/presentation/providers/startup_initialization_provider.dart';
import 'package:nai_launcher/presentation/providers/update_provider.dart';
import 'package:nai_launcher/presentation/screens/splash/app_bootstrap.dart';
import 'package:nai_launcher/presentation/screens/splash/splash_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

  testWidgets('Splash 先渲染，关键初始化完成后进入主应用', (tester) async {
    final migration = Completer<void>();
    final database = Completer<void>();
    final criticalServices = Completer<void>();
    final mainShellData = Completer<void>();
    final calls = <String>[];

    await tester.pumpWidget(
      _buildApp(
        tasks: StartupInitializationTasks(
          initializeRuntimeConfiguration: () async {
            calls.add('runtimeConfiguration');
          },
          runDataMigration: (_) async {
            calls.add('migration');
            await migration.future;
            return _successfulMigration();
          },
          initializeDatabase: () async {
            calls.add('database');
            await database.future;
          },
          initializeCriticalServices: () async {
            calls.add('criticalServices');
            await criticalServices.future;
          },
          initializeMainShellData: () async {
            calls.add('mainShellData');
            await mainShellData.future;
          },
          runDeferredDataMaintenance: () async {},
        ),
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('main_app')), findsNothing);
    expect(calls, ['runtimeConfiguration', 'migration']);

    migration.complete();
    await _pumpAsync(tester);
    expect(calls, ['runtimeConfiguration', 'migration', 'database']);
    expect(find.byType(SplashScreen), findsOneWidget);

    database.complete();
    await _pumpAsync(tester);
    expect(calls, [
      'runtimeConfiguration',
      'migration',
      'database',
      'criticalServices',
    ]);
    expect(find.byType(SplashScreen), findsOneWidget);

    criticalServices.complete();
    await _pumpAsync(tester);
    expect(calls.last, 'mainShellData');
    expect(find.byType(SplashScreen), findsOneWidget);

    mainShellData.complete();
    await _pumpAsync(tester);
    expect(find.byKey(const ValueKey('main_app')), findsOneWidget);
    expect(_splashOverlayOpacity(tester), 0);
    expect(calls.where((call) => call == 'migration'), hasLength(1));
    expect(calls.where((call) => call == 'database'), hasLength(1));
    expect(calls.where((call) => call == 'criticalServices'), hasLength(1));
  });

  testWidgets('主应用显示后自动执行更新检测且自定义构建器不会绕过', (tester) async {
    var updateChecks = 0;

    await tester.pumpWidget(
      _buildApp(
        tasks: _successfulTasks(),
        autoUpdateDelay: Duration.zero,
        autoUpdateCheckRunner: (_) async {
          updateChecks++;
        },
      ),
    );
    await _pumpAsync(tester);

    expect(find.byKey(const ValueKey('main_app')), findsOneWidget);
    expect(find.byType(AutomaticUpdateCheck), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    expect(updateChecks, 1);
  });

  testWidgets('持续动画不会阻止真实自动检测入口执行', (tester) async {
    var checks = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          automaticUpdateCheckProvider(onStartup: true).overrideWith((
            ref,
          ) async {
            checks++;
          }),
        ],
        child: const AutomaticUpdateCheck(
          delay: Duration(seconds: 1),
          child: MaterialApp(home: CircularProgressIndicator()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(checks, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('真实自动检测跨过帧间异步间隙后仍完成并写回更新状态', (tester) async {
    const latest = VersionInfo(
      version: '2.0.0',
      currentVersion: '1.0.0',
      releaseNotes: 'test',
      isNewer: true,
    );
    final serviceReady = Completer<UpdateCheckService>();
    final checkService = _MockUpdateCheckService();
    final installer = _MockUpdateInstallerService();
    when(installer.consumeExecutionResult).thenAnswer((_) async => null);
    when(installer.restorePendingUpdate).thenAnswer((_) async => null);
    when(checkService.shouldCheckOnStartup).thenAnswer((_) async => true);
    when(
      () => checkService.checkForUpdates(ignoreSkipped: false),
    ).thenAnswer((_) async => latest);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateCheckServiceReadyProvider.overrideWith(
            (ref) => serviceReady.future,
          ),
          updateCheckServiceProvider.overrideWithValue(checkService),
          updateInstallerServiceProvider.overrideWithValue(installer),
        ],
        child: const AutomaticUpdateCheck(
          delay: Duration(seconds: 1),
          child: SizedBox(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    // 服务就绪前先走几帧：无订阅者的 autoDispose provider 会在此期间被回收
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
    serviceReady.complete(checkService);
    await tester.pump();
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AutomaticUpdateCheck)),
    );
    final state = container.read(updateStateProvider);
    expect(state.status, UpdateStatus.available);
    expect(state.versionInfo, latest);
    verify(checkService.shouldCheckOnStartup).called(1);
    verify(() => checkService.checkForUpdates(ignoreSkipped: false)).called(1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('后台暂停检测，回到前台补查且不并发重复请求', (tester) async {
    var checks = 0;
    final pending = Completer<void>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      ProviderScope(
        child: AutomaticUpdateCheck(
          delay: const Duration(seconds: 1),
          checkRunner: (_) async {
            checks++;
            if (checks == 2) await pending.future;
          },
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(checks, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(hours: 1));
    expect(checks, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(checks, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(checks, 2);
    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));
    expect(checks, 3);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 5));
    expect(checks, 3);
  });

  testWidgets('窗口失焦时照常计时，切换焦点不重置延迟', (tester) async {
    var checks = 0;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    void switchFocus() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }

    await tester.pumpWidget(
      ProviderScope(
        child: AutomaticUpdateCheck(
          delay: const Duration(seconds: 10),
          checkRunner: (_) async => checks++,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 4));
    switchFocus();
    await tester.pump(const Duration(seconds: 4));
    switchFocus();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 2));
    expect(checks, 1);

    await tester.pump(UpdateCheckService.failedCheckRetryInterval);
    expect(checks, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(hours: 1));
    expect(checks, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 10));
    expect(checks, 3);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('数据库失败保留 Splash，点击重试后才进入主应用', (tester) async {
    var databaseAttempts = 0;
    var criticalServiceCalls = 0;

    await tester.pumpWidget(
      _buildApp(
        tasks: StartupInitializationTasks(
          initializeRuntimeConfiguration: () async {},
          runDataMigration: (_) async => _successfulMigration(),
          initializeDatabase: () async {
            databaseAttempts++;
            if (databaseAttempts == 1) {
              throw StateError('database failed');
            }
          },
          initializeCriticalServices: () async {
            criticalServiceCalls++;
          },
          initializeMainShellData: () async {},
          runDeferredDataMaintenance: () async {},
        ),
      ),
    );
    await _pumpAsync(tester);

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('main_app')), findsNothing);
    expect(find.byKey(const ValueKey('warmup_retry')), findsOneWidget);
    expect(databaseAttempts, 1);
    expect(criticalServiceCalls, 0);

    await tester.tap(find.byKey(const ValueKey('warmup_retry')));
    await _pumpAsync(tester);

    expect(databaseAttempts, 2);
    expect(criticalServiceCalls, 1);
    expect(find.byKey(const ValueKey('main_app')), findsOneWidget);
  });

  testWidgets('移除 Splash 时保持主应用 Element，不重新挂载路由树', (tester) async {
    var initCount = 0;
    var buildCount = 0;
    var disposeCount = 0;

    await tester.pumpWidget(
      _buildApp(
        tasks: _successfulTasks(),
        mainAppBuilder: (_) => _LifecycleProbe(
          onInit: () => initCount++,
          onBuild: () => buildCount++,
          onDispose: () => disposeCount++,
        ),
      ),
    );
    await _pumpAsync(tester);

    expect(_splashOverlayOpacity(tester), 0);
    expect(initCount, 1);
    expect(buildCount, 1);
    expect(disposeCount, 0);
  });

  testWidgets('完成回调发生在主页首帧后，主页不被额外 Splash 覆盖', (tester) async {
    var mainAppBuilt = false;
    var completionSawBuiltMainApp = false;
    var tapCount = 0;

    await tester.pumpWidget(
      _buildApp(
        tasks: _successfulTasks(),
        onWarmupComplete: () {
          completionSawBuiltMainApp = mainAppBuilt;
        },
        mainAppBuilder: (_) {
          mainAppBuilt = true;
          return MaterialApp(
            home: TextButton(
              key: const ValueKey('ready_action'),
              onPressed: () {
                tapCount++;
              },
              child: const Text('ready'),
            ),
          );
        },
      ),
    );
    await _pumpAsync(tester);

    expect(completionSawBuiltMainApp, isTrue);
    expect(_splashOverlayOpacity(tester), 0);
    expect(
      find.byKey(const ValueKey('ready_action'), skipOffstage: false),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('ready_action')));
    expect(tapCount, 1);
  });
}

StartupInitializationTasks _successfulTasks() {
  return StartupInitializationTasks(
    initializeRuntimeConfiguration: () async {},
    runDataMigration: (_) async => _successfulMigration(),
    initializeDatabase: () async {},
    initializeCriticalServices: () async {},
    initializeMainShellData: () async {},
    runDeferredDataMaintenance: () async {},
  );
}

double _splashOverlayOpacity(WidgetTester tester) {
  return tester
      .widget<Opacity>(find.byKey(const ValueKey('splash_overlay')))
      .opacity;
}

Widget _buildApp({
  required StartupInitializationTasks tasks,
  Duration autoUpdateDelay = const Duration(seconds: 3),
  AutomaticUpdateCheckRunner? autoUpdateCheckRunner,
  VoidCallback? onWarmupComplete,
  WidgetBuilder? mainAppBuilder,
}) {
  return ProviderScope(
    overrides: [
      localStorageServiceProvider.overrideWith((ref) => _MemoryStorage()),
      startupInitializationTasksProvider.overrideWithValue(tasks),
    ],
    child: AppBootstrap(
      autoUpdateDelay: autoUpdateDelay,
      autoUpdateCheckRunner: autoUpdateCheckRunner,
      onWarmupComplete: onWarmupComplete,
      mainAppBuilder:
          mainAppBuilder ??
          (_) => const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(key: ValueKey('main_app')),
          ),
    ),
  );
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({
    required this.onInit,
    required this.onBuild,
    required this.onDispose,
  });

  final VoidCallback onInit;
  final VoidCallback onBuild;
  final VoidCallback onDispose;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return const SizedBox();
  }
}

MigrationResult _successfulMigration() {
  return MigrationResult()
    ..hiveMigrated = true
    ..vibeMigrated = true
    ..imageMigrated = true;
}

Future<void> _pumpAsync(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
}

class _MemoryStorage extends LocalStorageService {
  @override
  T? getSetting<T>(String key, {T? defaultValue}) => defaultValue;
}

class _MockUpdateCheckService extends Mock implements UpdateCheckService {}

class _MockUpdateInstallerService extends Mock
    implements UpdateInstallerService {}
