import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/tag_library_page_screen.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/category_tree_view.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/tag_library_toolbar.dart';
import '../../../helpers/light_theme_contrast.dart';

void main() {
  testWidgets('open category panel immediately applies sorting and collapse', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    await _pumpTagLibrary(tester, _SortingTagLibraryPageNotifier.new);
    await tester.tap(find.byKey(const Key('tag-library-categories-button')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('分类 10')).dy,
      lessThan(tester.getTopLeft(find.text('分类 2')).dy),
    );
    final categoryElement = tester.element(find.text('分类 10'));
    await tester.tap(find.byKey(const ValueKey('sidebar-sort-tagCategories')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('sidebar-sort-option-nameAscending')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('分类 2')).dy,
      lessThan(tester.getTopLeft(find.text('分类 10')).dy),
    );
    expect(tester.element(find.text('分类 10')), same(categoryElement));
    final headerTitle = find.descendant(
      of: find.byKey(const Key('tag-library-category-section-toggle')),
      matching: find.text('分类'),
    );
    await tester.tap(headerTitle);
    await tester.pumpAndSettle();
    expect(find.text('分类 2'), findsNothing);
    await tester.tap(headerTitle);
    await tester.pumpAndSettle();
    expect(find.text('分类 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
    final createCategory = find.byTooltip('新建');
    await tester.ensureVisible(createCategory);
    await tester.tap(createCategory);
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

  testWidgets('挂载后 Ctrl+F 聚焦搜索框，点外部失焦后页面快捷键仍然可用', (tester) async {
    await _setViewport(tester, const Size(1180, 800));
    await _pumpTagLibrary(tester, _DialogTagLibraryPageNotifier.new);
    FocusNode searchFocus() => tester
        .widget<EditableText>(
          find.descendant(
            of: find.byType(TagLibraryToolbar),
            matching: find.byType(EditableText),
          ),
        )
        .focusNode;

    await _pressCtrl(tester, LogicalKeyboardKey.keyF);
    expect(searchFocus().hasPrimaryFocus, isTrue);

    await tester.tapAt(const Offset(1160, 780), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(searchFocus().hasFocus, isFalse);

    await _pressCtrl(tester, LogicalKeyboardKey.keyF);
    expect(searchFocus().hasPrimaryFocus, isTrue);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('搜索框里的 Delete 与 Ctrl+C 交给输入框，不被批量操作快捷键截走', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _setViewport(tester, const Size(1180, 800));
    await _pumpTagLibrary(tester, _DialogTagLibraryPageNotifier.new);
    final search = find.descendant(
      of: find.byType(TagLibraryToolbar),
      matching: find.byType(EditableText),
    );
    await _pressCtrl(tester, LogicalKeyboardKey.keyF);
    await tester.enterText(search, 'abc');
    await tester.pump();
    final controller = tester.widget<EditableText>(search).controller;
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(controller.text, 'bc');

    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
    await tester.pump();
    await _pressCtrl(tester, LogicalKeyboardKey.keyC);
    expect(copied, ['bc']);
  });

  testWidgets('搜索框留在页面作用域焦点历史里时，右键重命名的分类输入框仍直接可输入', (tester) async {
    await _setViewport(tester, const Size(1180, 800));
    await _pumpTagLibrary(tester, _TestTagLibraryPageNotifier.new);
    final search = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(TagLibraryToolbar),
        matching: find.byType(EditableText),
      ),
    );
    await _pressCtrl(tester, LogicalKeyboardKey.keyF);
    // 外壳切回分支时只聚焦输入框所在作用域，输入框仍是该作用域记住的子节点
    search.focusNode.enclosingScope!.requestScopeFocus();
    await tester.pump();

    await tester.tap(
      find.text('测试类别'),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名').last);
    await tester.pumpAndSettle();

    final rename = tester.widget<EditableText>(
      find.byWidgetPredicate(
        (widget) => widget is EditableText && widget.controller.text == '测试类别',
      ),
    );
    expect(rename.focusNode.hasPrimaryFocus, isTrue);
    tester.testTextInput.enterText('新类别');
    await tester.pump();
    expect(rename.controller.text, '新类别');
    expect(search.controller.text, isEmpty);
  });

  testWidgets('重命名分类时按 Esc 放弃修改并退出，按键不冒泡给页面', (tester) async {
    await _setViewport(tester, const Size(1180, 800));
    await _pumpTagLibrary(tester, _TestTagLibraryPageNotifier.new);
    await _openCategoryRename(tester, '测试类别');
    final escapes = _recordBubbledEscapes(tester);

    tester.testTextInput.enterText('草稿');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(escapes, isEmpty, reason: 'Esc 应被重命名框消费');
    expect(_categoryRenameField(), findsNothing);
    expect(find.text('测试类别'), findsOneWidget);

    await _openCategoryRename(tester, '测试类别');
    expect(_categoryRenameEditable(tester).controller.text, '测试类别');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_categoryRenameField(), findsNothing);
  });

  testWidgets('重命名分类回车不被页面“发送到首页”截走，新名称写入存储', (tester) async {
    await _setViewport(tester, const Size(1180, 800));
    await _pumpTagLibrary(tester, _StoredTagLibraryPageNotifier.new);
    await _openCategoryRename(tester, '测试类别');

    tester.testTextInput.enterText('新类别');
    await tester.pump();
    // 桌面引擎只在框架未处理时把回车交给输入法，由输入法触发提交
    final handled = await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(handled, isFalse);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TagLibraryPageScreen)),
    );
    expect(_categoryRenameField(), findsNothing);
    expect(
      find.descendant(
        of: find.byType(CategoryTreeView),
        matching: find.text('新类别'),
      ),
      findsOneWidget,
    );
    expect(
      container.read(tagLibraryPageNotifierProvider).categories.single.name,
      '新类别',
    );
    expect(
      container.read(localStorageServiceProvider).getTagLibraryCategoriesJson(),
      contains('新类别'),
    );
  });
}

Finder _categoryRenameField() => find.descendant(
  of: find.byType(CategoryTreeView),
  matching: find.byType(EditableText),
);

EditableText _categoryRenameEditable(WidgetTester tester) =>
    tester.widget<EditableText>(_categoryRenameField());

Future<void> _openCategoryRename(WidgetTester tester, String label) async {
  await tester.tap(
    find.text(label),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('重命名').last);
  await tester.pumpAndSettle();
  expect(_categoryRenameField(), findsOneWidget);
  expect(_categoryRenameEditable(tester).focusNode.hasPrimaryFocus, isTrue);
}

/// 路由作用域位于分类树与页面级 Esc 绑定之间，冒泡的 Esc 必先经过它
List<KeyEvent> _recordBubbledEscapes(WidgetTester tester) {
  final scope = FocusScope.of(tester.element(find.byType(CategoryTreeView)));
  final previousHandler = scope.onKeyEvent;
  final escapes = <KeyEvent>[];
  scope.onKeyEvent = (node, event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      escapes.add(event);
    }
    return KeyEventResult.ignored;
  };
  addTearDown(() => scope.onKeyEvent = previousHandler);
  return escapes;
}

Future<void> _pressCtrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
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
        localStorageServiceProvider.overrideWith(
          (ref) => InMemoryLocalStorageService(),
        ),
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

/// 经存储加载，重命名的保存走真实持久化路径
class _StoredTagLibraryPageNotifier extends TagLibraryPageNotifier {
  @override
  TagLibraryPageState build() {
    ref
        .read(localStorageServiceProvider)
        .setTagLibraryCategoriesJson(
          jsonEncode([
            TagLibraryCategory(
              id: 'test-category',
              name: '测试类别',
              createdAt: DateTime(2026),
            ).toJson(),
          ]),
        );
    return super.build();
  }
}

class _SortingTagLibraryPageNotifier extends TagLibraryPageNotifier {
  @override
  TagLibraryPageState build() => TagLibraryPageState(
    categories: [
      TagLibraryCategory(
        id: 'a',
        name: '分类 10',
        sortOrder: 0,
        createdAt: DateTime(2026),
      ),
      TagLibraryCategory(
        id: 'b',
        name: '分类 2',
        sortOrder: 1,
        createdAt: DateTime(2026),
      ),
    ],
  );
}
