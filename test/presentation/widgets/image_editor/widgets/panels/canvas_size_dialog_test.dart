import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/panels/canvas_size_dialog.dart';

void main() {
  testWidgets('320x568、3x 文本与 IME 下字段和底部动作始终可达', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    await _pumpLauncher(tester, textScale: 3);
    await tester.tap(find.byKey(const ValueKey('open-canvas-size')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const ValueKey('canvas-size-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final dialog = tester.getRect(
      find.byKey(const ValueKey('canvas-size-dialog')),
    );
    expect(dialog.left, greaterThanOrEqualTo(0));
    expect(dialog.right, lessThanOrEqualTo(320));
    expect(dialog.bottom, lessThanOrEqualTo(388));

    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('canvas-size-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final field in [
      find.byKey(const ValueKey('canvas-size-preset')),
      find.byKey(const ValueKey('canvas-size-mode')),
      find.byKey(const ValueKey('canvas-size-width')),
      find.byKey(const ValueKey('canvas-size-height')),
    ]) {
      await tester.scrollUntilVisible(field, 100, scrollable: scrollable);
      await tester.pump();
      expect(field, findsOneWidget);
      expect(tester.getRect(field).overlaps(dialog), isTrue);
      expect(tester.takeException(), isNull);
    }

    await tester.scrollUntilVisible(
      find.text('9:16'),
      100,
      scrollable: scrollable,
    );
    await tester.pump();
    expect(find.text('9:16'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final cancel = find.widgetWithText(TextButton, '取消');
    final confirm = find.widgetWithText(FilledButton, 'Apply');
    expect(cancel, findsOneWidget);
    expect(confirm, findsOneWidget);
    expect(tester.getRect(cancel).bottom, lessThanOrEqualTo(388));
    expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(388));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Expanded 使用居中弹窗并保留完整表单与动作', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    CanvasSizeResult? result;

    await _pumpLauncher(tester, onResult: (value) => result = value);
    await tester.tap(find.byKey(const ValueKey('open-canvas-size')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    final dialog = tester.getRect(
      find.byKey(const ValueKey('canvas-size-dialog')),
    );
    expect(dialog.width, lessThanOrEqualTo(480));
    expect(dialog.center.dx, moreOrLessEquals(800));
    expect(
      find.byType(DropdownButtonFormField<CanvasSizePreset>),
      findsOneWidget,
    );
    expect(
      find.byType(DropdownButtonFormField<ContentHandlingMode>),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('canvas-size-width')), findsOneWidget);
    expect(find.byKey(const ValueKey('canvas-size-height')), findsOneWidget);
    expect(find.widgetWithText(TextButton, '取消'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Apply'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.size, const Size(1024, 1024));
    expect(result!.mode, ContentHandlingMode.crop);
  });
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  double textScale = 1,
  ValueChanged<CanvasSizeResult?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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
              key: const ValueKey('open-canvas-size'),
              onPressed: () async {
                final result = await CanvasSizeDialog.show(
                  context,
                  initialSize: const Size(1024, 1024),
                  title: 'Canvas test',
                  confirmText: 'Apply',
                );
                onResult?.call(result);
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
