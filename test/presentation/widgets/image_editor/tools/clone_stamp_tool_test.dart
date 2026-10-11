import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/tool_setting_rows.dart';

import '../image_editor_workspace_harness.dart';
import 'tool_panel_matrix.dart';

void main() {
  testToolPanelMatrix(
    '仿制图章设置行完整可达',
    toolId: 'clone_stamp',
    verify: (tester, scenario) async {
      final l10n = scenario.l10n;
      final rows = find.byType(ToolSettingRows);
      expectPanelTextsSingleLine(
        tester,
        scenario,
        within: rows,
        labels: [l10n.editor_size, l10n.editor_opacity],
        values: const ['20', '100%'],
      );
      final sliders = find.descendant(of: rows, matching: find.byType(Slider));
      expect(sliders, findsNWidgets(2), reason: '$scenario');
      for (var i = 0; i < 2; i++) {
        await expectReachable(tester, sliders.at(i), reason: '$scenario');
      }
    },
  );

  testWidgets('不透明度以百分比显示，调整后写回工具', (tester) async {
    await pumpEditorWorkspace(
      tester,
      viewSize: const Size(1180, 760),
      toolId: 'clone_stamp',
    );

    tester.semantics.decrease(toolSliderSemantics('Opacity'));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(ToolSettingRows),
        matching: find.text('95%'),
      ),
      findsOneWidget,
    );
  });
}
