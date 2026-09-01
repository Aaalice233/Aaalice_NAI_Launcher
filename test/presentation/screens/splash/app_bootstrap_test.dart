import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/app_version.dart';
import 'package:nai_launcher/core/services/data_migration_service.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/startup_initialization_provider.dart';
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
