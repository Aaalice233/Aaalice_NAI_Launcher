import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/tag_library/tag_library_entry_hover_preview.dart';

void main() {
  testWidgets('词库来源条目悬浮后显示完整词库同款预览', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final entry = TagLibraryEntry.create(
      name: '角色预设',
      content: '1girl, blue eyes',
      tags: const ['角色', '蓝色'],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 260,
              height: 64,
              child: TagLibraryEntryHoverPreview(
                entry: entry,
                child: const ColoredBox(color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getCenter(find.byType(TagLibraryEntryHoverPreview)),
    );
    await tester.pump(const Duration(milliseconds: 499));

    const previewKey = ValueKey('tag-library-entry-preview-overlay');
    expect(find.byKey(previewKey), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byKey(previewKey), findsOneWidget);
    expect(find.text('角色预设'), findsOneWidget);
    expect(find.text('1girl, blue eyes'), findsOneWidget);
    expect(find.text('角色'), findsOneWidget);
    expect(find.text('蓝色'), findsOneWidget);

    await mouse.moveTo(const Offset(10, 10));
    await tester.pump();
    expect(find.byKey(previewKey), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
