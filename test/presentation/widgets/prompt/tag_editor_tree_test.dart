import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/autocomplete/autocomplete_overlay_handle.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_session.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_capsule.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_tree.dart';

import '../../../helpers/ink_expectations.dart';

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
    Widget app(double width) => _treeApp(
      session: session,
      autocomplete: autocomplete,
      keys: keys,
      width: width,
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

  testWidgets('权重组标签的悬停与按压反馈画在组底色之上', (tester) async {
    final source = TextEditingController(text: '1.2::cat, dog::, bird');
    final session = TagEditorSession(source);
    final autocomplete = AutocompleteOverlayHandle();
    final selected = <PromptEditorTag>[];
    addTearDown(source.dispose);
    addTearDown(session.dispose);
    addTearDown(autocomplete.dispose);
    await tester.pumpWidget(
      _treeApp(
        session: session,
        autocomplete: autocomplete,
        keys: <int, GlobalKey>{},
        width: 600,
        onSelect: selected.add,
      ),
    );
    await tester.pump();

    final group = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'tag-weight-group-',
          ),
    );
    final badge = find.descendant(of: group, matching: find.text('×1.2'));
    final theme = Theme.of(tester.element(group));
    final fill =
        (tester.widget<Container>(group).decoration! as BoxDecoration).color!;

    await hoverOver(tester, badge);
    expectInkOnTop(tester, group, ink: theme.hoverColor, below: fill);

    final press = await pressAndHold(tester, badge);
    expectInkOnTop(tester, group, ink: theme.highlightColor, below: fill);
    await press.up();
    await tester.pump();
    expect(selected, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _treeApp({
  required TagEditorSession session,
  required AutocompleteOverlayHandle autocomplete,
  required Map<int, GlobalKey> keys,
  required double width,
  ValueChanged<PromptEditorTag>? onSelect,
}) {
  return MaterialApp(
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
              onSelect: onSelect ?? (_) {},
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
}
