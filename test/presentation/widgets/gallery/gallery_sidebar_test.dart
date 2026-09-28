import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
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

  testWidgets('侧栏分组标题悬停只加深分组底色，按压反馈画在侧栏底色之上', (tester) async {
    var toggles = 0;
    await _pumpSectionHeader(tester, onToggle: () => toggles++);
    final surface = _sidebarSurface();
    final toggle = _sectionToggle();
    final theme = Theme.of(tester.element(toggle));
    final sidebarFill = controlSurfaceColor(theme.colorScheme);

    await hoverOver(tester, toggle);
    final header = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('section-toggle')),
    );
    expect(
      (header.decoration! as BoxDecoration).color,
      theme.colorScheme.onSurface.withValues(alpha: 0.11),
    );
    expect(
      tester.renderObject(surface),
      isNot(inkOnTop(ink: theme.hoverColor)),
    );

    final press = await pressAndHold(tester, toggle);
    expectInkOnTop(
      tester,
      surface,
      ink: theme.highlightColor,
      below: sidebarFill,
    );
    await press.up();
    await tester.pump();
    expect(toggles, 1);
  });

  testWidgets(
    'Tab 聚焦侧栏分组标题时焦点高亮画在侧栏底色之上',
    (tester) async {
      await _pumpSectionHeader(tester, onToggle: () {});
      final surface = _sidebarSurface();
      final theme = Theme.of(tester.element(surface));

      await tabUntilFocused(tester, _sectionToggle());
      expectInkOnTop(
        tester,
        surface,
        ink: theme.focusColor,
        below: controlSurfaceColor(theme.colorScheme),
      );
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
    }),
  );

  testWidgets('集合工具栏上的菜单按钮悬停与按压反馈画在工具栏底色之上', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GalleryCollectionToolbarSurface(
            child: Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<int>(
                key: const ValueKey('toolbar-menu'),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 1, child: Text('1')),
                ],
                child: const SizedBox(width: 96, height: 48),
              ),
            ),
          ),
        ),
      ),
    );
    final toolbar = find.byType(GalleryCollectionToolbarSurface);
    final menu = find.byKey(const ValueKey('toolbar-menu'));
    final theme = Theme.of(tester.element(menu));
    final toolbarFill = sectionSurfaceColor(theme.colorScheme);

    await hoverOver(tester, menu);
    expectInkOnTop(tester, toolbar, ink: theme.hoverColor, below: toolbarFill);

    final press = await pressAndHold(tester, menu);
    expectInkOnTop(
      tester,
      toolbar,
      ink: theme.highlightColor,
      below: toolbarFill,
    );
    await press.cancel();
    await tester.pump(const Duration(milliseconds: 300));
  });
}

Finder _sidebarSurface() => find.byType(GallerySidebarSurface);

Finder _sectionToggle() => find.descendant(
  of: find.byType(GallerySidebarSectionHeader),
  matching: find.byType(InkWell),
);

Future<void> _pumpSectionHeader(
  WidgetTester tester, {
  required VoidCallback onToggle,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 400,
            child: GallerySidebarSurface(
              child: Column(
                children: [
                  GallerySidebarSectionHeader(
                    toggleKey: const ValueKey('section-toggle'),
                    icon: Icons.photo_album_outlined,
                    title: '相簿',
                    isExpanded: true,
                    onToggle: onToggle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
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
