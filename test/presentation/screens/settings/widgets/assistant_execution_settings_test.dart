import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_presenter.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/assistant_execution_settings.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/assistant_task_thinking_field.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/prompt_assistant_settings_forms.dart';

Widget app(Widget child, {double scale = 1}) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: SafeArea(child: child)),
);

void main() {
  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('provider concurrency saves at $width / ${scale}x', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        PromptAssistantProviderFormResult? result;
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  result =
                      await AdaptivePresenter.showForm<
                        PromptAssistantProviderFormResult
                      >(
                        context: context,
                        title: '提供商',
                        dialogWidth: 520,
                        builder: (context, controller) =>
                            PromptAssistantProviderForm(
                              scrollController: controller,
                            ),
                      );
                },
                child: const Text('打开'),
              ),
            ),
            scale: scale,
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        final mode = find.byKey(const ValueKey('assistant-concurrency-mode'));
        await tester.scrollUntilVisible(mode, 180, scrollable: find.descendant(of: find.byType(PromptAssistantProviderForm), matching: find.byType(Scrollable)).first);
        await tester.pumpAndSettle();
        expect(find.text('自动'), findsOneWidget);
        await tester.tap(mode);
        await tester.pumpAndSettle();
        await tester.tap(find.text('手动').last);
        await tester.pumpAndSettle();
        final count = find.byKey(const ValueKey('assistant-concurrency-count'));
        await tester.scrollUntilVisible(count, 180, scrollable: find.descendant(of: find.byType(PromptAssistantProviderForm), matching: find.byType(Scrollable)).first);
        await tester.enterText(count, '7');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(result?.concurrency.mode, AssistantConcurrencyMode.manual);
        expect(result?.concurrency.maxConcurrentRequests, 7);
        expect(tester.takeException(), isNull);
      });

      testWidgets('thinking choices remain reachable at $width / ${scale}x', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 500);
        addTearDown(tester.view.reset);
        var value = AssistantThinkingLevel.automatic;
        await tester.pumpWidget(
          app(
            StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AssistantTaskThinkingField(
                  task: AssistantTaskType.translate,
                  provider: ProviderPreset.deepseek.createConfig(),
                  model: 'deepseek-v4-flash',
                  value: value,
                  onChanged: (next) => setState(() => value = next),
                ),
              ),
            ),
            scale: scale,
          ),
        );
        await tester.tap(
          find.byType(DropdownButtonFormField<AssistantThinkingLevel>),
        );
        await tester.pumpAndSettle();
        final maximum = find.text('最大').last;
        await tester.ensureVisible(maximum);
        await tester.tap(maximum);
        await tester.pumpAndSettle();
        expect(value, AssistantThinkingLevel.max);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'binary models expose On/Off and unknown models use their default',
    (tester) async {
      await tester.pumpWidget(
        app(
          Column(
            children: [
              AssistantTaskThinkingField(
                task: AssistantTaskType.translate,
                provider: ProviderPreset.moonshot.createConfig(),
                model: 'kimi-k2.5',
                value: AssistantThinkingLevel.high,
                onChanged: (_) {},
              ),
              AssistantTaskThinkingField(
                task: AssistantTaskType.llm,
                provider: ProviderPreset.openaiCompatibleChat.createConfig(),
                model: 'unknown',
                value: AssistantThinkingLevel.high,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      );
      final selectors = tester
          .widgetList<DropdownButtonFormField<AssistantThinkingLevel>>(
            find.byType(DropdownButtonFormField<AssistantThinkingLevel>),
          )
          .toList();
      expect(selectors.first.initialValue, AssistantThinkingLevel.high);
      expect(selectors.last.initialValue, AssistantThinkingLevel.automatic);
      expect(find.text('开启'), findsOneWidget);
      expect(find.text('未识别到可调思考等级，使用模型默认行为。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manual input stays usable with short landscape, IME and SafeArea',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(840, 400);
      tester.view.viewInsets = const FakeViewPadding(bottom: 140);
      tester.view.padding = const FakeViewPadding(
        left: 24,
        right: 24,
        bottom: 12,
      );
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        app(
          PromptAssistantProviderForm(
            scrollController: controller,
            provider: ProviderPreset.deepseek.createConfig().copyWith(
              concurrency: const AssistantConcurrencySettings(
                mode: AssistantConcurrencyMode.manual,
                maxConcurrentRequests: 4,
              ),
            ),
          ),
        ),
      );
      final count = find.byKey(const ValueKey('assistant-concurrency-count'));
      await tester.scrollUntilVisible(count, 180, scrollable: find.descendant(of: find.byType(PromptAssistantProviderForm), matching: find.byType(Scrollable)).first);
      await tester.enterText(count, '');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('请输入大于 0 的整数'), findsOneWidget);
      expect(find.text('保存').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
