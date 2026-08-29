import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/prompt_tag.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TagView settles immediately when isLoading is false', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: TagView(
              tags: const [PromptTag(id: '1', text: '1girl')],
              onTagsChanged: (_) {},
              isLoading: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  });

  testWidgets('EditorCanvas settles immediately when there is no selection', (tester) async {
    final state = EditorState();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: EditorCanvas(state: state))));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    state.dispose();
  });
}
