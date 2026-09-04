import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/export_dialog.dart';
import 'package:nai_launcher/presentation/providers/pending_prompt_provider.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/import_dialog.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/send_to_home_dialog.dart';

void main() {
  testWidgets(
    '320x568 3x SafeArea/IME keeps send options, preview, and result reachable',
    (tester) async {
      await _setBlockedCompactImeViewport(tester);
      final result = ValueNotifier<SendOptions?>(null);
      addTearDown(result.dispose);
      final entry = TagLibraryEntry(
        id: 'entry-pipe',
        name: '角色组合',
        content:
            'masterpiece, best quality, extremely detailed, cinematic lighting, '
            'intricate background | 1girl, red hair | 1boy, blue eyes',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result.value = await SendToHomeDialog.show(
                  context,
                  entry: entry,
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      final panel = find.byKey(const ValueKey('adaptive-bottom-sheet'));
      expect(panel, findsOneWidget);
      final panelRect = tester.getRect(panel);
      expect(panelRect.top, greaterThanOrEqualTo(24));
      expect(panelRect.bottom, lessThanOrEqualTo(408));
      expect(
        find.byKey(const ValueKey('send-to-home-dialog-frame')),
        findsOneWidget,
      );
      expect(find.text('发送到主提示词'), findsOneWidget);
      expect(find.text('智能分解'), findsWidgets);
      expect(find.text('替换角色提示词'), findsOneWidget);
      expect(find.text('追加角色提示词'), findsOneWidget);
      expect(find.text('发送到固定词'), findsOneWidget);
      expect(find.text('作为别名发送'), findsOneWidget);
      expect(find.text('发送预览'), findsOneWidget);
      expect(find.text('1girl, red hair'), findsOneWidget);
      expect(find.text('1boy, blue eyes'), findsOneWidget);
      expect(
        find.text(
          'masterpiece, best quality, extremely detailed, cinematic lighting, '
          'intricate background',
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('发送到固定词'));
      await tester.tap(find.text('发送到固定词'));
      await tester.ensureVisible(find.text('作为别名发送'));
      await tester.tap(find.byType(Switch));
      final send = find.text('发送');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(result.value?.targetType, SendTargetType.fixedTag);
      expect(result.value?.sendAsAlias, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('medium send form is bounded and system back returns null', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final result = ValueNotifier<SendOptions?>(
      const SendOptions(targetType: SendTargetType.mainPrompt),
    );
    addTearDown(result.dispose);
    var completed = false;
    final entry = TagLibraryEntry(
      id: 'entry-medium',
      name: '中等窗口条目',
      content: 'masterpiece | 1girl | 1boy',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result.value = await SendToHomeDialog.show(context, entry: entry);
              completed = true;
            },
            child: const Text('打开'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    expect(panel, findsOneWidget);
    expect(tester.getSize(panel).width, lessThanOrEqualTo(700));
    expect(tester.getSize(panel).height, lessThanOrEqualTo(800));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result.value, isNull);
    expect(panel, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px 3x SafeArea/IME keeps tag import chooser reachable', (
    tester,
  ) async {
    await _setCompactImeViewport(tester);
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => ImportDialog.show(context),
            child: const Text('打开导入'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开导入'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    final chooser = find.text('点击选择 ZIP 文件');
    await tester.ensureVisible(chooser);
    expect(chooser, findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '320px 3x SafeArea/IME keeps non-empty export selection and actions reachable',
    (tester) async {
      await _setCompactImeViewport(tester);
      final category = TagLibraryCategory(
        id: 'people',
        name: '人物',
        createdAt: DateTime(2026),
      );
      final entries = [
        TagLibraryEntry(
          id: 'entry-1',
          name: '测试条目',
          content: '1girl, portrait',
          categoryId: category.id,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => ExportDialog.show(
                context,
                entries: entries,
                categories: [category],
              ),
              child: const Text('打开导出'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开导出'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('adaptive-bottom-sheet')),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('测试条目'), findsOneWidget);
      final export = find.text('导出 (2 项)');
      await tester.ensureVisible(export);
      expect(export, findsOneWidget);
      expect(find.text('包含预览图'), findsOneWidget);
      final stats = find.byKey(const ValueKey('tag-library-export-stats'));
      final selectionActions = find.byKey(
        const ValueKey('tag-library-export-selection-actions'),
      );
      expect(tester.getCenter(stats).dy, tester.getCenter(selectionActions).dy);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('1180px import and export forms use centered dialogs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1180, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final entry = TagLibraryEntry(
      id: 'entry-wide',
      name: '宽屏条目',
      content: 'landscape',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => Row(
            children: [
              FilledButton(
                onPressed: () => ImportDialog.show(context),
                child: const Text('导入'),
              ),
              FilledButton(
                onPressed: () => ExportDialog.show(
                  context,
                  entries: [entry],
                  categories: const [],
                ),
                child: const Text('导出'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('导入'));
    await tester.pumpAndSettle();
    var panel = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(panel, findsOneWidget);
    expect(tester.getSize(panel).width, 700);
    expect(tester.getSize(panel).height, lessThan(700));
    expect(tester.getRect(panel).center.dy, moreOrLessEquals(400));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.tap(find.text('导出'));
    await tester.pumpAndSettle();
    panel = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(panel, findsOneWidget);
    expect(tester.getSize(panel).width, 600);
    expect(find.text('宽屏条目'), findsOneWidget);
    final stats = find.byKey(const ValueKey('tag-library-export-stats'));
    final selectionActions = find.byKey(
      const ValueKey('tag-library-export-selection-actions'),
    );
    expect(tester.getCenter(stats).dy, tester.getCenter(selectionActions).dy);

    final content = find.byKey(const ValueKey('tag-library-export-content'));
    final dialogActions = find.byKey(
      const ValueKey('tag-library-export-dialog-actions'),
    );
    expect(
      tester.getRect(content).right - tester.getRect(dialogActions).right,
      16,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setBlockedCompactImeViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewInsets = const FakeViewPadding(bottom: 160);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewInsets();
  });
}

Future<void> _setCompactImeViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(320, 720);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewInsets = const FakeViewPadding(bottom: 220);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewInsets();
  });
}

Widget _wrap(Widget child) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(3)),
      child: child!,
    ),
    home: Scaffold(body: Center(child: child)),
  ),
);
