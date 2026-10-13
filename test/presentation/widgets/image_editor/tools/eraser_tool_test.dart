import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/layer_role_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_role.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/eraser_tool.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/tool_setting_rows.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/text_layout_expectations.dart';
import '../image_editor_workspace_harness.dart';

void main() {
  for (final viewSize in editorPanelViewSizes) {
    for (final scale in const [1.0, 3.0]) {
      testWidgets('$viewSize ${scale}x 文字下橡皮擦设置行完整可达', (tester) async {
        await pumpEditorWorkspace(
          tester,
          viewSize: viewSize,
          textScale: scale,
          toolId: 'eraser',
        );
        final scenario = '$viewSize x$scale';
        expect(tester.takeException(), isNull, reason: scenario);

        final rows = find.byType(ToolSettingRows);
        for (final text in const ['Size', 'Hardness', '100%']) {
          expectSingleLineUntruncated(
            tester,
            find.descendant(of: rows, matching: find.text(text)),
            reason: '$text $scenario',
          );
        }
        final sliders = find.descendant(
          of: rows,
          matching: find.byType(Slider),
        );
        for (final control in [
          find.descendant(of: rows, matching: find.byType(EditableText)),
          sliders.first,
          sliders.last,
        ]) {
          await tester.ensureVisible(control);
          await tester.pumpAndSettle();
          expect(control.hitTestable(), findsOneWidget, reason: scenario);
        }
      });
    }
  }

  testWidgets('蒙版层上的橡皮擦不显示硬度，切回图片层恢复', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = EditorState();
    addTearDown(state.dispose);
    final image = state.layerManager.addLayer(name: 'image');
    final mask = state.layerManager.addLayer(
      name: 'mask',
      index: 0,
      role: LayerRole.mask,
    );
    state.setRolePolicy(LayerRolePolicy.inpaint(protectedLayerId: image.id));
    final eraser = state.tools.whereType<EraserTool>().single;
    state.setTool(eraser);
    state.layerManager.setActiveLayer(mask.id);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => eraser.buildSettingsPanel(context, state),
          ),
        ),
      ),
    );
    final hardness = find.descendant(
      of: find.byType(ToolSettingRows),
      matching: find.text('Hardness'),
    );

    expect(hardness, findsNothing);

    state.layerManager.setActiveLayer(image.id);
    await tester.pump();

    expect(hardness, findsOneWidget);
  });

  testWidgets('橡皮擦大小输入越界时回显钳制后的值', (tester) async {
    await pumpEditorWorkspace(
      tester,
      viewSize: const Size(1180, 760),
      toolId: 'eraser',
    );
    final rows = find.byType(ToolSettingRows);
    final field = find.descendant(
      of: rows,
      matching: find.byType(EditableText),
    );

    await tester.enterText(field, '900');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(tester.widget<EditableText>(field).controller.text, '500');
    expect(
      tester
          .widget<Slider>(
            find.descendant(of: rows, matching: find.byType(Slider)).first,
          )
          .value,
      500,
    );
  });
}
