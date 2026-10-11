import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/category/vibe_category_item.dart';
import 'package:nai_launcher/presentation/widgets/common/surface_ink_well.dart';

import '../../../../../helpers/ink_expectations.dart';

void main() {
  testWidgets('未选中的分类悬停只换底色，按压反馈画在悬停底色之上', (tester) async {
    var taps = 0;
    await _pumpItem(tester, isSelected: false, onTap: () => taps++);
    final item = find.byType(SurfaceInkWell);
    final theme = Theme.of(tester.element(item));
    final hovered = theme.colorScheme.surfaceContainerHighest;

    await hoverOver(tester, item);
    expect(tester.widget<SurfaceInkWell>(item).color, hovered);
    expect(tester.renderObject(item), isNot(inkOnTop(ink: theme.hoverColor)));

    final press = await pressAndHold(tester, item);
    expectInkOnTop(tester, item, ink: theme.highlightColor, below: hovered);
    await press.up();
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('选中分类的悬停与按压反馈画在选中底色之上', (tester) async {
    await _pumpItem(tester, isSelected: true, onTap: () {});
    final item = find.byType(SurfaceInkWell);
    final theme = Theme.of(tester.element(item));
    final selected = theme.colorScheme.primaryContainer;

    await hoverOver(tester, item);
    expectInkOnTop(tester, item, ink: theme.hoverColor, below: selected);

    final press = await pressAndHold(tester, item);
    expectInkOnTop(tester, item, ink: theme.highlightColor, below: selected);
    await press.up();
    await tester.pump();
  });
}

Future<void> _pumpItem(
  WidgetTester tester, {
  required bool isSelected,
  required VoidCallback onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 280,
            child: VibeCategoryItem(
              icon: Icons.folder_outlined,
              label: '角色参考',
              count: 4,
              isSelected: isSelected,
              onTap: onTap,
            ),
          ),
        ),
      ),
    ),
  );
}
