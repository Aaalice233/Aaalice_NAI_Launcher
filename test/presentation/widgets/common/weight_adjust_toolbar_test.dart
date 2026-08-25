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
}) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse)
    ..hover(tester.getCenter(find.byKey(_fieldKey)));
  await tester.sendEventToBinding(pointer.scroll(delta));
  await tester.pump();
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
  testWidgets('有选区时滚轮不改文本和选区并滚动外层页面', (tester) async {
    final prompt = TextEditingController(text: 'cat, dog');
    final focus = FocusNode();
    final page = ScrollController(initialScrollOffset: 100);
    _registerCleanup(tester, prompt, focus, page);

    await _pumpHarness(tester, prompt: prompt, focus: focus, page: page);
    focus.requestFocus();
    const selection = TextSelection(baseOffset: 0, extentOffset: 3);
    prompt.selection = selection;
    await tester.pump();
    final pageOffsetBefore = page.offset;

    await _sendWheel(tester);

    expect(prompt.text, 'cat, dog');
    expect(prompt.selection, selection);
    expect(page.offset, greaterThan(pageOffsetBefore));
  });

  testWidgets('无选区时滚轮不改文本和光标并滚动外层页面', (tester) async {
    final prompt = TextEditingController(text: 'cat, dog');
    final focus = FocusNode();
    final page = ScrollController(initialScrollOffset: 100);
    _registerCleanup(tester, prompt, focus, page);

    await _pumpHarness(tester, prompt: prompt, focus: focus, page: page);
    const selection = TextSelection.collapsed(offset: 3);
    prompt.selection = selection;
    await tester.pump();
    final pageOffsetBefore = page.offset;

    await _sendWheel(tester);

    expect(prompt.text, 'cat, dog');
    expect(prompt.selection, selection);
    expect(page.offset, greaterThan(pageOffsetBefore));
  });

  testWidgets('有选区时滚轮保留文本和选区并滚动输入框', (tester) async {
    final original = List<String>.filled(40, 'tag').join('\n');
    final prompt = TextEditingController(text: original);
    final focus = FocusNode();
    final page = ScrollController(initialScrollOffset: 100);
    _registerCleanup(tester, prompt, focus, page);

    await _pumpHarness(tester, prompt: prompt, focus: focus, page: page);
    focus.requestFocus();
    const selection = TextSelection(baseOffset: 0, extentOffset: 3);
    prompt.selection = selection;
    await tester.pump();

    final innerFinder = find.descendant(
      of: find.byKey(_fieldKey),
      matching: find.byType(Scrollable),
    );
    expect(innerFinder, findsOneWidget);
    final inner = tester.state<ScrollableState>(innerFinder);
    final innerOffsetBefore = inner.position.pixels;

    await _sendWheel(tester);

    expect(prompt.text, original);
    expect(prompt.selection, selection);
    expect(inner.position.pixels, greaterThan(innerOffsetBefore));
  });

  testWidgets('浮动工具条按钮仍可调整和重置权重', (tester) async {
    final prompt = TextEditingController(text: 'cat');
    final focus = FocusNode();
    final page = ScrollController(initialScrollOffset: 100);
    _registerCleanup(tester, prompt, focus, page);

    await _pumpHarness(tester, prompt: prompt, focus: focus, page: page);
    focus.requestFocus();
    prompt.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(prompt.text, '1.05::cat::');

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(prompt.text, 'cat');
  });

  testWidgets('replacement controller without selection hides open toolbar', (
    tester,
  ) async {
    final controllerA = TextEditingController(text: 'cat');
    final controllerB = TextEditingController(text: 'dog');
    final focus = FocusNode();
    final page = ScrollController(initialScrollOffset: 100);
    _registerControllerSwapCleanup(
      tester,
      [controllerA, controllerB],
      focus,
      page,
    );

    await _pumpHarness(tester, prompt: controllerA, focus: focus, page: page);
    focus.requestFocus();
    controllerA.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(2));

    await _pumpHarness(tester, prompt: controllerB, focus: focus, page: page);
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('open toolbar targets selected replacement controller', (
    tester,
  ) async {
    final controllerA = TextEditingController(text: 'cat');
    final controllerB = TextEditingController(text: 'dog')
      ..selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    final focus = FocusNode();
    final page = ScrollController(initialScrollOffset: 100);
    _registerControllerSwapCleanup(
      tester,
      [controllerA, controllerB],
      focus,
      page,
    );

    await _pumpHarness(tester, prompt: controllerA, focus: focus, page: page);
    focus.requestFocus();
    controllerA.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    await tester.pump();

    await _pumpHarness(tester, prompt: controllerB, focus: focus, page: page);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(controllerA.text, 'cat');
    expect(controllerB.text, '1.05::dog::');
  });

  testWidgets('replacement controller with selection shows toolbar', (
    tester,
  ) async {
    final controllerA = TextEditingController(text: 'cat');
    final controllerB = TextEditingController(text: 'dog')
      ..selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    final focus = FocusNode();
    final page = ScrollController(initialScrollOffset: 100);
    _registerControllerSwapCleanup(
      tester,
      [controllerA, controllerB],
      focus,
      page,
    );

    await _pumpHarness(tester, prompt: controllerA, focus: focus, page: page);
    expect(find.byType(TextField), findsOneWidget);

    await _pumpHarness(tester, prompt: controllerB, focus: focus, page: page);
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(2));
  });
}

void _registerControllerSwapCleanup(
  WidgetTester tester,
  List<TextEditingController> prompts,
  FocusNode focus,
  ScrollController page,
) {
  addTearDown(() async {
    for (final prompt in prompts) {
      if (prompt.selection.isValid) {
        prompt.selection = TextSelection.collapsed(offset: prompt.text.length);
      }
    }
    focus.unfocus();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));
    page.dispose();
    focus.dispose();
    for (final prompt in prompts) {
      prompt.dispose();
    }
  });
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  required TextEditingController prompt,
  required FocusNode focus,
  required ScrollController page,
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
                    child: ThemedInput(
                      key: _fieldKey,
                      controller: prompt,
                      focusNode: focus,
                      maxLines: null,
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
