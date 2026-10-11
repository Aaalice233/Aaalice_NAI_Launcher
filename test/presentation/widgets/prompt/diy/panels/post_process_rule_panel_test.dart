import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/post_process_rule.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/surface_ink_well.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/panels/post_process_rule_panel.dart';

import '../../../../../helpers/ink_expectations.dart';

void main() {
  testWidgets('3x text stacks presets at 320px and keeps the wide row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(960, 3600);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    List<PostProcessRule>? changedRules;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PostProcessRulePanel(
              rules: const [],
              onRulesChanged: (rules) => changedRules = rules,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final sleeping = find.text('Sleeping Rule');
    final mermaid = find.text('Mermaid Rule');
    expect(sleeping, findsOneWidget);
    expect(mermaid, findsOneWidget);
    expect(
      tester.getCenter(sleeping).dy,
      lessThan(tester.getCenter(mermaid).dy),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(sleeping);
    await tester.pump();
    expect(changedRules, hasLength(1));
    expect(changedRules!.single.id, 'sleeping_rule');
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1800, 3600);
    await tester.pump();

    expect(
      tester.getCenter(sleeping).dy,
      closeTo(tester.getCenter(mermaid).dy, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('预设规则按钮的悬停与按压反馈画在底色之上，前景描边不改变尺寸', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PostProcessRulePanel(
              rules: const [],
              onRulesChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final preset = find.ancestor(
      of: find.text('Sleeping Rule'),
      matching: find.byType(SurfaceInkWell),
    );
    final row = find.descendant(of: preset, matching: find.byType(Row)).first;
    // 12 内边距加 1 描边，上下各 13
    expect(
      tester.getSize(preset).height,
      moreOrLessEquals(tester.getSize(row).height + 26),
    );

    final theme = Theme.of(tester.element(preset));
    final fill = theme.colorScheme.surfaceContainerHighest;
    await hoverOver(tester, preset);
    expectInkOnTop(tester, preset, ink: theme.hoverColor, below: fill);

    final press = await pressAndHold(tester, preset);
    expectInkOnTop(tester, preset, ink: theme.highlightColor, below: fill);
    await press.up();
    await tester.pump();
  });
}
