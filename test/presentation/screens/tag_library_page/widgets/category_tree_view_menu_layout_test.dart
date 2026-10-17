import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/category_tree_view.dart';

Finder _menuText(String label) => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
  matching: find.text(label),
);

Future<void> _pumpTree(
  WidgetTester tester, {
  required Size size,
  required String locale,
  required double scale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: CategoryTreeView(
          categories: [
            TagLibraryCategory(
              id: 'parent',
              name: 'P',
              createdAt: DateTime(2026),
            ),
            TagLibraryCategory(
              id: 'child',
              name: 'C',
              parentId: 'parent',
              createdAt: DateTime(2026),
            ),
          ],
          entries: const [],
          expandedCategoryIds: const {'parent'},
          onExpandedCategoryIdsChanged: (_) {},
          onCategorySelected: (_) {},
          onCategoryRename: (_, _) {},
          onCategoryDelete: (_) {},
          onAddSubCategory: (_) {},
          onAddEntry: (_) {},
          onCategoryMove: (_, _) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectMenuReachable(
  WidgetTester tester,
  Iterable<String> labels,
) async {
  expect(tester.takeException(), isNull);
  for (final label in labels) {
    final item = _menuText(label);
    expect(item, findsOneWidget, reason: label);
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    expect(item.hitTestable(), findsOneWidget, reason: label);
  }
  expect(tester.takeException(), isNull);
}

void main() {
  const cases = [
    (size: Size(360, 760), locale: 'en', scale: 1.0),
    (size: Size(360, 760), locale: 'en', scale: 3.0),
    (size: Size(360, 760), locale: 'ja', scale: 3.0),
    (size: Size(600, 760), locale: 'en', scale: 3.0),
    (size: Size(600, 760), locale: 'ja', scale: 1.0),
  ];

  for (final c in cases) {
    final name = '${c.size.width.toInt()} ${c.locale} ${c.scale}x';

    testWidgets('$name 分类右键菜单不溢出且每项可点', (tester) async {
      await _pumpTree(tester, size: c.size, locale: c.locale, scale: c.scale);
      final l10n = lookupAppLocalizations(Locale(c.locale));

      await tester.tap(find.text('C'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      await _expectMenuReachable(tester, [
        l10n.common_rename,
        l10n.tagLibrary_addEntry,
        l10n.tagLibrary_addSubCategory,
        l10n.tagLibrary_moveToRoot,
        l10n.common_delete,
      ]);
    });

    testWidgets('$name 空白区域右键菜单不溢出且每项可点', (tester) async {
      await _pumpTree(tester, size: c.size, locale: c.locale, scale: c.scale);
      final l10n = lookupAppLocalizations(Locale(c.locale));

      await tester.tapAt(
        Offset(c.size.width / 2, c.size.height - 8),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      await _expectMenuReachable(tester, [
        l10n.tagLibrary_addEntry,
        l10n.tagLibrary_newCategory,
      ]);
    });
  }
}
