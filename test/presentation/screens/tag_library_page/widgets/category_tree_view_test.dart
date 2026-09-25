import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/category_tree_view.dart';
import 'package:nai_launcher/presentation/widgets/common/surface_ink_well.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_divider.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_sidebar.dart';

import '../../../../helpers/ink_expectations.dart';

void main() {
  testWidgets('分类悬停切换时仅高亮当前行且不改变选中行', (tester) async {
    await _pumpCategoryTree(tester);

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

    Color backgroundColor(String label) =>
        tester.widget<SurfaceInkWell>(_categoryRow(label)).color!;

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

  testWidgets('分类右键菜单可在目标分类中创建词条', (tester) async {
    final category = TagLibraryCategory(
      id: 'target-category',
      name: '目标分类',
      createdAt: DateTime(2026),
    );
    String? createdInCategory;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 320,
            child: CategoryTreeView(
              categories: [category],
              entries: const [],
              expandedCategoryIds: const {},
              onExpandedCategoryIdsChanged: (_) {},
              onCategorySelected: (_) {},
              onCategoryRename: (_, _) {},
              onCategoryDelete: (_) {},
              onAddSubCategory: (_) {},
              onAddEntry: (id) => createdInCategory = id,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('目标分类'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加条目'));
    await tester.pumpAndSettle();

    expect(createdInCategory, 'target-category');
    expect(tester.takeException(), isNull);
  });

  testWidgets('悬停出现的操作菜单在指针移出行后仍能派发选中项', (tester) async {
    String? addedUnderCategory;
    final categories = [
      TagLibraryCategory(
        id: 'target-category',
        name: '目标分类',
        createdAt: DateTime(2026),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InteractionPolicyScope(
            initialPolicy: const InteractionPolicy(
              modality: InteractionModality.pointer,
              touchAvailable: false,
              precisePointerAvailable: true,
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                height: 320,
                child: CategoryTreeView(
                  categories: categories,
                  entries: const [],
                  selectedCategoryId: null,
                  expandedCategoryIds: const <String>{},
                  onExpandedCategoryIdsChanged: (_) {},
                  onCategorySelected: (_) {},
                  onCategoryRename: (_, _) {},
                  onCategoryDelete: (_) {},
                  onAddSubCategory: (id) => addedUnderCategory = id,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 必须用真实鼠标：合成 tap 不更新指针命中，测不出菜单打开后按钮被卸载的回归。
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('目标分类')));
    await tester.pumpAndSettle();

    final menu = find.byKey(const ValueKey('category-item-actions-menu'));
    expect(menu, findsOneWidget);

    Future<void> clickAt(Offset target) async {
      await mouse.moveTo(target);
      await tester.pumpAndSettle();
      await mouse.down(target);
      await tester.pump();
      await mouse.up();
      await tester.pumpAndSettle();
    }

    await clickAt(tester.getCenter(menu));
    await clickAt(tester.getCenter(find.byIcon(Icons.create_new_folder)));

    expect(addedUnderCategory, 'target-category');
    expect(tester.takeException(), isNull);
  });

  testWidgets('悬停中的分类行按压时，反馈画在悬停底色之上', (tester) async {
    await _pumpCategoryTree(tester);
    final row = _categoryRow('第一悬停分类');
    final theme = Theme.of(tester.element(row));

    await hoverOver(tester, row);
    expect(tester.renderObject(row), isNot(inkOnTop(ink: theme.hoverColor)));

    final press = await pressAndHold(tester, row);
    expectInkOnTop(
      tester,
      row,
      ink: theme.highlightColor,
      below: theme.colorScheme.surfaceContainerHighest,
    );
    await press.up();
    await tester.pump();
  });

  testWidgets(
    'Tab 聚焦选中分类时焦点高亮画在选中底色之上',
    (tester) async {
      await _pumpCategoryTree(tester);
      final row = _categoryRow('已选分类');
      final theme = Theme.of(tester.element(row));

      await tabUntilFocused(
        tester,
        find.descendant(of: row, matching: find.byType(InkWell)),
      );
      expectInkOnTop(
        tester,
        row,
        ink: theme.focusColor,
        below: theme.colorScheme.primaryContainer,
      );
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
    }),
  );
}

Future<void> _pumpCategoryTree(WidgetTester tester) async {
  final categories = [
    TagLibraryCategory(id: 'selected', name: '已选分类', createdAt: DateTime(2026)),
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
}

Finder _categoryRow(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(SurfaceInkWell));
