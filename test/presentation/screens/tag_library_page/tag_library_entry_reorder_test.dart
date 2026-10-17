import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_selection_provider.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/tag_library_page_screen.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/entry_reorder/entry_reorder_scope.dart';

import '../../../helpers/light_theme_contrast.dart';

const _touch = InteractionPolicy(
  modality: InteractionModality.touch,
  touchAvailable: true,
  precisePointerAvailable: false,
);
const _indicatorAfter = ValueKey('tag-library-reorder-indicator-after');
const _indicatorBefore = ValueKey('tag-library-reorder-indicator-before');

void main() {
  final abc = [_entry('a', 0), _entry('b', 1), _entry('c', 2)];

  testWidgets('触屏长按拖到另一张卡片的右半边，插到它之后', (tester) async {
    final container = await _pump(tester, entries: abc);

    final gesture = await _longPressDragTo(
      tester,
      _tile('a'),
      _rightPart(tester, _tile('c')),
    );
    expect(
      find.descendant(of: _tile('c'), matching: find.byKey(_indicatorAfter)),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_displayed(container), ['b', 'c', 'a']);
    expect(find.byKey(_indicatorAfter), findsNothing);
    expect(
      container.read(tagLibrarySelectionNotifierProvider).selectedIds,
      isEmpty,
      reason: '自定义排序下长按交给拖动，不进入多选',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖到左半边插到它之前，放回自身不改顺序', (tester) async {
    final container = await _pump(tester, entries: abc);

    final gesture = await _longPressDragTo(
      tester,
      _tile('c'),
      _leftPart(tester, _tile('a')),
    );
    expect(
      find.descendant(of: _tile('a'), matching: find.byKey(_indicatorBefore)),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_displayed(container), ['c', 'a', 'b']);

    final back = await _longPressDragTo(
      tester,
      _tile('b'),
      _rightPart(tester, _tile('b')),
    );
    expect(find.byKey(_indicatorAfter), findsNothing);
    await back.up();
    await tester.pumpAndSettle();
    expect(_displayed(container), ['c', 'a', 'b']);
  });

  testWidgets('多选时拖动选中项整组移动', (tester) async {
    final container = await _pump(tester, entries: abc);
    container.read(tagLibrarySelectionNotifierProvider.notifier)
      ..enterAndSelect('a')
      ..toggle('b');
    await tester.pump();

    final gesture = await _longPressDragTo(
      tester,
      _tile('a'),
      _rightPart(tester, _tile('c')),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_displayed(container), ['c', 'a', 'b']);
  });

  testWidgets('分组视图跨组放下时移入该分类', (tester) async {
    final container = await _pump(
      tester,
      viewMode: TagLibraryViewMode.grouped,
      categories: [_category('x', 0), _category('y', 1)],
      entries: [
        _entry('x1', 0, category: 'x'),
        _entry('x2', 1, category: 'x'),
        _entry('y1', 2, category: 'y'),
      ],
    );

    final gesture = await _longPressDragTo(
      tester,
      _tile('x1'),
      _rightPart(tester, _tile('y1')),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    final entries = container.read(tagLibraryPageNotifierProvider).entries;
    expect(entries.firstWhere((e) => e.id == 'x1').categoryId, 'y');
    expect(_displayed(container), ['x2', 'y1', 'x1']);
  });

  testWidgets('非自定义排序下长按仍进入多选，不出现插入线', (tester) async {
    final container = await _pump(tester, entries: abc);
    container
        .read(tagLibraryPageNotifierProvider.notifier)
        .setSortBy(TagLibrarySortBy.name);
    await tester.pumpAndSettle();

    final gesture = await _longPressDragTo(
      tester,
      _tile('a'),
      _rightPart(tester, _tile('c')),
    );
    expect(find.byKey(_indicatorAfter), findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      container.read(tagLibrarySelectionNotifierProvider).selectedIds,
      contains('a'),
    );
    expect(_displayed(container), ['a', 'b', 'c']);
  });

  testWidgets('拖到列表下边缘时自动滚动，离开边缘即停', (tester) async {
    await _pump(
      tester,
      viewMode: TagLibraryViewMode.list,
      entries: [for (var i = 0; i < 40; i++) _entry('e$i', i)],
    );
    final scope = tester.getRect(find.byType(EntryReorderScope));
    ScrollPosition position() => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(EntryReorderScope),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    final gesture = await _longPressDragTo(
      tester,
      _tile('e0'),
      Offset(scope.center.dx, scope.bottom - 4),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final scrolled = position().pixels;
    expect(scrolled, greaterThan(0));

    await gesture.moveTo(scope.center);
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(position().pixels, scrolled);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Finder _tile(String id) => find.byKey(ValueKey(id));

Offset _rightPart(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  return Offset(rect.right - rect.width / 6, rect.center.dy);
}

Offset _leftPart(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  return Offset(rect.left + rect.width / 6, rect.center.dy);
}

Future<TestGesture> _longPressDragTo(
  WidgetTester tester,
  Finder source,
  Offset target,
) async {
  final start = tester.getCenter(source);
  final gesture = await tester.startGesture(
    start,
    kind: PointerDeviceKind.touch,
  );
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  for (var step = 1; step <= 6; step++) {
    await gesture.moveTo(Offset.lerp(start, target, step / 6)!);
    await tester.pump();
  }
  return gesture;
}

List<String> _displayed(ProviderContainer container) => [
  for (final e
      in container.read(tagLibraryPageNotifierProvider).filteredEntries)
    e.id,
];

TagLibraryEntry _entry(String id, int order, {String? category}) =>
    TagLibraryEntry(
      id: id,
      name: '条目 $id',
      content: id,
      sortOrder: order,
      categoryId: category,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

TagLibraryCategory _category(String id, int order) => TagLibraryCategory(
  id: id,
  name: '分类 $id',
  sortOrder: order,
  createdAt: DateTime(2026),
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required List<TagLibraryEntry> entries,
  List<TagLibraryCategory> categories = const [],
  TagLibraryViewMode viewMode = TagLibraryViewMode.card,
}) async {
  tester.view.physicalSize = const Size(840, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWith(
          (ref) => InMemoryLocalStorageService(),
        ),
        tagLibraryPageNotifierProvider.overrideWith(
          () => _SeededNotifier(entries, categories, viewMode),
        ),
        shortcutConfigNotifierProvider.overrideWith(_ShortcutConfig.new),
      ],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InteractionPolicyScope(
          initialPolicy: _touch,
          child: TagLibraryPageScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(TagLibraryPageScreen)),
  );
}

class _ShortcutConfig extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

/// 经存储加载，移动后的保存走真实持久化路径
class _SeededNotifier extends TagLibraryPageNotifier {
  _SeededNotifier(this.entries, this.categories, this.viewMode);

  final List<TagLibraryEntry> entries;
  final List<TagLibraryCategory> categories;
  final TagLibraryViewMode viewMode;

  @override
  TagLibraryPageState build() {
    final storage = ref.read(localStorageServiceProvider);
    storage
      ..setTagLibraryEntriesJson(
        jsonEncode(entries.map((e) => e.toJson()).toList()),
      )
      ..setTagLibraryCategoriesJson(
        jsonEncode(categories.map((c) => c.toJson()).toList()),
      )
      ..setTagLibraryViewMode(viewMode.index);
    return super.build();
  }
}
