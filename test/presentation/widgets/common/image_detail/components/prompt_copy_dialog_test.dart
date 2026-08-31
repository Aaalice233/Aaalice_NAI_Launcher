import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/prompt_copy_dialog.dart';

void main() {
  String? clipboardText;

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
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

  testWidgets(
    'export mode shows real categories and writes complete text to clipboard',
    (tester) async {
      const metadata = NaiImageMetadata(
        prompt: 'fixed, 1girl, very aesthetic',
        negativePrompt: 'bad anatomy, lowres',
        fixedPrefixTags: ['fixed'],
        fixedNegativePrefixTags: ['bad anatomy'],
        qualityTags: ['very aesthetic'],
        characterPrompts: ['alice', 'bob'],
        characterNegativePrompts: ['glasses', 'hat'],
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final value = await PromptCopyDialog.showExport(
                  context,
                  metadata: metadata,
                );
                if (value != null) {
                  await Clipboard.setData(ClipboardData(text: value));
                }
              },
              child: const Text('open export'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open export'));
      await tester.pumpAndSettle();
      expect(find.text('全部正面提示词'), findsOneWidget);
      expect(find.text('全部负面提示词'), findsOneWidget);
      expect(find.text('固定正面提示词'), findsOneWidget);
      expect(find.text('固定负面提示词'), findsOneWidget);
      expect(find.text('角色 1 正面提示词'), findsOneWidget);
      expect(find.text('角色 2 负面提示词'), findsOneWidget);
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((checkbox) => checkbox.value == true),
        isTrue,
      );

      await tester.tap(find.text('复制'));
      await tester.pumpAndSettle();
      expect(
        clipboardText,
        startsWith(
          'positive: fixed, 1girl, very aesthetic | alice | bob\n'
          'negative: bad anatomy, lowres | glasses | hat\nmetadata: ',
        ),
      );
      expect(clipboardText, isNot('{}'));
    },
  );

  testWidgets(
    'partial selection updates parents and empty selection cannot copy',
    (tester) async {
      const metadata = NaiImageMetadata(
        prompt: 'main',
        negativePrompt: 'negative',
        characterPrompts: ['character'],
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final value = await PromptCopyDialog.showExport(
                  context,
                  metadata: metadata,
                );
                if (value != null) {
                  await Clipboard.setData(ClipboardData(text: value));
                }
              },
              child: const Text('open export'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('角色 1 正面提示词'));
      await tester.pump();
      final positiveParent = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, '全部正面提示词'),
      );
      expect(positiveParent.value, isNull);

      // Partial -> all -> none follows the platform tri-state checkbox cycle.
      await tester.tap(find.text('全部正面提示词'));
      await tester.pump();
      await tester.tap(find.text('全部正面提示词'));
      await tester.tap(find.text('全部负面提示词'));
      await tester.pump();
      final copyButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '复制'),
      );
      expect(copyButton.onPressed, isNull);
      expect(clipboardText, isNull);
    },
  );
}
