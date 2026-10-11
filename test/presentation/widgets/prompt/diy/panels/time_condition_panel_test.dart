import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/time_condition.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/surface_ink_well.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/panels/time_condition_panel.dart';

import '../../../../../helpers/ink_expectations.dart';

void main() {
  testWidgets('节日模板按钮的悬停与按压反馈画在按钮底色之上，点击套用模板', (tester) async {
    TimeCondition? changed;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TimeConditionPanel(
              condition: TimeCondition.christmas(),
              onConditionChanged: (condition) => changed = condition,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final preset = find.ancestor(
      of: find.text('Halloween'),
      matching: find.byType(SurfaceInkWell),
    );
    final theme = Theme.of(tester.element(preset));
    final fill = theme.colorScheme.surfaceContainerHighest;

    await hoverOver(tester, preset);
    expectInkOnTop(tester, preset, ink: theme.hoverColor, below: fill);

    final press = await pressAndHold(tester, preset);
    expectInkOnTop(tester, preset, ink: theme.highlightColor, below: fill);
    await press.up();
    await tester.pump();
    expect(changed?.startMonth, 10);
    expect(changed?.endMonth, 10);
  });

  testWidgets('只读时模板按钮不响应悬停与点击', (tester) async {
    TimeCondition? changed;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TimeConditionPanel(
              condition: TimeCondition.christmas(),
              readOnly: true,
              onConditionChanged: (condition) => changed = condition,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final preset = find.ancestor(
      of: find.text('Halloween'),
      matching: find.byType(SurfaceInkWell),
    );
    final theme = Theme.of(tester.element(preset));
    await hoverOver(tester, preset);
    expect(tester.renderObject(preset), isNot(inkOnTop(ink: theme.hoverColor)));
    await tester.tap(preset);
    await tester.pump();
    expect(changed, isNull);
  });
}
