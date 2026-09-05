import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_providers.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:nai_launcher/core/autocomplete/zh_dictionary_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_capsule.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_mode_prompt_field.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_view.dart';

Future<void> pumpEditor(
  WidgetTester tester,
  TextEditingController source, {
  Locale locale = const Locale('zh'),
  double width = 600,
  double scale = 1,
  double height = 800,
  EdgeInsets insets = EdgeInsets.zero,
  TagTranslationLookup? lookup,
  bool enabled = true,
  InteractionPolicy policy = InteractionPolicy.touchFirst,
  ZhDictionaryService? dictionary,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      zhDictionaryServiceProvider.overrideWith(
        (ref) => dictionary ?? _Dictionary(),
      ),
      tagTranslationLookupProvider.overrideWithValue(
        lookup ??
            TagTranslationLookup.fromResolver(
              (tags) async => {
                for (final tag in tags)
                  tag: switch (tag) {
                    'cat' => '猫',
                    'dog' => '狗',
                    _ => '译文 $tag',
                  },
              },
            ),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          viewInsets: insets,
          padding: const EdgeInsets.only(top: 24, bottom: 20),
          disableAnimations: true,
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: 400,
              child: InteractionPolicyScope(
                initialPolicy: policy,
                child: TagModePromptField(
                  controller: source,
                  enabled: enabled,
                  enableAutocomplete: false,
                  child: ThemedInput(
                    controller: source,
                    maxLines: null,
                    expands: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('editing hides translation and preserves the capsule footprint', (
    tester,
  ) async {
    final source = TextEditingController(text: 'cat, dog');
    addTearDown(source.dispose);
    await pumpEditor(tester, source);
    await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
    await tester.pumpAndSettle();
    final capsule = find.byType(TagEditorCapsule).first;
    final before = tester.getSize(capsule);
    expect(
      find.descendant(of: capsule, matching: find.text('猫')),
      findsOneWidget,
    );
    await tester.tap(find.text('cat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cat'));
    await tester.pumpAndSettle();
    expect(tester.getSize(capsule), before);
    expect(
      find.descendant(of: capsule, matching: find.text('猫')),
      findsNothing,
    );
    final field = find.byKey(const ValueKey('tag-input-0'));
    expect(tester.getSize(field).height, closeTo(before.height - 16, 1));
    await tester.enterText(field, 'longer_tag_name');
    await tester.pumpAndSettle();
    expect(tester.getSize(capsule), before);
    expect(source.text, 'longer_tag_name, dog');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: capsule, matching: find.byType(TextField)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('add button follows the final tag and opens only on demand', (
    tester,
  ) async {
    final source = TextEditingController(text: 'cat, dog');
    addTearDown(source.dispose);
    await pumpEditor(tester, source, locale: const Locale('en'));
    await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
    await tester.pumpAndSettle();
    final add = find.byKey(const ValueKey('tag-add-button'));
    final field = find.byKey(const ValueKey('tag-add-input'));
    final lastTag = find.byType(TagEditorCapsule).last;
    expect(field, findsNothing);
    expect(
      tester.getRect(add).left,
      greaterThan(tester.getRect(lastTag).right),
    );
    expect(tester.getCenter(add).dy, closeTo(tester.getCenter(lastTag).dy, 1));
    expect(tester.getSize(add).height, greaterThanOrEqualTo(44));
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(field, findsOneWidget);
    expect(add, findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(add, findsOneWidget);
    expect(field, findsNothing);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(add, findsOneWidget);
    expect(source.text, 'cat, dog');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'becoming read-only disables weight and drag but still permits leaving tag mode',
    (tester) async {
      final source = TextEditingController(text: 'cat, dog');
      addTearDown(source.dispose);
      await pumpEditor(tester, source, locale: const Locale('en'));
      await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('cat'));
      await tester.pumpAndSettle();
      await pumpEditor(
        tester,
        source,
        locale: const Locale('en'),
        enabled: false,
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.drag_indicator), findsNothing);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('prompt-weight-value')),
            )
            .enabled,
        isFalse,
      );
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(find.text('cat')),
          scrollDelta: const Offset(0, -20),
        ),
      );
      expect(source.text, 'cat, dog');
      await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
      await tester.pumpAndSettle();
      expect(find.byType(TagEditorCapsule), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'dragging from desktop blank space selects intersecting capsules',
    (tester) async {
      final source = TextEditingController(text: 'cat, dog, bird');
      addTearDown(source.dispose);
      await pumpEditor(
        tester,
        source,
        locale: const Locale('en'),
        policy: const InteractionPolicy(
          modality: InteractionModality.pointer,
          touchAvailable: false,
          precisePointerAvailable: true,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
      await tester.pumpAndSettle();
      final area = tester.getRect(find.byType(TagEditorView));
      final cat = tester.getRect(
        find.descendant(
          of: find.byType(TagEditorCapsule).first,
          matching: find.text('cat'),
        ),
      );
      final drag = await tester.startGesture(
        Offset(area.right - 16, cat.bottom + 10),
        kind: PointerDeviceKind.mouse,
      );
      await drag.moveTo(Offset(cat.left - 5, cat.top - 5));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<TagEditorCapsule>(find.byType(TagEditorCapsule))
            .where((w) => w.selected),
        hasLength(3),
      );
      expect(source.text, 'cat, dog, bird');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Traditional Chinese uses the same translations and language changes stop queries',
    (tester) async {
      final source = TextEditingController(text: 'cat');
      addTearDown(source.dispose);
      var calls = 0;
      final lookup = TagTranslationLookup.fromResolver((tags) async {
        calls++;
        return {for (final tag in tags) tag: tag == 'cat' ? '猫' : '狗'};
      });
      await pumpEditor(
        tester,
        source,
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
        ),
        lookup: lookup,
      );
      await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
      await tester.pumpAndSettle();
      expect(find.text('猫'), findsOneWidget);
      final before = calls;
      await pumpEditor(
        tester,
        source,
        locale: const Locale('en'),
        lookup: lookup,
      );
      source.text = 'dog';
      await tester.pumpAndSettle();
      expect(find.text('猫'), findsNothing);
      expect(find.text('狗'), findsNothing);
      expect(calls, before);
      await pumpEditor(tester, source, lookup: lookup);
      await tester.pumpAndSettle();
      expect(find.text('狗'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'missing dictionary gives one settings hint while editing remains available',
    (tester) async {
      final source = TextEditingController(text: 'unknown');
      final dictionary = _MissingDictionary();
      addTearDown(source.dispose);
      await pumpEditor(
        tester,
        source,
        dictionary: dictionary,
        lookup: TagTranslationLookup.fromResolver((_) async => {}),
      );
      await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(dictionary.initializations, 1);
      source.text = 'another';
      await tester.pumpAndSettle();
      expect(dictionary.initializations, 1);
      expect(find.byType(TagEditorCapsule), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'whole-tag long press previews a drop and keeps multi-selection',
    (tester) async {
      final source = TextEditingController(text: 'cat, dog, bird');
      addTearDown(source.dispose);
      await pumpEditor(tester, source, locale: const Locale('en'));
      await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('dog'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.drag_indicator), findsNothing);
      final drag = await tester.startGesture(
        tester.getCenter(find.text('dog')),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('tag-drag-feedback')), findsOneWidget);
      await drag.moveTo(tester.getCenter(find.text('cat')));
      await tester.pumpAndSettle();
      expect(source.text, 'cat, dog, bird');
      expect(find.byKey(const ValueKey('tag-drop-indicator')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tag-drag-placeholder')),
        findsOneWidget,
      );
      await drag.moveTo(
        tester.getCenter(find.byKey(const ValueKey('tag-drag-placeholder'))),
      );
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tag-drag-placeholder')), findsNothing);
      expect(find.byKey(const ValueKey('tag-drag-feedback')), findsNothing);
      expect(source.text, 'dog, cat, bird');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('bird'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      final secondary = await tester.startGesture(
        tester.getCenter(find.text('cat')),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await secondary.up();
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<TagEditorCapsule>(find.byType(TagEditorCapsule))
            .where((w) => w.selected),
        hasLength(3),
      );
      expect(find.text('Weight'), findsOneWidget);
      await tester.tap(find.text('Disable'));
      await tester.pumpAndSettle();
      expect(
        source.text,
        '/*disabled:dog*/, /*disabled:cat*/, /*disabled:bird*/',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('multi-tag drag previews the end slot and undo restores source', (
    tester,
  ) async {
    final source = TextEditingController(text: 'cat, dog, bird');
    addTearDown(source.dispose);
    await pumpEditor(tester, source, locale: const Locale('en'));
    await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cat'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('dog'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    final drag = await tester.startGesture(
      tester.getCenter(find.text('cat')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 400));
    await drag.moveTo(
      tester.getCenter(find.byKey(const ValueKey('tag-add-button'))),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tag-drop-indicator')), findsOneWidget);
    expect(find.text('+1'), findsWidgets);
    expect(source.text, 'cat, dog, bird');
    await drag.moveTo(
      tester.getCenter(find.byKey(const ValueKey('tag-drag-placeholder'))),
    );
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    expect(source.text, 'bird, cat, dog');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(source.text, 'cat, dog, bird');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'cancelling a narrow-screen long press drag removes only the preview',
    (tester) async {
      final source = TextEditingController(text: 'cat, dog, bird');
      addTearDown(source.dispose);
      await pumpEditor(
        tester,
        source,
        width: 320,
        scale: 3,
        locale: const Locale('en'),
      );
      await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
      await tester.pumpAndSettle();
      final drag = await tester.startGesture(
        tester.getCenter(find.text('dog')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await drag.moveTo(tester.getCenter(find.text('cat')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('tag-drag-placeholder')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await drag.moveTo(const Offset(2, 2));
      await drag.cancel();
      await tester.pumpAndSettle();
      expect(source.text, 'cat, dog, bird');
      expect(find.byKey(const ValueKey('tag-drag-placeholder')), findsNothing);
      expect(find.byKey(const ValueKey('tag-drag-feedback')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('external source replacement invalidates a pending drop', (
    tester,
  ) async {
    final source = TextEditingController(text: 'cat, dog, bird');
    addTearDown(source.dispose);
    await pumpEditor(tester, source, locale: const Locale('en'));
    await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
    await tester.pumpAndSettle();
    final drag = await tester.startGesture(
      tester.getCenter(find.text('dog')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 400));
    await drag.moveTo(tester.getCenter(find.text('cat')));
    await tester.pumpAndSettle();
    source.text = 'cat, dog, bird, fish';
    await tester.pumpAndSettle();
    await drag.up();
    await tester.pumpAndSettle();
    expect(source.text, 'cat, dog, bird, fish');
    expect(find.byKey(const ValueKey('tag-drag-placeholder')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('new composing text is preserved when leaving tag mode', (
    tester,
  ) async {
    final source = TextEditingController();
    addTearDown(source.dispose);
    await pumpEditor(tester, source);
    await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-add-button')));
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '猫',
        composing: TextRange(start: 0, end: 1),
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    expect(source.text, '猫');
    await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
    await tester.pumpAndSettle();
    expect(source.text, '猫');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('native text undo includes earlier tag transactions', (
    tester,
  ) async {
    final source = TextEditingController(text: 'cat');
    addTearDown(source.dispose);
    await pumpEditor(tester, source, locale: const Locale('en'));
    await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(TagEditorCapsule),
        matching: find.text('cat'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Disable'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ThemedInput));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(source.text, 'cat');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('toolbar fits short landscape with keyboard and SafeArea', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = TextEditingController(text: 'cat, dog');
    addTearDown(source.dispose);
    await pumpEditor(
      tester,
      source,
      width: 600,
      height: 320,
      insets: const EdgeInsets.only(bottom: 100),
      scale: 3,
    );
    await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cat'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final toolbar = tester.getRect(
      find.byKey(const ValueKey('prompt-action-viewport')),
    );
    expect(toolbar.top, greaterThanOrEqualTo(24));
    expect(toolbar.bottom, lessThanOrEqualTo(220));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'mouse multiselect, selected wheel and middle disable preserve originals',
    (tester) async {
      final source = TextEditingController(text: 'cat, dog, bird');
      addTearDown(source.dispose);
      await pumpEditor(tester, source, locale: const Locale('en'));
      await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('cat'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('dog'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<TagEditorCapsule>(find.byType(TagEditorCapsule))
            .where((w) => w.selected),
        hasLength(2),
      );
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(find.text('dog')),
          scrollDelta: const Offset(0, -20),
        ),
      );
      await tester.pumpAndSettle();
      expect(source.text, '1.05::cat::, 1.05::dog::, bird');
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(find.text('bird')),
          scrollDelta: const Offset(0, -20),
        ),
      );
      expect(source.text, '1.05::cat::, 1.05::dog::, bird');
      final pointer = await tester.startGesture(
        tester.getCenter(find.text('bird')),
        kind: PointerDeviceKind.mouse,
        buttons: kMiddleMouseButton,
      );
      await pointer.up();
      await tester.pumpAndSettle();
      expect(source.text, '1.05::cat::, 1.05::dog::, /*disabled:bird*/');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'touch long press selects multiple tags and Back clears selection',
    (tester) async {
      final source = TextEditingController(text: 'cat, dog');
      addTearDown(source.dispose);
      await pumpEditor(tester, source);
      await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('cat'));
      await tester.tap(find.text('dog'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<TagEditorCapsule>(find.byType(TagEditorCapsule))
            .where((w) => w.selected),
        hasLength(2),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<TagEditorCapsule>(find.byType(TagEditorCapsule))
            .where((w) => w.selected),
        isEmpty,
      );
      expect(source.text, 'cat, dog');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'IME comma does not split the composing input or replace its controller',
    (tester) async {
      final source = TextEditingController(text: 'cat, dog');
      addTearDown(source.dispose);
      await pumpEditor(tester, source);
      await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('cat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('cat'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('tag-input-0'));
      final controller = tester.widget<TextField>(field).controller;
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '猫,蓝',
          composing: TextRange(start: 0, end: 3),
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.pumpAndSettle();
      expect(source.text, '猫,蓝, dog');
      expect(tester.widget<TextField>(field).controller, same(controller));
      expect(controller!.value.composing, const TextRange(start: 0, end: 3));
      expect(find.byType(TagEditorCapsule), findsNWidgets(2));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '猫,蓝',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TagEditorCapsule), findsNWidgets(3));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('read-only mode cannot enter the editor', (tester) async {
    final source = TextEditingController(text: 'cat');
    addTearDown(source.dispose);
    await pumpEditor(tester, source, enabled: false);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('tag-mode-button')))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'all translations visible and inline edit updates the source without leaving mode',
    (tester) async {
      final source = TextEditingController(text: 'cat, dog');
      addTearDown(source.dispose);
      await pumpEditor(tester, source);
      await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
      await tester.pumpAndSettle();
      expect(find.text('猫'), findsOneWidget);
      expect(find.text('狗'), findsOneWidget);
      expect(find.byType(TagEditorCapsule), findsNWidgets(2));
      await tester.tap(find.text('cat'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tag-action-toolbar')), findsOneWidget);
      await tester.tap(find.text('cat'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('tag-input-0')), 'bird');
      await tester.pumpAndSettle();
      expect(source.text, 'bird, dog');
      expect(find.text('译文 bird'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('译文 bird'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
      await tester.pumpAndSettle();
      expect(source.text, 'bird, dog');
      expect(find.byType(TagEditorCapsule), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('empty and non-Chinese mode never requires a dictionary query', (
    tester,
  ) async {
    final source = TextEditingController();
    addTearDown(source.dispose);
    var calls = 0;
    await pumpEditor(
      tester,
      source,
      locale: const Locale('en'),
      lookup: TagTranslationLookup.fromResolver((_) async {
        calls++;
        return {};
      }),
    );
    await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-add-button')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('tag-add-input')), 'cat');
    await tester.pumpAndSettle();
    expect(source.text, 'cat');
    expect(calls, 0);
    expect(find.byType(TagEditorCapsule), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'external changes preserve tag mode and discard old translation',
    (tester) async {
      final source = TextEditingController(text: 'cat');
      addTearDown(source.dispose);
      await pumpEditor(tester, source);
      await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
      await tester.pumpAndSettle();
      source.text = 'dog';
      await tester.pumpAndSettle();
      expect(find.text('猫'), findsNothing);
      expect(find.text('狗'), findsOneWidget);
      expect(find.byType(TagEditorCapsule), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'responsive capsules and selected toolbar remain bounded at 3x text',
    (tester) async {
      for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        final source = TextEditingController(
          text: 'cat, very_long_tag_name_that_must_wrap, dog',
        );
        await pumpEditor(tester, source, width: width, scale: 3);
        await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('cat'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'width=$width');
        final toolbar = tester.getRect(
          find.byKey(const ValueKey('tag-action-toolbar')),
        );
        expect(toolbar.left, greaterThanOrEqualTo(0));
        expect(toolbar.right, lessThanOrEqualTo(width));
        await tester.pumpWidget(const SizedBox.shrink());
        source.dispose();
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
}

class _Dictionary extends ZhDictionaryService {
  @override
  ZhDictionaryState get state => const ZhDictionaryState(isInstalled: true);
  @override
  Future<void> initialize() async {}
}

class _MissingDictionary extends ZhDictionaryService {
  int initializations = 0;
  @override
  ZhDictionaryState get state => const ZhDictionaryState(isInstalled: false);
  @override
  Future<void> initialize() async {
    initializations++;
  }
}
