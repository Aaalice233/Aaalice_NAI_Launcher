import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
import 'package:nai_launcher/presentation/widgets/prompt/new_preset_dialog.dart';

void main() {
  testWidgets('320 宽紧凑窗格以全屏长表单呈现', (tester) async {
    await _setView(tester, size: const Size(320, 640));

    await _pumpLauncher(tester);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('new-preset-dialog-frame')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('new-preset-dialog-scroll')),
      findsOneWidget,
    );
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Medium 与 Expanded 窗格紧凑有界且操作区贴底', (tester) async {
    await _setView(tester, size: const Size(700, 900));
    await _pumpLauncher(tester);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    _expectBoundedDialog(tester, surfaceKey: 'adaptive-centered-form');
    expect(
      find.byKey(const ValueKey('adaptive-panel-header-divider')),
      findsNothing,
    );
    final headerSurface = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('adaptive-panel-header-surface')),
    );
    final headerContext = tester.element(
      find.byKey(const ValueKey('adaptive-panel-header-surface')),
    );
    expect(
      headerSurface.color,
      sectionSurfaceColor(Theme.of(headerContext).colorScheme),
    );

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    await _setView(tester, size: const Size(1200, 900));
    await tester.pump();
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    _expectBoundedDialog(tester, surfaceKey: 'adaptive-centered-form');
    expect(tester.takeException(), isNull);
  });

  testWidgets('3x 字体、IME 与 SafeArea 下可滚动且动作可达', (tester) async {
    await _setView(
      tester,
      size: const Size(320, 800),
      padding: const FakeViewPadding(left: 12, top: 32, right: 20, bottom: 28),
      viewInsets: const FakeViewPadding(bottom: 280),
    );

    await _pumpLauncher(tester, textScale: 3);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final surfaceRect = tester.getRect(
      find.byKey(const ValueKey('adaptive-bottom-sheet')),
    );
    expect(surfaceRect.left, greaterThanOrEqualTo(12));
    expect(surfaceRect.right, lessThanOrEqualTo(300));
    expect(surfaceRect.top, greaterThanOrEqualTo(32));
    expect(surfaceRect.bottom, lessThanOrEqualTo(520));

    final scrollable = find.byKey(const ValueKey('new-preset-dialog-scroll'));
    expect(scrollable, findsOneWidget);
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();

    for (final label in ['取消', '创建']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(12));
      expect(rect.right, lessThanOrEqualTo(300));
      expect(rect.top, greaterThanOrEqualTo(32));
      expect(rect.bottom, lessThanOrEqualTo(492));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('选择创建方式后返回完整结果，系统返回则取消', (tester) async {
    await _setView(tester, size: const Size(360, 700));

    NewPresetResult? result;
    var completed = false;
    await _pumpLauncher(
      tester,
      onResult: (value) {
        result = value;
        completed = true;
      },
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '移动端预设');
    await tester.drag(
      find.byKey(const ValueKey('new-preset-dialog-scroll')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('完全空白'));
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(result?.name, '移动端预设');
    expect(result?.mode, PresetCreationMode.blank);

    completed = false;
    result = null;
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
    expect(find.text('创建新预设'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _expectBoundedDialog(WidgetTester tester, {required String surfaceKey}) {
  final surfaceRect = tester.getRect(find.byKey(ValueKey(surfaceKey)));
  final frameRect = tester.getRect(
    find.byKey(const ValueKey('new-preset-dialog-frame')),
  );
  final createRect = tester.getRect(find.text('创建'));

  if (surfaceKey == 'adaptive-centered-form') {
    expect(frameRect.width, 420);
    expect(frameRect.height, lessThanOrEqualTo(460));
  } else {
    expect(frameRect.width, surfaceRect.width);
    expect(frameRect.height, lessThan(surfaceRect.height));
    expect(frameRect.bottom, closeTo(surfaceRect.bottom, 0.01));
  }
  expect(frameRect.left, greaterThanOrEqualTo(surfaceRect.left));
  expect(frameRect.right, lessThanOrEqualTo(surfaceRect.right));
  expect(frameRect.top, greaterThanOrEqualTo(surfaceRect.top));
  expect(frameRect.bottom, lessThanOrEqualTo(surfaceRect.bottom));
  expect(createRect.right, lessThanOrEqualTo(frameRect.right - 16));
  expect(createRect.bottom, lessThanOrEqualTo(frameRect.bottom - 16));
  expect(createRect.bottom, greaterThan(frameRect.bottom - 64));
}

Future<void> _setView(
  WidgetTester tester, {
  required Size size,
  FakeViewPadding padding = FakeViewPadding.zero,
  FakeViewPadding viewInsets = FakeViewPadding.zero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = padding;
  tester.view.viewInsets = viewInsets;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewInsets();
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
