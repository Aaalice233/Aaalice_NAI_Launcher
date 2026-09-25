import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/surface_ink_well.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_sidebar.dart';

import '../../../helpers/ink_expectations.dart';

void main() {
  testWidgets('未选中导航项悬停只换底色，按压反馈画在悬停底色之上', (tester) async {
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

  testWidgets('选中导航项的悬停与按压反馈画在选中底色之上', (tester) async {
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

  testWidgets(
    'Tab 聚焦选中导航项时焦点高亮画在选中底色之上',
    (tester) async {
      await _pumpItem(tester, isSelected: true, onTap: () {});
      final item = find.byType(SurfaceInkWell);
      final theme = Theme.of(tester.element(item));

      await tabUntilFocused(
        tester,
        find.descendant(of: item, matching: find.byType(InkWell)),
      );
      expectInkOnTop(
        tester,
        item,
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

Future<void> _pumpItem(
  WidgetTester tester, {
  required bool isSelected,
  required VoidCallback onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 280,
            child: GallerySidebarNavigationItem(
              icon: Icons.photo_library_outlined,
              label: '全部作品',
              count: 12,
              isSelected: isSelected,
              onTap: onTap,
            ),
          ),
        ),
      ),
    ),
  );
}
