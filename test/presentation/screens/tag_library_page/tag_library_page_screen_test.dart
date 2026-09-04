import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/tag_library_page_screen.dart';

void main() {
  testWidgets(
    'mobile category selection closes its panel without popping route',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const TagLibraryPageScreen()),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagLibraryPageNotifierProvider.overrideWith(
              _TestTagLibraryPageNotifier.new,
            ),
            shortcutConfigNotifierProvider.overrideWith(
              _TestShortcutConfigNotifier.new,
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tag-library-categories-button')));
      await tester.pumpAndSettle();
      expect(find.text('测试类别'), findsOneWidget);

      await tester.tap(find.text('测试类别'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TagLibraryPageScreen)),
      );
      expect(
        container.read(tagLibraryPageNotifierProvider).selectedCategoryId,
        'test-category',
      );
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.text('测试类别'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('category expansion survives round trips across 840px', (
    tester,
  ) async {
    await _setViewport(tester, const Size(840, 700));
    await _pumpTagLibrary(tester, _TestTagLibraryPageNotifier.new);

    expect(
      find.byKey(const Key('tag-library-category-section-toggle')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('tag-library-all-entries')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.text('测试子类别'), findsOneWidget);

    tester.view.physicalSize = const Size(839, 700);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tag-library-category-sidebar')), findsNothing);

    tester.view.physicalSize = const Size(840, 700);
    await tester.pumpAndSettle();
    expect(find.text('测试子类别'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop toolbar toggles the persistent category panel', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1180, 700));
    await _pumpTagLibrary(tester, _TestTagLibraryPageNotifier.new);

    final categoriesButton = find.byKey(
      const Key('tag-library-categories-button'),
    );
    expect(
      find.byKey(const Key('tag-library-category-sidebar')),
      findsOneWidget,
    );

    await tester.tap(categoriesButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tag-library-category-sidebar')), findsNothing);

    await tester.tap(categoriesButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('tag-library-category-sidebar')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact category panel keeps expansion after close and reopen', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 700));
    await _pumpTagLibrary(tester, _TestTagLibraryPageNotifier.new);

    final categoriesButton = find.byKey(
      const Key('tag-library-categories-button'),
    );
    await tester.tap(categoriesButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.text('测试子类别'), findsOneWidget);

    await tester.tap(find.text('测试子类别'));
    await tester.pumpAndSettle();
    expect(find.text('测试子类别'), findsNothing);

    await tester.tap(categoriesButton);
    await tester.pumpAndSettle();
    expect(find.text('测试子类别'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toolbar opens add import and export through adaptive forms', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1180, 800));
    await _pumpTagLibrary(tester, _DialogTagLibraryPageNotifier.new);

    for (final label in ['添加条目', '导入', '导出']) {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('adaptive-centered-form')),
        findsOneWidget,
        reason: label,
      );
      expect(find.byType(Dialog), findsNothing, reason: label);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('card tail and content context menu both create entries', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1180, 800));
    await _pumpTagLibrary(tester, _DialogTagLibraryPageNotifier.new);

    await tester.tap(find.byKey(const Key('tag-library-create-card')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(GridView), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('tag-library-context-create-entry')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('tag-library-context-create-entry')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('new category input survives compact SafeArea IME and 3x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
    await _pumpTagLibrary(
      tester,
      _DialogTagLibraryPageNotifier.new,
      textScale: 3,
    );

    await tester.tap(find.byKey(const Key('tag-library-categories-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建'));
    await tester.pumpAndSettle();

    final panels = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    expect(panels, findsNWidgets(2));
    final panel = panels.last;
    expect(
      find.byKey(const ValueKey('tag-library-add-category-form')),
      findsOneWidget,
    );
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('创建'), findsOneWidget);
    final rect = tester.getRect(panel);
    expect(rect.top, greaterThanOrEqualTo(24));
    expect(rect.bottom, lessThanOrEqualTo(408));
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tag-library-add-category-form')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
  });

  testWidgets('responsive sidebar rebuild keeps the active library viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1180, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagLibraryPageNotifierProvider.overrideWith(
            _ScrollableTagLibraryPageNotifier.new,
          ),
          shortcutConfigNotifierProvider.overrideWith(
            _TestShortcutConfigNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TagLibraryPageScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GridView), const Offset(0, -420));
    await tester.pumpAndSettle();
    double offset() => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(GridView),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .pixels;
    final desktopOffset = offset();
    expect(desktopOffset, greaterThan(0));

    tester.view.physicalSize = const Size(390, 700);
    await tester.pumpAndSettle();
    expect(offset(), closeTo(desktopOffset, 1));

    tester.view.physicalSize = const Size(1180, 700);
    await tester.pumpAndSettle();
    expect(offset(), closeTo(desktopOffset, 1));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpTagLibrary(
  WidgetTester tester,
  TagLibraryPageNotifier Function() createNotifier, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tagLibraryPageNotifierProvider.overrideWith(createNotifier),
        shortcutConfigNotifierProvider.overrideWith(
          _TestShortcutConfigNotifier.new,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const TagLibraryPageScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _TestShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

class _DialogTagLibraryPageNotifier extends TagLibraryPageNotifier {
  @override
  TagLibraryPageState build() => TagLibraryPageState(
    viewMode: TagLibraryViewMode.card,
    entries: [
      TagLibraryEntry(
        id: 'dialog-entry',
        name: '对话框条目',
        content: '1girl',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ],
  );
}

class _ScrollableTagLibraryPageNotifier extends TagLibraryPageNotifier {
  @override
  TagLibraryPageState build() => TagLibraryPageState(
    viewMode: TagLibraryViewMode.card,
    entries: [
      for (var index = 0; index < 100; index++)
        TagLibraryEntry(
          id: 'entry-$index',
          name: '条目 $index',
          content: 'tag_$index',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
    ],
  );
}

class _TestTagLibraryPageNotifier extends TagLibraryPageNotifier {
  @override
  TagLibraryPageState build() => TagLibraryPageState(
    categories: [
      TagLibraryCategory(
        id: 'test-category',
        name: '测试类别',
        createdAt: DateTime(2026),
      ),
      TagLibraryCategory(
        id: 'test-child-category',
        name: '测试子类别',
        parentId: 'test-category',
        createdAt: DateTime(2026),
      ),
    ],
  );
}
