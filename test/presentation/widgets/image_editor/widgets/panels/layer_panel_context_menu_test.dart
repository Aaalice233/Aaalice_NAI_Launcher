import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/panels/layer_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../image_editor_workspace_harness.dart';

Finder _menuText(String label) => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is PopupMenuItem<String>),
  matching: find.text(label),
);

List<Layer> _layers(WidgetTester tester) => tester
    .widget<EditorCanvas>(find.byType(EditorCanvas))
    .state
    .layerManager
    .layers;

Future<void> _openLayerMenu(
  WidgetTester tester, {
  required AppLocalizations l10n,
  required bool viaLongPress,
}) async {
  if (find.byType(LayerPanel).evaluate().isEmpty) {
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == l10n.editor_layers,
      ),
    );
    await tester.pumpAndSettle();
  }
  final layer = _layers(tester).first;
  final name = find.descendant(
    of: find.byType(LayerPanel),
    matching: find.text(layer.name),
  );
  if (viaLongPress) {
    await tester.longPress(name);
  } else {
    await tester.tap(
      name,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const cases = [
    (size: Size(1180, 760), locale: 'en', scale: 1.0),
    (size: Size(1180, 760), locale: 'en', scale: 3.0),
    (size: Size(1180, 760), locale: 'ja', scale: 1.0),
    (size: Size(1180, 760), locale: 'ja', scale: 3.0),
    (size: Size(600, 760), locale: 'en', scale: 1.0),
    (size: Size(600, 760), locale: 'en', scale: 3.0),
    (size: Size(600, 760), locale: 'ja', scale: 1.0),
    (size: Size(600, 760), locale: 'ja', scale: 3.0),
  ];

  for (final c in cases) {
    final viaLongPress = c.size.width < 840;
    testWidgets(
      '${c.size.width.toInt()} ${c.locale} ${c.scale}x 图层菜单不溢出且每项可点',
      (tester) async {
        await pumpEditorWorkspace(
          tester,
          viewSize: c.size,
          locale: c.locale,
          textScale: c.scale,
        );
        final l10n = lookupAppLocalizations(Locale(c.locale));

        await _openLayerMenu(tester, l10n: l10n, viaLongPress: viaLongPress);
        expect(tester.takeException(), isNull);

        final labels = {
          l10n.layer_duplicate,
          l10n.layer_delete,
          l10n.layer_merge,
          l10n.layer_visibility,
          l10n.layer_lock,
          l10n.layer_rename,
          l10n.layer_moveUp,
          l10n.layer_moveDown,
        };
        for (final label in labels) {
          final item = _menuText(label);
          expect(item, findsOneWidget, reason: label);
          await tester.ensureVisible(item);
          await tester.pumpAndSettle();
          expect(item.hitTestable(), findsOneWidget, reason: label);
        }

        final layerCount = _layers(tester).length;
        final duplicate = _menuText(l10n.layer_duplicate);
        await tester.ensureVisible(duplicate);
        await tester.pumpAndSettle();
        await tester.tap(duplicate);
        await tester.pumpAndSettle();
        expect(_layers(tester), hasLength(layerCount + 1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
