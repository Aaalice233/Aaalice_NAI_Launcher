import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/entry_add_dialog.dart';

void main() {
  testWidgets('320px、3x 字号、IME 与 SafeArea 下全屏呈现且全部表单操作可达', (tester) async {
    await _pumpLauncher(
      tester,
      size: const Size(320, 900),
      textScaler: const TextScaler.linear(3),
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 20),
      viewInsets: const EdgeInsets.only(bottom: 280),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsOneWidget,
    );
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);

    final surface = tester.getRect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
    );
    expect(surface.left, greaterThanOrEqualTo(12));
    expect(surface.right, lessThanOrEqualTo(308));
    expect(surface.top, greaterThanOrEqualTo(24));
    expect(surface.bottom, lessThanOrEqualTo(600));

    final scrollable = find
        .descendant(
          of: find.byKey(const Key('entry-add-dialog-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final label in ['预览图', '名称', '分类', '标签', '提示词内容']) {
      final target = find.text(label);
      await tester.scrollUntilVisible(target, 180, scrollable: scrollable);
      expect(target, findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    final save = find.widgetWithText(FilledButton, '保存');
    final cancel = find.widgetWithText(TextButton, '取消');
    expect(save, findsOneWidget);
    expect(cancel, findsOneWidget);
    expect(surface.contains(tester.getCenter(save)), isTrue);
    expect(surface.contains(tester.getCenter(cancel)), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Medium 在 IME 导致短高度时切换为全屏表单', (tester) async {
    await _pumpLauncher(
      tester,
      size: const Size(700, 720),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      viewInsets: const EdgeInsets.only(bottom: 180),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const ValueKey('adaptive-centered-form')), findsNothing);
    final panelFinder = find.byKey(const ValueKey('adaptive-full-screen-form'));
    expect(panelFinder, findsOneWidget);
    final panel = tester.getRect(panelFinder);
    expect(panel.top, greaterThanOrEqualTo(24));
    expect(panel.bottom, lessThanOrEqualTo(520));
    expect(find.byKey(const Key('entry-add-dialog-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Expanded 使用有界侧栏并保留关闭结果', (tester) async {
    var completed = false;
    await _pumpLauncher(
      tester,
      size: const Size(1180, 800),
      onCompleted: () => completed = true,
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final panelFinder = find.byKey(const ValueKey('adaptive-side-sheet'));
    expect(panelFinder, findsOneWidget);
    final panel = tester.getRect(panelFinder);
    expect(panel.width, 520);
    expect(panel.right, 1180);
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('系统返回关闭表单且 Future<void> 正常完成', (tester) async {
    var completed = false;
    await _pumpLauncher(
      tester,
      size: const Size(320, 700),
      onCompleted: () => completed = true,
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(completed, isFalse);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsNothing,
    );
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required Size size,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  VoidCallback? onCompleted,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            padding: padding,
            viewPadding: padding,
            viewInsets: viewInsets,
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  await EntryAddDialog.show(context, categories: const []);
                  onCompleted?.call();
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
