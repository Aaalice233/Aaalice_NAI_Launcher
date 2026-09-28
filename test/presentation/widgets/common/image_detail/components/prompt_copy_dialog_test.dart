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

      await tester.scrollUntilVisible(
        find.text('复制'),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('prompt-copy-options-list')),
          matching: find.byType(Scrollable),
        ),
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

  testWidgets('worst-case export stays usable in compact bottom sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final characters = List.generate(12, (index) => 'character $index');
    final negativeCharacters = List.generate(
      12,
      (index) => 'negative character $index',
    );
    final metadata = NaiImageMetadata(
      prompt: 'fixed prefix, main prompt, quality tag, fixed suffix',
      negativePrompt: 'negative fixed, main negative',
      fixedPrefixTags: const ['fixed prefix'],
      fixedSuffixTags: const ['fixed suffix'],
      fixedNegativePrefixTags: const ['negative fixed'],
      qualityTags: const ['quality tag'],
      characterPrompts: characters,
      characterNegativePrompts: negativeCharacters,
    );
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: const Size(320, 568),
            textScaler: const TextScaler.linear(3),
            viewInsets: const EdgeInsets.only(bottom: 240),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await PromptCopyDialog.showExport(
                context,
                metadata: metadata,
              );
            },
            child: const Text('open export'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open export'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.byKey(const Key('prompt-copy-options-list')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final copyButton = find.text('Copy');
    await tester.scrollUntilVisible(
      copyButton,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('prompt-copy-options-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(copyButton);
    await tester.pumpAndSettle();
    expect(copyButton.hitTestable(), findsOneWidget);
    await tester.tap(copyButton);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result, contains('positive:'));
    expect(result, contains('negative:'));
    expect(result, contains('metadata:'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded export uses a width-bounded adaptive surface', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(size: const Size(1200, 800)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => PromptCopyDialog.showExport(
              context,
              metadata: const NaiImageMetadata(
                prompt: 'main',
                negativePrompt: 'negative',
              ),
            ),
            child: const Text('open export'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open export'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(surface, findsOneWidget);
    expect(tester.getSize(surface).width, 480);
    expect(tester.takeException(), isNull);
  });

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
