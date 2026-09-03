import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/tag_library/tag_library_entry_hover_preview.dart';

void main() {
  const previewKey = ValueKey('tag-library-entry-preview-overlay');
  final lookup = TagTranslationLookup.fromResolver((tags) async {
    return {if (tags.contains('1girl')) '1girl': '1个女孩'};
  });

  final entry = TagLibraryEntry.create(
    name: '角色预设',
    content: '1girl, blue eyes',
    tags: const ['角色', '蓝色'],
  ).copyWith(useCount: 7, lastUsedAt: DateTime.now());

  Future<TestGesture> showPreview(
    WidgetTester tester, {
    required Size viewport,
    required Alignment alignment,
    double devicePixelRatio = 1,
  }) async {
    tester.view.physicalSize = Size(
      viewport.width * devicePixelRatio,
      viewport.height * devicePixelRatio,
    );
    tester.view.devicePixelRatio = devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tagTranslationLookupProvider.overrideWithValue(lookup)],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: alignment,
              child: SizedBox(
                width: 80,
                height: 64,
                child: TagLibraryEntryHoverPreview(
                  entry: entry,
                  hoverDelay: Duration.zero,
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byType(TagLibraryEntryHoverPreview)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byKey(previewKey), findsOneWidget);
    return mouse;
  }

  void expectInsideViewport(WidgetTester tester, Size viewport) {
    final rect = tester.getRect(find.byKey(previewKey));
    expect(rect.left, greaterThanOrEqualTo(10));
    expect(rect.top, greaterThanOrEqualTo(10));
    expect(rect.right, lessThanOrEqualTo(viewport.width - 10));
    expect(rect.bottom, lessThanOrEqualTo(viewport.height - 10));
    expect(tester.takeException(), isNull);
  }

  testWidgets('词库来源条目悬浮后显示完整词库同款预览', (tester) async {
    final mouse = await showPreview(
      tester,
      viewport: const Size(1000, 700),
      alignment: Alignment.center,
    );
    addTearDown(mouse.removePointer);

    expect(find.text('角色预设'), findsOneWidget);
    expect(find.text('1girl, blue eyes'), findsOneWidget);
    expect(find.text('1个女孩，blue eyes'), findsOneWidget);
    expect(find.text('角色'), findsOneWidget);
    expect(find.text('蓝色'), findsOneWidget);
    expect(find.byIcon(Icons.repeat), findsNothing);
    expect(find.text('使用 7 次'), findsNothing);
    expect(find.byIcon(Icons.access_time), findsOneWidget);

    await mouse.moveTo(const Offset(10, 10));
    await tester.pump();
    expect(find.byKey(previewKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final testCase in <({String name, Alignment alignment})>[
    (name: '靠左锚点向右展开', alignment: Alignment.centerLeft),
    (name: '靠右锚点向左展开', alignment: Alignment.centerRight),
    (name: '靠上锚点向下夹紧', alignment: Alignment.topCenter),
    (name: '靠下锚点向上夹紧', alignment: Alignment.bottomCenter),
  ]) {
    testWidgets('${testCase.name}且预览完整位于窗口内', (tester) async {
      const viewport = Size(1000, 700);
      final mouse = await showPreview(
        tester,
        viewport: viewport,
        alignment: testCase.alignment,
      );
      addTearDown(mouse.removePointer);

      expectInsideViewport(tester, viewport);
      final anchor = tester.getRect(find.byType(TagLibraryEntryHoverPreview));
      final preview = tester.getRect(find.byKey(previewKey));
      if (testCase.alignment == Alignment.centerLeft) {
        expect(preview.left, greaterThan(anchor.right));
      } else if (testCase.alignment == Alignment.centerRight) {
        expect(preview.right, lessThan(anchor.left));
      } else if (testCase.alignment == Alignment.topCenter) {
        expect(preview.top, 10);
      } else {
        expect(preview.bottom, viewport.height - 10);
      }
    });
  }

  testWidgets('高 DPI 窄窗口约束预览尺寸且保持完整可见', (tester) async {
    const viewport = Size(260, 220);
    final mouse = await showPreview(
      tester,
      viewport: viewport,
      alignment: Alignment.center,
      devicePixelRatio: 2,
    );
    addTearDown(mouse.removePointer);

    expectInsideViewport(tester, viewport);
    final rect = tester.getRect(find.byKey(previewKey));
    expect(rect.width, lessThan(320));
    expect(rect.height, lessThanOrEqualTo(200));
  });

  testWidgets('窗口缩放使锚点离开鼠标时及时关闭预览', (tester) async {
    final mouse = await showPreview(
      tester,
      viewport: const Size(1000, 700),
      alignment: Alignment.centerRight,
    );
    addTearDown(mouse.removePointer);

    tester.view.physicalSize = const Size(260, 220);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(previewKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('滚动列表时及时关闭悬浮预览且不残留 OverlayEntry', (tester) async {
    tester.view.physicalSize = const Size(600, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            controller: scrollController,
            children: [
              const SizedBox(height: 100),
              SizedBox(
                height: 64,
                child: TagLibraryEntryHoverPreview(
                  entry: entry,
                  hoverDelay: Duration.zero,
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
              const SizedBox(height: 600),
            ],
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byType(TagLibraryEntryHoverPreview)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(previewKey), findsOneWidget);

    scrollController.jumpTo(20);
    await tester.pump();
    expect(find.byKey(previewKey), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(find.byKey(previewKey), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
