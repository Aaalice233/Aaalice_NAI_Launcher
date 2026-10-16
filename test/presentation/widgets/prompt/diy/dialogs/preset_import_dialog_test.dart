import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/dialogs/preset_import_dialog.dart';

void main() {
  testWidgets('导入面板在 Compact 3x 文本、IME 和 SafeArea 下动作可达', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    });

    await _pumpLauncher(tester, textScale: 3);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('preset-import-scroll')), findsOneWidget);

    final closeRect = tester.getRect(
      find.widgetWithIcon(IconButton, Icons.close),
    );
    final submitRect = tester.getRect(find.byType(FilledButton));
    final cancelRect = tester.getRect(find.byType(OutlinedButton));
    expect(closeRect.top, greaterThanOrEqualTo(24));
    expect(submitRect.left, greaterThanOrEqualTo(0));
    expect(cancelRect.right, lessThanOrEqualTo(320));
    expect(cancelRect.bottom, lessThanOrEqualTo(600));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    expect(find.byType(PresetImportDialog), findsNothing);
  });

  testWidgets('JSON 输入区字号取自主题 bodySmall 并保持等宽字体', (tester) async {
    const fontSize = 17.0;
    final base = ThemeData();
    final theme = base.copyWith(
      textTheme: base.textTheme.copyWith(
        bodySmall: base.textTheme.bodySmall!.copyWith(fontSize: fontSize),
      ),
    );
    await _pumpLauncher(tester, theme: theme);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final style = tester
        .widget<EditableText>(
          find.descendant(
            of: find.byType(PresetImportDialog),
            matching: find.byType(EditableText),
          ),
        )
        .style;
    expect(style.fontSize, fontSize);
    expect(style.fontFamily, 'monospace');
    expect(style.color, theme.colorScheme.onSurface);
    expect(tester.takeException(), isNull);
  });

  testWidgets('导入面板在 Expanded 使用受限宽度居中弹窗', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpLauncher(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final contentRect = tester.getRect(
      find.byKey(const ValueKey('preset-import-scroll')),
    );
    final panel = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(find.byType(Dialog), findsNothing);
    expect(contentRect.width, lessThanOrEqualTo(560));
    expect(contentRect.right, lessThanOrEqualTo(1600));
    expect(tester.getSize(panel).height, lessThan(700));
    expect(tester.getRect(panel).center.dy, moreOrLessEquals(450));
    expect(tester.takeException(), isNull);
  });

  testWidgets('导出的当前版本预设可以再次导入，更高版本提示更新应用', (tester) async {
    tester.view.physicalSize = const Size(1180, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    RandomPreset? imported;
    await _pumpLauncher(tester, onImported: (preset) => imported = preset);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final input = find.byType(EditableText);
    await tester.enterText(
      input,
      jsonEncode({'name': '未来', 'version': RandomPreset.currentVersion + 1}),
    );
    await tester.pump();
    expect(
      find.text(
        '该预设由更新版本的应用导出（数据版本 ${RandomPreset.currentVersion + 1}），请更新应用后再导入',
      ),
      findsOneWidget,
    );

    final exported = RandomPreset.create(name: '往返预设').toExportJson();
    await tester.enterText(input, jsonEncode(exported));
    await tester.pump();
    expect(find.textContaining('请更新应用'), findsNothing);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(imported?.name, '往返预设');
    expect(imported?.version, RandomPreset.currentVersion);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  double textScale = 1,
  ValueChanged<RandomPreset?>? onImported,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final preset = await PresetImportDialog.showImport(context);
              onImported?.call(preset);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
