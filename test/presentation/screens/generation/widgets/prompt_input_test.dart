import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/services/prompt_token_counter_service.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_history_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_state_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/widgets/prompt_assistant_overlay.dart';
import 'package:nai_launcher/presentation/providers/character_position_canvas_provider.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/prompt_token_counter_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/generation_toggle_button.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_type_switch.dart';
import 'package:nai_launcher/presentation/themes/core/input_surface_style.dart';
import 'package:nai_launcher/presentation/widgets/common/input_surface_container.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import 'package:nai_launcher/presentation/widgets/common/weight_adjust_toolbar.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_editor.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';

void main() {
  test('Windows 下提示词切换按钮不使用富文本 Tooltip', () {
    expect(shouldUseRichPromptTypeTooltip(TargetPlatform.windows), isFalse);
    expect(shouldUseRichPromptTypeTooltip(TargetPlatform.macOS), isTrue);
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

  testWidgets('手机最大化提示词工作台把预设工具放在编辑区下方', (tester) async {
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
      find.byKey(const ValueKey('generation_prompt_mobile_character_action')),
      find.byKey(const ValueKey('generation_prompt_mobile_fixed_tags_action')),
      find.byKey(const ValueKey('generation_prompt_mobile_quality_action')),
      find.byKey(const ValueKey('generation_prompt_mobile_uc_action')),
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
      findsNothing,
    );
    expect(secondaryScroll, findsOneWidget);
    expect(tester.getSize(secondaryScroll).height, 44);
    expect(tester.getSize(secondaryScroll).width, 380);
    for (final action in secondaryActions) {
      expect(action, findsOneWidget);
      expect(tester.getSize(action).height, 44);
      expect(
        tester.getCenter(action).dy,
        closeTo(tester.getCenter(secondaryActions.first).dy, 0.1),
      );
    }
    expect(
      tester.getBottomLeft(primaryRow).dy,
      lessThan(tester.getTopLeft(editor).dy),
    );
    expect(
      tester.getBottomLeft(editor).dy,
      lessThan(tester.getTopLeft(secondaryScroll).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('手机角色按钮直接展开单个已有角色的完整编辑器', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(380, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

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
              width: 380,
              height: 720,
              child: PromptInputWidget(isMaximized: true),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PromptInputWidget)),
    );
    final notifier = container.read(characterPromptNotifierProvider.notifier);
    (notifier as _TestCharacterPromptNotifier).seed([
      CharacterPrompt.create(name: '测试角色', prompt: '1girl, blue hair'),
    ]);
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('generation_prompt_mobile_character_action')),
    );
    await tester.pumpAndSettle();

    expect(find.text('测试角色'), findsWidgets);
    expect(find.byType(CharacterPromptEditor), findsOneWidget);
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey('generation_mobile_character_manager_sheet'),
            ),
          )
          .height,
      greaterThan(600),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('手机多角色管理先显示概览，选择角色后展开编辑器', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(380, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final container = await _pumpMobilePromptHarness(tester);
    final notifier = container.read(characterPromptNotifierProvider.notifier);
    (notifier as _TestCharacterPromptNotifier).seed([
      CharacterPrompt.create(name: '角色甲', prompt: '1girl'),
      CharacterPrompt.create(name: '角色乙', prompt: '1boy'),
    ]);
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('generation_prompt_mobile_character_action')),
    );
    await tester.pumpAndSettle();

    final sheet = find.byKey(
      const ValueKey('generation_mobile_character_manager_sheet'),
    );
    final overviewHeight = tester.getSize(sheet).height;
    expect(find.text('角色甲'), findsOneWidget);
    expect(find.text('角色乙'), findsOneWidget);
    expect(find.byType(CharacterPromptEditor), findsNothing);
    expect(overviewHeight, lessThan(600));

    await tester.tap(find.text('角色乙'));
    await tester.pumpAndSettle();

    expect(find.byType(CharacterPromptEditor), findsOneWidget);
    expect(tester.getSize(sheet).height, greaterThan(overviewHeight + 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('手机角色位置入口关闭管理层并显示预览画布', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(380, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final container = await _pumpMobilePromptHarness(tester);
    final canvasSubscription = container.listen<bool>(
      characterPositionCanvasProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(canvasSubscription.close);
    final notifier = container.read(characterPromptNotifierProvider.notifier);
    (notifier as _TestCharacterPromptNotifier).seed([
      CharacterPrompt.create(name: '角色甲', prompt: '1girl'),
    ]);
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('generation_prompt_mobile_character_action')),
    );
    await tester.pumpAndSettle();

    final sheet = find.byKey(
      const ValueKey('generation_mobile_character_manager_sheet'),
    );
    expect(sheet, findsOneWidget);

    await tester.tap(find.byIcon(Icons.control_camera));
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(container.read(characterPositionCanvasProvider), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手机空角色管理可直接添加并进入新角色编辑器', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(380, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final container = await _pumpMobilePromptHarness(tester);
    await tester.tap(
      find.byKey(const ValueKey('generation_prompt_mobile_character_action')),
    );
    await tester.pumpAndSettle();

    final sheet = find.byKey(
      const ValueKey('generation_mobile_character_manager_sheet'),
    );
    final l10n = AppLocalizations.of(tester.element(sheet))!;
    final addMenu = find.byKey(const Key('character-add-menu'));
    expect(addMenu, findsOneWidget);
    expect(find.byType(CharacterPromptEditor), findsNothing);
    final addEntryRect = tester.getRect(addMenu);

    await tester.tap(addMenu);
    await tester.pumpAndSettle();
    final addFemale = find.text(l10n.characterEditor_addFemale);
    expect(addFemale, findsOneWidget);
    expect(
      tester.getRect(addFemale).top,
      greaterThanOrEqualTo(addEntryRect.bottom),
    );

    await tester.tap(addFemale);
    await tester.pumpAndSettle();

    expect(
      container.read(characterPromptNotifierProvider).characters,
      hasLength(1),
    );
    expect(find.byType(CharacterPromptEditor), findsOneWidget);
    expect(tester.getSize(sheet).height, greaterThan(600));
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

  testWidgets('手机提示词助手在 footer 同栏展开且不侵占编辑区', (tester) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
    addTearDown(() => PlatformCapabilities.debugOverride = null);

    final storage = _TestLocalStorageService(
      defaultModel: 'nai-diffusion-5-curated',
      lastPrompt: List.filled(24, 'long_prompt_tag').join(', '),
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
            (ref) async => const PromptTokenUsage(usedTokens: 259, limit: 1471),
          ),
          promptTokenUsageProvider(
            PromptTokenCountTarget.negative,
          ).overrideWith(
            (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 1471),
          ),
        ],
        child: const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 420,
              child: PromptInputWidget(isMaximized: true),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final input = find.byKey(
      const ValueKey('generation_prompt_positive_input'),
    );
    final transparent = find.byKey(
      const ValueKey('generation_transparent_background_toggle'),
    );
    final footer = find.byKey(const ValueKey('generation_prompt_footer'));
    final count = find.byKey(const ValueKey('generation_prompt_footer_count'));
    final assistant = find.byKey(
      const ValueKey('generation_prompt_footer_assistant'),
    );
    final toolbar = find.byKey(
      const ValueKey(
        'prompt_assistant_toolbar_${PromptHistorySessionIds.generationPrompt}',
      ),
    );
    final textField = tester.widget<TextField>(
      find.descendant(of: input, matching: find.byType(TextField)).first,
    );

    expect(transparent, findsOneWidget);
    expect(count, findsOneWidget);
    expect(find.text('259 / 1471'), findsOneWidget);
    expect(
      find.descendant(
        of: assistant,
        matching: find.byIcon(Icons.auto_awesome_rounded),
      ),
      findsOneWidget,
    );
    expect(assistant, findsOneWidget);
    expect(toolbar, findsOneWidget);
    expect(textField.decoration?.contentPadding, const EdgeInsets.all(12));
    expect(
      tester.getRect(transparent).top,
      greaterThanOrEqualTo(tester.getRect(input).bottom),
    );
    expect(
      tester.getRect(count).top,
      greaterThanOrEqualTo(tester.getRect(input).bottom),
    );
    expect(
      tester.getRect(assistant).top,
      greaterThanOrEqualTo(tester.getRect(input).bottom),
    );
    expect(
      tester.getRect(transparent).right,
      lessThanOrEqualTo(tester.getRect(count).left),
    );
    expect(
      tester.getRect(assistant).left - tester.getRect(count).right,
      greaterThanOrEqualTo(8),
    );
    expect(tester.getSize(toolbar).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(toolbar).height, 48);
    final collapsedFooterHeight = tester.getSize(footer).height;

    await tester.tap(
      find.descendant(
        of: assistant,
        matching: find.byIcon(Icons.auto_awesome_rounded),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    expect(count, findsNothing);
    expect(find.text('259 / 1471'), findsNothing);
    expect(
      find.descendant(
        of: assistant,
        matching: find.byIcon(Icons.auto_awesome_rounded),
      ),
      findsNothing,
    );
    expect(transparent, findsNothing);
    expect(assistant, findsOneWidget);
    expect(tester.getSize(footer).height, collapsedFooterHeight);
    expect(
      tester.getRect(assistant).top,
      greaterThanOrEqualTo(tester.getRect(input).bottom),
    );
    for (final icon in [
      Icons.translate,
      Icons.auto_fix_high,
      Icons.tune_rounded,
      Icons.manage_accounts_rounded,
      Icons.more_horiz,
      Icons.keyboard_arrow_down_rounded,
    ]) {
      final action = find.widgetWithIcon(IconButton, icon);
      expect(action, findsOneWidget);
      expect(tester.getSize(action), const Size(48, 48));
      await tester.ensureVisible(action);
      await tester.pump();
      expect(
        tester.getRect(action).top,
        greaterThanOrEqualTo(tester.getRect(input).bottom),
      );
      expect(
        tester.getRect(action).left,
        greaterThanOrEqualTo(tester.getRect(assistant).left),
      );
      expect(
        tester.getRect(action).right,
        lessThanOrEqualTo(tester.getRect(assistant).right),
      );
    }

    await tester.tap(
      find.descendant(
        of: assistant,
        matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
      ),
    );
    await tester.pump(const Duration(milliseconds: 160));
    expect(count, findsOneWidget);
    expect(find.text('259 / 1471'), findsOneWidget);
    expect(
      find.descendant(
        of: assistant,
        matching: find.byIcon(Icons.auto_awesome_rounded),
      ),
      findsOneWidget,
    );
    expect(transparent, findsOneWidget);
    expect(tester.getSize(footer).height, collapsedFooterHeight);
    expect(
      tester.getRect(assistant).left - tester.getRect(count).right,
      greaterThanOrEqualTo(8),
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

Future<ProviderContainer> _pumpMobilePromptHarness(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWith(
          (ref) => _TestLocalStorageService(),
        ),
        characterPromptNotifierProvider.overrideWith(
          _TestCharacterPromptNotifier.new,
        ),
        promptTokenUsageProvider(PromptTokenCountTarget.positive).overrideWith(
          (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 512),
        ),
        promptTokenUsageProvider(PromptTokenCountTarget.negative).overrideWith(
          (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 512),
        ),
      ],
      child: const MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SizedBox(
            width: 380,
            height: 720,
            child: PromptInputWidget(isMaximized: true),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(
    tester.element(find.byType(PromptInputWidget)),
  );
}

class _TestLocalStorageService extends LocalStorageService {
  _TestLocalStorageService({
    this.enablePromptWeightScroll = true,
    this.defaultModel = 'nai-diffusion-4-5-full',
    this.lastPrompt = '',
  });

  final bool enablePromptWeightScroll;
  final String defaultModel;
  final String lastPrompt;
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
  String getLastPrompt() => lastPrompt;

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

  void seed(List<CharacterPrompt> characters) {
    state = CharacterPromptConfig(characters: characters);
  }

  @override
  void addCharacter(
    CharacterGender gender, {
    String? name,
    String? prompt,
    String? negativePrompt,
    String? thumbnailPath,
  }) {
    state = state.addCharacter(
      gender: gender,
      name: name,
      prompt: prompt,
      negativePrompt: negativePrompt,
      thumbnailPath: thumbnailPath,
    );
  }
}
