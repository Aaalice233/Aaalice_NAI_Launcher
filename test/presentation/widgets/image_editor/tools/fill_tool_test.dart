import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/tool_setting_rows.dart';

import '../image_editor_workspace_harness.dart';
import 'tool_panel_matrix.dart';

void main() {
  testToolPanelMatrix(
    '填充容差行完整可达',
    toolId: 'fill',
    verify: (tester, scenario) async {
      final rows = find.byType(ToolSettingRows);
      expectPanelTextsSingleLine(
        tester,
        scenario,
        within: rows,
        labels: [scenario.l10n.editor_tolerance],
        values: const ['32'],
      );
      await expectReachable(
        tester,
        find.descendant(of: rows, matching: find.byType(Slider)),
        reason: '$scenario',
      );
    },
  );

  testWidgets('容差按整数一格步进', (tester) async {
    await pumpEditorWorkspace(
      tester,
      viewSize: const Size(1180, 760),
      toolId: 'fill',
    );

    tester.semantics.increase(toolSliderSemantics('Tolerance'));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(ToolSettingRows),
        matching: find.text('33'),
      ),
      findsOneWidget,
    );
  });
}
