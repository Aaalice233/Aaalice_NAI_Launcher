import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/surface_ink_well.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/panels/conditional_branch_panel.dart';

import '../../../../../helpers/ink_expectations.dart';

void main() {
  testWidgets('概率条分段的悬停与按压反馈画在分段渐变之上，选中后依旧可见', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConditionalBranchPanel(
              config: const ConditionalBranchConfig(
                id: 'outfit',
                name: 'Outfit',
                branches: [
                  ConditionalBranch(name: 'Uniform', probability: 60),
                  ConditionalBranch(name: 'Casual', probability: 40),
                ],
              ),
              onConfigChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final segment = find.byType(SurfaceInkWell).first;
    final theme = Theme.of(tester.element(segment));
    Color leadingStop() =>
        tester.widget<SurfaceInkWell>(segment).gradient!.colors.first;
    expect(leadingStop(), theme.colorScheme.primary.withValues(alpha: 0.6));

    await hoverOver(tester, segment);
    expectInkOnTop(tester, segment, ink: theme.hoverColor, belowGradient: true);

    final press = await pressAndHold(tester, segment);
    expectInkOnTop(
      tester,
      segment,
      ink: theme.highlightColor,
      belowGradient: true,
    );
    await press.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(leadingStop(), theme.colorScheme.primary);

    final again = await pressAndHold(tester, segment);
    expectInkOnTop(
      tester,
      segment,
      ink: theme.highlightColor,
      belowGradient: true,
    );
    await again.up();
    await tester.pump(const Duration(milliseconds: 300));
  });
}
