import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/horizontal_action_strip.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/brush_tool.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/tool_setting_rows.dart';

import '../../../../helpers/text_layout_expectations.dart';
import '../image_editor_workspace_harness.dart';

void main() {
  testWidgets('拖动画笔大小滑块时滑块值应实时更新', (tester) async {
    final tool = BrushTool();
    final state = EditorState();

    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => Material(
              child: tool.buildSettingsPanel(context, state),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final sliderFinder = find.byType(Slider).first;
    final before = tester.widget<Slider>(sliderFinder);
    expect(before.value, equals(20));

    await tester.drag(sliderFinder, const Offset(160, 0));
    await tester.pump();

    final after = tester.widget<Slider>(sliderFinder);
    expect(after.value, greaterThan(20));
  });

  for (final viewSize in editorPanelViewSizes) {
    for (final scale in const [1.0, 3.0]) {
      testWidgets('$viewSize ${scale}x 文字下笔刷预设完整可点且不溢出', (tester) async {
        await pumpEditorWorkspace(tester, viewSize: viewSize, textScale: scale);
        final scenario = '$viewSize x$scale';
        expect(tester.takeException(), isNull, reason: scenario);

        final tileHeights = <double>{};
        for (final (index, preset) in defaultBrushPresets.indexed) {
          final reason = '${preset.name} $scenario';
          final tile = find.byKey(ValueKey('brush-preset-$index'));
          await tester.ensureVisible(tile);
          await tester.pumpAndSettle();
          expect(tile.hitTestable(), findsOneWidget, reason: reason);

          final tileRect = tester.getRect(tile);
          tileHeights.add(tileRect.height);
          expect(tileRect.width, greaterThanOrEqualTo(56), reason: reason);
          expect(
            tileRect.height,
            scale == 1 ? 70 : greaterThan(70),
            reason: '1x 保持原高度，放大后随文字长高 $reason',
          );
          final stripRect = tester.getRect(
            find.ancestor(
              of: tile,
              matching: find.byType(HorizontalActionStrip),
            ),
          );
          expect(tileRect.top, greaterThanOrEqualTo(stripRect.top));
          expect(tileRect.bottom, lessThanOrEqualTo(stripRect.bottom));

          expect(
            find.descendant(of: tile, matching: find.text(preset.name)),
            findsWidgets,
            reason: reason,
          );
          final labels = find.descendant(of: tile, matching: find.byType(Text));
          for (var i = 0; i < labels.evaluate().length; i++) {
            expectSingleLineUntruncated(tester, labels.at(i), reason: reason);
            expect(
              tileRect.expandToInclude(tester.getRect(labels.at(i))),
              tileRect,
              reason: reason,
            );
          }

          await tester.tap(tile);
          await tester.pumpAndSettle();
          expect(
            _sizeFieldText(tester),
            '${preset.size.round()}',
            reason: reason,
          );
        }
        expect(tileHeights, hasLength(1), reason: '预设同行等高 $scenario');

        for (final label in const ['Size', 'Opacity', 'Hardness']) {
          expectSingleLineUntruncated(
            tester,
            find.descendant(
              of: find.byType(ToolSettingRows),
              matching: find.text(label),
            ),
            reason: '$label $scenario',
          );
        }
        expect(tester.takeException(), isNull, reason: scenario);
      });
    }
  }
}

String _sizeFieldText(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byType(ToolSettingRows),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;
