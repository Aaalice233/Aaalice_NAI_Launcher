import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
import 'package:nai_launcher/presentation/widgets/drop/image_destination_dialog.dart';

void main() {
  testWidgets('shows reverse prompt before image-to-image destination', (
    tester,
  ) async {
    ImageDestination? selected;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          replicationQueueNotifierProvider.overrideWith(
            _TestReplicationQueueNotifier.new,
          ),
          queueExecutionNotifierProvider.overrideWith(
            _TestQueueExecutionNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    selected = await ImageDestinationDialog.show(
                      context,
                      imageBytes: _transparentPngBytes,
                      fileName: 'dropped.png',
                      showExtractMetadata: false,
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final dialogContext = tester.element(find.byType(ImageDestinationDialog));
    final l10n = AppLocalizations.of(dialogContext)!;
    final reversePromptFinder = find.text(l10n.drop_reversePrompt);
    final img2imgFinder = find.text(l10n.drop_img2img);

    expect(reversePromptFinder, findsOneWidget);
    expect(img2imgFinder, findsOneWidget);
    expect(
      tester.getTopLeft(reversePromptFinder).dy,
      lessThan(tester.getTopLeft(img2imgFinder).dy),
    );

    await tester.tap(reversePromptFinder);
    await tester.pumpAndSettle();

    expect(selected.toString(), equals('ImageDestination.reversePrompt'));
  });

  testWidgets('shows exact positive and negative prompt text from metadata', (
    tester,
  ) async {
    const positive = '  masterpiece, 1.2::detailed eyes::,\n[artist:foo]  ';
    const negative = '{lowres}, bad anatomy,\n  watermark';

    await _openMetadataDialog(
      tester,
      metadata: const NaiImageMetadata(
        prompt: positive,
        negativePrompt: negative,
        width: 832,
        height: 1216,
        steps: 28,
        scale: 5,
        seed: 123456,
        source: 'NovelAI Diffusion V4.5',
      ),
    );

    expect(
      _promptController(tester, 'drop-positive-prompt-card').text,
      positive,
    );
    expect(
      _promptController(tester, 'drop-negative-prompt-card').text,
      negative,
    );
    expect(find.text('NovelAI metadata detected'), findsOneWidget);
  });

  testWidgets('character prompts stay separate and preserve exact text', (
    tester,
  ) async {
    const characterPrompt = '  character one,\n[artist:foo]  ';
    const characterNegative = 'bad hands,  extra fingers';
    await _openMetadataDialog(
      tester,
      metadata: const NaiImageMetadata(
        prompt: 'base scene',
        characterPrompts: [characterPrompt],
        characterNegativePrompts: [characterNegative],
      ),
    );

    expect(find.text('Character Prompts (1)'), findsOneWidget);
    await tester.tap(find.text('Character Prompts (1)'));
    await tester.pumpAndSettle();

    expect(
      _promptController(tester, 'drop-character-prompt-card-0').text,
      characterPrompt,
    );
    expect(
      _promptController(tester, 'drop-character-negative-prompt-card-0').text,
      characterNegative,
    );
  });

  testWidgets('selected prompt opens library confirmation with exact text', (
    tester,
  ) async {
    const prompt = 'first, [artist:foo, watercolor],\n  final tag';
    await _openMetadataDialog(
      tester,
      metadata: const NaiImageMetadata(prompt: prompt),
    );

    final controller = _promptController(tester, 'drop-positive-prompt-card');
    const selected = '[artist:foo, watercolor],\n  final';
    final start = prompt.indexOf(selected);
    controller.selection = TextSelection(
      baseOffset: start,
      extentOffset: start + selected.length,
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Add to library').last);
    await tester.pumpAndSettle();

    final contentField = tester.widget<TextField>(
      find.byKey(const ValueKey('prompt-library-content')),
    );
    expect(contentField.controller!.text, selected);
    expect(find.byType(ImageDestinationDialog), findsOneWidget);
  });

  testWidgets('duplicate prompt content is blocked before writing', (
    tester,
  ) async {
    const prompt = 'same, exact prompt';
    await _openMetadataDialog(
      tester,
      metadata: const NaiImageMetadata(prompt: prompt),
      libraryEntries: [
        TagLibraryEntry.create(name: 'Existing entry', content: prompt),
      ],
    );

    await tester.tap(find.text('Add full prompt to library').first);
    await tester.pumpAndSettle();

    expect(
      find.text('The same content already exists in “Existing entry”'),
      findsOneWidget,
    );
    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm').last,
    );
    expect(confirmButton.onPressed, isNull);
  });

  testWidgets('parse failure is distinct from an image without metadata', (
    tester,
  ) async {
    await _openMetadataDialog(
      tester,
      metadata: null,
      metadataParseError: 'Invalid metadata payload',
    );

    expect(find.text('Metadata could not be parsed'), findsOneWidget);
    expect(find.text('View error details'), findsOneWidget);
    expect(find.text('Extract Metadata'), findsNothing);
    expect(find.text('Image2Image'), findsOneWidget);
  });

  testWidgets('metadata menu has no overflow at required desktop widths', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const metadata = NaiImageMetadata(
      prompt:
          'masterpiece, best quality, 1.2::detailed eyes::, '
          '[artist:foo, watercolor style], night street, cinematic lighting',
      negativePrompt: 'lowres, bad anatomy, extra fingers, text, watermark',
      width: 832,
      height: 1216,
      steps: 28,
      scale: 5,
      seed: 123456,
      source: 'NovelAI Diffusion V4.5',
    );

    for (final width in [700.0, 840.0, 1180.0, 1600.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await _openMetadataDialog(tester, metadata: metadata);

      expect(find.byKey(const ValueKey('drop-positive-prompt-card')), findsOne);
      expect(find.byKey(const ValueKey('drop-negative-prompt-card')), findsOne);
      expect(find.text('Extract Metadata'), findsOneWidget);
      expect(find.text('Reverse Prompt'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width=$width');

      if (width == 700) {
        final characterReference = find.text('Precise Reference');
        await tester.ensureVisible(characterReference);
        await tester.pumpAndSettle();
        expect(characterReference.hitTestable(), findsOneWidget);
        await tester.tap(characterReference);
        await tester.pumpAndSettle();
        expect(find.byType(ImageDestinationDialog), findsNothing);
      } else {
        await tester.tap(find.byTooltip('Close').first);
        await tester.pumpAndSettle();
      }
    }
  });

  test(
    'double-click segment range respects nested punctuation and weights',
    () {
      const prompt = 'alpha, [artist:foo, watercolor], 1.2::final tag::\nnext';

      expect(
        topLevelPromptSegmentRange(prompt, prompt.indexOf('watercolor')),
        const TextRange(start: 7, end: 31),
      );
      final weightedStart = prompt.indexOf('1.2::');
      expect(
        topLevelPromptSegmentRange(prompt, weightedStart + 6),
        TextRange(start: weightedStart, end: prompt.indexOf('\n')),
      );
    },
  );

  test('negative-only metadata is importable', () {
    expect(const NaiImageMetadata(negativePrompt: 'lowres').hasData, isTrue);
  });
}

Future<void> _openMetadataDialog(
  WidgetTester tester, {
  required NaiImageMetadata? metadata,
  String? metadataParseError,
  List<TagLibraryEntry> libraryEntries = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        replicationQueueNotifierProvider.overrideWith(
          _TestReplicationQueueNotifier.new,
        ),
        queueExecutionNotifierProvider.overrideWith(
          _TestQueueExecutionNotifier.new,
        ),
        tagLibraryPageNotifierProvider.overrideWith(
          () => _TestTagLibraryPageNotifier(libraryEntries),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ImageDestinationDialog.show(
                context,
                imageBytes: _transparentPngBytes,
                fileName: 'metadata.png',
                showExtractMetadata: metadata != null,
                metadata: metadata,
                metadataParseError: metadataParseError,
              ),
              child: const Text('Open metadata'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open metadata'));
  await tester.pumpAndSettle();
}

TextEditingController _promptController(WidgetTester tester, String cardKey) {
  final textField = tester.widget<TextField>(
    find.descendant(
      of: find.byKey(ValueKey(cardKey)),
      matching: find.byType(TextField),
    ),
  );
  return textField.controller!;
}

final _transparentPngBytes = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0a,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0d,
  0x0a,
  0x2d,
  0xb4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
]);

class _TestReplicationQueueNotifier extends ReplicationQueueNotifier {
  @override
  ReplicationQueueState build() => const ReplicationQueueState();
}

class _TestQueueExecutionNotifier extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() => const QueueExecutionState();
}

class _TestTagLibraryPageNotifier extends TagLibraryPageNotifier {
  final List<TagLibraryEntry> entries;

  _TestTagLibraryPageNotifier(this.entries);

  @override
  TagLibraryPageState build() => TagLibraryPageState(entries: entries);
}
