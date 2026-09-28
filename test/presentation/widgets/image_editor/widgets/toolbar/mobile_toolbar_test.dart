import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/closed_region_fill_tool.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/toolbar/mobile_toolbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'toolbar_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const closedFill = ClosedRegionFillTool.toolId;

  Widget bottomBar(Widget toolbar) =>
      Align(alignment: Alignment.bottomCenter, child: toolbar);

  testWidgets('touch entries switch layers from the scrolling strip', (
    tester,
  ) async {
    final (:state, :source, :mask) = createInpaintToolbarState();
    state.layerManager.setActiveLayer(source.id);
    await pumpToolbarHost(
      tester,
      size: const Size(360, 720),
      child: bottomBar(MobileToolbar(state: state)),
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
    expectEntryInGroup('inpaint', closedFill);
    expectEntryInGroup('edit', 'clone_stamp');
    expect(find.byTooltip('填充封闭区域'), findsOneWidget);

    await tester.tap(toolEntry('inpaint', 'eraser'));
    await tester.pump();
    expect(state.layerManager.activeLayer, same(mask));
    expect(state.currentTool?.id, 'eraser');
    expect(isEntrySelected(tester, 'inpaint', 'eraser'), isTrue);

    final cloneStamp = toolEntry('edit', 'clone_stamp');
    await tester.ensureVisible(cloneStamp);
    await tester.pump();
    await tester.tap(cloneStamp);
    await tester.pump();
    expect(state.layerManager.activeLayer, same(source));
    expect(state.currentTool?.id, 'clone_stamp');
  });

  for (final width in const [320.0, 600.0]) {
    for (final textScale in const [1.0, 3.0]) {
      for (final locale in const [Locale('zh'), Locale('en')]) {
        testWidgets(
          'every group stays reachable: $width $locale x$textScale',
          (tester) async {
            final (:state, source: _, mask: _) = createInpaintToolbarState();
            await pumpToolbarHost(
              tester,
              size: Size(width, 720),
              locale: locale,
              textScale: textScale,
              child: bottomBar(MobileToolbar(state: state)),
            );

            expect(tester.takeException(), isNull);
            for (final (group, toolId) in [
              ('inpaint', 'brush'),
              ('edit', 'color_picker'),
              ('common', 'lasso_selection'),
            ]) {
              final entry = toolEntry(group, toolId);
              await tester.ensureVisible(entry);
              await tester.pump();
              final rect = tester.getRect(entry);
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(width));
              expect(rect.height, greaterThanOrEqualTo(44));
            }
          },
        );
      }
    }
  }
}
