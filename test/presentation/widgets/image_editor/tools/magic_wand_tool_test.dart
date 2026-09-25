import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/tool_setting_rows.dart';

import '../../../../helpers/text_layout_expectations.dart';
import '../image_editor_workspace_harness.dart';
import 'tool_panel_matrix.dart';

// 长分段标签可能比视口还宽，命中与点击都落在滚入视口的前缘
const _segmentLead = Alignment(-0.9, 0);

final _modeSegments = find.byType(SegmentedButton<MagicWandSelectionMode>);

void main() {
  testToolPanelMatrix(
    '魔棒模式、容差与反选完整可达',
    toolId: 'magic_wand',
    verify: (tester, scenario) async {
      final l10n = scenario.l10n;
      final panel = toolPanel(l10n.editor_toolMagicWand);
      expectPanelTextsSingleLine(
        tester,
        scenario,
        within: panel,
        labels: [l10n.editor_magicWandMode, l10n.editor_magicWandInvert],
      );
      // 分段选项横向滚动，任何语言都必须保留完整标签
      for (final label in [
        l10n.editor_magicWandSmartObject,
        l10n.editor_magicWandColorArea,
      ]) {
        expectSingleLineUntruncated(
          tester,
          find.descendant(of: _modeSegments, matching: find.text(label)),
          reason: '$label $scenario',
        );
      }
      // 常规字号下两种模式并排可见，不必横向滚动才发现第二项
      if (scenario.labelWidthsRealistic && scenario.textScale == 1) {
        final panelRight = tester.getRect(panel).right;
        for (final label in [
          l10n.editor_magicWandSmartObject,
          l10n.editor_magicWandColorArea,
        ]) {
          final segment = find.descendant(
            of: _modeSegments,
            matching: find.text(label),
          );
          expect(
            tester.getRect(segment).right,
            lessThanOrEqualTo(panelRight),
            reason: '$label $scenario',
          );
        }
      }
      await expectReachable(
        tester,
        find.descendant(of: panel, matching: find.byType(Switch)),
        reason: '$scenario',
      );

      await _selectMode(
        tester,
        scenario,
        l10n.editor_magicWandColorArea,
        MagicWandSelectionMode.colorArea,
      );
      final rows = find.byType(ToolSettingRows);
      expectPanelTextsSingleLine(
        tester,
        scenario,
        within: rows,
        labels: [l10n.editor_tolerance],
        values: const ['32'],
      );
      await expectReachable(
        tester,
        find.descendant(of: rows, matching: find.byType(Slider)),
        reason: '$scenario',
      );

      await _selectMode(
        tester,
        scenario,
        l10n.editor_magicWandSmartObject,
        MagicWandSelectionMode.smartObject,
      );
      expect(rows, findsNothing, reason: '智能对象模式不显示容差 $scenario');
    },
  );

  testWidgets('颜色区域容差按整数一格步进', (tester) async {
    const scenario = ToolPanelScenario(
      locale: 'en',
      viewSize: Size(1180, 760),
      textScale: 1,
    );
    await pumpEditorWorkspace(
      tester,
      viewSize: scenario.viewSize,
      toolId: 'magic_wand',
    );
    await _selectMode(
      tester,
      scenario,
      scenario.l10n.editor_magicWandColorArea,
      MagicWandSelectionMode.colorArea,
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

Future<void> _selectMode(
  WidgetTester tester,
  ToolPanelScenario scenario,
  String label,
  MagicWandSelectionMode mode,
) async {
  final segment = find.descendant(
    of: _modeSegments,
    matching: find.text(label),
  );
  await expectReachable(
    tester,
    segment,
    reason: '$label $scenario',
    at: _segmentLead,
  );
  await tester.tapAt(_segmentLead.withinRect(tester.getRect(segment)));
  await tester.pumpAndSettle();
  expect(
    tester
        .widget<SegmentedButton<MagicWandSelectionMode>>(_modeSegments)
        .selected,
    {mode},
    reason: '$label $scenario',
  );
}
