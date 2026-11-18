import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/services/prompt_token_counter_service.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_history_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/prompt_assistant_service.dart';
import 'package:nai_launcher/presentation/prompt_assistant/widgets/prompt_assistant_overlay.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/prompt_token_counter_provider.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/mobile_generation_controller.dart';
import 'package:nai_launcher/presentation/screens/generation/mobile_generation_view_data.dart';
import 'package:nai_launcher/presentation/screens/generation/mobile_generation_workspace.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input_controller.dart';

import '../../../helpers/controlled_prompt_assistant_service.dart';
import '../../../helpers/memory_local_storage.dart';

void main() {
  testWidgets('竖屏隐藏的提示词输入框静音，横屏显示后恢复且保留编辑器状态', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final prompt = PromptInputController(prompt: '', negativePrompt: '');
    addTearDown(prompt.dispose);
    final maximized = ValueNotifier(false);
    addTearDown(maximized.dispose);
    await tester.pumpWidget(_workspace(prompt: prompt, maximized: maximized));
    await tester.pump();
    final input = find.byType(PromptInputWidget, skipOffstage: false);
    final inputState = tester.state(input);
    expect(find.byType(PromptInputWidget), findsNothing);
    expect(TickerMode.valuesOf(tester.element(input)).enabled, isFalse);
    prompt.promptController.text = 'retained prompt';
    await tester.pump();

    await tester.binding.setSurfaceSize(const Size(800, 360));
    await tester.pump();
    expect(find.byType(PromptInputWidget), findsOneWidget);
    expect(TickerMode.valuesOf(tester.element(input)).enabled, isTrue);
    expect(tester.state(input), same(inputState));
    expect(prompt.promptController.text, 'retained prompt');

    await tester.binding.setSurfaceSize(const Size(390, 820));
    await tester.pump();
    expect(TickerMode.valuesOf(tester.element(input)).enabled, isFalse);
    expect(tester.state(input), same(inputState));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (scenario, nextWidth, keyboardInset) in [
    ('收起全屏回到竖屏摘要', null, null),
    ('跨过全屏的宽度断点', 680.0, null),
    ('软键盘跨过全屏的高度断点', null, 580.0),
  ]) {
    testWidgets('$scenario时主提示词翻译继续并写回', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      if (keyboardInset != null) {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }
      final prompt = PromptInputController(
        prompt: 'original prompt',
        negativePrompt: '',
      );
      final maximized = ValueNotifier(true);
      final service = ControlledPromptAssistantService();
      addTearDown(prompt.dispose);
      addTearDown(maximized.dispose);
      addTearDown(service.dispose);

      await tester.pumpWidget(
        _workspace(prompt: prompt, maximized: maximized, service: service),
      );
      await tester.pumpAndSettle();

      final assistant = find.byType(
        PromptAssistantOverlay,
        skipOffstage: false,
      );
      final assistantState = tester.state(assistant);
      final container = ProviderScope.containerOf(tester.element(assistant));
      final workbench = find.byKey(
        const ValueKey('generation_prompt_mobile_workbench'),
      );
      expect(workbench, findsOneWidget);
      await tester.tap(
        find.descendant(
          of: assistant,
          matching: find.byIcon(Icons.auto_awesome_rounded),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: assistant, matching: find.byIcon(Icons.translate)),
      );
      await tester.pump();
      expect(service.requests, [PromptHistorySessionIds.generationPrompt]);
      expect(service.stream.hasListener, isTrue);

      if (keyboardInset != null) {
        tester.view.viewInsets = FakeViewPadding(
          bottom: keyboardInset * tester.view.devicePixelRatio,
        );
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();
        expect(
          find.ancestor(
            of: find.byKey(const ValueKey('generation_prompt_footer')),
            matching: find.byType(SingleChildScrollView),
          ),
          findsOneWidget,
        );
      } else if (nextWidth != null) {
        await tester.binding.setSurfaceSize(Size(nextWidth, 820));
        await tester.pump();
        expect(workbench, findsNothing);
      } else {
        maximized.value = false;
        await tester.pump();
        expect(find.byType(MobileCollapsedPromptLauncher), findsOneWidget);
        expect(find.byType(PromptAssistantOverlay), findsNothing);
        expect(
          find.byKey(
            const ValueKey('generation_prompt_compact_scroll'),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
      }
      expect(service.cancellations, isEmpty);
      expect(service.stream.hasListener, isTrue);
      expect(assistant, findsOneWidget);
      expect(tester.state(assistant), same(assistantState));

      service.respond('translated prompt');
      await tester.pump();
      expect(prompt.promptController.text, 'translated prompt');
      expect(
        container.read(generationParamsNotifierProvider).prompt,
        'translated prompt',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('移动端提示词概览将字数放在第二行右侧且摘要占满剩余宽度', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 160));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_subject(prompt: List.filled(632, 'a').join()));
    await tester.pumpAndSettle();

    final primaryRow = find.byKey(
      const ValueKey('generation-prompt-overview-primary-row'),
    );
    final secondaryRow = find.byKey(
      const ValueKey('generation-prompt-overview-secondary-row'),
    );
    final characters = find.byKey(
      const ValueKey('generation-prompt-overview-characters'),
    );
    final launcher = find.byKey(
      const ValueKey('generation-collapsed-prompt-launcher'),
    );
    final summaryFinder = find.byKey(
      const ValueKey('generation-prompt-overview-summary'),
    );
    final summary = tester.widget<Text>(summaryFinder);

    expect(find.text('632 字'), findsOneWidget);
    expect(summary.softWrap, isFalse);
    expect(
      tester.getRect(summaryFinder).right,
      closeTo(tester.getRect(launcher).right - 10, 0.1),
    );
    expect(tester.getSize(summaryFinder).width, greaterThan(200));
    expect(
      tester.getCenter(primaryRow).dy,
      lessThan(tester.getCenter(characters).dy),
    );
    expect(
      tester.getCenter(secondaryRow).dy,
      closeTo(tester.getCenter(characters).dy, 0.1),
    );
    expect(find.byIcon(Icons.open_in_full_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 宽度与 3x 文本下提示词概览不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _subject(
        prompt: List.filled(120, 'a').join(),
        textScaler: const TextScaler.linear(3),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('generation-prompt-overview-characters')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.open_in_full_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _workspace({
  required PromptInputController prompt,
  required ValueNotifier<bool> maximized,
  PromptAssistantService? service,
}) {
  final controller = _WorkspaceController();
  final promptKey = GlobalKey();
  final storage = MemoryLocalStorage()
    ..values[StorageKeys.lastPrompt] = prompt.promptController.text
    ..values[StorageKeys.enableAutocomplete] = false;
  return ProviderScope(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      characterPromptNotifierProvider.overrideWith(_EmptyCharacters.new),
      imageGenerationNotifierProvider.overrideWith(_IdleGeneration.new),
      queueExecutionNotifierProvider.overrideWith(_IdleQueue.new),
      shortcutConfigNotifierProvider.overrideWith(_DefaultShortcuts.new),
      if (service != null)
        promptAssistantServiceProvider.overrideWithValue(service),
      for (final target in PromptTokenCountTarget.values)
        promptTokenUsageProvider(target).overrideWith(
          (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 512),
        ),
    ],
    child: MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: maximized,
          builder: (context, isMaximized, child) => MobileGenerationWorkspace(
            controller: controller,
            data: MobileGenerationViewData(
              batchStatus: (
                isGenerating: false,
                isPreparing: false,
                currentImage: 0,
                totalImages: 0,
              ),
              cooldownRemainingSeconds: 0,
              isPromptMaximized: isMaximized,
              isSelectionMode: false,
              isFixedTagsOverlayVisible: false,
              keyboardVisible: false,
              isGenerating: false,
              isLauncherGenerating: false,
              requiresLogin: false,
              showRandomTools: false,
              isUpscaleMode: false,
              randomModeEnabled: false,
              promptSummary: '',
              enabledCharacterCount: 0,
              qualityEnabled: false,
              negativePresetLabel: null,
              fixedTagCount: 0,
            ),
            promptInputController: prompt,
            promptInputKey: promptKey,
          ),
        ),
      ),
    ),
  );
}

Widget _subject({required String prompt, TextScaler? textScaler}) =>
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: MobileCollapsedPromptLauncher(
              prompt: prompt,
              characterCount: 1,
              qualityEnabled: true,
              negativePresetLabel: '负面预设',
              fixedTagCount: 2,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

class _WorkspaceController extends Mock implements MobileGenerationController {
  @override
  bool get agentFullScreen => false;

  @override
  bool get workspacePointerActive => false;

  @override
  double get workspaceDragFeedback => 0;

  @override
  bool get showGestureHint => false;

  @override
  final embeddedPromptKey = GlobalKey();
}

class _IdleGeneration extends ImageGenerationNotifier {
  @override
  ImageGenerationState build() => const ImageGenerationState();
}

class _IdleQueue extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() => const QueueExecutionState();
}

class _EmptyCharacters extends CharacterPromptNotifier {
  @override
  CharacterPromptConfig build() => const CharacterPromptConfig();
}

class _DefaultShortcuts extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}
