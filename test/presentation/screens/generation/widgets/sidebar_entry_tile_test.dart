import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/sidebar_entry_tile.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final isListMode in [true, false]) {
      testWidgets('$brightness list=$isListMode selection remains readable', (
        tester,
      ) async {
        addTearDown(() => tester.view.resetPhysicalSize());
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        final theme = ThemeData.from(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: brightness,
          ),
        );
        for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
          tester.view.physicalSize = Size(width, 500);
          for (final scale in [1.0, 3.0]) {
            Color? inactiveColor;
            for (final enabled in [false, true]) {
              var toggles = 0;
              await tester.pumpWidget(
                MaterialApp(
                  theme: theme,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      padding: const EdgeInsets.only(bottom: 24),
                      viewInsets: const EdgeInsets.only(bottom: 100),
                    ),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: SafeArea(
                      child: InteractionPolicyScope(
                        initialPolicy: const InteractionPolicy(
                          modality: InteractionModality.touch,
                          touchAvailable: true,
                          precisePointerAvailable: false,
                        ),
                        child: SizedBox(
                          width: width,
                          height: isListMode ? null : 240,
                          child: SidebarEntryTile(
                            entry: FixedTagEntry.create(
                              name: 'Fixed tag',
                              content: 'blue eyes',
                              enabled: enabled,
                            ),
                            categoryColor: theme.colorScheme.primary,
                            isListMode: isListMode,
                            onToggle: () => toggles++,
                            onEdit: () {},
                            onDelete: () {},
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              final tile = find.byType(SidebarEntryTile);
              final selectionSemantics = tester.widget<Semantics>(
                find
                    .descendant(of: tile, matching: find.byType(Semantics))
                    .first,
              );
              expect(selectionSemantics.properties.selected, enabled);
              final material = tester.widget<Material>(
                find
                    .descendant(of: tile, matching: find.byType(Material))
                    .first,
              );
              final background = material.color!;
              if (!enabled) inactiveColor = background;
              if (enabled) expect(background, isNot(inactiveColor));
              expect(
                find.byIcon(
                  enabled ? Icons.check_circle : Icons.radio_button_unchecked,
                ),
                findsOneWidget,
              );
              for (final label in ['Fixed tag', 'blue eyes']) {
                final text = tester.widget<Text>(find.text(label));
                final foreground = text.style!.color!;
                final a = foreground.computeLuminance();
                final b = background.computeLuminance();
                final contrast = a > b
                    ? (a + 0.05) / (b + 0.05)
                    : (b + 0.05) / (a + 0.05);
                expect(contrast, greaterThanOrEqualTo(4.5));
              }
              expect(
                find.byIcon(Icons.edit_rounded).hitTestable(),
                findsOneWidget,
              );
              expect(
                find.byIcon(Icons.copy_rounded).hitTestable(),
                findsOneWidget,
              );
              expect(
                find.byIcon(Icons.delete_outline_rounded).hitTestable(),
                findsOneWidget,
              );
              await tester.tap(find.text('Fixed tag'));
              expect(toggles, 1);
              expect(tester.takeException(), isNull);
            }
          }
        }
      });
    }
  }
}
