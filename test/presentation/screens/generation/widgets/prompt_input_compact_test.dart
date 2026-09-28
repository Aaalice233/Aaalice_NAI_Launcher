import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/services/prompt_token_counter_service.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/prompt_token_counter_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input.dart';

void main() {
  testWidgets('紧凑模式会显示正向 token 计数', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) {
            return _TestLocalStorageService();
          }),
          promptTokenUsageProvider(
            PromptTokenCountTarget.positive,
          ).overrideWith(
            (ref) async => const PromptTokenUsage(usedTokens: 12, limit: 512),
          ),
        ],
        child: const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 720,
                height: 160,
                child: PromptInputWidget(compact: true),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('12 / 512'), findsOneWidget);
  });

  testWidgets('V5 紧凑模式会在提示词框下方显示透明背景开关', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => _TestLocalStorageService(
              defaultModel: 'nai-diffusion-5-curated',
            ),
          ),
          promptTokenUsageProvider(
            PromptTokenCountTarget.positive,
          ).overrideWith(
            (ref) async => const PromptTokenUsage(usedTokens: 12, limit: 703),
          ),
        ],
        child: const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 720,
                height: 160,
                child: PromptInputWidget(compact: true),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final input = find.byKey(const ValueKey('generation_prompt_compact_input'));
    final transparent = find.byKey(
      const ValueKey('generation_transparent_background_toggle'),
    );
    final count = find.byKey(const ValueKey('generation_prompt_footer_count'));
    final assistant = find.byKey(
      const ValueKey('prompt_assistant_toolbar_generation_prompt_main'),
    );

    expect(transparent, findsOneWidget);
    expect(find.text('12 / 703'), findsOneWidget);
    expect(assistant, findsOneWidget);
    expect(
      tester.getRect(transparent).top,
      greaterThanOrEqualTo(tester.getRect(input).bottom),
    );
    expect(
      tester.getRect(transparent).right,
      lessThanOrEqualTo(tester.getRect(count).left),
    );
    expect(
      tester.getRect(assistant).bottom,
      lessThanOrEqualTo(tester.getRect(input).bottom),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('手机紧凑输入面填满可用高度并显示完整引导文案', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => _TestLocalStorageService(),
          ),
          promptTokenUsageProvider(
            PromptTokenCountTarget.positive,
          ).overrideWith(
            (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 512),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 160,
                child: PromptInputWidget(compact: true),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final compactInput = find.byKey(
      const ValueKey('generation_prompt_compact_input'),
    );
    final textField = find.descendant(
      of: compactInput,
      matching: find.byType(TextField),
    );
    expect(compactInput, findsOneWidget);
    expect(textField, findsOneWidget);
    final field = tester.widget<TextField>(textField);
    final fieldSize = tester.getSize(textField);
    expect(fieldSize.height, greaterThan(90));
    expect(fieldSize.width, greaterThanOrEqualTo(358));
    expect(
      fieldSize.height - 24,
      greaterThanOrEqualTo(70),
      reason: '12px 上下内边距后仍应保留至少 70px 的可读高度',
    );
    expect(field.decoration?.contentPadding, const EdgeInsets.all(12));
    expect(field.decoration?.hintText, '描述你想生成的画面');
    expect(tester.takeException(), isNull);
  });

  testWidgets('紧凑输入助手位于编辑面内且底栏保留完整触控区域', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => _TestLocalStorageService(lastPrompt: '1girl'),
          ),
          promptTokenUsageProvider(
            PromptTokenCountTarget.positive,
          ).overrideWith(
            (ref) async => const PromptTokenUsage(usedTokens: 1, limit: 512),
          ),
        ],
        child: const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: InteractionPolicyScope(
            initialPolicy: InteractionPolicy(
              modality: InteractionModality.touch,
              touchAvailable: true,
              precisePointerAvailable: false,
            ),
            child: Scaffold(
              body: SizedBox(
                width: 360,
                height: 220,
                child: PromptInputWidget(compact: true),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final inputRect = tester.getRect(
      find.byKey(const ValueKey('generation_prompt_compact_input')),
    );
    final assistantButton = find.widgetWithIcon(
      IconButton,
      Icons.auto_awesome_rounded,
    );
    final fullscreenButton = find.widgetWithIcon(IconButton, Icons.fullscreen);
    final clearButton = find.widgetWithIcon(IconButton, Icons.clear);
    final assistantRect = tester.getRect(assistantButton);
    final fullscreenRect = tester.getRect(fullscreenButton);
    final clearRect = tester.getRect(clearButton);

    expect(assistantButton, findsOneWidget);
    expect(fullscreenButton, findsOneWidget);
    expect(clearButton, findsOneWidget);
    expect(assistantRect.top, greaterThanOrEqualTo(inputRect.top));
    expect(assistantRect.bottom, lessThanOrEqualTo(inputRect.bottom));
    expect(fullscreenRect.top, greaterThanOrEqualTo(inputRect.bottom));
    expect(clearRect.top, greaterThanOrEqualTo(inputRect.bottom));
    expect(assistantRect.size, const Size(48, 48));
    expect(fullscreenRect.size, const Size(48, 48));
    expect(clearRect.size, const Size(48, 48));

    await tester.tap(assistantButton);
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byIcon(Icons.translate), findsOneWidget);
    expect(
      tester.getRect(
        find.byKey(const ValueKey('generation_prompt_compact_input')),
      ),
      inputRect,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('键盘过渡的极小高度不会让紧凑输入区溢出', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => _TestLocalStorageService(),
          ),
          promptTokenUsageProvider(
            PromptTokenCountTarget.positive,
          ).overrideWith(
            (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 512),
          ),
        ],
        child: const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 40,
              child: PromptInputWidget(compact: true),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byKey(const ValueKey('generation_prompt_compact_input')),
      findsOneWidget,
    );
    expect(find.text('0 / 512'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('generation_prompt_footer_count')),
    );
    await tester.pump();
    expect(find.text('0 / 512').hitTestable(), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tag-mode-button')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _TestLocalStorageService extends LocalStorageService {
  _TestLocalStorageService({
    this.defaultModel = 'nai-diffusion-4-5-full',
    this.lastPrompt = '',
  });

  final String defaultModel;
  final String lastPrompt;

  @override
  bool getEnablePromptWeightScroll() => true;

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
  String getLastNegativePrompt() => '';

  @override
  String getDefaultModel() => defaultModel;

  @override
  bool getLastTransparentBackground() => false;

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
