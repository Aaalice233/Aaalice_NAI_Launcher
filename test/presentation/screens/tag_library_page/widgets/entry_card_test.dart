import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/entry_card.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
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
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
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

  testWidgets('触屏更多菜单可以点击移动到分类', (tester) async {
    var classifyCount = 0;
    final entry = TagLibraryEntry(
      id: 'touch-entry',
      name: '触屏词条',
      content: '1girl',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InteractionPolicyScope(
          initialPolicy: const InteractionPolicy(
            modality: InteractionModality.touch,
            touchAvailable: true,
            precisePointerAvailable: false,
          ),
          child: Scaffold(
            body: EntryCard(
              entry: entry,
              onTap: () {},
              onDelete: () {},
              onToggleFavorite: () {},
              onClassify: () => classifyCount++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移动到分类'));
    expect(classifyCount, 1);
  });
}
