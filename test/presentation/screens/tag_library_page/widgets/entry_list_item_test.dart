import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/entry_list_item.dart';
import 'package:nai_launcher/presentation/widgets/common/library_card_badges.dart';

void main() {
  testWidgets('列表模式按可用宽度展示完整提示词摘要', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1180, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final content = List.generate(
      80,
      (index) => 'prompt_tag_$index',
    ).join(', ');
    final timestamp = DateTime(2026);
    final entry = TagLibraryEntry(
      id: 'wide-entry',
      name: '宽屏条目',
      content: content,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EntryListItem(
            entry: entry,
            onTap: () {},
            onDelete: () {},
            onToggleFavorite: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final prompt = find.text(content);
    expect(prompt, findsOneWidget);
    expect(tester.getSize(prompt).width, greaterThan(700));
    expect(tester.takeException(), isNull);
  });

  testWidgets('桌面悬浮使用不闪烁的高亮且不会抬升或改变布局几何', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final timestamp = DateTime(2026);
    final entry = TagLibraryEntry(
      id: 'stable-entry',
      name: '稳定条目',
      content: List.filled(20, 'long_prompt_tag').join(', '),
      isFavorite: true,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EntryListItem(
            entry: entry,
            onTap: () {},
            onDelete: () {},
            onToggleFavorite: () {},
            onEdit: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final item = find.byType(EntryListItem);
    final itemContainer = find
        .descendant(of: item, matching: find.byType(AnimatedContainer))
        .first;
    final prompt = find.text(entry.content);
    final restingItemRect = tester.getRect(item);
    final restingPromptSize = tester.getSize(prompt);
    final theme = Theme.of(tester.element(item));
    final placeholder = find.byIcon(Icons.image_outlined);
    final thumbnail = find
        .ancestor(of: placeholder, matching: find.byType(Container))
        .first;
    expect(tester.getSize(thumbnail), const Size(64, 64));
    final favoriteBadge = find.byType(LibraryCardFavoriteBadge);
    final favoriteIcon = find.descendant(
      of: favoriteBadge,
      matching: find.byIcon(Icons.favorite_rounded),
    );
    expect(favoriteBadge, findsOneWidget);
    expect(favoriteIcon, findsOneWidget);
    expect(
      tester.getRect(favoriteBadge).topLeft,
      restingItemRect.topLeft + const Offset(12, 8),
    );
    expect(
      tester.getRect(favoriteIcon).center,
      tester.getRect(favoriteBadge).center,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(850, 300));
    await mouse.moveTo(tester.getCenter(item));
    await tester.pump(const Duration(milliseconds: 220));

    final hoveredContainer = tester.widget<AnimatedContainer>(itemContainer);
    final hoveredDecoration = hoveredContainer.decoration! as BoxDecoration;
    expect(hoveredContainer.transform, isNull);
    expect(
      hoveredDecoration.color,
      Color.alphaBlend(
        theme.colorScheme.primary.withValues(alpha: 0.08),
        theme.colorScheme.surfaceContainerLow,
      ),
    );
    expect(hoveredDecoration.color!.a, 1);
    expect(tester.getRect(item).size, restingItemRect.size);
    expect(tester.getSize(prompt), restingPromptSize);
    expect(tester.takeException(), isNull);
  });
}
