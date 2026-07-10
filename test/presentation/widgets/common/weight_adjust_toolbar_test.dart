import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import 'package:nai_launcher/presentation/widgets/common/weight_adjust_toolbar.dart';

const _fieldKey = ValueKey('weight_test_prompt');

Future<void> _sendWheel(
  WidgetTester tester, {
  Offset delta = const Offset(0, 40),
  RespondPointerEventCallback? onRespond,
}) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse)
    ..hover(tester.getCenter(find.byKey(_fieldKey)));
  await tester.sendEventToBinding(pointer.scroll(delta, onRespond: onRespond));
}

void _registerCleanup(
  WidgetTester tester,
  TextEditingController prompt,
  FocusNode focus,
  ScrollController page,
) {
  addTearDown(() async {
    if (prompt.selection.isValid) {
      prompt.selection = TextSelection.collapsed(offset: prompt.text.length);
    }
    focus.unfocus();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));
    page.dispose();
    focus.dispose();
    prompt.dispose();
  });
}

void main() {
  testWidgets('selected prompt adjusts weight without scrolling the page', (
    tester,
  ) async {
    final prompt = TextEditingController(text: 'cat, dog');
    final focus = FocusNode();
    final page = ScrollController(initialScrollOffset: 100);
    _registerCleanup(tester, prompt, focus, page);

    await _pumpHarness(
      tester,
      prompt: prompt,
      focus: focus,
      page: page,
      enableWheelAdjustment: true,
    );
    focus.requestFocus();
    prompt.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    await tester.pump();
    final pageOffsetBefore = page.offset;
    bool? platformDefaultAllowed;

    await _sendWheel(
      tester,
      onRespond: ({required bool allowPlatformDefault}) {
        platformDefaultAllowed = allowPlatformDefault;
      },
    );

    expect(prompt.text, '0.95::cat::, dog');
    expect(page.offset, pageOffsetBefore);
    expect(platformDefaultAllowed, isFalse);
  });

  testWidgets('disabled wheel adjustment leaves page scrolling available', (
    tester,
  ) async {
    final prompt = TextEditingController(text: 'cat, dog');
    final focus = FocusNode();
    final page = ScrollController(initialScrollOffset: 100);
    _registerCleanup(tester, prompt, focus, page);

    await _pumpHarness(
      tester,
      prompt: prompt,
      focus: focus,
      page: page,
      enableWheelAdjustment: false,
    );
    focus.requestFocus();
    prompt.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    await tester.pump();
    final pageOffsetBefore = page.offset;

    await _sendWheel(tester);

    expect(prompt.text, 'cat, dog');
    expect(page.offset, greaterThan(pageOffsetBefore));
  });

  testWidgets('wheel without a selection leaves page scrolling available', (
    tester,
  ) async {
    final prompt = TextEditingController(text: 'cat, dog');
    final focus = FocusNode();
    final page = ScrollController(initialScrollOffset: 100);
    _registerCleanup(tester, prompt, focus, page);

    await _pumpHarness(
      tester,
      prompt: prompt,
      focus: focus,
      page: page,
      enableWheelAdjustment: true,
    );
    prompt.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();
    final pageOffsetBefore = page.offset;

    await _sendWheel(tester);

    expect(prompt.text, 'cat, dog');
    expect(page.offset, greaterThan(pageOffsetBefore));
  });

  testWidgets('selected prompt does not scroll its internal text viewport', (
    tester,
  ) async {
    final prompt = TextEditingController(
      text: List<String>.filled(40, 'tag').join('\n'),
    );
    final focus = FocusNode();
    final page = ScrollController(initialScrollOffset: 100);
    _registerCleanup(tester, prompt, focus, page);

    await _pumpHarness(
      tester,
      prompt: prompt,
      focus: focus,
      page: page,
      enableWheelAdjustment: true,
      scrollPhysics: WeightAdjustScrollPhysics(controller: prompt),
    );
    focus.requestFocus();
    prompt.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    await tester.pump();

    final innerFinder = find.descendant(
      of: find.byKey(_fieldKey),
      matching: find.byType(Scrollable),
    );
    expect(innerFinder, findsOneWidget);
    final inner = tester.state<ScrollableState>(innerFinder);
    final innerOffsetBefore = inner.position.pixels;
    final pageOffsetBefore = page.offset;

    await _sendWheel(tester);

    expect(prompt.text, startsWith('0.95::tag::\n'));
    expect(inner.position.pixels, innerOffsetBefore);
    expect(page.offset, pageOffsetBefore);
  });

  testWidgets('disabling on a mounted field restores internal scrolling', (
    tester,
  ) async {
    final original = List<String>.filled(40, 'tag').join('\n');
    final prompt = TextEditingController(text: original);
    final focus = FocusNode();
    final page = ScrollController(initialScrollOffset: 100);
    _registerCleanup(tester, prompt, focus, page);

    await _pumpHarness(
      tester,
      prompt: prompt,
      focus: focus,
      page: page,
      enableWheelAdjustment: true,
      scrollPhysics: WeightAdjustScrollPhysics(controller: prompt),
    );
    focus.requestFocus();
    prompt.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    await tester.pump();

    await _pumpHarness(
      tester,
      prompt: prompt,
      focus: focus,
      page: page,
      enableWheelAdjustment: false,
      scrollPhysics: null,
    );
    await tester.pump();

    final innerFinder = find.descendant(
      of: find.byKey(_fieldKey),
      matching: find.byType(Scrollable),
    );
    final inner = tester.state<ScrollableState>(innerFinder);
    final innerOffsetBefore = inner.position.pixels;

    await _sendWheel(tester);

    expect(prompt.text, original);
    expect(inner.position.pixels, greaterThan(innerOffsetBefore));
  });

  testWidgets('enabling on a mounted field installs exclusive physics', (
    tester,
  ) async {
    final prompt = TextEditingController(
      text: List<String>.filled(40, 'tag').join('\n'),
    );
    final focus = FocusNode();
    final page = ScrollController(initialScrollOffset: 100);
    _registerCleanup(tester, prompt, focus, page);

    await _pumpHarness(
      tester,
      prompt: prompt,
      focus: focus,
      page: page,
      enableWheelAdjustment: false,
      scrollPhysics: null,
    );
    focus.requestFocus();
    prompt.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    await tester.pump();

    await _pumpHarness(
      tester,
      prompt: prompt,
      focus: focus,
      page: page,
      enableWheelAdjustment: true,
      scrollPhysics: WeightAdjustScrollPhysics(controller: prompt),
    );
    await tester.pump();

    final innerFinder = find.descendant(
      of: find.byKey(_fieldKey),
      matching: find.byType(Scrollable),
    );
    final inner = tester.state<ScrollableState>(innerFinder);
    final innerOffsetBefore = inner.position.pixels;
    final pageOffsetBefore = page.offset;

    await _sendWheel(tester);

    expect(prompt.text, startsWith('0.95::tag::\n'));
    expect(inner.position.pixels, innerOffsetBefore);
    expect(page.offset, pageOffsetBefore);
  });

  test('exclusive prompt physics is desktop-only', () {
    expect(supportsPromptWeightScrollPhysics(TargetPlatform.windows), isTrue);
    expect(supportsPromptWeightScrollPhysics(TargetPlatform.macOS), isTrue);
    expect(supportsPromptWeightScrollPhysics(TargetPlatform.linux), isTrue);
    expect(supportsPromptWeightScrollPhysics(TargetPlatform.android), isFalse);
    expect(supportsPromptWeightScrollPhysics(TargetPlatform.iOS), isFalse);
    expect(supportsPromptWeightScrollPhysics(TargetPlatform.fuchsia), isFalse);
  });

  testWidgets('floating toolbar wheel obeys the wheel setting', (tester) async {
    final prompt = TextEditingController(text: 'cat');
    final focus = FocusNode();
    final page = ScrollController(initialScrollOffset: 100);
    _registerCleanup(tester, prompt, focus, page);

    await _pumpHarness(
      tester,
      prompt: prompt,
      focus: focus,
      page: page,
      enableWheelAdjustment: true,
    );
    focus.requestFocus();
    prompt.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(2));

    await _pumpHarness(
      tester,
      prompt: prompt,
      focus: focus,
      page: page,
      enableWheelAdjustment: false,
    );
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(2));

    final weightField = find.byType(TextField).last;
    final pointer = TestPointer(2, PointerDeviceKind.mouse)
      ..hover(tester.getCenter(weightField));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 40)));
    await tester.pump();

    expect(prompt.text, 'cat');
  });
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  required TextEditingController prompt,
  required FocusNode focus,
  required ScrollController page,
  required bool enableWheelAdjustment,
  ScrollPhysics? scrollPhysics,
}) {
  return tester.pumpWidget(
    MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SizedBox(
          height: 300,
          child: SingleChildScrollView(
            controller: page,
            child: Column(
              children: [
                const SizedBox(height: 160),
                SizedBox(
                  height: 80,
                  child: WeightAdjustToolbarWrapper(
                    controller: prompt,
                    focusNode: focus,
                    enableWheelAdjustment: enableWheelAdjustment,
                    child: ThemedInput(
                      key: _fieldKey,
                      controller: prompt,
                      focusNode: focus,
                      maxLines: null,
                      scrollPhysics: scrollPhysics,
                    ),
                  ),
                ),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
