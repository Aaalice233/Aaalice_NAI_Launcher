import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/desktop_window_frame.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/closed_region_fill_tool.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/frame_tool.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/toolbar/desktop_toolbar.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/toolbar/editor_toolbar_flyout.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'toolbar_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const closedFill = ClosedRegionFillTool.toolId;
  const expandHint = '悬停、右键或长按可展开同组工具';

  Widget toolbarHost(Widget toolbar) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(height: 2000, child: toolbar),
  );

  Future<void> pumpInpaintToolbar(WidgetTester tester) async {
    final (:state, source: _, mask: _) = createInpaintToolbarState();
    await pumpToolbarHost(
      tester,
      size: const Size(400, 2000),
      child: toolbarHost(DesktopToolbar(state: state)),
    );
  }

  final openMenuItems = find.byType(MenuItemButton);

  testWidgets('the inpaint group stays flat while other groups fold', (
    tester,
  ) async {
    await pumpInpaintToolbar(tester);

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
    for (final toolId in [
      'brush',
      'eraser',
      closedFill,
      'fill',
      'magic_wand',
      FrameTool.toolId,
    ]) {
      expectEntryInGroup('inpaint', toolId);
    }
    expect(toolSlot('inpaint', 'region'), findsNothing);
    for (final toolId in ['brush', 'eraser', 'fill', 'blur', 'color_picker']) {
      expectEntryInGroup('edit', toolId);
    }
    for (final toolId in ['move', 'rect_selection']) {
      expectEntryInGroup('common', toolId);
    }
    expect(toolEntry('common', FrameTool.toolId), findsNothing);

    // 同族其余工具只在二级菜单里
    for (final (group, toolId) in [
      ('edit', 'magic_wand'),
      ('edit', 'clone_stamp'),
      ('common', 'ellipse_selection'),
      ('common', 'lasso_selection'),
    ]) {
      expect(toolEntry(group, toolId), findsNothing, reason: '$group:$toolId');
    }
    // 编辑组两族、选区族加底部视图方向
    expect(foldIndicators, findsNWidgets(4));

    expect(find.byTooltip('填充封闭区域'), findsOneWidget);
    expect(find.byTooltip('按颜色填充蒙版 (G)'), findsOneWidget);
    expect(find.byTooltip('取景框 (C)'), findsOneWidget);
    expect(toolEntry('edit', closedFill), findsNothing);
  });

  testWidgets('folded slots leave their names to the family menu', (
    tester,
  ) async {
    await pumpInpaintToolbar(tester);

    for (final slot in [
      toolSlot('edit', 'region'),
      toolSlot('edit', 'retouch'),
      toolSlot('common', 'selection'),
      find.byKey(const ValueKey('editor-view-slot-orientation')),
    ]) {
      expect(
        find.descendant(of: slot, matching: find.byType(Tooltip)),
        findsNothing,
      );
    }
    // 读屏仍能读到名称与展开方式
    final semantics = entrySemantics(tester, 'edit', 'fill');
    expect(semantics.label, '填充 (G)');
    expect(semantics.hint, expandHint);
  });

  testWidgets('hovering a folded slot opens the family without a tooltip', (
    tester,
  ) async {
    await pumpInpaintToolbar(tester);
    final slot = toolSlot('edit', 'region');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(390, 1990));

    await mouse.moveTo(tester.getCenter(slot));
    for (var waited = Duration.zero;
        waited < EditorToolbarFlyout.hoverOpenDelay * 3;
        waited += const Duration(milliseconds: 50)) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.textContaining('填充 (G)'),
        findsNothing,
        reason: '$waited 时闪出说明',
      );
    }

    expect(flyoutLabels(tester), ['填充', '魔棒']);
  });

  testWidgets('right-click lists the family beside the slot', (tester) async {
    await pumpInpaintToolbar(tester);
    final slot = toolSlot('edit', 'region');

    await openFlyoutWithRightClick(tester, slot);

    expect(flyoutLabels(tester), ['填充', '魔棒']);
    final slotRect = tester.getRect(slot);
    final menuRect = tester.getRect(find.byType(MenuItemButton).first);
    expect(menuRect.left, greaterThanOrEqualTo(slotRect.right));
    expect(menuRect.top, closeTo(slotRect.top, slotRect.height / 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('clicking elsewhere closes a right-click family', (tester) async {
    final (:state, source: _, mask: _) = createInpaintToolbarState();
    await pumpToolbarHost(
      tester,
      size: const Size(400, 2000),
      child: toolbarHost(DesktopToolbar(state: state)),
    );
    final before = state.currentTool?.id;

    await openFlyoutWithRightClick(tester, toolSlot('common', 'selection'));
    expect(openMenuItems, findsNWidgets(3));
    // 右键展开的不随指针离开收起
    await tester.pump(EditorToolbarFlyout.hoverCloseDelay * 2);
    expect(openMenuItems, findsNWidgets(3));

    await tester.tapAt(const Offset(390, 1990));
    await tester.pump();

    expect(openMenuItems, findsNothing);
    expect(state.currentTool?.id, before);
  });

  testWidgets('choosing from the family switches tool, layer and slot icon', (
    tester,
  ) async {
    final (:state, :source, :mask) = createInpaintToolbarState();
    state.layerManager.setActiveLayer(mask.id);
    await pumpToolbarHost(
      tester,
      size: const Size(400, 2000),
      child: toolbarHost(DesktopToolbar(state: state)),
    );

    await openFlyoutWithRightClick(tester, toolSlot('edit', 'region'));
    await chooseFlyoutEntry(tester, flyoutEntry('edit', 'magic_wand'));

    expect(openMenuItems, findsNothing);
    expect(state.layerManager.activeLayer, same(source));
    expect(state.currentTool?.id, 'magic_wand');
    expect(toolEntry('edit', 'fill'), findsNothing);
    expectEntryInGroup('edit', 'magic_wand');
    expect(isEntrySelected(tester, 'edit', 'magic_wand'), isTrue);

    // 换走后按钮仍显示刚用过的魔棒，单击即可再次选中
    await tester.tap(toolEntry('edit', 'brush'));
    await tester.pump();
    expect(isEntrySelected(tester, 'edit', 'magic_wand'), isFalse);
    await tester.tap(toolEntry('edit', 'magic_wand'));
    await tester.pump();
    expect(state.currentTool?.id, 'magic_wand');
    expect(openMenuItems, findsNothing);
  });

  testWidgets('a shortcut to a folded tool shows it on the slot', (
    tester,
  ) async {
    final (:state, :source, mask: _) = createInpaintToolbarState();
    state.layerManager.setActiveLayer(source.id);
    await pumpToolbarHost(
      tester,
      size: const Size(400, 2000),
      child: toolbarHost(DesktopToolbar(state: state)),
    );

    state.setToolById('magic_wand');
    await tester.pump();

    expectEntryInGroup('edit', 'magic_wand');
    expect(isEntrySelected(tester, 'edit', 'magic_wand'), isTrue);
    expect(toolEntry('edit', 'fill'), findsNothing);
  });

  testWidgets('hovering opens after a pause and leaving closes it', (
    tester,
  ) async {
    await pumpInpaintToolbar(tester);
    final slot = toolSlot('common', 'selection');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(390, 1990));

    // 只是划过不展开
    await mouse.moveTo(tester.getCenter(slot));
    await tester.pump(const Duration(milliseconds: 100));
    await mouse.moveTo(const Offset(390, 1990));
    await tester.pump(EditorToolbarFlyout.hoverOpenDelay);
    expect(openMenuItems, findsNothing);

    await mouse.moveTo(tester.getCenter(slot));
    await tester.pump(EditorToolbarFlyout.hoverOpenDelay);
    expect(flyoutLabels(tester), ['矩形选框', '椭圆选框', '套索选区']);

    // 移进菜单后保持展开
    await mouse.moveTo(
      tester.getCenter(flyoutEntry('common', 'lasso_selection')),
    );
    await tester.pump(EditorToolbarFlyout.hoverCloseDelay * 2);
    expect(openMenuItems, findsNWidgets(3));

    await mouse.moveTo(const Offset(390, 1990));
    await tester.pump(EditorToolbarFlyout.hoverCloseDelay);
    await tester.pump();
    expect(openMenuItems, findsNothing);
  });

  testWidgets('clicking the slot while hover-opened picks its own tool', (
    tester,
  ) async {
    final (:state, source: _, mask: _) = createInpaintToolbarState();
    await pumpToolbarHost(
      tester,
      size: const Size(400, 2000),
      child: toolbarHost(DesktopToolbar(state: state)),
    );
    final slot = toolSlot('common', 'selection');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(slot));
    await tester.pump(EditorToolbarFlyout.hoverOpenDelay);
    expect(openMenuItems, findsNWidgets(3));

    await mouse.down(tester.getCenter(slot));
    await mouse.up();
    await tester.pump();

    expect(openMenuItems, findsNothing);
    expect(state.currentTool?.id, 'rect_selection');
  });

  testWidgets('keyboard opens the family and returns focus to the slot', (
    tester,
  ) async {
    final (:state, source: _, mask: _) = createInpaintToolbarState();
    await pumpToolbarHost(
      tester,
      size: const Size(400, 2000),
      child: toolbarHost(DesktopToolbar(state: state)),
    );
    final slot = toolSlot('edit', 'region');
    Focus.of(
      tester.element(find.descendant(of: slot, matching: find.byType(Icon))),
    ).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump();
    expect(openMenuItems, findsNWidgets(2));
    expect(
      find.descendant(
        of: flyoutEntry('edit', 'fill'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Focus && widget.focusNode?.hasPrimaryFocus == true,
        ),
      ),
      findsOneWidget,
      reason: '展开后焦点落在当前显示的那一项',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(openMenuItems, findsNothing);
    expect(state.currentTool?.id, 'magic_wand');
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(focused, isNotNull);
    expect(
      find.descendant(
        of: toolSlot('edit', 'region'),
        matching: find.byWidget(focused!.widget),
      ),
      findsOneWidget,
      reason: '收起后焦点回到折叠按钮',
    );
  });

  testWidgets('escape closes a keyboard-opened family without changing tools', (
    tester,
  ) async {
    final (:state, source: _, mask: _) = createInpaintToolbarState();
    await pumpToolbarHost(
      tester,
      size: const Size(400, 2000),
      child: toolbarHost(DesktopToolbar(state: state)),
    );
    final before = state.currentTool?.id;
    final slot = toolSlot('edit', 'retouch');
    final anchorFocus = Focus.of(
      tester.element(find.descendant(of: slot, matching: find.byType(Icon))),
    )..requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pump();
    await tester.pump();
    expect(flyoutLabels(tester), ['模糊', '仿制图章']);
    expect(anchorFocus.hasPrimaryFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();

    expect(openMenuItems, findsNothing);
    expect(state.currentTool?.id, before);
    expect(anchorFocus.hasPrimaryFocus, isTrue);
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

    // 取景框不切图层
    await tester.tap(toolEntry('inpaint', FrameTool.toolId));
    await tester.pump();
    expect(state.currentTool?.id, FrameTool.toolId);
    expect(state.layerManager.activeLayer, same(mask));
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
    expect(find.byTooltip('取景框 (C)'), findsNothing);
    expectEntryInGroup('edit', 'brush');
    expectEntryInGroup('common', 'move');
    expect(toolSlot('edit', 'region'), findsOneWidget);
    expect(toolSlot('common', 'selection'), findsOneWidget);
  });

  for (final locale in const [Locale('zh'), Locale('en'), Locale('ja')]) {
    for (final textScale in const [1.0, 3.0]) {
      testWidgets('group titles fit the narrow column: $locale x$textScale', (
        tester,
      ) async {
        final (:state, source: _, mask: _) = createInpaintToolbarState();
        await pumpToolbarHost(
          tester,
          size: const Size(400, 900),
          locale: locale,
          textScale: textScale,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(height: 900, child: DesktopToolbar(state: state)),
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
        final lastSlot = toolSlot('common', 'selection');
        await tester.ensureVisible(lastSlot);
        await tester.pump();
        expect(tester.getRect(lastSlot).bottom, lessThanOrEqualTo(900));
      });
    }
  }

  testWidgets('view controls scroll with the tools when the column is short', (
    tester,
  ) async {
    final (:state, source: _, mask: _) = createInpaintToolbarState();
    const columnHeight = 300.0;
    await pumpToolbarHost(
      tester,
      size: const Size(400, columnHeight),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: columnHeight,
          child: DesktopToolbar(state: state),
        ),
      ),
    );
    final orientation = find.byKey(
      const ValueKey('editor-view-slot-orientation'),
    );

    expect(
      find.ancestor(
        of: orientation,
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(orientation);
    await tester.pump();
    expect(orientation.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a maximized 1080p window shows every inpaint button at once', (
    tester,
  ) async {
    // 1080 减去 Windows 任务栏 48、窗口标题栏与编辑器顶栏各 40
    const editorTopBarHeight = 40.0;
    const columnHeight =
        1080 - 48 - desktopWindowHeaderHeight - editorTopBarHeight;
    final (:state, source: _, mask: _) = createInpaintToolbarState();
    await pumpToolbarHost(
      tester,
      size: const Size(400, columnHeight),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: columnHeight,
          child: DesktopToolbar(state: state),
        ),
      ),
    );

    final toolScroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(DesktopToolbar),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(toolScroll.position.maxScrollExtent, 0);
    expect(
      find.byKey(const ValueKey('editor-view-slot-orientation')).hitTestable(),
      findsOneWidget,
    );
  });
}
