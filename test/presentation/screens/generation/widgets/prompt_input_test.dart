import 'dart:ui' show PointerDeviceKind;

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
import 'package:nai_launcher/presentation/screens/generation/widgets/generation_toggle_button.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input.dart';
import 'package:nai_launcher/presentation/themes/core/input_surface_style.dart';
import 'package:nai_launcher/presentation/widgets/common/input_surface_container.dart';
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

  testWidgets('紧凑提示词编辑器使用区别于页面的输入色面', (tester) async {
    const colorScheme = ColorScheme.dark(
      surface: Color(0xFF1A1A1A),
      onSurface: Color(0xFFF4EEDC),
    );
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
        ],
        child: MaterialApp(
          theme: ThemeData(colorScheme: colorScheme),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(
            body: SizedBox(
              width: 400,
              height: 180,
              child: PromptInputWidget(compact: true),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final expectedColor = inputSurfaceFillColor(colorScheme, prominent: true);
    final surface = find.byKey(
      const ValueKey('generation_prompt_compact_surface'),
    );
    final input = tester.widget<UnifiedPromptInput>(
      find.byKey(const ValueKey('generation_prompt_compact_input')),
    );
    expect(surface, findsOneWidget);
    expect(
      find.descendant(
        of: surface,
        matching: find.byType(InputSurfaceContainer),
      ),
      findsOneWidget,
    );
    expect(input.surfaceColor, expectedColor);
    expect(input.surfaceColor, isNot(colorScheme.surface));
  });

  testWidgets('手机最大化提示词工具区固定为主次两行且不挤占编辑区', (tester) async {
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
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 380,
                height: 420,
                child: PromptInputWidget(isMaximized: true),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final primaryRow = find.byKey(
      const ValueKey('generation_prompt_mobile_primary_row'),
    );
    final secondaryScroll = find.byKey(
      const ValueKey('generation_prompt_mobile_secondary_scroll'),
    );
    final secondaryActions = [
      find.byKey(const ValueKey('generation_prompt_mobile_fixed_tags_action')),
      find.byKey(const ValueKey('generation_prompt_mobile_quality_action')),
      find.byKey(const ValueKey('generation_prompt_mobile_uc_action')),
      find.byKey(const ValueKey('generation_prompt_mobile_character_action')),
    ];
    final editor = find.byKey(
      const ValueKey('generation_prompt_positive_input'),
    );

    expect(primaryRow, findsOneWidget);
    expect(
      find.descendant(
        of: primaryRow,
        matching: find.byIcon(Icons.fullscreen_exit),
      ),
      findsOneWidget,
    );
    expect(secondaryScroll, findsOneWidget);
    expect(tester.getSize(secondaryScroll).height, 48);
    expect(tester.getSize(secondaryScroll).width, 380);
    for (final action in secondaryActions) {
      expect(action, findsOneWidget);
      expect(tester.getSize(action).height, 48);
      expect(
        tester.getCenter(action).dy,
        closeTo(tester.getCenter(secondaryActions.first).dy, 0.1),
      );
    }
    expect(
      tester.getBottomLeft(secondaryScroll).dy,
      lessThan(tester.getTopLeft(editor).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('V5 透明背景开关位于正向提示词框左下角', (tester) async {
    final storage = _TestLocalStorageService(
      defaultModel: 'nai-diffusion-5-curated',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
          characterPromptNotifierProvider.overrideWith(
            _TestCharacterPromptNotifier.new,
          ),
          promptTokenUsageProvider(
            PromptTokenCountTarget.positive,
          ).overrideWith(
            (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 703),
          ),
          promptTokenUsageProvider(
            PromptTokenCountTarget.negative,
          ).overrideWith(
            (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 703),
          ),
        ],
        child: const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              width: 960,
              height: 420,
              child: PromptInputWidget(autoGrow: true),
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
    final toggle = find.byKey(
      const ValueKey('generation_transparent_background_toggle'),
    );

    expect(toggle, findsOneWidget);
    expect(
      tester.getTopLeft(toggle).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(promptField).dy),
    );
    expect(
      tester.getTopLeft(toggle).dx,
      closeTo(tester.getTopLeft(promptField).dx, 1),
    );
    expect(tester.widget<GenerationToggleButton>(toggle).isEnabled, isFalse);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(toggle));
    await tester.pump(const Duration(milliseconds: 301));

    expect(find.text(', transparent background'), findsOneWidget);

    await mouse.moveTo(const Offset(950, 400));
    await tester.pump();

    await tester.tap(toggle);
    await tester.pump();

    expect(tester.widget<GenerationToggleButton>(toggle).isEnabled, isTrue);
    expect(storage.savedTransparentBackground, isTrue);

    await tester.tap(find.byIcon(Icons.block).first);
    await tester.pump();

    expect(toggle, findsNothing);
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
      await tester.tap(
        find.byKey(const ValueKey('prompt_input_replace_current')),
      );
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
      await tester.tap(
        find.byKey(const ValueKey('prompt_input_replace_toggle')),
      );
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
                width: 320,
                height: 80,
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
      expect(toolbarRect.left, greaterThanOrEqualTo(8));
      expect(toolbarRect.right, lessThanOrEqualTo(312));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

class _TestLocalStorageService extends LocalStorageService {
  _TestLocalStorageService({
    this.enablePromptWeightScroll = true,
    this.defaultModel = 'nai-diffusion-4-5-full',
  });

  final bool enablePromptWeightScroll;
  final String defaultModel;
  bool? savedTransparentBackground;

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
  String getDefaultModel() => defaultModel;

  @override
  bool getLastTransparentBackground() => false;

  @override
  Future<void> setLastTransparentBackground(bool value) async {
    savedTransparentBackground = value;
  }

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
