import 'dart:async';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/thumbnail_display.dart';
import 'package:nai_launcher/presentation/widgets/prompt/fixed_tags_dialog.dart';

void main() {
  late Directory temporaryDirectory;
  late String thumbnailPath;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'fixed_tag_library_picker_test_',
    );
    final thumbnail = File('${temporaryDirectory.path}/preview.png');
    thumbnail.writeAsBytesSync(
      img.encodePng(img.Image(width: 160, height: 90)),
    );
    thumbnailPath = thumbnail.path;
  });

  tearDown(() {
    if (temporaryDirectory.existsSync()) {
      temporaryDirectory.deleteSync(recursive: true);
    }
  });

  testWidgets('320dp、3x 字号、SafeArea 与 IME 下全屏选择器可返回', (tester) async {
    _setViewport(tester, const Size(320, 900));

    await _openPicker(
      tester,
      entries: [
        for (var index = 0; index < 20; index++)
          _entry(id: 'compact-$index', name: '紧凑预设 $index'),
      ],
      textScaler: const TextScaler.linear(3),
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      viewInsets: const EdgeInsets.only(bottom: 180),
    );

    expect(find.byType(FixedTagLibraryPickerDialog), findsOneWidget);
    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    final dialogRect = tester.getRect(
      find.byKey(const ValueKey('adaptive-bottom-sheet')),
    );
    expect(dialogRect.top, greaterThanOrEqualTo(24));
    expect(dialogRect.bottom, lessThanOrEqualTo(720));
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(FixedTagLibraryPickerDialog), findsNothing);
  });

  testWidgets('有图条目悬浮显示共享预览且窄窗口内不越界', (tester) async {
    _setViewport(tester, const Size(500, 360));
    final entry = _entry(
      id: 'with-image',
      name: '角色预设',
      thumbnail: thumbnailPath,
    );

    await _openPicker(tester, entries: [entry]);
    final mouse = await _hoverEntry(tester, entry.id);
    addTearDown(mouse.removePointer);
    await tester.pump(const Duration(milliseconds: 500));

    const previewKey = ValueKey('tag-library-entry-preview-overlay');
    expect(find.byKey(previewKey), findsOneWidget);
    expect(find.text('角色预设'), findsNWidgets(2));
    final thumbnail = tester.widget<ThumbnailDisplay>(
      find.descendant(
        of: find.byKey(previewKey),
        matching: find.byType(ThumbnailDisplay),
      ),
    );
    expect(thumbnail.imagePath, thumbnailPath);

    final previewRect = tester.getRect(find.byKey(previewKey));
    expect(previewRect.left, greaterThanOrEqualTo(10));
    expect(previewRect.top, greaterThanOrEqualTo(10));
    expect(previewRect.right, lessThanOrEqualTo(490));
    expect(previewRect.bottom, lessThanOrEqualTo(350));
    expect(tester.takeException(), isNull);
  });

  testWidgets('无图条目悬浮不创建预览浮层', (tester) async {
    _setViewport(tester, const Size(800, 600));
    final entry = _entry(id: 'without-image', name: '纯文本预设');

    await _openPicker(tester, entries: [entry]);
    final mouse = await _hoverEntry(tester, entry.id);
    addTearDown(mouse.removePointer);
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.byKey(const ValueKey('tag-library-entry-preview-overlay')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('离开、滚动和关闭选择器都会清理预览', (tester) async {
    _setViewport(tester, const Size(900, 640));
    final entries = [
      for (var index = 0; index < 30; index++)
        _entry(id: 'entry-$index', name: '预设 $index', thumbnail: thumbnailPath),
    ];

    await _openPicker(tester, entries: entries);
    final mouse = await _hoverEntry(tester, entries.first.id);
    addTearDown(mouse.removePointer);
    await tester.pump(const Duration(milliseconds: 500));

    const previewKey = ValueKey('tag-library-entry-preview-overlay');
    expect(find.byKey(previewKey), findsOneWidget);

    await mouse.moveTo(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(previewKey), findsNothing);

    await mouse.moveTo(
      tester.getCenter(
        find.byKey(ValueKey('fixed-tag-library-entry-${entries.first.id}')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(previewKey), findsOneWidget);

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('fixed-tag-library-entry-list')),
        matching: find.byType(Scrollable),
      ),
    );
    scrollable.position.jumpTo(100);
    await tester.pump();
    expect(find.byKey(previewKey), findsNothing);

    final visibleEntry = entries[3];
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(ValueKey('fixed-tag-library-entry-${visibleEntry.id}')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(previewKey), findsOneWidget);

    Navigator.of(
      tester.element(find.byType(FixedTagLibraryPickerDialog)),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.byType(FixedTagLibraryPickerDialog), findsNothing);
    expect(find.byKey(previewKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击有图条目仍执行添加并关闭选择器', (tester) async {
    _setViewport(tester, const Size(800, 600));
    final entry = _entry(
      id: 'clickable',
      name: '可添加预设',
      thumbnail: thumbnailPath,
    );
    TagLibraryEntry? selected;

    await _openPicker(
      tester,
      entries: [entry],
      onSelect: (value) => selected = value,
    );
    final mouse = await _hoverEntry(tester, entry.id);
    addTearDown(mouse.removePointer);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byKey(const ValueKey('tag-library-entry-preview-overlay')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(ValueKey('fixed-tag-library-entry-${entry.id}')),
    );
    await tester.pumpAndSettle();

    expect(selected, entry);
    expect(find.byType(FixedTagLibraryPickerDialog), findsNothing);
    expect(
      find.byKey(const ValueKey('tag-library-entry-preview-overlay')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('搜索后无图条目仍可正常添加', (tester) async {
    _setViewport(tester, const Size(800, 600));
    final hiddenEntry = _entry(id: 'hidden', name: '其他预设');
    final targetEntry = _entry(id: 'target', name: '目标预设');
    TagLibraryEntry? selected;

    await _openPicker(
      tester,
      entries: [hiddenEntry, targetEntry],
      onSelect: (value) => selected = value,
    );
    await tester.enterText(find.byType(TextField), '目标');
    await tester.pump();

    expect(
      find.byKey(const ValueKey('fixed-tag-library-entry-hidden')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('fixed-tag-library-entry-target')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('fixed-tag-library-entry-target')),
    );
    await tester.pumpAndSettle();

    expect(selected, targetEntry);
    expect(find.byType(FixedTagLibraryPickerDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

TagLibraryEntry _entry({
  required String id,
  required String name,
  String? thumbnail,
}) {
  return TagLibraryEntry.create(
    name: name,
    content: '1girl, blue eyes',
    thumbnail: thumbnail,
    tags: const ['角色'],
  ).copyWith(id: id);
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openPicker(
  WidgetTester tester, {
  required List<TagLibraryEntry> entries,
  ValueChanged<TagLibraryEntry>? onSelect,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: textScaler,
          padding: padding,
          viewPadding: padding,
          viewInsets: viewInsets,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () {
              unawaited(
                FixedTagLibraryPickerDialog.show(
                  context: context,
                  entries: entries,
                ).then((entry) {
                  if (entry != null) onSelect?.call(entry);
                }),
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}

Future<TestGesture> _hoverEntry(WidgetTester tester, String entryId) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer();
  await mouse.moveTo(
    tester.getCenter(find.byKey(ValueKey('fixed-tag-library-entry-$entryId'))),
  );
  return mouse;
}
