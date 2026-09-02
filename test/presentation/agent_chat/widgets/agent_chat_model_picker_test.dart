import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_model_picker.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';

void main() {
  testWidgets(
    'model and reasoning are independent controls with visible values',
    (tester) async {
      await _pumpControls(tester, width: 520);

      expect(
        find.byKey(const ValueKey('agent-chat-model-selector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('agent-chat-thinking-selector')),
        findsOneWidget,
      );
      expect(find.text('Model:'), findsOneWidget);
      expect(find.text('Aurora Chat'), findsOneWidget);
      expect(find.text('Reasoning effort:'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('model search matches display name model id and provider', (
    tester,
  ) async {
    await _pumpControls(tester, width: 840);
    await tester.tap(find.byKey(const ValueKey('agent-chat-model-selector')));
    await tester.pumpAndSettle();

    final search = find.byKey(const ValueKey('agent-chat-model-search'));
    final results = find.byKey(const ValueKey('agent-chat-model-results'));
    expect(search, findsOneWidget);

    await tester.enterText(search, 'nebula');
    await tester.pump();
    expect(
      find.descendant(of: results, matching: find.text('Nebula Reasoner')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: results, matching: find.text('Aurora Chat')),
      findsNothing,
    );

    await tester.enterText(search, 'aurora-chat-v2');
    await tester.pump();
    expect(
      find.descendant(of: results, matching: find.text('Aurora Chat')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: results, matching: find.text('Nebula Reasoner')),
      findsNothing,
    );

    await tester.enterText(search, 'second cloud');
    await tester.pump();
    expect(
      find.descendant(of: results, matching: find.text('Nebula Reasoner')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('search supports empty results clearing and keyboard selection', (
    tester,
  ) async {
    String? selectedProvider;
    String? selectedModel;
    await _pumpControls(
      tester,
      width: 840,
      onModelSelected: (provider, model) async {
        selectedProvider = provider;
        selectedModel = model;
      },
    );
    await tester.tap(find.byKey(const ValueKey('agent-chat-model-selector')));
    await tester.pumpAndSettle();

    final search = find.byKey(const ValueKey('agent-chat-model-search'));
    await tester.enterText(search, 'missing-model');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('agent-chat-model-empty')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('agent-chat-model-search-clear')),
    );
    await tester.pump();
    final results = find.byKey(const ValueKey('agent-chat-model-results'));
    expect(
      find.descendant(of: results, matching: find.text('Aurora Chat')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: results, matching: find.text('Nebula Reasoner')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(selectedProvider, 'second-cloud');
    expect(selectedModel, 'nebula-reasoner-2026');
  });

  testWidgets('mobile picker filters a large model catalog without overflow', (
    tester,
  ) async {
    final largeConfig = _config.copyWith(
      models: [
        ..._config.models,
        for (var index = 0; index < 240; index++)
          ModelConfig(
            providerId: 'second-cloud',
            name: 'bulk-model-$index',
            displayName: 'Bulk model $index with a deliberately long name',
            forTask: AssistantTaskType.chat,
          ),
      ],
    );
    await _pumpControls(tester, width: 320, config: largeConfig);
    await tester.tap(find.byKey(const ValueKey('agent-chat-model-selector')));
    await tester.pumpAndSettle();

    final search = find.byKey(const ValueKey('agent-chat-model-search'));
    await tester.enterText(search, 'bulk-model-239');
    await tester.pump();

    expect(
      find.text('Bulk model 239 with a deliberately long name'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'picker stays scrollable and selectable at 320 with 3x text safe area and IME',
    (tester) async {
      String? selectedModel;
      await _pumpControls(
        tester,
        width: 320,
        height: 900,
        textScaler: const TextScaler.linear(3),
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
        viewInsets: const EdgeInsets.only(bottom: 320),
        onModelSelected: (_, model) async => selectedModel = model,
      );
      expect(tester.takeException(), isNull, reason: 'closed controls');

      await tester.tap(find.byKey(const ValueKey('agent-chat-model-selector')));
      await tester.pumpAndSettle();

      final sheet = find.byKey(const ValueKey('adaptive-bottom-sheet'));
      final search = find.byKey(const ValueKey('agent-chat-model-search'));
      expect(sheet, findsOneWidget);
      expect(search, findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.enterText(search, 'nebula');
      await tester.pump();
      final option = find.byKey(
        const ValueKey(
          'agent-chat-model-option-second-cloud-nebula-reasoner-2026',
        ),
      );
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();

      expect(selectedModel, 'nebula-reasoner-2026');
      expect(sheet, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reasoning picker exposes only supported levels', (tester) async {
    ThinkingLevel? selected;
    await _pumpControls(
      tester,
      width: 520,
      levels: const [ThinkingLevel.off, ThinkingLevel.high],
      onThinkingSelected: (level) async => selected = level,
    );

    await tester.tap(
      find.byKey(const ValueKey('agent-chat-thinking-selector')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Off'), findsOneWidget);
    expect(find.text('High'), findsWidgets);
    expect(find.text('Low'), findsNothing);
    expect(find.text('Medium'), findsNothing);

    await tester.tap(find.text('Off'));
    await tester.pumpAndSettle();
    expect(selected, ThinkingLevel.off);
  });

  testWidgets('controls remain overflow-free on compact and expanded widths', (
    tester,
  ) async {
    for (final width in const [320.0, 412.0, 600.0, 840.0]) {
      await _pumpControls(
        tester,
        width: width,
        textScaler: const TextScaler.linear(2),
      );
      expect(find.text('High'), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'overflow at width=$width',
      );
    }
  });
}

Future<void> _pumpControls(
  WidgetTester tester, {
  required double width,
  double height = 720,
  double devicePixelRatio = 1,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  TextScaler textScaler = TextScaler.noScaling,
  List<ThinkingLevel> levels = const [
    ThinkingLevel.off,
    ThinkingLevel.low,
    ThinkingLevel.high,
  ],
  PromptAssistantConfigState? config,
  Future<void> Function(String provider, String model)? onModelSelected,
  Future<void> Function(ThinkingLevel level)? onThinkingSelected,
}) async {
  await tester.binding.setSurfaceSize(Size(width, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          devicePixelRatio: devicePixelRatio,
          padding: padding,
          viewPadding: padding,
          viewInsets: viewInsets,
          textScaler: textScaler,
        ),
        child: child!,
      ),
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Builder(
              builder: (context) {
                final model = AgentChatModelControl(
                  config: config ?? _config,
                  agentSettings: _settings,
                  routeLabel: 'First Cloud / aurora-chat-v2',
                  routeError: '',
                  enabled: true,
                  onSelected: onModelSelected ?? (_, _) async {},
                );
                final thinking = SizedBox(
                  width: 180,
                  child: AgentChatThinkingControl(
                    level: ThinkingLevel.high,
                    availableLevels: levels,
                    enabled: true,
                    onSelected: onThinkingSelected ?? (_) async {},
                  ),
                );
                if (width < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      model,
                      const SizedBox(height: 4),
                      Align(alignment: Alignment.centerRight, child: thinking),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: model),
                    const SizedBox(width: 4),
                    thinking,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

final _config = PromptAssistantConfigState.defaults().copyWith(
  providers: const [
    ProviderConfig(
      id: 'first-cloud',
      name: 'First Cloud',
      baseUrl: 'https://first.example',
    ),
    ProviderConfig(
      id: 'second-cloud',
      name: 'Second Cloud',
      baseUrl: 'https://second.example',
    ),
  ],
  models: const [
    ModelConfig(
      providerId: 'first-cloud',
      name: 'aurora-chat-v2',
      displayName: 'Aurora Chat',
      forTask: AssistantTaskType.chat,
    ),
    ModelConfig(
      providerId: 'second-cloud',
      name: 'nebula-reasoner-2026',
      displayName: 'Nebula Reasoner',
      forTask: AssistantTaskType.chat,
    ),
    ModelConfig(
      providerId: 'second-cloud',
      name: 'default-model',
      displayName: 'Placeholder',
      forTask: AssistantTaskType.chat,
    ),
  ],
);

const _settings = AgentSettingsState(
  initialized: true,
  settings: AgentSettings(
    chat: AgentChatConfig(
      modelReference: AgentModelReference(
        providerId: 'first-cloud',
        model: 'aurora-chat-v2',
      ),
    ),
  ),
);
