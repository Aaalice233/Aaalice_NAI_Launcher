import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/layer_role_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_role.dart';

/// 与重绘会话一致：蒙版压在图片层之上，原图层受保护，可以填充封闭区域
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
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

Finder toolGroup(String group) => find.byKey(ValueKey('editor-tool-group-$group'));

Finder toolEntry(String group, String toolId) =>
    find.byKey(ValueKey('editor-tool-$group:$toolId'));

/// 入口必须落在所属组的色面之内，不能串到相邻组
void expectEntryInGroup(String group, String toolId) {
  expect(
    find.descendant(of: toolGroup(group), matching: toolEntry(group, toolId)),
    findsOneWidget,
  );
}

/// 入口按钮自身的语义节点；直接对入口取会拿到外层分组容器
SemanticsNode entrySemantics(WidgetTester tester, String group, String toolId) {
  return tester.getSemantics(
    find.descendant(
      of: toolEntry(group, toolId),
      matching: find.byType(InkWell),
    ),
  );
}

bool isEntrySelected(WidgetTester tester, String group, String toolId) {
  return entrySemantics(tester, group, toolId).flagsCollection.isSelected ==
      Tristate.isTrue;
}
