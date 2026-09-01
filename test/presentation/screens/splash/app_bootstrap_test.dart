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

  testWidgets('Splash 先渲染，并在交互任务完成后才进入主应用', (tester) async {
    final migration = Completer<void>();
    final database = Completer<void>();
    final criticalServices = Completer<void>();
    final interactiveReadiness = Completer<void>();
    final calls = <String>[];

    await tester.pumpWidget(
      _buildApp(
        tasks: StartupInitializationTasks(
          enablePostWarmupTasks: false,
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
          initializeInteractiveReadiness: () async {
            calls.add('interactiveReadiness');
            await interactiveReadiness.future;
          },
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
    expect(calls.last, 'interactiveReadiness');
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('main_app')), findsNothing);

    interactiveReadiness.complete();
    await _pumpAsync(tester);
    expect(find.byKey(const ValueKey('main_app')), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(calls.where((call) => call == 'migration'), hasLength(1));
    expect(calls.where((call) => call == 'database'), hasLength(1));
    expect(calls.where((call) => call == 'interactiveReadiness'), hasLength(1));
  });

  testWidgets('主应用显示后自动执行更新检测且自定义构建器不会绕过', (tester) async {
    var updateChecks = 0;

    await tester.pumpWidget(
      _buildApp(
        tasks: StartupInitializationTasks(
          enablePostWarmupTasks: false,
          initializeRuntimeConfiguration: () async {},
          runDataMigration: (_) async => _successfulMigration(),
          initializeDatabase: () async {},
          initializeCriticalServices: () async {},
          initializeInteractiveReadiness: () async {},
        ),
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
          enablePostWarmupTasks: false,
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
          initializeInteractiveReadiness: () async {},
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

  testWidgets('交互准备失败保留 Splash，重试成功后才显示主页', (tester) async {
    var readinessAttempts = 0;

    await tester.pumpWidget(
      _buildApp(
        tasks: StartupInitializationTasks(
          enablePostWarmupTasks: false,
          initializeRuntimeConfiguration: () async {},
          runDataMigration: (_) async => _successfulMigration(),
          initializeDatabase: () async {},
          initializeCriticalServices: () async {},
          initializeInteractiveReadiness: () async {
            readinessAttempts++;
            if (readinessAttempts == 1) {
              throw StateError('readiness failed');
            }
          },
        ),
      ),
    );
    await _pumpAsync(tester);

    expect(readinessAttempts, 1);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('main_app')), findsNothing);
    expect(find.byKey(const ValueKey('warmup_retry')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('warmup_retry')));
    await _pumpAsync(tester);

    expect(readinessAttempts, 2);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byKey(const ValueKey('main_app')), findsOneWidget);
  });

  testWidgets('完成回调等待主页首帧和启动 microtask，随后可立即交互', (tester) async {
    var mainStartupMicrotaskSettled = false;
    var completionSawSettledMicrotask = false;
    var tapCount = 0;

    await tester.pumpWidget(
      _buildApp(
        tasks: StartupInitializationTasks(
          enablePostWarmupTasks: false,
          initializeRuntimeConfiguration: () async {},
          runDataMigration: (_) async => _successfulMigration(),
          initializeDatabase: () async {},
          initializeCriticalServices: () async {},
          initializeInteractiveReadiness: () async {},
        ),
        onWarmupComplete: () {
          completionSawSettledMicrotask = mainStartupMicrotaskSettled;
        },
        mainAppBuilder: (_) {
          scheduleMicrotask(() {
            mainStartupMicrotaskSettled = true;
          });
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

    expect(completionSawSettledMicrotask, isTrue);
    expect(find.byType(SplashScreen), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ready_action')));
    expect(tapCount, 1);
  });
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
