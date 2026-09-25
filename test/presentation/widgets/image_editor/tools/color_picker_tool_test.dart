import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/color_picker_tool.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/tool_setting_rows.dart';

import '../../../../helpers/text_layout_expectations.dart';
import '../image_editor_workspace_harness.dart';

void main() {
  for (final viewSize in editorPanelViewSizes) {
    for (final scale in const [1.0, 3.0]) {
      testWidgets('$viewSize ${scale}x 文字下取色设置的标签与分段选项完整可选', (tester) async {
        await pumpEditorWorkspace(
          tester,
          viewSize: viewSize,
          textScale: scale,
          toolId: 'color_picker',
        );
        await _expectColorPickerSettingsUsable(
          tester,
          locale: 'en',
          scenario: '$viewSize x$scale',
        );
      });
    }
  }

  testWidgets('中文 1x 侧栏中分段选项不被挤断', (tester) async {
    await pumpEditorWorkspace(
      tester,
      viewSize: const Size(1180, 760),
      locale: 'zh',
      toolId: 'color_picker',
    );
    await _expectColorPickerSettingsUsable(
      tester,
      locale: 'zh',
      scenario: 'zh 1180 x1',
    );
  });
}

Future<void> _expectColorPickerSettingsUsable(
  WidgetTester tester, {
  required String locale,
  required String scenario,
}) async {
  final l10n = lookupAppLocalizations(Locale(locale));
  final rows = find.byType(ToolSettingRows);
  expect(tester.takeException(), isNull, reason: scenario);
  for (final label in [l10n.editor_sample, l10n.editor_source]) {
    expectSingleLineUntruncated(
      tester,
      find.descendant(of: rows, matching: find.text(label)),
      reason: '$label $scenario',
    );
  }

  Future<void> tapSegment(String label) async {
    final segment = find.descendant(of: rows, matching: find.text(label));
    await tester.ensureVisible(segment);
    await tester.pumpAndSettle();
    expectSingleLineUntruncated(tester, segment, reason: '$label $scenario');
    expect(segment.hitTestable(), findsOneWidget, reason: '$label $scenario');
    await tester.tap(segment);
    await tester.pumpAndSettle();
  }

  for (final (label, mode) in [
    (l10n.editor_sampleArea, ColorPickerSampleMode.area),
    (l10n.editor_samplePoint, ColorPickerSampleMode.point),
  ]) {
    await tapSegment(label);
    expect(
      tester
          .widget<SegmentedButton<ColorPickerSampleMode>>(
            find.byType(SegmentedButton<ColorPickerSampleMode>),
          )
          .selected,
      {mode},
      reason: '$label $scenario',
    );
  }
  for (final (label, source) in [
    (l10n.editor_sourceAllLayers, ColorPickerSource.allLayers),
    (l10n.editor_sourceCurrentLayer, ColorPickerSource.currentLayer),
  ]) {
    await tapSegment(label);
    expect(
      tester
          .widget<SegmentedButton<ColorPickerSource>>(
            find.byType(SegmentedButton<ColorPickerSource>),
          )
          .selected,
      {source},
      reason: '$label $scenario',
    );
  }
  expect(tester.takeException(), isNull, reason: scenario);
}
