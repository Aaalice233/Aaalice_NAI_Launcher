import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/prompt_copy_dialog.dart';

void main() {
  testWidgets(
    'defaults to subject and characters while excluding quality and fixed tags',
    (tester) async {
      const metadata = NaiImageMetadata(
        prompt:
            'private-prefix, 1girl, blue hair, private-suffix, very aesthetic',
        negativePrompt: '',
        fixedPrefixTags: ['private-prefix'],
        fixedSuffixTags: ['private-suffix'],
        qualityTags: ['very aesthetic'],
        characterPrompts: ['cat ears, green eyes'],
      );
      String? copiedPrompt;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                copiedPrompt = await PromptCopyDialog.show(
                  context,
                  metadata: metadata,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final values = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .map((checkbox) => checkbox.value)
          .toList();
      expect(values, [true, true, false, false]);

      await tester.tap(find.text('复制'));
      await tester.pumpAndSettle();
      expect(copiedPrompt, '1girl, blue hair\n\n| cat ears, green eyes');
    },
  );
}
