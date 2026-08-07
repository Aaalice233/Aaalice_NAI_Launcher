import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/services/prompt_token_counter_service.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_state_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/widgets/prompt_assistant_overlay.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/prompt_token_counter_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import 'package:nai_launcher/presentation/widgets/common/weight_adjust_toolbar.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';

void main() {
  test('Windows 下提示词切换按钮不使用富文本 Tooltip', () {
    expect(usesRichPromptTypeTooltip(TargetPlatform.windows), isFalse);
    expect(usesRichPromptTypeTooltip(TargetPlatform.macOS), isTrue);
  });

  testWidgets('冷启动时切换到负面提示词不会抛出异常', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) {
            return _TestLocalStorageService();
          }),
          characterPromptNotifierProvider.overrideWith(
            _TestCharacterPromptNotifier.new,
          ),
          promptTokenUsageProvider(
            PromptTokenCountTarget.positive,
          ).overrideWith(
            (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 512),
          ),
          promptTokenUsageProvider(
            PromptTokenCountTarget.negative,
          ).overrideWith(
            (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 512),
          ),
        ],
        child: const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(width: 960, height: 420, child: PromptInputWidget()),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byIcon(Icons.block).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byKey(const ValueKey('generation_prompt_negative_input')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ctrl+F 搜索选中命中且编辑提示词不重置光标', (tester) async {
    const prompt = 'alpha, beta, Alpha';
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) {
              return _TestLocalStorageService();
            }),
            characterPromptNotifierProvider.overrideWith(
              _TestCharacterPromptNotifier.new,
            ),
            promptTokenUsageProvider(
              PromptTokenCountTarget.positive,
            ).overrideWith(
              (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 512),
            ),
            promptTokenUsageProvider(
              PromptTokenCountTarget.negative,
            ).overrideWith(
              (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 512),
            ),
          ],
          child: const MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SizedBox(
                width: 960,
                height: 420,
                child: PromptInputWidget(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final promptField = find
          .descendant(
            of: find.byKey(const ValueKey('generation_prompt_positive_input')),
            matching: find.byType(TextField),
          )
          .first;

      await tester.tap(promptField);
      await tester.enterText(promptField, prompt);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      final searchField = find.byKey(
        const ValueKey('prompt_input_search_field'),
      );
      expect(searchField, findsOneWidget);
      final promptTextField = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == prompt,
      );
      expect(promptTextField, findsOneWidget);
      expect(
        tester.getBottomLeft(searchField).dy,
        lessThanOrEqualTo(tester.getTopLeft(promptTextField).dy),
      );

      await tester.enterText(searchField, 'alpha');
      await tester.pump();

      expect(find.text('1 / 2'), findsOneWidget);

      final promptEditable = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .singleWhere((editable) => editable.controller.text == prompt);
      expect(
        promptEditable.controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );

      final promptController = promptEditable.controller;
      final activePromptField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            identical(widget.controller, promptController),
      );
      await tester.tap(activePromptField);
      await tester.pump();

      const editedPrompt = '$prompt!';
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: editedPrompt,
          selection: TextSelection.collapsed(offset: editedPrompt.length),
        ),
      );
      await tester.pump();

      expect(promptController.text, editedPrompt);
      expect(
        promptController.selection,
        const TextSelection.collapsed(offset: editedPrompt.length),
      );
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 250));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Ctrl+H 展开替换栏并支持替换当前与全部替换', (tester) async {
    const prompt = 'alpha, beta, Alpha';
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) {
              return _TestLocalStorageService();
            }),
            characterPromptNotifierProvider.overrideWith(
              _TestCharacterPromptNotifier.new,
            ),
            promptTokenUsageProvider(
              PromptTokenCountTarget.positive,
            ).overrideWith(
              (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 512),
            ),
            promptTokenUsageProvider(
              PromptTokenCountTarget.negative,
            ).overrideWith(
              (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 512),
            ),
          ],
          child: const MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SizedBox(
                width: 960,
                height: 420,
                child: PromptInputWidget(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final promptField = find
          .descendant(
            of: find.byKey(const ValueKey('generation_prompt_positive_input')),
            matching: find.byType(TextField),
          )
          .first;

      await tester.tap(promptField);
      await tester.enterText(promptField, prompt);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      final searchField = find.byKey(
        const ValueKey('prompt_input_search_field'),
      );
      final replaceField = find.byKey(
        const ValueKey('prompt_input_replace_field'),
      );
      expect(searchField, findsOneWidget);
      expect(replaceField, findsOneWidget);

      await tester.enterText(searchField, 'alpha');
      await tester.pump();
      await tester.enterText(replaceField, 'omega');
      await tester.pump();

      // 大小写不敏感搜索：alpha 与 Alpha 都应命中。
      expect(find.text('1 / 2'), findsOneWidget);

      final promptController = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .singleWhere((editable) => editable.controller.text == prompt)
          .controller;

      // 替换当前命中后应跳到后一处命中。
      await tester.tap(find.byKey(const ValueKey('prompt_input_replace_current')));
      await tester.pump();
      expect(promptController.text, 'omega, beta, Alpha');
      expect(
        promptController.selection,
        const TextSelection(baseOffset: 13, extentOffset: 18),
      );

      // 全部替换应把剩余命中一次改完。
      await tester.tap(find.byKey(const ValueKey('prompt_input_replace_all')));
      await tester.pump();
      expect(promptController.text, 'omega, beta, omega');

      // 替换栏可折叠。
      await tester.tap(find.byKey(const ValueKey('prompt_input_replace_toggle')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('prompt_input_replace_field')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('prompt_input_search_field')),
        findsOneWidget,
      );

      // 全部替换的 toast 有 3 秒延迟 + 退场动画，需要等它彻底移除；
      // 输入框光标闪烁是周期定时器，这里不能用 pumpAndSettle。
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('shared prompt input reads the disabled wheel setting', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => _TestLocalStorageService(enablePromptWeightScroll: false),
          ),
          characterPromptNotifierProvider.overrideWith(
            _TestCharacterPromptNotifier.new,
          ),
          promptTokenUsageProvider(
            PromptTokenCountTarget.positive,
          ).overrideWith(
            (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 512),
          ),
          promptTokenUsageProvider(
            PromptTokenCountTarget.negative,
          ).overrideWith(
            (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 512),
          ),
        ],
        child: const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(width: 960, height: 420, child: PromptInputWidget()),
          ),
        ),
      ),
    );
    await tester.pump();

    final wrapper = tester.widget<WeightAdjustToolbarWrapper>(
      find.byType(WeightAdjustToolbarWrapper).first,
    );
    final input = tester.widget<ThemedInput>(find.byType(ThemedInput).first);

    expect(wrapper.enableWheelAdjustment, isFalse);
    expect(input.scrollPhysics, isNull);
  });

  testWidgets('expanded prompt assistant does not cover editable prompt text', (
    tester,
  ) async {
    const sessionId = 'assistant_clearance_test';
    final controller = TextEditingController(
      text: List.filled(12, 'long prompt tag').join(', '),
    );
    addTearDown(controller.dispose);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith(
              (ref) => _TestLocalStorageService(),
            ),
          ],
          child: MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SizedBox(
                width: 720,
                height: 72,
                child: UnifiedPromptInput(
                  controller: controller,
                  sessionId: sessionId,
                  config: const UnifiedPromptConfig(
                    enableAutocomplete: false,
                    enableSyntaxHighlight: false,
                  ),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(12),
                  ),
                  maxLines: null,
                  expands: true,
                ),
              ),
            ),
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(UnifiedPromptInput)),
      );
      container
          .read(promptAssistantStateProvider.notifier)
          .setExpanded(sessionId, true);
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      final padding = textField.decoration!.contentPadding!.resolve(
        TextDirection.ltr,
      );
      final toolbar = find.byKey(
        const ValueKey<String>('prompt_assistant_toolbar_$sessionId'),
      );
      final editableRect = tester.getRect(find.byType(EditableText));
      final toolbarRect = tester.getRect(toolbar);

      expect(padding.bottom, PromptAssistantOverlay.contentBottomClearance);
      expect(toolbar, findsOneWidget);
      expect(editableRect.height, greaterThanOrEqualTo(18));
      expect(editableRect.bottom, lessThanOrEqualTo(toolbarRect.top));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

class _TestLocalStorageService extends LocalStorageService {
  _TestLocalStorageService({this.enablePromptWeightScroll = true});

  final bool enablePromptWeightScroll;

  @override
  bool getEnablePromptWeightScroll() => enablePromptWeightScroll;

  @override
  bool getEnableAutocomplete() => false;

  @override
  bool getAutoFormatPrompt() => false;

  @override
  bool getHighlightEmphasis() => false;

  @override
  bool getSdSyntaxAutoConvert() => false;

  @override
  bool getEnableCooccurrenceRecommendation() => false;

  @override
  String getLastPrompt() => '';

  @override
  Future<void> setLastPrompt(String prompt) async {}

  @override
  String getLastNegativePrompt() => '';

  @override
  Future<void> setLastNegativePrompt(String prompt) async {}

  @override
  String getDefaultModel() => 'nai-diffusion-4-5-full';

  @override
  String getDefaultSampler() => 'k_euler_ancestral';

  @override
  int getDefaultSteps() => 28;

  @override
  double getDefaultScale() => 5.0;

  @override
  int getDefaultWidth() => 832;

  @override
  int getDefaultHeight() => 1216;

  @override
  bool getLastSmea() => false;

  @override
  bool getLastSmeaDyn() => false;

  @override
  double getLastCfgRescale() => 0.0;

  @override
  String getLastNoiseSchedule() => 'native';

  @override
  bool getSeedLocked() => false;

  @override
  int? getLockedSeedValue() => null;
}

class _TestCharacterPromptNotifier extends CharacterPromptNotifier {
  @override
  CharacterPromptConfig build() => const CharacterPromptConfig();
}
