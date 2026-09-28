import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/vibe_transfer_content.dart';
import 'package:nai_launcher/presentation/widgets/common/surface_ink_well.dart';

import '../../../../helpers/ink_expectations.dart';

void main() {
  testWidgets('空状态卡片悬停只换底色，按压反馈画在卡片底色之上', (tester) async {
    var adds = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              width: 720,
              child: VibeTransferContent(
                vibes: const [],
                normalizeVibeStrength: true,
                showBackground: false,
                onAddVibe: () => adds++,
                onAddLibraryVibe: (_) {},
                onRemoveVibe: (_) {},
                onUpdateStrength: (_, _) {},
                onUpdateInfoExtracted: (_, _) {},
                onUpdateEnabled: (_, _) {},
                onClearAll: () {},
                onImportDroppedResources: (_) async => 0,
                recentEntries: const [],
                isRecentCollapsed: false,
                onToggleRecentCollapsed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.text('Add from File'),
      matching: find.byType(SurfaceInkWell),
    );
    final theme = Theme.of(tester.element(card));
    final hovered = theme.colorScheme.surfaceContainerHigh;

    await hoverOver(tester, card);
    expect(tester.widget<SurfaceInkWell>(card).color, hovered);
    expect(tester.renderObject(card), isNot(inkOnTop(ink: theme.hoverColor)));

    final press = await pressAndHold(tester, card);
    expectInkOnTop(tester, card, ink: theme.highlightColor, below: hovered);
    await press.up();
    await tester.pump();
    expect(adds, 1);
  });
}
