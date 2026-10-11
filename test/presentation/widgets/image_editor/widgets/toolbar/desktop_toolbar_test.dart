import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/closed_region_fill_tool.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/toolbar/desktop_toolbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'toolbar_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const closedFill = ClosedRegionFillTool.toolId;

  Widget toolbarHost(Widget toolbar) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(height: 2000, child: toolbar),
  );

  testWidgets('inpaint tools are grouped under titled sections', (
    tester,
  ) async {
    final (:state, source: _, mask: _) = createInpaintToolbarState();
    await pumpToolbarHost(
      tester,
      size: const Size(400, 2000),
      child: toolbarHost(DesktopToolbar(state: state)),
    );

    for (final (group, title) in [
      ('inpaint', '重绘'),
      ('edit', '编辑'),
      ('common', '通用'),
    ]) {
      expect(
        find.descendant(of: toolGroup(group), matching: find.text(title)),
        findsOneWidget,
      );
    }
    for (final toolId in ['brush', 'eraser', closedFill, 'fill', 'magic_wand']) {
      expectEntryInGroup('inpaint', toolId);
    }
    for (final toolId in [
      'brush',
      'eraser',
      'fill',
      'magic_wand',
      'blur',
      'clone_stamp',
      'color_picker',
    ]) {
      expectEntryInGroup('edit', toolId);
    }
    for (final toolId in [
      'move',
      'rect_selection',
      'ellipse_selection',
      'lasso_selection',
    ]) {
      expectEntryInGroup('common', toolId);
    }

    // 两个填充各有专属名称，封闭区域填充只在重绘组
    expect(find.byTooltip('填充封闭区域'), findsOneWidget);
    expect(find.byTooltip('按颜色填充蒙版 (G)'), findsOneWidget);
    expect(find.byTooltip('填充 (G)'), findsOneWidget);
    expect(toolEntry('edit', closedFill), findsNothing);
  });

  testWidgets('tapping an entry switches to the layer it edits', (
    tester,
  ) async {
    final (:state, :source, :mask) = createInpaintToolbarState();
    state.layerManager.setActiveLayer(source.id);
    await pumpToolbarHost(
      tester,
      size: const Size(400, 2000),
      child: toolbarHost(DesktopToolbar(state: state)),
    );

    await tester.tap(toolEntry('inpaint', closedFill));
    await tester.pump();
    expect(state.layerManager.activeLayer, same(mask));
    expect(state.currentTool?.id, closedFill);
    expect(isEntrySelected(tester, 'inpaint', closedFill), isTrue);
    expect(
      entrySemantics(tester, 'inpaint', closedFill).tooltip,
      '填充封闭区域',
    );

    await tester.tap(toolEntry('edit', 'brush'));
    await tester.pump();
    expect(state.layerManager.activeLayer, same(source));
    expect(state.currentTool?.id, 'brush');

    // 从图层面板切到蒙版层，高亮随之落到重绘组的同一工具
    state.layerManager.setActiveLayer(mask.id);
    await tester.pump();
    expect(isEntrySelected(tester, 'inpaint', 'brush'), isTrue);
    expect(isEntrySelected(tester, 'edit', 'brush'), isFalse);
  });

  testWidgets('edit sessions keep one ungrouped tool column', (tester) async {
    final state = createEditToolbarState();
    await pumpToolbarHost(
      tester,
      size: const Size(400, 2000),
      child: toolbarHost(DesktopToolbar(state: state)),
    );

    expect(toolGroup('inpaint'), findsNothing);
    expect(find.text('编辑'), findsNothing);
    expect(find.text('通用'), findsNothing);
    expect(find.byTooltip('填充封闭区域'), findsNothing);
    expectEntryInGroup('edit', 'brush');
    expectEntryInGroup('common', 'move');
  });

  for (final locale in const [Locale('zh'), Locale('en'), Locale('ja')]) {
    for (final textScale in const [1.0, 3.0]) {
      testWidgets(
        'group titles fit the narrow column: $locale x$textScale',
        (tester) async {
          final (:state, source: _, mask: _) = createInpaintToolbarState();
          await pumpToolbarHost(
            tester,
            size: const Size(400, 900),
            locale: locale,
            textScale: textScale,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                height: 900,
                child: DesktopToolbar(state: state),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          final column = tester.getRect(find.byType(DesktopToolbar));
          for (final group in ['inpaint', 'edit', 'common']) {
            final rect = tester.getRect(toolGroup(group));
            expect(rect.left, greaterThanOrEqualTo(column.left));
            expect(rect.right, lessThanOrEqualTo(column.right));
          }
          // 工具区整列可滚动，末组的末项仍可达
          final lastEntry = toolEntry('common', 'lasso_selection');
          await tester.ensureVisible(lastEntry);
          await tester.pump();
          expect(tester.getRect(lastEntry).bottom, lessThanOrEqualTo(900));
        },
      );
    }
  }
}
