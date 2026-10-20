import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/prompt_formatter_wrapper.dart';

void main() {
  late TextEditingController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = TextEditingController();
    focusNode = FocusNode();
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Future<void> pumpWrapper(
    WidgetTester tester, {
    bool enableAutoFormat = false,
    bool enableSdSyntaxAutoConvert = false,
    bool separateNumericWeightClosing = false,
    bool replaceUnderscores = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: PromptFormatterWrapper(
            controller: controller,
            focusNode: focusNode,
            enableAutoFormat: enableAutoFormat,
            enableSdSyntaxAutoConvert: enableSdSyntaxAutoConvert,
            separateNumericWeightClosing: separateNumericWeightClosing,
            replaceUnderscores: replaceUnderscores,
            child: TextField(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
  }

  // 改写成功会弹 Toast，时钟推过它的自动关闭，避免 teardown 时残留定时器
  Future<void> typeAndBlur(WidgetTester tester, String text) async {
    controller.text = text;
    focusNode.requestFocus();
    await tester.pump();
    focusNode.unfocus();
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('blur separates closings after numbers when enabled', (
    tester,
  ) async {
    await pumpWrapper(tester, separateNumericWeightClosing: true);

    await typeAndBlur(tester, '1.05::year_2025::, other tags');

    expect(controller.text, '1.05::year_2025 ::, other tags');
  });

  testWidgets('blur leaves closings untouched when disabled', (tester) async {
    await pumpWrapper(tester, enableAutoFormat: true);

    await typeAndBlur(tester, '1.05::year_2025::, other tags');

    expect(controller.text, '1.05::year_2025::, other_tags');
  });

  testWidgets('SD conversion and auto format keep the separating space', (
    tester,
  ) async {
    await pumpWrapper(
      tester,
      enableAutoFormat: true,
      enableSdSyntaxAutoConvert: true,
      separateNumericWeightClosing: true,
    );

    await typeAndBlur(tester, '(year 2025:1.2), other tags');

    expect(controller.text, '1.2::year_2025 ::, other_tags');
  });

  testWidgets('spaces preference reaches the shared blur pipeline', (
    tester,
  ) async {
    await pumpWrapper(
      tester,
      enableAutoFormat: true,
      enableSdSyntaxAutoConvert: true,
      separateNumericWeightClosing: true,
      replaceUnderscores: true,
    );

    await typeAndBlur(tester, '(year_2025:1.2), long_hair, >_<, "my_text"');

    expect(controller.text, '1.2::year 2025 ::, long hair, >_<, "my_text"');
  });
}
