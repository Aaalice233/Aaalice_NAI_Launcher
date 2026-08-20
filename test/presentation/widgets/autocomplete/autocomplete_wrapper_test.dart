import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_cache_database.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_providers.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_settings.dart';
import 'package:nai_launcher/core/autocomplete/completion_models.dart';
import 'package:nai_launcher/core/autocomplete/danbooru_completion_source.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/autocomplete/autocomplete_config.dart';
import 'package:nai_launcher/presentation/widgets/autocomplete/autocomplete_wrapper.dart';

Future<void> _typeCurrentText(
  WidgetTester tester,
  TextEditingController controller,
) async {
  final text = controller.text;
  assert(text.isNotEmpty);
  final prefix = text.substring(0, text.length - 1);
  controller.value = TextEditingValue(
    text: prefix,
    selection: TextSelection.collapsed(offset: prefix.length),
  );
  await tester.pump();
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 30));
}

void main() {
  late String hivePath;

  setUp(() async {
    hivePath =
        '${Directory.systemTemp.path}/autocomplete_widget_${DateTime.now().microsecondsSinceEpoch}';
    Hive.init(hivePath);
    await Hive.openBox(StorageKeys.settingsBox);
    await Hive.openBox(StorageKeys.historyBox);
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
  });

  testWidgets('shows local BASE results and inserts by keyboard', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'blu');
    controller.selection = const TextSelection.collapsed(offset: 3);
    final focusNode = FocusNode();
    final baseSource = _BaseSource();
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autocompleteServicesProvider.overrideWithValue(
            AutocompleteServices(
              localSources: [baseSource],
              dictionaryTranslations: const _NoTranslations(),
              llmTranslations: const _NoTranslations(),
              danbooru: _NoDanbooru(),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AutocompleteWrapper(
              controller: controller,
              focusNode: focusNode,
              child: TextField(controller: controller, focusNode: focusNode),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await _typeCurrentText(tester, controller);

    expect(find.text('blue_eyes'), findsOneWidget);
    expect(find.text('BASE'), findsOneWidget);
    expect(baseSource.lastLimit, CompletionResultLimits.all);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.text, 'blue_eyes, ');
    expect(controller.selection.extentOffset, controller.text.length);
  });

  testWidgets('focus and caret clicks stay quiet until text is edited', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'blu');
    controller.selection = const TextSelection.collapsed(offset: 3);
    final focusNode = FocusNode();
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autocompleteServicesProvider.overrideWithValue(
            AutocompleteServices(
              localSources: [_BaseSource()],
              dictionaryTranslations: const _NoTranslations(),
              llmTranslations: const _NoTranslations(),
              danbooru: _NoDanbooru(),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AutocompleteWrapper(
              controller: controller,
              focusNode: focusNode,
              child: TextField(
                autofocus: true,
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(
      find.byKey(const ValueKey('autocomplete-popup-surface')),
      findsNothing,
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(
      find.byKey(const ValueKey('autocomplete-popup-surface')),
      findsNothing,
    );

    await _typeCurrentText(tester, controller);
    expect(
      find.byKey(const ValueKey('autocomplete-popup-surface')),
      findsOneWidget,
    );

    controller.selection = const TextSelection.collapsed(offset: 1);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('autocomplete-popup-surface')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(
      find.byKey(const ValueKey('autocomplete-popup-surface')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens normal autocomplete on tag click when enabled', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'blu');
    controller.selection = const TextSelection.collapsed(offset: 3);
    final focusNode = FocusNode();
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autocompleteSettingsProvider.overrideWith(
            (ref) => _OpenOnTagClickSettingsNotifier(),
          ),
          autocompleteServicesProvider.overrideWithValue(
            AutocompleteServices(
              localSources: [_BaseSource()],
              dictionaryTranslations: const _NoTranslations(),
              llmTranslations: const _NoTranslations(),
              danbooru: _NoDanbooru(),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AutocompleteWrapper(
              controller: controller,
              focusNode: focusNode,
              child: TextField(controller: controller, focusNode: focusNode),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(find.text('Tag autocomplete'), findsOneWidget);
    expect(find.text('blue_eyes'), findsOneWidget);
    expect(find.text('Related tags'), findsNothing);
  });

  testWidgets(
    'selection callback receives full text and normal completion opens related tags',
    (tester) async {
      final controller = TextEditingController(text: 'masterpiece, blu');
      controller.selection = const TextSelection.collapsed(offset: 16);
      final focusNode = FocusNode();
      final source = _RecordingBaseSource();
      String? selectedText;
      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            autocompleteServicesProvider.overrideWithValue(
              AutocompleteServices(
                localSources: [source],
                dictionaryTranslations: const _NoTranslations(),
                llmTranslations: const _NoTranslations(),
                danbooru: _NoDanbooru(),
              ),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AutocompleteWrapper(
                controller: controller,
                focusNode: focusNode,
                config: const AutocompleteConfig(autoInsertComma: false),
                onSuggestionSelected: (value) => selectedText = value,
                child: TextField(controller: controller, focusNode: focusNode),
              ),
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();
      await _typeCurrentText(tester, controller);
      expect(source.tokens.last, 'blu');
      final queryCountBeforeSelection = source.tokens.length;

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(controller.text, 'masterpiece, blue_eyes');
      expect(selectedText, controller.text);
      expect(source.tokens, hasLength(queryCountBeforeSelection + 2));
      expect(source.relatedTags.last, 'blue_eyes');
      expect(find.text('Related tags'), findsOneWidget);
      expect(find.text('halo'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(controller.text, 'masterpiece, blue_eyes, halo');
      expect(source.relatedTags.last, 'halo');
      expect(find.text('Related tags'), findsOneWidget);
      expect(find.text('smile'), findsOneWidget);
    },
  );

  testWidgets('global insertion and translation settings remain effective', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'blu');
    controller.selection = const TextSelection.collapsed(offset: 3);
    final focusNode = FocusNode();
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autocompleteSettingsProvider.overrideWith(
            (ref) => _FixedAutocompleteSettingsNotifier(),
          ),
          autocompleteServicesProvider.overrideWithValue(
            AutocompleteServices(
              localSources: [_TranslatedBaseSource()],
              dictionaryTranslations: const _NoTranslations(),
              llmTranslations: const _NoTranslations(),
              danbooru: _NoDanbooru(),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AutocompleteWrapper(
              controller: controller,
              focusNode: focusNode,
              config: const AutocompleteConfig(
                showTranslation: true,
                autoInsertComma: true,
                replaceUnderscoreWithSpace: false,
              ),
              child: TextField(controller: controller, focusNode: focusNode),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await _typeCurrentText(tester, controller);

    expect(find.text('蓝眼睛'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.text, 'blue eyes');
  });

  testWidgets('does not query while an IME composition is active', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final source = _RecordingBaseSource();
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autocompleteSettingsProvider.overrideWith(
            (ref) => _FixedAutocompleteSettingsNotifier(),
          ),
          autocompleteServicesProvider.overrideWithValue(
            AutocompleteServices(
              localSources: [source],
              dictionaryTranslations: const _NoTranslations(),
              llmTranslations: const _NoTranslations(),
              danbooru: _NoDanbooru(),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AutocompleteWrapper(
              controller: controller,
              focusNode: focusNode,
              child: TextField(controller: controller, focusNode: focusNode),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    controller.value = const TextEditingValue(
      text: '蓝',
      selection: TextSelection.collapsed(offset: 1),
      composing: TextRange(start: 0, end: 1),
    );
    await tester.pump(const Duration(milliseconds: 30));
    expect(source.tokens, isEmpty);

    controller.value = const TextEditingValue(
      text: '蓝',
      selection: TextSelection.collapsed(offset: 1),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(source.tokens, ['蓝']);
  });

  testWidgets('escape closes the popup while results are loading', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'blu');
    controller.selection = const TextSelection.collapsed(offset: 3);
    final focusNode = FocusNode();
    final source = _PendingSource();
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autocompleteServicesProvider.overrideWithValue(
            AutocompleteServices(
              localSources: [source],
              dictionaryTranslations: const _NoTranslations(),
              llmTranslations: const _NoTranslations(),
              danbooru: _NoDanbooru(),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AutocompleteWrapper(
              controller: controller,
              focusNode: focusNode,
              child: TextField(controller: controller, focusNode: focusNode),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await _typeCurrentText(tester, controller);

    expect(
      find.byKey(const ValueKey('autocomplete-popup-surface')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('autocomplete-popup-surface')),
      findsNothing,
    );

    source.complete();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('autocomplete-popup-surface')),
      findsNothing,
    );
  });

  testWidgets('keyboard repeat navigates candidates without repeated insert', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'tag');
    controller.selection = const TextSelection.collapsed(offset: 3);
    final focusNode = FocusNode();
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autocompleteServicesProvider.overrideWithValue(
            AutocompleteServices(
              localSources: [_ManyBaseSource()],
              dictionaryTranslations: const _NoTranslations(),
              llmTranslations: const _NoTranslations(),
              danbooru: _NoDanbooru(),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AutocompleteWrapper(
              controller: controller,
              focusNode: focusNode,
              child: TextField(controller: controller, focusNode: focusNode),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await _typeCurrentText(tester, controller);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.text, 'tag_02, ');
  });

  testWidgets('positions multiline suggestions beside the caret line', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'first line\nblu');
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    final focusNode = FocusNode();
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autocompleteServicesProvider.overrideWithValue(
            AutocompleteServices(
              localSources: [_BaseSource()],
              dictionaryTranslations: const _NoTranslations(),
              llmTranslations: const _NoTranslations(),
              danbooru: _NoDanbooru(),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 480,
                child: AutocompleteWrapper(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: null,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 6,
                    maxLines: null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await _typeCurrentText(tester, controller);

    final inputRect = tester.getRect(find.byType(TextField));
    final popupRect = tester.getRect(
      find.byKey(const ValueKey('autocomplete-popup-surface')),
    );
    expect(popupRect.top, lessThan(inputRect.bottom));
    expect(popupRect.top, greaterThan(inputRect.top));

    const updatedText = 'one\ntwo\nthree\nfour\nfive\nsix\nseven\nblu';
    controller.value = const TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: updatedText.length),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(
      find.byKey(const ValueKey('autocomplete-popup-surface')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard navigation scrolls only at the viewport edge', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'tag');
    controller.selection = const TextSelection.collapsed(offset: 3);
    final focusNode = FocusNode();
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autocompleteServicesProvider.overrideWithValue(
            AutocompleteServices(
              localSources: [_ManyBaseSource()],
              dictionaryTranslations: const _NoTranslations(),
              llmTranslations: const _NoTranslations(),
              danbooru: _NoDanbooru(),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AutocompleteWrapper(
              controller: controller,
              focusNode: focusNode,
              child: TextField(controller: controller, focusNode: focusNode),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await _typeCurrentText(tester, controller);

    final listView = tester.widget<ListView>(find.byType(ListView));
    final scrollController = listView.controller!;
    final popup = find.byKey(const ValueKey('autocomplete-popup-surface'));
    final initialPopupRect = tester.getRect(popup);
    expect(scrollController.offset, 0);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('autocomplete-candidate-tag_00')),
        matching: find.byType(AnimatedContainer),
      ),
      findsNothing,
      reason: 'keyboard selection must not start a per-row implicit animation',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(scrollController.offset, 0);
    expect(tester.getRect(popup), initialPopupRect);

    for (var i = 0; i < 10; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.pumpAndSettle();

    expect(tester.getRect(popup), initialPopupRect);
    expect(scrollController.offset, greaterThan(0));
    expect(
      scrollController.offset,
      lessThan(12 * 35),
      reason: 'the selected row must not be aligned to the top edge',
    );
  });

  testWidgets('Ctrl-click keeps related intent until mouse up', (tester) async {
    final controller = TextEditingController(text: 'solo_focus');
    controller.selection = const TextSelection.collapsed(offset: 10);
    final focusNode = FocusNode();
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autocompleteSettingsProvider.overrideWith(
            (ref) => _OpenOnTagClickSettingsNotifier(),
          ),
          autocompleteServicesProvider.overrideWithValue(
            AutocompleteServices(
              localSources: [_NormalAndRelatedSource()],
              dictionaryTranslations: const _NoTranslations(),
              llmTranslations: const _NoTranslations(),
              danbooru: _NoDanbooru(),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AutocompleteWrapper(
              controller: controller,
              focusNode: focusNode,
              child: TextField(controller: controller, focusNode: focusNode),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await _typeCurrentText(tester, controller);
    expect(find.text('Tag autocomplete'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    expect(HardwareKeyboard.instance.isControlPressed, isTrue);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(
      location: tester.getCenter(find.byType(TextField)),
    );
    await gesture.down(tester.getCenter(find.byType(TextField)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();

    expect(find.text('Related tags'), findsOneWidget);
    expect(find.text('halo'), findsOneWidget);
  });

  testWidgets(
    'opens, pins, and continuously inserts related tags by keyboard',
    (tester) async {
      final controller = TextEditingController(text: 'blue_archive');
      controller.selection = const TextSelection.collapsed(offset: 5);
      final focusNode = FocusNode();
      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            autocompleteServicesProvider.overrideWithValue(
              AutocompleteServices(
                localSources: [_RelatedSource()],
                dictionaryTranslations: const _NoTranslations(),
                llmTranslations: const _NoTranslations(),
                danbooru: _NoDanbooru(),
              ),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AutocompleteWrapper(
                controller: controller,
                focusNode: focusNode,
                child: TextField(controller: controller, focusNode: focusNode),
              ),
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.text('Related tags'), findsOneWidget);
      expect(find.text('halo'), findsOneWidget);
      expect(find.text('smile'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('autocomplete-popup-related-pin')),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(controller.text, 'blue_archive, halo, ');
      expect(find.text('smile'), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(controller.text, 'blue_archive, halo, smile, ');
      expect(find.text('No related tags are available'), findsOneWidget);
    },
  );

  testWidgets('typing < shows library entries instead of tag completion', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final baseSource = _BaseSource();
    final librarySource = _LibrarySource();
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autocompleteServicesProvider.overrideWithValue(
            AutocompleteServices(
              localSources: [baseSource],
              dictionaryTranslations: const _NoTranslations(),
              llmTranslations: const _NoTranslations(),
              danbooru: _NoDanbooru(),
              libraryAliases: librarySource,
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AutocompleteWrapper(
              controller: controller,
              focusNode: focusNode,
              child: TextField(controller: controller, focusNode: focusNode),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    controller.value = const TextEditingValue(
      text: '<',
      selection: TextSelection.collapsed(offset: 1),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(baseSource.lastLimit, isNull);
    expect(librarySource.queries, ['']);
    expect(find.text('角色立绘'), findsOneWidget);
    expect(find.text('常用角色提示词'), findsOneWidget);
    expect(find.text('LIB'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.text, '<角色立绘>, ');
    expect(controller.selection.extentOffset, controller.text.length);
  });

  testWidgets('settings button receives hover and opens data settings', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'blu');
    controller.selection = const TextSelection.collapsed(offset: 3);
    final focusNode = FocusNode();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: SizedBox(
                width: 480,
                child: AutocompleteWrapper(
                  controller: controller,
                  focusNode: focusNode,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                  ),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => Scaffold(
            body: Text("settings:${state.uri.queryParameters['section']}"),
          ),
        ),
      ],
    );
    addTearDown(() {
      router.dispose();
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autocompleteServicesProvider.overrideWithValue(
            AutocompleteServices(
              localSources: [_BaseSource()],
              dictionaryTranslations: const _NoTranslations(),
              llmTranslations: const _NoTranslations(),
              danbooru: _NoDanbooru(),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await _typeCurrentText(tester, controller);

    final inputRect = tester.getRect(find.byType(TextField));
    final popupRect = tester.getRect(
      find.byKey(const ValueKey('autocomplete-popup-surface')),
    );
    expect(popupRect.bottom, lessThanOrEqualTo(inputRect.top - 8));
    expect(popupRect.width, lessThanOrEqualTo(800 * 0.62));

    final settingsButton = find.byKey(
      const ValueKey('autocomplete-popup-settings'),
    );
    expect(settingsButton, findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(settingsButton));
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      find.text('Open autocomplete and data source settings'),
      findsOneWidget,
    );

    await mouse.down(tester.getCenter(settingsButton));
    await tester.pump();
    expect(settingsButton, findsOneWidget);
    await mouse.up();
    await tester.pumpAndSettle();

    expect(find.text('settings:storage'), findsOneWidget);
  });
}

class _BaseSource implements CompletionSource {
  int? lastLimit;

  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    lastLimit = query.limit;
    return [
      const CompletionCandidate(
        canonicalTag: 'blue_eyes',
        category: TagCategory.general,
        postCount: 1000,
        matchKind: CompletionMatchKind.englishPrefix,
        sources: {CompletionSourceKind.base},
      ),
    ];
  }
}

class _RecordingBaseSource implements CompletionSource {
  final List<String> tokens = [];
  final List<String> relatedTags = [];

  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    tokens.add(query.token);
    if (query.relatedTag case final relatedTag?) {
      relatedTags.add(relatedTag);
      return [
        CompletionCandidate(
          canonicalTag: relatedTag == 'blue_eyes' ? 'halo' : 'smile',
          category: TagCategory.general,
          postCount: 250000,
          matchKind: CompletionMatchKind.related,
          sources: const {CompletionSourceKind.cooccurrence},
          relatedScore: 0.77,
          cooccurrenceCount: 220000,
        ),
      ];
    }
    return [
      CompletionCandidate(
        canonicalTag: query.token == '蓝' ? '蓝色眼睛' : 'blue_eyes',
        category: TagCategory.general,
        postCount: 1000,
        matchKind: CompletionMatchKind.englishPrefix,
        sources: const {CompletionSourceKind.base},
      ),
    ];
  }
}

class _PendingSource implements CompletionSource {
  final Completer<List<CompletionCandidate>> _completer = Completer();

  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) =>
      _completer.future;

  void complete() => _completer.complete(const []);
}

class _TranslatedBaseSource implements CompletionSource {
  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    return const [
      CompletionCandidate(
        canonicalTag: 'blue_eyes',
        category: TagCategory.general,
        postCount: 1000,
        translation: '蓝眼睛',
        matchKind: CompletionMatchKind.englishPrefix,
        sources: {CompletionSourceKind.base},
      ),
    ];
  }
}

class _ManyBaseSource implements CompletionSource {
  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    return List.generate(
      30,
      (index) => CompletionCandidate(
        canonicalTag: 'tag_${index.toString().padLeft(2, '0')}',
        category: TagCategory.general,
        postCount: 1000,
        matchKind: CompletionMatchKind.englishPrefix,
        sources: const {CompletionSourceKind.base},
      ),
    );
  }
}

class _LibrarySource implements CompletionSource {
  final List<String> queries = [];

  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    expect(query.kind, CompletionQueryKind.libraryAlias);
    queries.add(query.token);
    return const [
      CompletionCandidate(
        canonicalTag: '角色立绘',
        category: TagCategory.library,
        postCount: 7,
        translation: '常用角色提示词',
        matchKind: CompletionMatchKind.fullText,
        sources: {CompletionSourceKind.library},
      ),
    ];
  }
}

class _NormalAndRelatedSource implements CompletionSource {
  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    if (query.relatedTag != null) {
      return const [
        CompletionCandidate(
          canonicalTag: 'halo',
          category: TagCategory.general,
          postCount: 250000,
          matchKind: CompletionMatchKind.related,
          sources: {CompletionSourceKind.cooccurrence},
          relatedScore: 0.77,
          cooccurrenceCount: 220000,
        ),
      ];
    }
    return const [
      CompletionCandidate(
        canonicalTag: 'solo_focus',
        category: TagCategory.general,
        postCount: 497667,
        matchKind: CompletionMatchKind.englishExact,
        sources: {CompletionSourceKind.base},
      ),
    ];
  }
}

class _RelatedSource implements CompletionSource {
  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    if (query.relatedTag == null) return const [];
    return const [
          CompletionCandidate(
            canonicalTag: 'halo',
            category: TagCategory.general,
            postCount: 250000,
            matchKind: CompletionMatchKind.related,
            sources: {CompletionSourceKind.cooccurrence},
            relatedScore: 0.77,
            cooccurrenceCount: 220000,
          ),
          CompletionCandidate(
            canonicalTag: 'smile',
            category: TagCategory.general,
            postCount: 200000,
            matchKind: CompletionMatchKind.related,
            sources: {CompletionSourceKind.cooccurrence},
            relatedScore: 0.6,
            cooccurrenceCount: 180000,
          ),
        ]
        .where(
          (candidate) => !query.existingTags.contains(candidate.canonicalTag),
        )
        .toList();
  }
}

class _OpenOnTagClickSettingsNotifier extends AutocompleteSettingsNotifier {
  _OpenOnTagClickSettingsNotifier() : super(LocalStorageService()) {
    state = const AutocompleteSettings(
      openOnTagClick: true,
      danbooruEnabled: false,
      zhInstallPromptDismissed: true,
    );
  }
}

class _FixedAutocompleteSettingsNotifier extends AutocompleteSettingsNotifier {
  _FixedAutocompleteSettingsNotifier() : super(LocalStorageService()) {
    state = const AutocompleteSettings(
      showTranslations: false,
      autoInsertComma: false,
      replaceUnderscores: true,
      danbooruEnabled: false,
      zhInstallPromptDismissed: true,
    );
  }
}

class _NoTranslations implements TranslationResolver {
  const _NoTranslations();

  @override
  Future<Map<String, String>> resolve(
    List<String> canonicalTags, {
    required String locale,
  }) async => const {};
}

class _NoDanbooru extends DanbooruCompletionSource {
  _NoDanbooru() : super(cache: _MemoryCache());

  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async =>
      const [];

  @override
  Future<List<CompletionCandidate>> relatedTags(
    String tag, {
    int limit = 20,
  }) async => const [];
}

class _MemoryCache extends AutocompleteCacheDatabase {
  @override
  Future<CachedAutocompletePayload?> getRemote(String key) async => null;

  @override
  Future<void> putRemote(
    String key,
    List<Map<String, dynamic>> payload,
  ) async {}
}
