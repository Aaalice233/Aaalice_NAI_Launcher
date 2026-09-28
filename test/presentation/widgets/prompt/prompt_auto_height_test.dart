import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_editor_resize_region.dart';
import 'package:nai_launcher/presentation/widgets/prompt/prompt_tag_mode_toggle.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_view.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_mode_prompt_field.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';

import '../../../helpers/memory_local_storage.dart';

void main() {
  testWidgets('editing a tag grows and shrinks the active content height', (
    tester,
  ) async {
    final source = TextEditingController(text: 'cat');
    final viewport = ScrollController();
    addTearDown(source.dispose);
    addTearDown(viewport.dispose);
    await _pumpEditor(tester, source, viewport, width: 600, scale: 1);
    await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cat'));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('tag-input-0'));
    final field = find.byType(TagModePromptField);
    final before = tester.getSize(field).height;
    await tester.enterText(input, 'long_tag_' * 40);
    await tester.pumpAndSettle();
    expect(tester.getSize(field).height, greaterThan(before));
    expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
    await tester.enterText(input, 'cat');
    await tester.pumpAndSettle();
    expect(tester.getSize(field).height, closeTo(before, .01));
    expect(source.text, 'cat');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'automatic tag height respects a bounded parent and keeps overflow scrollable',
    (tester) async {
      final source = TextEditingController(
        text: List.generate(60, (i) => 'long_tag_$i').join(', '),
      );
      final viewport = ScrollController();
      addTearDown(source.dispose);
      addTearDown(viewport.dispose);
      await _pumpEditor(
        tester,
        source,
        viewport,
        width: 600,
        scale: 1,
        bounded: true,
      );
      await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
      await tester.pumpAndSettle();
      final field = find.byType(TagModePromptField);
      final fullHeight = tester.getSize(field).height;
      expect(fullHeight, lessThanOrEqualTo(210));
      final scroll = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(TagEditorView.scrollViewKey),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      expect(scroll.maxScrollExtent, greaterThan(0));
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pump();
      source.text = 'cat';
      await tester.pumpAndSettle();
      expect(tester.getSize(field).height, lessThan(fullHeight));
      expect(scroll.maxScrollExtent, closeTo(0, .01));
      expect(scroll.pixels, closeTo(0, .01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('active content owns automatic height $width/$scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final source = TextEditingController(
          text: List.filled(8, 'cat').join(',\n\n\n'),
        );
        final original = source.text;
        final viewport = ScrollController();
        addTearDown(source.dispose);
        addTearDown(viewport.dispose);
        double? persistedHeight;
        await _pumpEditor(
          tester,
          source,
          viewport,
          width: width,
          scale: scale,
          onHeightChanged: (height) => persistedHeight = height,
        );
        await tester.pumpAndSettle();
        final field = find.byType(TagModePromptField);
        final textHeight = tester.getSize(field).height;
        final toggle = find.byKey(const ValueKey('tag-mode-button'));
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        final tagHeight = tester.getSize(field).height;
        expect(tagHeight, lessThan(textHeight));
        final tagState = tester.state(find.byType(TagEditorView));
        ScrollPosition tagScroll() => tester
            .state<ScrollableState>(
              find.descendant(
                of: find.byKey(TagEditorView.scrollViewKey),
                matching: find.byType(Scrollable),
              ),
            )
            .position;
        expect(tagScroll().maxScrollExtent, closeTo(0, .01));
        // Raw text layout changes without changing the rendered tag content.
        source.text = List.filled(8, 'cat').join(', ');
        await tester.pumpAndSettle();
        expect(tester.getSize(field).height, closeTo(tagHeight, .01));
        source.text = original;
        await tester.pumpAndSettle();
        final handle = find.byKey(
          const ValueKey('generation-prompt-height-handle'),
        );
        await tester.ensureVisible(handle);
        await tester.drag(
          handle,
          const Offset(0, 180),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(persistedHeight, isNotNull);
        expect(tester.getSize(field).height, greaterThan(tagHeight));
        await tester.ensureVisible(handle);
        await tester.tap(handle, kind: PointerDeviceKind.mouse);
        await tester.pump(const Duration(milliseconds: 70));
        await tester.tap(handle, kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
        expect(persistedHeight, isNull);
        expect(tester.getSize(field).height, closeTo(tagHeight, .01));
        expect(tester.state(find.byType(TagEditorView)), same(tagState));
        expect(tagScroll().maxScrollExtent, closeTo(0, .01));
        source.text = 'cat';
        await tester.pumpAndSettle();
        final shortHeight = tester.getSize(field).height;
        expect(shortHeight, lessThanOrEqualTo(tagHeight));
        source.text = List.generate(40, (i) => 'long_tag_$i').join(', ');
        await tester.pumpAndSettle();
        expect(tester.getSize(field).height, greaterThan(shortHeight));
        expect(tagScroll().maxScrollExtent, closeTo(0, .01));
        source.text = original;
        await tester.pumpAndSettle();
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.getSize(field).height, closeTo(textHeight, .01));
        expect(source.text, original);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

Future<void> _pumpEditor(
  WidgetTester tester,
  TextEditingController source,
  ScrollController viewport, {
  required double width,
  required double scale,
  ValueChanged<double?>? onHeightChanged,
  bool bounded = false,
}) {
  final editor = PromptEditorResizeRegion(
    enabled: true,
    onHeightChanged: onHeightChanged,
    builder: (manual) => UnifiedPromptInput(
      sessionId: 'auto-height',
      controller: source,
      enableAssistant: false,
      showTagModeSwitch: false,
      fitContent: !manual,
      expands: manual,
      minLines: manual ? null : 4,
      config: const UnifiedPromptConfig(
        enableTagMode: true,
        enableAutocomplete: false,
        enableAutoFormat: false,
        enableSyntaxHighlight: false,
      ),
    ),
  );
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWith((ref) => MemoryLocalStorage()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1400),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: Column(
              children: [
                const PromptTagModeToggle(sessionId: 'auto-height'),
                if (bounded)
                  SizedBox(height: 210, child: editor)
                else
                  Expanded(
                    child: SingleChildScrollView(
                      controller: viewport,
                      child: editor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
