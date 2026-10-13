import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsData;
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/layer_role_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/frame/editor_frame_commands.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_role.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/toolbar/editor_toolbar_flyout.dart';

/// 工具栏只看会话是否提供了取景框命令
class FrameCommandsStub extends Fake implements EditorFrameCommands {}

/// 与重绘会话一致：蒙版压在图片层之上，原图层受保护，可以填充封闭区域，有取景框
({EditorState state, Layer source, Layer mask}) createInpaintToolbarState() {
  final state = EditorState();
  addTearDown(state.dispose);
  final source = state.layerManager.addLayer(name: 'Source');
  final mask = state.layerManager.addLayer(
    name: 'Mask',
    index: 0,
    role: LayerRole.mask,
  );
  state.setRolePolicy(LayerRolePolicy.inpaint(protectedLayerId: source.id));
  state.setClosedRegionFillHandler((_) async {});
  state.setFrameCommands(FrameCommandsStub());
  return (state: state, source: source, mask: mask);
}

EditorState createEditToolbarState() {
  final state = EditorState();
  addTearDown(state.dispose);
  state.layerManager.addLayer(name: 'Layer 1');
  return state;
}

Future<void> pumpToolbarHost(
  WidgetTester tester, {
  required Widget child,
  required Size size,
  Locale locale = const Locale('zh'),
  double textScale = 1,
  InteractionPolicy? policy,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: InteractionPolicyScope(
        initialPolicy: policy,
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

Finder toolGroup(String group) => find.byKey(ValueKey('editor-tool-group-$group'));

Finder toolEntry(String group, String toolId) =>
    find.byKey(ValueKey('editor-tool-$group:$toolId'));

/// 折叠按钮；身份不随它当前显示的工具变化
Finder toolSlot(String group, String family) =>
    find.byKey(ValueKey('editor-tool-slot-$group:family:$family'));

Finder flyoutEntry(String group, String toolId) =>
    find.byKey(ValueKey('editor-tool-flyout-$group:$toolId'));

Finder get foldIndicators => find.byType(EditorToolbarFoldIndicator);

Future<void> openFlyoutWithRightClick(WidgetTester tester, Finder slot) async {
  await tester.tap(
    slot,
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
}

/// 菜单项的 onPressed 在下一帧才执行
Future<void> chooseFlyoutEntry(WidgetTester tester, Finder entry) async {
  await tester.tap(entry);
  await tester.pump();
  await tester.pump();
}

/// 二级菜单列出的工具
List<String> flyoutLabels(WidgetTester tester) => [
  for (final button in tester.widgetList<MenuItemButton>(
    find.byType(MenuItemButton),
  ))
    (button.child! as Text).data!,
];

/// 入口必须落在所属组的色面之内，不能串到相邻组
void expectEntryInGroup(String group, String toolId) {
  expect(
    find.descendant(of: toolGroup(group), matching: toolEntry(group, toolId)),
    findsOneWidget,
  );
}

/// 入口按钮读屏实际读到的语义；直接对入口取会拿到外层分组容器，
/// 折叠按钮的选中态与提示合并在外层节点上，要取合并后的数据
SemanticsData entrySemantics(WidgetTester tester, String group, String toolId) {
  return tester
      .getSemantics(
        find.descendant(
          of: toolEntry(group, toolId),
          matching: find.byType(InkWell),
        ),
      )
      .getSemanticsData();
}

bool isEntrySelected(WidgetTester tester, String group, String toolId) {
  return entrySemantics(tester, group, toolId).flagsCollection.isSelected ==
      Tristate.isTrue;
}
