import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/generation_workspace_row.dart';

void main() {
  testWidgets(
    'responsive generation workspace preserves its main pane without overflow',
    (tester) async {
      for (final width in [700.0, 840.0, 1180.0, 1600.0]) {
        final desktop = width >= 1000;
        final leadingWidth = desktop ? (300.0 + 8 + 400 + 8) : 0.0;
        await tester.binding.setSurfaceSize(Size(width, 700));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GenerationWorkspaceRow(
                occupiedLeadingWidth: leadingWidth,
                leading: desktop
                    ? const [
                        SizedBox(width: 300),
                        SizedBox(width: 8),
                        SizedBox(width: 408),
                      ]
                    : const [],
                main: const ColoredBox(color: Colors.blue),
                rightPanelExpanded: desktop,
                preferredRightPanelWidth: 960,
                rightHandle: const SizedBox(width: 8),
                rightPanelBuilder: (panelWidth, expanded) => SizedBox(
                  key: ValueKey('test-generation-right-panel-$expanded'),
                  width: panelWidth,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull, reason: 'width=$width');
        final mainRect = tester.getRect(
          find.byKey(const ValueKey('generation-main-workspace-slot')),
        );
        expect(
          mainRect.width,
          greaterThanOrEqualTo(
            GenerationWorkspaceRow.minimumMainWorkspaceWidth,
          ),
          reason: 'width=$width',
        );
        if (desktop) {
          final expectsExpanded = width >= 1600;
          final panelRect = tester.getRect(
            find.byKey(
              ValueKey('test-generation-right-panel-$expectsExpanded'),
            ),
          );
          expect(panelRect.right, lessThanOrEqualTo(width));
        }
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
}
