import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/surface_ink_well.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_category_tree_view.dart';

import '../../../helpers/ink_expectations.dart';

void main() {
  testWidgets('未选中的分类行悬停只加深底色，按压反馈画在底色之上', (tester) async {
    String? selected;
    await _pumpTree(tester, onCategorySelected: (id) => selected = id);
    final row = _row('收藏');
    final theme = Theme.of(tester.element(row));
    final hovered = theme.colorScheme.onSurface.withValues(alpha: 0.07);

    await hoverOver(tester, row);
    expect(tester.widget<SurfaceInkWell>(row).color, hovered);
    expect(tester.renderObject(row), isNot(inkOnTop(ink: theme.hoverColor)));

    final press = await pressAndHold(tester, row);
    expectInkOnTop(tester, row, ink: theme.highlightColor, below: hovered);
    await press.up();
    await tester.pump();
    expect(selected, 'favorites');
  });

  testWidgets('选中的分类行悬停与按压反馈画在选中底色之上', (tester) async {
    await _pumpTree(tester, onCategorySelected: (_) {});
    final row = _row('全部图片');
    final theme = Theme.of(tester.element(row));
    final fill = theme.colorScheme.primaryContainer;

    await hoverOver(tester, row);
    expectInkOnTop(tester, row, ink: theme.hoverColor, below: fill);

    final press = await pressAndHold(tester, row);
    expectInkOnTop(tester, row, ink: theme.highlightColor, below: fill);
    await press.up();
    await tester.pump();
  });
}

Future<void> _pumpTree(
  WidgetTester tester, {
  required ValueChanged<String?> onCategorySelected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 280,
          height: 400,
          child: GalleryCategoryTreeView(
            categories: const [],
            totalImageCount: 3,
            showScanProgress: false,
            onCategorySelected: onCategorySelected,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _row(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(SurfaceInkWell));
