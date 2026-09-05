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
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_history_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_state_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/widgets/prompt_assistant_overlay.dart';
import 'package:nai_launcher/presentation/providers/character_position_canvas_provider.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/prompt_token_counter_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/generation_toggle_button.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input.dart';
import 'package:nai_launcher/presentation/themes/core/input_surface_style.dart';
import 'package:nai_launcher/presentation/widgets/common/input_surface_container.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import 'package:nai_launcher/presentation/widgets/common/weight_adjust_toolbar.dart';
import 'package:nai_launcher/presentation/widgets/character/character_prompt_button.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_editor.dart';
import 'package:nai_launcher/presentation/widgets/prompt/fixed_tags_button.dart';
import 'package:nai_launcher/presentation/widgets/prompt/quality_tags_selector.dart';
import 'package:nai_launcher/presentation/widgets/prompt/uc_preset_selector.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';

void main() {
  testWidgets('主提示词拖动高度保留正文并跨正负和标签模式复用', (tester) async {
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
            body: SingleChildScrollView(
              child: PromptInputWidget(autoGrow: true),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final positive = find.byKey(
      const ValueKey('generation_prompt_positive_input'),
    );
    final text = find
        .descendant(of: positive, matching: find.byType(EditableText))
        .first;
    await tester.enterText(text, 'cat, dog');
    await tester.pump();
    final editor = tester.widget<EditableText>(text);
    editor.controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();
    // Dismiss the autocomplete overlay before interacting with the bottom edge.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    final editorState = tester.state(text);
    final oldHeight = tester.getSize(positive).height;
    final handle = find.byKey(
      const ValueKey('generation-prompt-height-handle'),
    );
    await tester.drag(
      handle,
      const Offset(0, 100),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    final manualHeight = tester.getSize(positive).height;
    expect(manualHeight, greaterThan(oldHeight + 40));
    expect(tester.state(text), same(editorState));
    expect(editor.focusNode.hasFocus, isTrue);
    expect(editor.controller.text, 'cat, dog');
    expect(
      editor.controller.selection,
      const TextSelection.collapsed(offset: 3),
    );

    await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
    await tester.pump();
    expect(tester.getSize(positive).height, manualHeight);
    await tester.drag(
      handle,
      const Offset(0, -40),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    final tagHeight = tester.getSize(positive).height;
    expect(tagHeight, lessThan(manualHeight));
    expect(editor.controller.text, 'cat, dog');
    await tester.tap(find.byIcon(Icons.block).first);
    await tester.pump();
    final negative = find.byKey(
      const ValueKey('generation_prompt_negative_input'),
    );
    expect(tester.getSize(negative).height, tagHeight);
    expect(tester.takeException(), isNull);
    // Settle the double-tap recognizer and the existing toolbar blur delay.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpWidget(const SizedBox.shrink());
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

  testWidgets('响应式壳层切换保持提示词控制器、选区与焦点', (tester) async {
    final harnessKey = GlobalKey<_ResponsivePromptHarnessState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => _TestLocalStorageService(),
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
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: _ResponsivePromptHarness(key: harnessKey)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final editableFinder = find.descendant(
      of: find.byKey(const ValueKey('responsive-prompt-host')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(editableFinder.first, 'one, two, three');
    await tester.showKeyboard(editableFinder.first);
    final before = tester.widget<EditableText>(editableFinder.first);
    before.controller.selection = const TextSelection(
      baseOffset: 5,
      extentOffset: 8,
    );
    expect(before.focusNode.hasFocus, isTrue);

    harnessKey.currentState!.toggleLayout();
    await tester.pump();
    await tester.pump();

    final after = tester.widget<EditableText>(editableFinder.first);
    expect(identical(after.controller, before.controller), isTrue);
    expect(after.controller.text, 'one, two, three');
    expect(
      after.controller.selection,
      const TextSelection(baseOffset: 5, extentOffset: 8),
    );
    expect(after.focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('紧凑提示词编辑器使用独立色面且正文没有额外右侧预留', (tester) async {
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
      find.byKey(const ValueKey('generation_prompt_positive_input')),
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
    final surfaceRect = tester.getRect(
      find.descendant(
        of: surface,
        matching: find.byType(InputSurfaceContainer),
      ),
    );
    final editableRect = tester.getRect(
      find.descendant(of: surface, matching: find.byType(EditableText)),
    );
    expect(editableRect.left - surfaceRect.left, closeTo(13, 0.1));
    expect(surfaceRect.right - editableRect.right, closeTo(13, 0.1));
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
                width: 320,
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

    final typeSwitch = find.byKey(
      const ValueKey('generation_prompt_type_switch'),
    );
    final secondaryScroll = find.byKey(
      const ValueKey('generation_prompt_mobile_secondary_scroll'),
    );
    final contextBar = find.byKey(
      const ValueKey('generation_prompt_mobile_context_bar'),
    );
    final clearAction = find.byKey(
      const ValueKey('generation_prompt_mobile_clear_action'),
    );
    final secondaryActions = [
      find.byKey(const ValueKey('generation_prompt_mobile_character_action')),
      find.byKey(const ValueKey('generation_prompt_mobile_fixed_tags_action')),
      find.byKey(const ValueKey('generation_prompt_mobile_quality_action')),
      find.byKey(const ValueKey('generation_prompt_mobile_uc_action')),
      find.byKey(const ValueKey('generation_prompt_mobile_bottom_actions')),
    ];
    final editor = find.byKey(
      const ValueKey('generation_prompt_positive_input'),
    );

    expect(typeSwitch, findsOneWidget);
    expect(secondaryScroll, findsOneWidget);
    expect(clearAction, findsOneWidget);
    expect(tester.getSize(secondaryScroll).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(secondaryScroll).width, 272);
    expect(tester.getSize(clearAction), const Size.square(48));
    expect(
      tester.getRect(clearAction).right,
      closeTo(tester.getRect(contextBar).right, 0.1),
    );
    expect(
      find.descendant(of: clearAction, matching: find.byIcon(Icons.clear)),
      findsOneWidget,
    );
    expect(clearAction.hitTestable(), findsOneWidget);
    for (final action in secondaryActions) {
      expect(action, findsOneWidget);
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      expect(
        tester.getCenter(action).dy,
        closeTo(tester.getCenter(secondaryActions.first).dy, 0.1),
      );
      await tester.ensureVisible(action);
      await tester.pump();
      expect(action.hitTestable(), findsOneWidget);
    }
    expect(
      tester.getBottomLeft(typeSwitch).dy,
      lessThan(tester.getTopLeft(editor).dy),
    );
    expect(
      tester.getBottomLeft(editor).dy,
      lessThan(tester.getTopLeft(secondaryScroll).dy),
    );
    final bottomActions = find.byKey(
      const ValueKey('generation_prompt_mobile_bottom_actions'),
    );
    expect(
      find.descendant(
        of: bottomActions,
        matching: find.byIcon(Icons.casino_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bottomActions, matching: find.byIcon(Icons.clear)),
      findsNothing,
    );
    expect(
      find.descendant(of: bottomActions, matching: find.byIcon(Icons.settings)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('手机角色管理不会自动触发单角色编辑', (tester) async {
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
    expect(find.byType(CharacterPromptEditor), findsNothing);
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

  testWidgets('手机已有角色时添加菜单仍可新建角色', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(380, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final container = await _pumpMobilePromptHarness(tester);
    final notifier = container.read(characterPromptNotifierProvider.notifier);
    (notifier as _TestCharacterPromptNotifier).seed([
      CharacterPrompt.create(name: '已有角色', prompt: '1girl'),
    ]);
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('generation_prompt_mobile_character_action')),
    );
    await tester.pumpAndSettle();
    final sheet = find.byKey(
      const ValueKey('generation_mobile_character_manager_sheet'),
    );
    final l10n = AppLocalizations.of(tester.element(sheet))!;

    await tester.tap(find.byKey(const Key('character-add-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.characterEditor_addMale));
    await tester.pumpAndSettle();

    expect(
      container.read(characterPromptNotifierProvider).characters,
      hasLength(2),
    );
    expect(find.byType(CharacterPromptEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手机多角色管理使用全高 bottom sheet 并保持概览到编辑器状态', (tester) async {
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
    final formHeight = tester.getSize(sheet).height;
    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.text('角色甲'), findsOneWidget);
    expect(find.text('角色乙'), findsOneWidget);
    expect(find.byType(CharacterPromptEditor), findsNothing);
    expect(formHeight, greaterThan(600));

    await tester.tap(find.text('角色乙'));
    await tester.pumpAndSettle();

    expect(find.byType(CharacterPromptEditor), findsOneWidget);
    expect(tester.getSize(sheet).height, formHeight);
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

    final positionAction = find.byIcon(Icons.control_camera);
    await tester.ensureVisible(positionAction);
    await tester.pump();
    await tester.tap(positionAction);
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

  testWidgets('V5 透明背景开关切换正负面提示词后仍然可见', (tester) async {
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

    final assistant = find.byKey(
      const ValueKey('generation_prompt_footer_assistant'),
    );
    final count = find.byKey(const ValueKey('generation_prompt_footer_count'));
    await tester.tap(
      find.descendant(
        of: assistant,
        matching: find.byIcon(Icons.auto_awesome_rounded),
      ),
    );
    await tester.pump(const Duration(milliseconds: 160));

    expect(toggle, findsOneWidget);
    expect(count, findsOneWidget);
    expect(
      tester.getRect(toggle).right,
      lessThan(tester.getRect(assistant).left),
    );
    expect(
      tester.getRect(count).right,
      lessThan(tester.getRect(assistant).left),
    );

    await tester.tap(
      find.descendant(
        of: assistant,
        matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
      ),
    );
    await tester.pump(const Duration(milliseconds: 160));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(toggle));
    await tester.pump(const Duration(milliseconds: 301));

    final toggleTooltip = find.ancestor(
      of: toggle,
      matching: find.byType(Tooltip),
    );
    expect(toggleTooltip, findsOneWidget);
    expect(tester.widget<Tooltip>(toggleTooltip).richMessage, isNotNull);

    await mouse.moveTo(const Offset(950, 400));
    await tester.pump();

    await tester.tap(toggle);
    await tester.pump();

    expect(tester.widget<GenerationToggleButton>(toggle).isEnabled, isTrue);
    expect(storage.savedTransparentBackground, isTrue);

    await tester.tap(find.byIcon(Icons.block).first);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('generation_prompt_negative_input')),
      findsOneWidget,
    );
    expect(toggle, findsOneWidget);
    expect(tester.widget<GenerationToggleButton>(toggle).isEnabled, isTrue);
  });

  testWidgets('320 宽桌面侧栏可滚动到全部提示词入口且助手贴右', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith(
              (ref) => _TestLocalStorageService(
                defaultModel: 'nai-diffusion-5-curated',
              ),
            ),
            characterPromptNotifierProvider.overrideWith(
              _TestCharacterPromptNotifier.new,
            ),
            promptTokenUsageProvider(
              PromptTokenCountTarget.positive,
            ).overrideWith(
              (ref) async => const PromptTokenUsage(usedTokens: 12, limit: 703),
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
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 320,
                  height: 420,
                  child: PromptInputWidget(autoGrow: true),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final responsiveToolbar = find.byKey(
        const ValueKey('generation_prompt_mobile_toolbar'),
      );
      final typeSwitch = find.byKey(
        const ValueKey('generation_prompt_type_switch'),
      );
      final secondary = find.byKey(
        const ValueKey('generation_prompt_mobile_secondary_row'),
      );
      final footer = find.byKey(const ValueKey('generation_prompt_footer'));
      final assistant = find.byKey(
        const ValueKey('generation_prompt_footer_assistant'),
      );
      expect(tester.getSize(responsiveToolbar).width, 320);
      expect(typeSwitch, findsOneWidget);
      expect(secondary, findsOneWidget);
      expect(
        tester.getRect(assistant).right,
        closeTo(tester.getRect(footer).right, 0.1),
      );

      for (final key in const [
        'generation_prompt_mobile_fixed_tags_action',
        'generation_prompt_mobile_quality_action',
        'generation_prompt_mobile_uc_action',
      ]) {
        final action = find.byKey(ValueKey(key));
        expect(action, findsOneWidget);
        expect(action.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(action).right,
          lessThanOrEqualTo(tester.getRect(responsiveToolbar).right),
        );
      }
      expect(
        find.byKey(const ValueKey('generation_prompt_mobile_character_action')),
        findsNothing,
      );
      expect(find.byType(CharacterPromptButton), findsNothing);
      final bottomActions = find.byKey(
        const ValueKey('generation_prompt_bottom_actions'),
      );
      expect(bottomActions, findsOneWidget);
      expect(
        find.descendant(of: footer, matching: bottomActions),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: typeSwitch, matching: find.byIcon(Icons.block)),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('generation_prompt_negative_input')),
        findsOneWidget,
      );
      expect(
        tester.getRect(assistant).right,
        closeTo(tester.getRect(footer).right, 0.1),
      );

      final settings = find.widgetWithIcon(IconButton, Icons.settings);
      expect(settings, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('generation_prompt_footer_actions_scroll'),
          ),
          matching: settings,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('450 宽无全屏按钮时顶栏保留文字并保持单行', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith(
              (ref) => _TestLocalStorageService(),
            ),
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
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 450,
                  height: 420,
                  child: PromptInputWidget(
                    autoGrow: true,
                    showMaximizeButton: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final toolbar = find.byKey(
        const ValueKey('generation_prompt_compact_single_row'),
      );
      final typeSwitch = find.byKey(
        const ValueKey('generation_prompt_type_switch'),
      );
      expect(toolbar, findsOneWidget);
      expect(tester.getSize(toolbar).width, 450);
      expect(tester.getRect(typeSwitch).right, lessThanOrEqualTo(450));
      expect(
        tester.widget<FixedTagsButton>(find.byType(FixedTagsButton)).iconOnly,
        isFalse,
      );
      expect(
        tester
            .widget<QualityTagsSelector>(find.byType(QualityTagsSelector))
            .iconOnly,
        isFalse,
      );
      final bottomActions = find.byKey(
        const ValueKey('generation_prompt_bottom_actions'),
      );
      expect(bottomActions, findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.fullscreen), findsNothing);
      for (final icon in const [
        Icons.casino_outlined,
        Icons.clear,
        Icons.settings,
      ]) {
        expect(
          find.descendant(of: toolbar, matching: find.byIcon(icon)),
          findsNothing,
        );
        expect(
          find.descendant(of: bottomActions, matching: find.byIcon(icon)),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const ValueKey('generation_prompt_mobile_character_action')),
        findsNothing,
      );
      final positiveMode = find.byKey(
        const ValueKey('generation_prompt_positive_mode'),
      );
      final negativeMode = find.byKey(
        const ValueKey('generation_prompt_negative_mode'),
      );
      expect(tester.getSize(find.text('Prompt')).width, greaterThan(10));
      expect(
        tester.getSize(find.text('Undesired Content')).width,
        greaterThan(10),
      );
      expect(
        find.descendant(of: positiveMode, matching: find.text('0')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: negativeMode, matching: find.text('0')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('generation_prompt_positive_input')),
        '1girl, blue hair',
      );
      await tester.pump();
      expect(
        find.descendant(of: positiveMode, matching: find.text('2')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('520 宽桌面顶栏与底栏均保持单行', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith(
              (ref) => _TestLocalStorageService(),
            ),
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
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 520,
                  height: 420,
                  child: PromptInputWidget(autoGrow: true),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final toolbar = find.byKey(
        const ValueKey('generation_prompt_compact_single_row'),
      );
      final footer = find.byKey(const ValueKey('generation_prompt_footer'));
      final bottomActions = find.byKey(
        const ValueKey('generation_prompt_bottom_actions'),
      );
      expect(toolbar, findsOneWidget);
      expect(tester.getSize(toolbar).height, 48);
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey('generation_prompt_type_switch')),
            )
            .width,
        lessThanOrEqualTo(200),
      );
      expect(
        tester.widget<FixedTagsButton>(find.byType(FixedTagsButton)).iconOnly,
        isFalse,
      );
      expect(
        tester
            .widget<QualityTagsSelector>(find.byType(QualityTagsSelector))
            .iconOnly,
        isFalse,
      );
      expect(
        tester.widget<UcPresetSelector>(find.byType(UcPresetSelector)).iconOnly,
        isFalse,
      );
      final typeSwitch = find.byKey(
        const ValueKey('generation_prompt_type_switch'),
      );
      final compactActions = find.byKey(
        const ValueKey('generation_prompt_compact_single_row_actions'),
      );
      expect(
        tester.getRect(typeSwitch).right,
        closeTo(tester.getRect(compactActions).left - 4, 0.1),
      );
      expect(
        tester.getRect(compactActions).right,
        closeTo(tester.getRect(toolbar).right, 0.1),
      );
      expect(
        find.descendant(
          of: find.byType(UcPresetSelector),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
      for (final control in <Finder>[
        find.byType(FixedTagsButton),
        find.byType(QualityTagsSelector),
        find.byType(UcPresetSelector),
        find.widgetWithIcon(IconButton, Icons.fullscreen),
      ]) {
        expect(
          tester.getRect(control).right,
          lessThanOrEqualTo(tester.getRect(toolbar).right),
          reason: '$control must stay inside the compact toolbar',
        );
      }
      expect(find.byType(CharacterPromptButton), findsNothing);
      expect(
        find.descendant(of: footer, matching: bottomActions),
        findsOneWidget,
      );
      expect(
        find.widgetWithIcon(IconButton, Icons.settings).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.getRect(bottomActions).bottom,
        lessThanOrEqualTo(tester.getRect(footer).bottom),
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
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
            body: InteractionPolicyScope(
              initialPolicy: InteractionPolicy(
                modality: InteractionModality.touch,
                touchAvailable: true,
                precisePointerAvailable: false,
              ),
              child: SizedBox(
                width: 320,
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

    final input = find.byKey(
      const ValueKey('generation_prompt_positive_input'),
    );
    final narrowToolbarActions = [
      find.byKey(const ValueKey('generation_prompt_mobile_character_action')),
      find.byKey(const ValueKey('generation_prompt_mobile_fixed_tags_action')),
      find.byKey(const ValueKey('generation_prompt_mobile_quality_action')),
      find.byKey(const ValueKey('generation_prompt_mobile_uc_action')),
    ];
    for (final action in narrowToolbarActions) {
      expect(action, findsOneWidget);
      expect(tester.getSize(action).height, 48);
      await tester.ensureVisible(action);
      await tester.pump();
      expect(action.hitTestable(), findsOneWidget);
    }
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
    expect(
      tester.getRect(assistant).right,
      closeTo(tester.getRect(footer).right, 0.1),
    );
    expect(textField.decoration?.contentPadding, const EdgeInsets.all(12));
    expect(
      find.descendant(
        of: input,
        matching: find.byKey(const ValueKey('tag-mode-button')),
      ),
      findsOneWidget,
    );
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
      find.byKey(const ValueKey('generation_prompt_footer_actions_scroll')),
      findsOneWidget,
    );
    expect(transparent.hitTestable(), findsOneWidget);
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

    expect(count, findsOneWidget);
    expect(find.text('259 / 1471'), findsOneWidget);
    expect(
      find.descendant(
        of: assistant,
        matching: find.byIcon(Icons.auto_awesome_rounded),
      ),
      findsNothing,
    );
    expect(transparent, findsOneWidget);
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
    expect(
      tester
          .getRect(
            find.widgetWithIcon(IconButton, Icons.keyboard_arrow_down_rounded),
          )
          .right,
      closeTo(tester.getRect(footer).right, 0.1),
    );

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

class _ResponsivePromptHarness extends StatefulWidget {
  const _ResponsivePromptHarness({super.key});

  @override
  State<_ResponsivePromptHarness> createState() =>
      _ResponsivePromptHarnessState();
}

class _ResponsivePromptHarnessState extends State<_ResponsivePromptHarness> {
  final _promptKey = GlobalKey();
  var _compact = false;

  void toggleLayout() => setState(() => _compact = !_compact);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextButton(
        key: const ValueKey('toggle-responsive-prompt'),
        onPressed: toggleLayout,
        child: const Text('toggle'),
      ),
      Expanded(
        child: Container(
          key: const ValueKey('responsive-prompt-host'),
          alignment: Alignment.topCenter,
          padding: EdgeInsets.all(_compact ? 8 : 0),
          child: PromptInputWidget(key: _promptKey, compact: _compact),
        ),
      ),
    ],
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
