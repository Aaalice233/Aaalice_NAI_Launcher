import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/surface_ink_well.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/panels/emphasis_config_panel.dart';

import '../../../../../helpers/ink_expectations.dart';

void main() {
  testWidgets('未选中的层数按钮悬停与按压反馈画在按钮底色之上，点击切换层数', (tester) async {
    int? changed;
    await _pumpPanel(tester, onBracketCountChanged: (count) => changed = count);
    final tile = _countTile('3');
    await tester.ensureVisible(tile);
    await tester.pump();
    final theme = Theme.of(tester.element(tile));
    final fill = theme.colorScheme.surfaceContainerHighest;

    await hoverOver(tester, tile);
    expectInkOnTop(tester, tile, ink: theme.hoverColor, below: fill);

    final press = await pressAndHold(tester, tile);
    expectInkOnTop(tester, tile, ink: theme.highlightColor, below: fill);
    await press.up();
    await tester.pump();
    expect(changed, 3);
  });

  testWidgets('已选层数按钮的按压反馈画在渐变底色之上', (tester) async {
    await _pumpPanel(tester, onBracketCountChanged: (_) {});
    final tile = _countTile('2');
    await tester.ensureVisible(tile);
    await tester.pump();
    final theme = Theme.of(tester.element(tile));

    final press = await pressAndHold(tester, tile);
    expectInkOnTop(
      tester,
      tile,
      ink: theme.highlightColor,
      belowGradient: true,
    );
    await press.up();
    await tester.pump();
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required ValueChanged<int> onBracketCountChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: EmphasisConfigPanel(
            emphasisProbability: 0.5,
            bracketCount: 2,
            onProbabilityChanged: (_) {},
            onBracketCountChanged: onBracketCountChanged,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _countTile(String count) =>
    find.ancestor(of: find.text(count), matching: find.byType(SurfaceInkWell));
