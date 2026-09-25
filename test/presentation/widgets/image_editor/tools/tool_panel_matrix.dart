import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../../helpers/text_layout_expectations.dart';
import '../image_editor_workspace_harness.dart';

/// en 按两倍字宽施加溢出压力，ja 字宽接近真实且译文最长
const toolPanelLocales = ['en', 'ja'];

// 手机横屏下工作区把设置区压到 96px 高，控件只能靠滚动到达
const _shortLandscape = Size(780, 360);

/// 工具设置面板验收的一个场景
class ToolPanelScenario {
  const ToolPanelScenario({
    required this.locale,
    required this.viewSize,
    required this.textScale,
  });

  final String locale;
  final Size viewSize;
  final double textScale;

  AppLocalizations get l10n => lookupAppLocalizations(Locale(locale));

  // 测试字体每个字形 1em 宽，拉丁文约为真实宽度两倍，只有 CJK 的标签宽度可信
  bool get labelWidthsRealistic => locale != 'en';

  @override
  String toString() =>
      '$locale ${viewSize.width.toInt()}x${viewSize.height.toInt()} '
      '${textScale}x';
}

/// 在全部语言、窗口尺寸与 1x/3x 文字下逐场景验收 [toolId] 的设置面板
void testToolPanelMatrix(
  String description, {
  required String toolId,
  required Future<void> Function(
    WidgetTester tester,
    ToolPanelScenario scenario,
  )
  verify,
}) {
  for (final locale in toolPanelLocales) {
    for (final viewSize in [...editorPanelViewSizes, _shortLandscape]) {
      for (final textScale in const [1.0, 3.0]) {
        final scenario = ToolPanelScenario(
          locale: locale,
          viewSize: viewSize,
          textScale: textScale,
        );
        testWidgets('$scenario $description', (tester) async {
          await pumpEditorWorkspace(
            tester,
            viewSize: viewSize,
            textScale: textScale,
            locale: locale,
            toolId: toolId,
          );
          expect(tester.takeException(), isNull, reason: '$scenario');
          await verify(tester, scenario);
          expect(tester.takeException(), isNull, reason: '$scenario');
        });
      }
    }
  }
}

/// 设置面板根：面板标题所在的列
Finder toolPanel(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(Column)).first;

/// 标签只在字宽可信的语言下断言单行完整，数值在所有语言下都断言
void expectPanelTextsSingleLine(
  WidgetTester tester,
  ToolPanelScenario scenario, {
  required Finder within,
  Iterable<String> labels = const [],
  Iterable<String> values = const [],
}) {
  for (final text in [
    if (scenario.labelWidthsRealistic) ...labels,
    ...values,
  ]) {
    expectSingleLineUntruncated(
      tester,
      find.descendant(of: within, matching: find.text(text)),
      reason: '$text $scenario',
    );
  }
}

/// 以所在行标签朗读的滑块语义节点
FinderBase<SemanticsNode> toolSliderSemantics(String label) =>
    find.semantics.byPredicate(
      (node) => node.flagsCollection.isSlider && node.label == label,
    );

/// 滚动到可见后，控件在 [at] 处能被命中
Future<void> expectReachable(
  WidgetTester tester,
  Finder control, {
  required String reason,
  Alignment at = Alignment.center,
}) async {
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  expect(control.hitTestable(at: at), findsOneWidget, reason: reason);
}
