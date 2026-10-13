import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/closed_region_fill_tool.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/frame_tool.dart';
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
      policy: InteractionPolicy.touchFirst,
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
    expectEntryInGroup('inpaint', FrameTool.toolId);
    expectEntryInGroup('edit', 'blur');
    expect(toolEntry('edit', 'clone_stamp'), findsNothing);

    await tester.tap(toolEntry('inpaint', 'eraser'));
    await tester.pump();
    expect(state.layerManager.activeLayer, same(mask));
    expect(state.currentTool?.id, 'eraser');
    expect(isEntrySelected(tester, 'inpaint', 'eraser'), isTrue);

    final retouch = toolSlot('edit', 'retouch');
    await tester.ensureVisible(retouch);
    await tester.pump();
    await tester.longPress(retouch);
    await tester.pump();
    expect(flyoutLabels(tester), ['模糊', '仿制图章']);

    await chooseFlyoutEntry(tester, flyoutEntry('edit', 'clone_stamp'));
    expect(find.byType(MenuItemButton), findsNothing);
    expect(state.layerManager.activeLayer, same(source));
    expect(state.currentTool?.id, 'clone_stamp');
    expect(isEntrySelected(tester, 'edit', 'clone_stamp'), isTrue);
  });

  testWidgets('long-press opens the family above the bottom bar', (
    tester,
  ) async {
    final (:state, source: _, mask: _) = createInpaintToolbarState();
    await pumpToolbarHost(
      tester,
      size: const Size(360, 720),
      policy: InteractionPolicy.touchFirst,
      child: bottomBar(MobileToolbar(state: state)),
    );
    expect(toolSlot('inpaint', 'region'), findsNothing);
    final slot = toolSlot('edit', 'region');
    await tester.ensureVisible(slot);
    await tester.pump();

    await tester.longPress(slot);
    await tester.pump();

    expect(flyoutLabels(tester), ['填充', '魔棒']);
    final slotRect = tester.getRect(slot);
    final items = find.byType(MenuItemButton);
    expect(tester.getRect(items.last).bottom, lessThanOrEqualTo(slotRect.top));
    for (final item in items.evaluate()) {
      final rect = tester.getRect(find.byWidget(item.widget));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(rect.height, greaterThanOrEqualTo(44));
    }
    expect(tester.takeException(), isNull);

    // 折叠按钮没有提示气泡，说明只在二级菜单里
    expect(
      find.descendant(of: slot, matching: find.byType(Tooltip)),
      findsNothing,
    );
  });

  for (final width in const [320.0, 600.0]) {
    for (final textScale in const [1.0, 3.0]) {
      for (final locale in const [Locale('zh'), Locale('en')]) {
        testWidgets('every group stays reachable: $width $locale x$textScale', (
          tester,
        ) async {
          final (:state, source: _, mask: _) = createInpaintToolbarState();
          await pumpToolbarHost(
            tester,
            size: Size(width, 720),
            locale: locale,
            textScale: textScale,
            policy: InteractionPolicy.touchFirst,
            child: bottomBar(MobileToolbar(state: state)),
          );

          expect(tester.takeException(), isNull);
          for (final target in [
            toolEntry('inpaint', 'brush'),
            toolEntry('edit', 'color_picker'),
            toolSlot('common', 'selection'),
          ]) {
            await tester.ensureVisible(target);
            await tester.pump();
            final rect = tester.getRect(target);
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(width));
            expect(rect.height, greaterThanOrEqualTo(44));
          }
        });
      }
    }
  }
}
