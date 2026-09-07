import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/data/models/version/version_info.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/update_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/update_check_dialog.dart';

const _info = VersionInfo(
  version: '4.12.10',
  currentVersion: '4.11.9',
  isNewer: true,
  releaseNotes: '## 更新内容\n\n修复更新检测和手机布局。',
);

class _UpdateNotifier extends UpdateStateNotifier {
  _UpdateNotifier(this.initial);
  final UpdateState initial;
  int installs = 0;

  @override
  UpdateState build() => initial;

  @override
  Future<void> installDownloadedUpdate() async => installs++;
}

class _QueueNotifier extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() => const QueueExecutionState();
}

Future<_UpdateNotifier> _open(
  WidgetTester tester, {
  required Size size,
  required UpdateStatus status,
  double scale = 1,
  double keyboard = 0,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.reset);
  PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
    TargetPlatform.android,
  );
  addTearDown(() => PlatformCapabilities.debugOverride = null);
  final notifier = _UpdateNotifier(
    UpdateState(status: status, versionInfo: _info),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        updateStateNotifierProvider.overrideWith(() => notifier),
        queueExecutionNotifierProvider.overrideWith(_QueueNotifier.new),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => UpdateCheckDialog.show(context),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
  return notifier;
}

void main() {
  for (final width in [320.0, 360.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('version summary and actions at $width with ${scale}x text', (
        tester,
      ) async {
        await _open(
          tester,
          size: Size(width, 800),
          status: UpdateStatus.available,
          scale: scale,
        );
        final current = find.text('v4.11.9');
        final latest = find.text('v4.12.10');
        if (scale == 1) {
          expect(tester.getTopLeft(current).dy, tester.getTopLeft(latest).dy);
          expect(
            tester.getTopLeft(current).dx,
            lessThan(tester.getTopLeft(latest).dx),
          );
        }
        for (final target in [
          current,
          latest,
          find.text('查看 Release'),
          find.text('前往下载'),
        ]) {
          await tester.ensureVisible(target);
          await tester.pump();
          expect(target.hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final status in [
    UpdateStatus.downloaded,
    UpdateStatus.upToDate,
    UpdateStatus.error,
  ]) {
    testWidgets('$status panel follows short content height on mobile', (
      tester,
    ) async {
      await _open(tester, size: const Size(360, 800), status: status);
      final panel = tester.getRect(find.byType(UpdateCheckDialog));
      expect(panel.height, lessThan(400));
      expect(panel.bottom, lessThanOrEqualTo(776));
      expect(tester.takeException(), isNull);
    });
  }

  for (final scenario in [
    (size: const Size(360, 800), scale: 1.0, keyboard: 0.0),
    (size: const Size(640, 360), scale: 1.0, keyboard: 0.0),
    (size: const Size(320, 640), scale: 3.0, keyboard: 120.0),
  ]) {
    testWidgets(
      'install confirmation fits ${scenario.size} at ${scenario.scale}x',
      (tester) async {
        final notifier = await _open(
          tester,
          size: scenario.size,
          status: UpdateStatus.downloaded,
          scale: scenario.scale,
          keyboard: scenario.keyboard,
        );
        final install = find.text('立即安装');
        await tester.ensureVisible(install);
        await tester.pump();
        await tester.tap(install);
        await tester.pumpAndSettle();
        final confirmation = find.byKey(
          const ValueKey('update-install-confirmation'),
        );
        expect(confirmation, findsOneWidget);
        if (scenario.scale == 1 && scenario.size.height == 800) {
          final surface = find.descendant(
            of: confirmation,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Material && widget.type == MaterialType.card,
            ),
          );
          expect(tester.getSize(surface).height, lessThan(340));
        }
        final cancel = find.descendant(
          of: confirmation,
          matching: find.text('取消'),
        );
        await tester.ensureVisible(cancel);
        await tester.pump();
        expect(cancel.hitTestable(), findsOneWidget);
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(confirmation, findsNothing);
        expect(notifier.installs, 0);
        expect(find.byType(UpdateCheckDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
