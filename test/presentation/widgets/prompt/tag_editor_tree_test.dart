import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/autocomplete/autocomplete_overlay_handle.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_session.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_capsule.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_tree.dart';

void main() {
  testWidgets('layout-time reorder with visible tooltip keeps anchors valid', (
    tester,
  ) async {
    final source = TextEditingController(text: '1.2::cat::, dog');
    final session = TagEditorSession(source);
    final autocomplete = AutocompleteOverlayHandle();
    final keys = <int, GlobalKey>{};
    addTearDown(source.dispose);
    addTearDown(session.dispose);
    addTearDown(autocomplete.dispose);
    Widget app(double width) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: LayoutBuilder(
              builder: (context, constraints) => TagEditorTree(
                session: session,
                width: constraints.maxWidth,
                keys: keys,
                enabled: true,
                enableAutocomplete: false,
                showTranslation: false,
                translations: null,
                onRetryTranslation: () {},
                onSelect: (_) {},
                onEdit: (_, _) {},
                onMenu: (_, _) {},
                onWheel: (_, _) {},
                autocompleteOverlay: autocomplete,
                addition: const SizedBox(width: 44, height: 44),
                onDraggingChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(600));
    final capsule = find.ancestor(
      of: find.text('cat'),
      matching: find.byType(TagEditorCapsule),
    );
    final capsuleState = tester.state(capsule);
    final tooltip = tester.state<TooltipState>(find.byType(Tooltip).first);
    tooltip.ensureTooltipVisible();
    await tester.pumpAndSettle();
    final cat = session.leaves.first;
    session.setSelection([cat.id]);
    session.moveSelectedBefore(null);
    await tester.pumpWidget(app(320));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.state(capsule), same(capsuleState));
    expect(source.text, 'dog, 1.2::cat::');
    expect(
      tester
          .getRect(find.byKey(keys[cat.id]!))
          .contains(tester.getCenter(find.text('cat'))),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
