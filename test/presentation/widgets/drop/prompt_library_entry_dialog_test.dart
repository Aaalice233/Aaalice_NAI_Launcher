import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/adaptive_dialog_frame.dart';
import 'package:nai_launcher/presentation/widgets/drop/prompt_library_entry_dialog.dart';

void main() {
  test('append keeps both existing and selected text byte-for-byte', () {
    const existing = 'alpha, beta  ';
    const snippet = '\n  [artist:foo], {weighted}  ';

    expect(
      appendPromptSnippet(existing, snippet, PromptAppendSeparator.none),
      '$existing$snippet',
    );
    expect(
      appendPromptSnippet(existing, snippet, PromptAppendSeparator.newline),
      '$existing\n$snippet',
    );
  });

  test('short single fragment is suggested only as a name', () {
    expect(
      suggestedPromptLibraryName('  artist:foo  ', 'Prompt snippet'),
      'artist:foo',
    );
    expect(
      suggestedPromptLibraryName('artist:foo, watercolor', 'Prompt snippet'),
      'Prompt snippet',
    );
  });

  test('available name lookup is case insensitive', () {
    final entries = [
      TagLibraryEntry.create(name: 'Prompt snippet', content: 'one'),
      TagLibraryEntry.create(name: 'prompt snippet 2', content: 'two'),
    ];

    expect(
      availablePromptLibraryName('Prompt snippet', entries),
      'Prompt snippet 3',
    );
    expect(
      availablePromptLibraryName('  Prompt snippet  ', entries),
      'Prompt snippet 3',
    );
  });

  test('entry factory can preserve selected prompt whitespace exactly', () {
    const selected = '  [artist:foo],\n1.2::watercolor::  ';

    final preserved = TagLibraryEntry.create(
      name: 'Example',
      content: selected,
      preserveContentWhitespace: true,
    );
    final legacy = TagLibraryEntry.create(name: 'Example', content: selected);

    expect(preserved.content, selected);
    expect(legacy.content, selected.trim());
  });

  testWidgets('320dp at 3x adapts modes and actions with IME and SafeArea', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(960, 1704);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    bool? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagLibraryPageNotifierProvider.overrideWith(
            _TestTagLibraryPageNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
              viewPadding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
              textScaler: const TextScaler.linear(3),
              viewInsets: const EdgeInsets.only(bottom: 240),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  result = await PromptLibraryEntryDialog.show(
                    context,
                    content: 'masterpiece, best quality',
                    fallbackName: 'Prompt snippet',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsOneWidget,
    );
    expect(find.byType(AdaptiveDialogFrame), findsOneWidget);
    final frameRect = tester.getRect(find.byType(AdaptiveDialogFrame));
    expect(frameRect.left, greaterThanOrEqualTo(12));
    expect(frameRect.top, greaterThanOrEqualTo(24));
    expect(frameRect.bottom, lessThanOrEqualTo(568 - 16 - 240));

    final modeControl = tester.widget<SegmentedButton<PromptLibraryWriteMode>>(
      find.byKey(const ValueKey('prompt-library-write-mode')),
    );
    expect(modeControl.direction, Axis.vertical);
    expect(
      find.byKey(const ValueKey('prompt-library-actions-vertical')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    modeControl.onSelectionChanged!({PromptLibraryWriteMode.append});
    await tester.pumpAndSettle();
    final updatedModeControl = tester
        .widget<SegmentedButton<PromptLibraryWriteMode>>(
          find.byKey(const ValueKey('prompt-library-write-mode')),
        );
    expect(updatedModeControl.selected, {PromptLibraryWriteMode.append});

    updatedModeControl.onSelectionChanged!({PromptLibraryWriteMode.create});
    await tester.pumpAndSettle();
    final nameField = find.byKey(const ValueKey('prompt-library-name'));
    await tester.ensureVisible(nameField);
    await tester.tap(nameField);
    await tester.showKeyboard(nameField);
    await tester.enterText(nameField, 'Saved from compact dialog');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final saveButton = find.descendant(
      of: find.byKey(const ValueKey('prompt-library-actions-vertical')),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byType(PromptLibraryEntryDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('medium form is bounded and cancel returns false', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    bool? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagLibraryPageNotifierProvider.overrideWith(
            _TestTagLibraryPageNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  result = await PromptLibraryEntryDialog.show(
                    context,
                    content: 'masterpiece',
                    fallbackName: 'Prompt snippet',
                  );
                },
                child: const Text('Open'),
              ),
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
    expect(find.byType(AdaptiveDialogFrame), findsOneWidget);
    final surfaceRect = tester.getRect(
      find.byKey(const ValueKey('adaptive-centered-form')),
    );
    expect(surfaceRect.width, lessThan(700));
    expect(surfaceRect.height, lessThan(900));
    expect(
      tester
          .widget<SegmentedButton<PromptLibraryWriteMode>>(
            find.byKey(const ValueKey('prompt-library-write-mode')),
          )
          .direction,
      Axis.vertical,
    );

    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(find.byType(PromptLibraryEntryDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _TestTagLibraryPageNotifier extends TagLibraryPageNotifier {
  @override
  TagLibraryPageState build() => const TagLibraryPageState();

  @override
  Future<TagLibraryEntry> addEntry({
    required String name,
    required String content,
    String? thumbnail,
    double thumbnailOffsetX = 0.0,
    double thumbnailOffsetY = 0.0,
    double thumbnailScale = 1.0,
    List<String>? tags,
    String? categoryId,
    bool isFavorite = false,
    bool preserveContentWhitespace = false,
    bool failOnPersistenceError = false,
  }) async {
    final entry = TagLibraryEntry.create(
      name: name,
      content: content,
      tags: tags,
      categoryId: categoryId,
      preserveContentWhitespace: preserveContentWhitespace,
    );
    state = state.copyWith(entries: [entry]);
    return entry;
  }
}
