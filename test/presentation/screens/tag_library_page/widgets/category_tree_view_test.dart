import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/category_tree_view.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_divider.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_sidebar.dart';

void main() {
  testWidgets('分类悬停切换时仅高亮当前行且不改变选中行', (tester) async {
    final categories = [
      TagLibraryCategory(
        id: 'selected',
        name: '已选分类',
        createdAt: DateTime(2026),
      ),
      TagLibraryCategory(
        id: 'first-hover',
        name: '第一悬停分类',
        createdAt: DateTime(2026),
      ),
      TagLibraryCategory(
        id: 'second-hover',
        name: '第二悬停分类',
        createdAt: DateTime(2026),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              height: 320,
              child: CategoryTreeView(
                categories: categories,
                entries: const [],
                selectedCategoryId: 'selected',
                expandedCategoryIds: const <String>{},
                onExpandedCategoryIdsChanged: (_) {},
                onCategorySelected: (_) {},
                onCategoryRename: (_, _) {},
                onCategoryDelete: (_) {},
                onAddSubCategory: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(GallerySidebarNavigationItem), findsOneWidget);
    expect(find.byType(ThemedDivider), findsNothing);

    double navigationIconX(Finder row) {
      return tester
          .getCenter(
            find.descendant(of: row, matching: find.byType(Icon)).first,
          )
          .dx;
    }

    expect(
      navigationIconX(
        find.ancestor(of: find.text('已选分类'), matching: find.byType(InkWell)),
      ),
      closeTo(
        navigationIconX(find.byKey(const ValueKey('tag-library-favorites'))),
        0.1,
      ),
    );

    Container categoryBackground(String label) {
      final finder = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.margin ==
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        ),
      );
      expect(finder, findsOneWidget);
      return tester.widget<Container>(finder);
    }

    Color backgroundColor(String label) {
      final decoration = categoryBackground(label).decoration! as BoxDecoration;
      return decoration.color!;
    }

    final theme = Theme.of(tester.element(find.byType(CategoryTreeView)));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(700, 500));

    await mouse.moveTo(tester.getCenter(find.text('第一悬停分类')));
    await tester.pump();

    expect(backgroundColor('已选分类'), theme.colorScheme.primaryContainer);
    expect(
      backgroundColor('第一悬停分类'),
      theme.colorScheme.surfaceContainerHighest,
    );

    await mouse.moveTo(tester.getCenter(find.text('第二悬停分类')));
    await tester.pump();

    expect(backgroundColor('已选分类'), theme.colorScheme.primaryContainer);
    expect(backgroundColor('第一悬停分类'), Colors.transparent);
    expect(
      backgroundColor('第二悬停分类'),
      theme.colorScheme.surfaceContainerHighest,
    );

    final selectedInkWell = tester.widget<InkWell>(
      find.ancestor(of: find.text('已选分类'), matching: find.byType(InkWell)),
    );
    expect(selectedInkWell.hoverColor, Colors.transparent);
  });
}
