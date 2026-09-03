import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/app_version.dart';
import 'package:nai_launcher/core/services/diagnostic_log_export_service.dart';
import 'package:nai_launcher/core/services/update_check_service.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/update_provider.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/about_settings_section.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockDiagnosticLogExportService exportService;
  late _MockUpdateCheckService updateService;

  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'NAI Launcher',
      packageName: 'com.aaalice.nai_launcher',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await AppVersion.initialize();
  });

  setUp(() {
    exportService = _MockDiagnosticLogExportService();
    updateService = _MockUpdateCheckService();
    when(updateService.getLastCheckTime).thenAnswer((_) async => null);
    when(updateService.shouldIncludePrerelease).thenReturn(false);
  });

  testWidgets('导出诊断日志入口可见，并在无日志时给出恢复提示', (tester) async {
    when(
      () => exportService.export(dialogTitle: any(named: 'dialogTitle')),
    ).thenAnswer(
      (_) async =>
          const DiagnosticLogExportResult(DiagnosticLogExportStatus.noLogs),
    );

    await _pumpSubject(tester, exportService, updateService);

    final tile = find.byKey(const ValueKey('export-diagnostic-logs'));
    expect(tile, findsOneWidget);
    expect(find.text('导出诊断日志'), findsOneWidget);
    expect(find.textContaining('自动隐藏凭据与本地路径'), findsOneWidget);

    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.textContaining('请先开启日志记录并复现问题'), findsOneWidget);
    verify(() => exportService.export(dialogTitle: '导出诊断日志')).called(1);
  });

  testWidgets('导出期间禁用重复操作、播报进度并在完成后恢复', (tester) async {
    final completer = Completer<DiagnosticLogExportResult>();
    when(
      () => exportService.export(dialogTitle: any(named: 'dialogTitle')),
    ).thenAnswer((_) => completer.future);
    final semantics = tester.ensureSemantics();

    await _pumpSubject(tester, exportService, updateService);
    final tileFinder = find.byKey(const ValueKey('export-diagnostic-logs'));
    await tester.tap(tileFinder);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.getSemantics(tileFinder).label, contains('正在导出诊断日志'));
    expect(tester.widget<ListTile>(tileFinder).onTap, isNull);
    verify(
      () => exportService.export(dialogTitle: any(named: 'dialogTitle')),
    ).called(1);

    completer.complete(
      const DiagnosticLogExportResult(DiagnosticLogExportStatus.exported),
    );
    await tester.pumpAndSettle();

    expect(find.text('诊断日志已导出'), findsOneWidget);
    expect(tester.widget<ListTile>(tileFinder).onTap, isNotNull);
    semantics.dispose();
  });

  testWidgets('取消保持静默，失败给出提示且入口恢复可用', (tester) async {
    when(
      () => exportService.export(dialogTitle: any(named: 'dialogTitle')),
    ).thenAnswer(
      (_) async =>
          const DiagnosticLogExportResult(DiagnosticLogExportStatus.cancelled),
    );
    await _pumpSubject(tester, exportService, updateService);
    final tileFinder = find.byKey(const ValueKey('export-diagnostic-logs'));

    await tester.tap(tileFinder);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.widget<ListTile>(tileFinder).onTap, isNotNull);

    reset(exportService);
    when(
      () => exportService.export(dialogTitle: any(named: 'dialogTitle')),
    ).thenThrow(StateError('injected export failure'));
    await tester.tap(tileFinder);
    await tester.pumpAndSettle();

    expect(find.textContaining('导出失败'), findsOneWidget);
    expect(tester.widget<ListTile>(tileFinder).onTap, isNotNull);
  });

  testWidgets('紧凑与宽屏下的多语言文案不会溢出', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    when(
      () => exportService.export(dialogTitle: any(named: 'dialogTitle')),
    ).thenAnswer(
      (_) async =>
          const DiagnosticLogExportResult(DiagnosticLogExportStatus.cancelled),
    );
    final scenarios = <({Size size, Locale locale})>[
      (size: const Size(360, 900), locale: const Locale('ja')),
      (size: const Size(840, 900), locale: const Locale('en')),
      (size: const Size(1600, 900), locale: const Locale('zh', 'Hant')),
    ];

    for (final scenario in scenarios) {
      await tester.binding.setSurfaceSize(scenario.size);
      await _pumpSubject(
        tester,
        exportService,
        updateService,
        locale: scenario.locale,
        textScale: 1.3,
      );
      expect(
        find.byKey(const ValueKey('export-diagnostic-logs')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pumpSubject(
  WidgetTester tester,
  DiagnosticLogExportService exportService,
  UpdateCheckService updateService, {
  Locale locale = const Locale('zh'),
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(
          _MemoryLocalStorageService(),
        ),
        updateCheckServiceProvider.overrideWithValue(updateService),
        updateStateProvider.overrideWith(_FakeUpdateStateNotifier.new),
        diagnosticLogExportServiceProvider.overrideWithValue(exportService),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(child: AboutSettingsSection()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _MockDiagnosticLogExportService extends Mock
    implements DiagnosticLogExportService {}

class _MockUpdateCheckService extends Mock implements UpdateCheckService {}

class _FakeUpdateStateNotifier extends UpdateStateNotifier {
  @override
  UpdateState build() => const UpdateState();
}

class _MemoryLocalStorageService extends LocalStorageService {
  final Map<String, Object?> _values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (_values[key] as T?) ?? defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _values[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    _values.remove(key);
  }
}
