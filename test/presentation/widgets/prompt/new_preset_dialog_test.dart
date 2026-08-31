import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/new_preset_dialog.dart';

void main() {
  testWidgets('手机小高度弹出键盘后内容可滚动且动作始终可达', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    });

    await _pumpLauncher(tester, textScale: 1.35);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('创建新预设'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    for (final label in ['取消', '创建']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(12));
      expect(rect.right, lessThanOrEqualTo(348));
      expect(rect.top, greaterThanOrEqualTo(24));
      expect(rect.bottom, lessThanOrEqualTo(480));
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('创建'));
    await tester.pump();
    expect(find.text('请输入预设名称'), findsOneWidget);
    expect(tester.getRect(find.text('创建')).bottom, lessThanOrEqualTo(480));
    expect(tester.takeException(), isNull);
  });

  testWidgets('横屏大字体和键盘下动作栏仍在可见区域', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(left: 24, right: 24);
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    });

    await _pumpLauncher(tester, textScale: 1.6);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('创建新预设'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    for (final label in ['取消', '创建']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(160));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('滚动选择创建方式后返回完整结果', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    NewPresetResult? result;
    await _pumpLauncher(tester, onResult: (value) => result = value);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '移动端预设');
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('完全空白'));
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, '移动端预设');
    expect(result!.mode, PresetCreationMode.blank);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  double textScale = 1,
  ValueChanged<NewPresetResult?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                final result = await NewPresetDialog.show(context);
                onResult?.call(result);
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
}
