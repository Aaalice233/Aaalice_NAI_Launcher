import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/weight_adjust_toolbar.dart';
import 'package:nai_launcher/presentation/widgets/prompt/prompt_translation_caption.dart';

void main() {
  testWidgets('text toolbar translates only the current whole tag', (
    tester,
  ) async {
    final source = TextEditingController(text: 'cat, dog');
    final focus = FocusNode();
    addTearDown(source.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagTranslationLookupProvider.overrideWithValue(
            TagTranslationLookup.fromResolver(
              (tags) async => {'cat': '猫', 'dog': '狗'},
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(100),
              child: WeightAdjustToolbarWrapper(
                controller: source,
                focusNode: focus,
                child: TextField(controller: source, focusNode: focus),
              ),
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    source.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    await tester.pumpAndSettle();
    expect(find.text('猫'), findsOneWidget);
    source.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
    await tester.pumpAndSettle();
    expect(find.byType(PromptTranslationCaption), findsNothing);
    source.selection = const TextSelection(baseOffset: 0, extentOffset: 8);
    await tester.pumpAndSettle();
    expect(find.byType(PromptTranslationCaption), findsNothing);
    source.selection = const TextSelection(baseOffset: 5, extentOffset: 8);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(find.text('猫'), findsNothing);
    expect(find.text('狗'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
