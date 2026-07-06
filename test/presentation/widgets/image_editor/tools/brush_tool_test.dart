import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/brush_tool.dart';

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
}
