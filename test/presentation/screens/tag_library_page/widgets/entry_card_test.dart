import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/entry_card.dart';
import 'package:nai_launcher/presentation/widgets/common/thumbnail_display.dart';

void main() {
  testWidgets('词库卡片在多选模式下仍显示名称', (tester) async {
    final entry = TagLibraryEntry(
      id: 'entry-1',
      name: '测试词条名称',
      content: '1girl, solo',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    Future<void> pumpCard({required bool isSelected}) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 80,
              child: EntryCard(
                entry: entry,
                isSelectionMode: true,
                isSelected: isSelected,
                onToggleSelection: () {},
                onTap: () {},
                onDelete: () {},
                onToggleFavorite: () {},
              ),
            ),
          ),
        ),
      );
    }

    await pumpCard(isSelected: false);
    expect(find.text(entry.displayName), findsOneWidget);

    await pumpCard(isSelected: true);
    expect(find.text(entry.displayName), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('切换多选模式时保留缩略图状态并禁用拖拽', (tester) async {
    final entry = TagLibraryEntry(
      id: 'entry-with-thumbnail',
      name: '带缩略图的词条',
      content: '1girl, solo',
      thumbnail: 'missing-thumbnail.png',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    Future<void> pumpCard({required bool isSelectionMode}) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 80,
              child: EntryCard(
                entry: entry,
                enableDrag: !isSelectionMode,
                isSelectionMode: isSelectionMode,
                onToggleSelection: () {},
                onTap: () {},
                onDelete: () {},
                onToggleFavorite: () {},
              ),
            ),
          ),
        ),
      );
    }

    await pumpCard(isSelectionMode: false);
    await tester.pump();
    final thumbnailFinder = find.byType(ThumbnailDisplay);
    final thumbnailState = tester.state(thumbnailFinder);
    final thumbnail = tester.widget<ThumbnailDisplay>(thumbnailFinder);

    expect(thumbnail.width, 240);
    expect(thumbnail.height, 80);

    await pumpCard(isSelectionMode: true);

    expect(tester.state(find.byType(ThumbnailDisplay)), same(thumbnailState));
    final draggable = tester.widget<Draggable<TagLibraryEntry>>(
      find.byType(Draggable<TagLibraryEntry>),
    );
    expect(draggable.maxSimultaneousDrags, 0);
  });

  testWidgets('词库卡片复用共享预览并在进入多选模式时清理', (tester) async {
    final entry = TagLibraryEntry(
      id: 'hover-entry',
      name: '悬浮词条',
      content: '1girl, solo',
      thumbnail: 'missing-thumbnail.png',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    Future<void> pumpCard({required bool isSelectionMode}) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                height: 80,
                child: EntryCard(
                  entry: entry,
                  isSelectionMode: isSelectionMode,
                  onToggleSelection: () {},
                  onTap: () {},
                  onDelete: () {},
                  onToggleFavorite: () {},
                ),
              ),
            ),
          ),
        ),
      );
    }

    await pumpCard(isSelectionMode: false);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byType(EntryCard)));
    await tester.pump(const Duration(milliseconds: 500));

    const previewKey = ValueKey('tag-library-entry-preview-overlay');
    expect(find.byKey(previewKey), findsOneWidget);

    await pumpCard(isSelectionMode: true);
    await tester.pump();
    expect(find.byKey(previewKey), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
