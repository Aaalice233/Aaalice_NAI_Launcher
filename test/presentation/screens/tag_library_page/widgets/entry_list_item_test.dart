import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/entry_list_item.dart';

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

  testWidgets('桌面悬浮操作不会改变翻译摘要的布局几何', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final timestamp = DateTime(2026);
    final entry = TagLibraryEntry(
      id: 'stable-entry',
      name: '稳定条目',
      content: List.filled(20, 'long_prompt_tag').join(', '),
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
    final prompt = find.text(entry.content);
    final restingItemRect = tester.getRect(item);
    final restingPromptSize = tester.getSize(prompt);
    final placeholder = find.byIcon(Icons.image_outlined);
    expect(
      tester.getSize(
        find.ancestor(of: placeholder, matching: find.byType(Container)).first,
      ),
      const Size(64, 64),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(850, 300));
    await mouse.moveTo(tester.getCenter(item));
    await tester.pump(const Duration(milliseconds: 220));

    expect(tester.getRect(item).size, restingItemRect.size);
    expect(tester.getSize(prompt), restingPromptSize);
    expect(tester.takeException(), isNull);
  });
}
