import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tool_panel_matrix.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testToolPanelMatrix(
    'magnetic lasso options and touch actions stay in the tool panel',
    toolId: 'magnetic_lasso_selection',
    verify: (tester, scenario) async {
      final l10n = scenario.l10n;
      final panel = toolPanel(l10n.editor_toolMagneticLasso);
      for (final label in [
        l10n.editor_magneticLassoHelp,
        l10n.editor_magneticLassoWidth,
        l10n.editor_magneticLassoContrast,
        l10n.editor_magneticLassoFrequency,
        l10n.editor_magneticLassoClose,
        l10n.editor_magneticLassoRemoveAnchor,
        l10n.common_cancel,
      ]) {
        expect(
          find.descendant(of: panel, matching: find.text(label)),
          findsOneWidget,
        );
      }
      final sliders = find.descendant(of: panel, matching: find.byType(Slider));
      expect(sliders, findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        await expectReachable(
          tester,
          sliders.at(i),
          reason: '$scenario, slider $i',
        );
      }
      for (final action in [
        l10n.editor_magneticLassoClose,
        l10n.editor_magneticLassoRemoveAnchor,
        l10n.common_cancel,
      ]) {
        final label = find.descendant(of: panel, matching: find.text(action));
        final button = find.ancestor(
          of: label,
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        );
        final viewport = find
            .ancestor(of: button, matching: find.byType(Scrollable))
            .first;
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        final bounds = tester.getRect(button);
        expect(bounds.height, greaterThanOrEqualTo(44));
        expect(tester.getRect(viewport).contains(bounds.center), isTrue);
      }
    },
  );
}
