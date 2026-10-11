import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/library_export/library_export_panel.dart';
import 'package:nai_launcher/presentation/widgets/library_export/library_selection_controller.dart';

void main() {
  testWidgets('默认展开根分类与未分类，并渲染条目内容', (tester) async {
    final selection = await _pumpPanel(tester);

    expect(find.text('根分类'), findsOneWidget);
    expect(find.text('子分类'), findsOneWidget);
    expect(find.text('空分类'), findsOneWidget);
    expect(find.text('未分类'), findsOneWidget);
    expect(find.text('根条目'), findsOneWidget);
    expect(find.text('未分类条目'), findsOneWidget);
    // 子分类默认折叠
    expect(find.text('子条目'), findsNothing);
    expect(selection.isExpanded('child'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('折叠与展开分类只影响自身子树', (tester) async {
    final selection = await _pumpPanel(tester);

    await tester.tap(_expandButtonNear('根分类'));
    await tester.pump();
    expect(selection.isExpanded('root'), isFalse);
    expect(find.text('子分类'), findsNothing);
    expect(find.text('根条目'), findsNothing);
    expect(find.text('未分类条目'), findsOneWidget);

    await tester.tap(_expandButtonNear('根分类'));
    await tester.pump();
    expect(find.text('子分类'), findsOneWidget);
    expect(find.text('根条目'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('分类复选框级联到直接子分类与直接条目', (tester) async {
    final selection = await _pumpPanel(tester);

    await tester.tap(_checkboxNear('根分类'));
    await tester.pump();

    expect(selection.isCategorySelected('root'), isFalse);
    expect(selection.isCategorySelected('child'), isFalse);
    expect(selection.isEntrySelected('e-root'), isFalse);
    expect(selection.isEntrySelected('e-child'), isTrue);

    await tester.tap(_checkboxNear('根条目'));
    await tester.pump();
    expect(selection.isEntrySelected('e-root'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未分类分组整体切换', (tester) async {
    final selection = await _pumpPanel(tester);

    await tester.tap(_checkboxNear('未分类'));
    await tester.pump();
    expect(selection.isEntrySelected('e-free'), isFalse);

    await tester.tap(_checkboxNear('未分类'));
    await tester.pump();
    expect(selection.isEntrySelected('e-free'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidesEmptyCategories 隐藏既无子分类也无条目的分类', (tester) async {
    await _pumpPanel(tester, hidesEmptyCategories: true);

    expect(find.text('空分类'), findsNothing);
    expect(find.text('根分类'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 600.0, 1180.0, 1600.0]) {
    testWidgets('${width.toInt()} 宽下条目与操作完整可达且不溢出', (tester) async {
      final selection = await _pumpPanel(
        tester,
        width: width,
        textScaler: width == 320
            ? const TextScaler.linear(3)
            : TextScaler.noScaling,
      );

      expect(find.text('根分类'), findsOneWidget);
      expect(find.text('根条目'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(6));

      for (final label in ['根分类', '空分类', '未分类', '根条目']) {
        final checkbox = _checkboxNear(label);
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pump();
      }
      expect(selection.isNothingSelected, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('自带视口模式按可用高度 clamp 列表高度', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 800);
    addTearDown(tester.view.reset);

    await _pumpPanel(
      tester,
      mode: LibraryExportListMode.scrollable,
      wrapInScrollView: false,
    );

    expect(
      tester.getSize(find.byType(LibraryExportPanel<String>)).height,
      280,
    );
    expect(tester.takeException(), isNull);
  });

  test('列表高度扣除安全区与键盘后取 120～320', () {
    expect(
      LibraryExportPanel.listHeightFor(
        const MediaQueryData(size: Size(600, 2000)),
      ),
      320,
    );
    expect(
      LibraryExportPanel.listHeightFor(
        const MediaQueryData(size: Size(600, 200)),
      ),
      120,
    );
    expect(
      LibraryExportPanel.listHeightFor(
        const MediaQueryData(
          size: Size(600, 800),
          padding: EdgeInsets.only(top: 24, bottom: 24),
          viewInsets: EdgeInsets.only(bottom: 152),
        ),
      ),
      210,
    );
  });

  testWidgets('触屏策略下展开按钮保留 48 命中区', (tester) async {
    await _pumpPanel(tester, policy: InteractionPolicy.touchFirst);

    expect(
      tester.getSize(_expandButtonNear('根分类')),
      const Size.square(48),
    );
  });

  testWidgets('精确指针下展开按钮收紧到触屏命中区以下', (tester) async {
    await _pumpPanel(
      tester,
      policy: const InteractionPolicy(
        modality: InteractionModality.pointer,
        touchAvailable: false,
        precisePointerAvailable: true,
      ),
    );

    final size = tester.getSize(_expandButtonNear('根分类'));
    expect(size.height, lessThan(48));
    expect(size.width, lessThan(48));
  });
}

Finder _expandButtonNear(String label) {
  return find.descendant(
    of: _rowOf(label),
    matching: find.byType(IconButton),
  );
}

Finder _checkboxNear(String label) {
  return find.descendant(of: _rowOf(label), matching: find.byType(Checkbox));
}

Finder _rowOf(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(Row),
).first;

Future<LibrarySelectionController> _pumpPanel(
  WidgetTester tester, {
  double width = 600,
  TextScaler textScaler = TextScaler.noScaling,
  LibraryExportListMode mode = LibraryExportListMode.shrinkWrap,
  bool hidesEmptyCategories = false,
  bool wrapInScrollView = true,
  InteractionPolicy? policy,
}) async {
  final tree = _buildTree();
  final selection = LibrarySelectionController(tree: tree);
  addTearDown(selection.dispose);

  final panel = LibraryExportPanel<String>(
    tree: tree,
    selection: selection,
    uncategorizedLabel: '未分类',
    mode: mode,
    hidesEmptyCategories: hidesEmptyCategories,
    entryContentBuilder: (context, entry) => Text(entry.value),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: Scaffold(
            body: InteractionPolicyScope(
              initialPolicy: policy,
              child: SizedBox(
                width: width,
                child: wrapInScrollView
                    ? SingleChildScrollView(child: panel)
                    : panel,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return selection;
}

LibrarySelectionTree<String> _buildTree() {
  return LibrarySelectionTree<String>(
    categories: const [
      LibraryCategoryNode(id: 'root', displayName: '根分类'),
      LibraryCategoryNode(id: 'child', displayName: '子分类', parentId: 'root'),
      LibraryCategoryNode(id: 'empty', displayName: '空分类'),
    ],
    entries: const [
      LibraryEntryNode<String>(
        id: 'e-root',
        value: '根条目',
        categoryId: 'root',
      ),
      LibraryEntryNode<String>(
        id: 'e-child',
        value: '子条目',
        categoryId: 'child',
      ),
      LibraryEntryNode<String>(id: 'e-free', value: '未分类条目'),
    ],
  );
}
