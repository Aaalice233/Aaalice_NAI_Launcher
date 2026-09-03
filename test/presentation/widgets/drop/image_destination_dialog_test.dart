import 'dart:typed_data';

import 'package:flutter/gestures.dart';
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

    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    expect(find.byType(Dialog), findsNothing);
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

    final characterPrompts = find.text('Character Prompts (1)');
    expect(characterPrompts, findsOneWidget);
    await tester.ensureVisible(characterPrompts);
    await tester.pumpAndSettle();
    await tester.tap(characterPrompts);
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

    final promptField = _promptFieldFinder('drop-positive-prompt-card');
    await tester.ensureVisible(promptField);
    await tester.pumpAndSettle();
    tester.widget<TextField>(promptField).focusNode!.requestFocus();
    controller.selection = TextSelection(
      baseOffset: start,
      extentOffset: start + selected.length,
    );
    await tester.pump();
    final editableText = find.descendant(
      of: promptField,
      matching: find.byType(EditableText),
    );
    final editableState = tester.state<EditableTextState>(editableText);
    final textField = tester.widget<TextField>(promptField);
    final menuEntry = OverlayEntry(
      builder: (context) =>
          textField.contextMenuBuilder!(context, editableState),
    );
    Overlay.of(tester.element(promptField)).insert(menuEntry);
    await tester.pumpAndSettle();

    expect(find.text('Add to library'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add to library'), findsNothing);
    await tester.tap(find.text('Add to library'));
    menuEntry.remove();
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

    final promptField = _promptFieldFinder('drop-positive-prompt-card');
    await tester.ensureVisible(promptField);
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(promptField),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add full prompt to library'));
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
    expect(find.text('Send to Text to Image'), findsNothing);
    expect(find.text('Image2Image'), findsOneWidget);
  });

  for (final scenario in <({Size size, double scale, double keyboard})>[
    (size: const Size(320, 900), scale: 3, keyboard: 240),
    (size: const Size(1600, 900), scale: 1, keyboard: 0),
  ]) {
    testWidgets(
      'variable metadata errors use adaptive details at ${scenario.size}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = scenario.size;
        addTearDown(tester.view.reset);
        final error = List.generate(
          80,
          (index) => 'metadata failure line $index: invalid payload value',
        ).join('\n');

        await _openMetadataDialog(
          tester,
          metadata: null,
          metadataParseError: error,
          textScale: scenario.scale,
          keyboardHeight: scenario.keyboard,
          padding: const EdgeInsets.only(top: 20, bottom: 16),
        );
        final details = find.text('View error details');
        await tester.scrollUntilVisible(
          details,
          120,
          scrollable: find.descendant(
            of: find.byType(ImageDestinationDialog),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(details);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.byKey(const ValueKey('metadata-error-details-text')),
          findsOneWidget,
        );
        final detailsScrollable = find
            .descendant(
              of: find.byKey(const ValueKey('metadata-error-details-scroll')),
              matching: find.byType(Scrollable),
            )
            .first;
        final scrollPosition = tester
            .state<ScrollableState>(detailsScrollable)
            .position;
        expect(scrollPosition.maxScrollExtent, greaterThan(0));
        final presentationKey = scenario.size.width < 600
            ? const ValueKey('adaptive-full-screen-form')
            : const ValueKey('adaptive-centered-form');
        expect(find.byKey(presentationKey), findsNWidgets(2));
        expect(tester.takeException(), isNull);

        await tester.tap(find.byTooltip('Close').last);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('metadata-error-details-text')),
          findsNothing,
        );
        expect(find.byType(ImageDestinationDialog), findsOneWidget);
      },
    );
  }

  for (final scenario in <({Size size, double scale, double keyboard})>[
    (size: const Size(320, 800), scale: 1, keyboard: 0),
    (size: const Size(320, 900), scale: 3, keyboard: 0),
    (size: const Size(1600, 900), scale: 1, keyboard: 0),
    (size: const Size(700, 360), scale: 1, keyboard: 0),
    (size: const Size(320, 800), scale: 1, keyboard: 300),
  ]) {
    testWidgets('error and destinations stay reachable at ${scenario.size}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = scenario.size;
      addTearDown(tester.view.reset);

      await _openMetadataDialog(
        tester,
        metadata: null,
        metadataParseError: 'Invalid metadata payload',
        textScale: scenario.scale,
        keyboardHeight: scenario.keyboard,
      );

      final target = find.text('Precise Reference');
      await tester.scrollUntilVisible(
        target,
        120,
        scrollable: find.descendant(
          of: find.byType(ImageDestinationDialog),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Metadata could not be parsed'), findsOneWidget);
      expect(target.hitTestable(), findsOneWidget);
      final availableHeight = scenario.size.height - scenario.keyboard;
      final presentation = scenario.size.width < 600 || availableHeight < 560
          ? find.byKey(const ValueKey('adaptive-full-screen-form'))
          : find.byKey(const ValueKey('adaptive-centered-form'));
      expect(presentation, findsOneWidget);
      expect(
        tester.getRect(presentation).height,
        lessThanOrEqualTo(scenario.size.height - scenario.keyboard),
      );
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'metadata form uses bounded adaptive presentation on wide panes',
    (tester) async {
      addTearDown(tester.view.reset);
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

        final presentation = find.byKey(
          const ValueKey('adaptive-centered-form'),
        );
        expect(presentation, findsOneWidget);
        expect(tester.getSize(presentation).width, lessThan(width));
        expect(find.byType(Dialog), findsNothing);
        expect(
          find.byKey(const ValueKey('drop-positive-prompt-card')),
          findsOne,
        );
        expect(
          find.byKey(const ValueKey('drop-negative-prompt-card')),
          findsOne,
        );
        expect(find.text('Actions'), findsOneWidget);
        expect(find.text('Send to Text to Image'), findsOneWidget);
        expect(find.text('Reverse Prompt'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Send to Text to Image')).dy,
          lessThan(tester.getTopLeft(find.text('Reverse Prompt')).dy),
        );
        expect(tester.takeException(), isNull, reason: 'width=$width');

        await tester.tap(find.byTooltip('Close').first);
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'compact metadata form survives 320px, 3x text, IME and safe area',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 1000);
      addTearDown(tester.view.reset);

      await _openMetadataDialog(
        tester,
        metadata: const NaiImageMetadata(
          prompt: 'masterpiece, detailed eyes',
          negativePrompt: 'lowres, bad anatomy',
        ),
        textScale: 3,
        keyboardHeight: 300,
        padding: const EdgeInsets.only(top: 24, bottom: 20),
      );

      final presentation = find.byKey(
        const ValueKey('adaptive-full-screen-form'),
      );
      expect(presentation, findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.getTopLeft(presentation).dy, greaterThanOrEqualTo(24));
      expect(tester.getBottomRight(presentation).dy, lessThanOrEqualTo(680));

      final target = find.text('Precise Reference');
      await tester.scrollUntilVisible(
        target,
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('drop-metadata-form-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(target.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('metadata adaptive form preserves destination result', (
    tester,
  ) async {
    ImageDestination? selected;
    await _openMetadataDialog(
      tester,
      metadata: const NaiImageMetadata(prompt: 'masterpiece'),
      onResult: (result) => selected = result,
    );

    final extract = find.text('Send to Text to Image');
    await tester.ensureVisible(extract);
    await tester.tap(extract);
    await tester.pumpAndSettle();

    expect(selected, ImageDestination.extractMetadata);
    expect(find.byType(ImageDestinationDialog), findsNothing);
  });

  for (final pointerKind in <PointerDeviceKind>[
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  ]) {
    testWidgets(
      'double tap selects a complete prompt segment with $pointerKind',
      (tester) async {
        const prompt = 'alpha, [artist:foo, watercolor]';
        await _openMetadataDialog(
          tester,
          metadata: const NaiImageMetadata(prompt: prompt),
        );

        final promptField = _promptFieldFinder('drop-positive-prompt-card');
        await tester.ensureVisible(promptField);
        await tester.pumpAndSettle();
        final position = tester.getCenter(promptField);

        final firstTap = await tester.startGesture(position, kind: pointerKind);
        await firstTap.up();
        await tester.pump(const Duration(milliseconds: 50));
        final secondTap = await tester.startGesture(
          position,
          kind: pointerKind,
        );
        await secondTap.up();
        await tester.pump();

        final controller = _promptController(
          tester,
          'drop-positive-prompt-card',
        );
        expect(
          controller.selection.textInside(controller.text),
          '[artist:foo, watercolor]',
        );
      },
    );
  }

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
  double textScale = 1,
  double keyboardHeight = 0,
  EdgeInsets padding = EdgeInsets.zero,
  ValueChanged<ImageDestination?>? onResult,
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            padding: padding,
            viewPadding: padding,
            viewInsets: EdgeInsets.only(bottom: keyboardHeight),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await ImageDestinationDialog.show(
                  context,
                  imageBytes: _transparentPngBytes,
                  fileName: 'metadata.png',
                  showExtractMetadata: metadata != null,
                  metadata: metadata,
                  metadataParseError: metadataParseError,
                );
                onResult?.call(result);
              },
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

Finder _promptFieldFinder(String cardKey) {
  return find.descendant(
    of: find.byKey(ValueKey(cardKey)),
    matching: find.byType(TextField),
  );
}

TextEditingController _promptController(WidgetTester tester, String cardKey) {
  final textField = tester.widget<TextField>(_promptFieldFinder(cardKey));
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
