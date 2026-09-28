import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/widgets/common/model_family_icon.dart';
import 'package:nai_launcher/presentation/widgets/common/provider_icon.dart';
import 'package:nai_launcher/presentation/widgets/common/searchable_model_picker.dart';

const _provider = ProviderConfig(
  id: 'relay',
  name: 'OpenRouter',
  baseUrl: 'https://openrouter.ai/api/v1',
  preset: ProviderPreset.openaiCompatibleChat,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'model IDs identify common families independently of gateway and alias',
    () {
      final cases = <String, ModelFamily>{
        'google/gemini-3.1-pro': ModelFamily.gemini,
        'gemini-2.5-flash-image': ModelFamily.gemini,
        '金鱼奶': ModelFamily.gemini,
        'deepseek-ai/DeepSeek-V4-Flash': ModelFamily.deepseek,
        'deepseek-r1-distill-qwen-32b': ModelFamily.deepseek,
        'x-ai/grok-4': ModelFamily.grok,
        'openai/gpt-5.4': ModelFamily.openai,
        'o3-mini': ModelFamily.openai,
        'anthropic/claude-sonnet-4.6': ModelFamily.claude,
        'Qwen/Qwen3.5-35B-A3B': ModelFamily.qwen,
        'z-ai/glm-5': ModelFamily.glm,
        'moonshotai/kimi-k2.5': ModelFamily.kimi,
        'minimax-m2.5': ModelFamily.minimax,
        'mistralai/mistral-small-3': ModelFamily.mistral,
        'meta-llama/llama-4-scout': ModelFamily.llama,
        'nai-diffusion-4-5-full': ModelFamily.novelai,
        'google/gemma-3': ModelFamily.gemma,
        'doubao-seed-1.8': ModelFamily.doubao,
        'tencent/hunyuan-a13b': ModelFamily.hunyuan,
        'cohere/command-a': ModelFamily.cohere,
        'baidu/ernie-4.5': ModelFamily.wenxin,
        'stepfun/step-3.5-flash': ModelFamily.stepfun,
        'bytedance/seedream-4.5': ModelFamily.bytedance,
        'nvidia/nemotron-3-super': ModelFamily.nvidia,
        'microsoft/phi-4': ModelFamily.microsoft,
        'perplexity/sonar-pro': ModelFamily.perplexity,
        'amazon.nova-pro-v1:0': ModelFamily.nova,
        'xiaomi/mimo-v2-flash': ModelFamily.xiaomimimo,
        'black-forest-labs/flux.2-pro': ModelFamily.flux,
        'stable-diffusion-xl': ModelFamily.stability,
        'midjourney-v7': ModelFamily.midjourney,
        'dall-e-3': ModelFamily.dalle,
        'sora-2': ModelFamily.sora,
        'veo-3.1': ModelFamily.google,
        'kling-v3': ModelFamily.kling,
        '即梦': ModelFamily.jimeng,
        'hailuo-2.3': ModelFamily.hailuo,
        'runway/gen-4': ModelFamily.runway,
      };
      for (final entry in cases.entries) {
        expect(ModelFamily.resolve(entry.key), entry.value, reason: entry.key);
      }
      expect(
        ModelFamily.resolve('gpt-5', displayName: 'DeepSeek alias'),
        ModelFamily.openai,
      );
      expect(
        ModelFamily.resolve('deployment-1', displayName: 'Gemini Pro'),
        ModelFamily.gemini,
      );
      for (final name in [
        'unknown',
        'not-gpt-5',
        'deepseekish',
        'groq/model-x',
        'google/custom',
      ]) {
        expect(ModelFamily.resolve(name), isNull, reason: name);
      }
    },
  );

  test(
    'provider presets are covered without mistaking compatibility for OpenAI',
    () {
      for (final preset in ProviderPreset.values) {
        final generic =
            preset == ProviderPreset.openaiCompatibleChat ||
            preset == ProviderPreset.openaiCompatibleResponses;
        expect(
          providerIconAsset(preset: preset),
          generic ? isNull : isNotNull,
          reason: preset.name,
        );
      }
      expect(providerIconAsset(provider: _provider), 'openrouter-color');
      expect(ModelFamily.resolve('google/gemini-3'), ModelFamily.gemini);
      expect(
        providerIconAsset(
          provider: _provider.copyWith(
            name: 'Private relay',
            baseUrl: 'https://api.siliconflow.cn/v1',
          ),
        ),
        'siliconcloud-color',
      );
      expect(
        providerIconAsset(
          provider: _provider.copyWith(
            name: 'Private relay',
            baseUrl: 'https://api.openai.com.evil.test/v1',
          ),
        ),
        isNull,
      );
      expect(
        providerIconAsset(
          provider: _provider.copyWith(
            name: '硅基流动',
            baseUrl: 'https://relay.example/v1',
          ),
        ),
        'siliconcloud-color',
      );
      expect(
        providerIconAsset(
          provider: _provider.copyWith(
            name: 'Private relay',
            baseUrl: 'http://127.0.0.1:8080/v1',
          ),
        ),
        isNull,
      );
    },
  );

  test(
    'bundled artwork is decodable and small enough for offline use',
    () async {
      final files = Directory('assets/icons/ai_brands')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.png'))
          .toList();
      expect(files.length, 53);
      expect(
        files.fold<int>(0, (size, file) => size + file.lengthSync()),
        lessThan(600 * 1024),
      );
      for (final file in files) {
        final data = await rootBundle.load(file.path.replaceAll('\\', '/'));
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetWidth: 24,
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 24, reason: file.path);
        frame.image.dispose();
        codec.dispose();
      }
      for (final family in ModelFamily.values) {
        expect(
          File(family.assetPath).existsSync(),
          isTrue,
          reason: family.name,
        );
      }
      for (final preset in ProviderPreset.values) {
        final asset = providerIconAsset(preset: preset);
        if (asset != null) {
          expect(
            File('assets/icons/ai_brands/$asset.png').existsSync(),
            isTrue,
          );
        }
      }
    },
  );

  testWidgets(
    'monochrome logos follow light and dark themes and remain decorative',
    (tester) async {
      for (final brightness in Brightness.values) {
        final theme = ThemeData(brightness: brightness);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(body: ModelNameLabel(modelId: 'gpt-5')),
          ),
        );
        await tester.pumpAndSettle();
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.color, theme.colorScheme.onSurface);
        expect(image.excludeFromSemantics, isTrue);
        expect(find.text('gpt-5'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ModelNameLabel(modelId: 'custom-model')),
        ),
      );
      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
      expect(find.text('custom-model'), findsOneWidget);
    },
  );

  testWidgets(
    'model and provider icons survive search and selection at all widths',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const options = [
        ModelPickerOption(
          id: 'google/gemini-3',
          modelId: 'google/gemini-3',
          value: 'gemini',
          title: 'Gemini long model display name',
          subtitle: 'OpenRouter',
          subtitleLeading: ProviderIcon(provider: _provider, size: 14),
        ),
        ModelPickerOption(
          id: 'deepseek-v4-flash',
          modelId: 'deepseek-v4-flash',
          value: 'deepseek',
          title: 'DeepSeek V4 Flash',
          subtitle: 'OpenRouter',
          subtitleLeading: ProviderIcon(provider: _provider, size: 14),
        ),
      ];
      for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
        await tester.binding.setSurfaceSize(Size(width, 420));
        String? selected;
        final scroll = ScrollController();
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 420),
                textScaler: const TextScaler.linear(3),
                padding: const EdgeInsets.only(bottom: 20),
                viewInsets: const EdgeInsets.only(bottom: 50),
              ),
              child: Scaffold(
                body: SearchableModelPickerBody<String>(
                  title: 'Select model',
                  searchLabel: 'Search',
                  searchHint: 'Name',
                  clearSearchTooltip: 'Clear',
                  emptyMessage: 'No results',
                  options: options,
                  selectedId: 'google/gemini-3',
                  scrollController: scroll,
                  onSelected: (option) => selected = option.value,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ModelFamilyIcon), findsNWidgets(2));
        expect(find.byType(ProviderIcon), findsNWidgets(2));
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'DeepSeek');
        await tester.pumpAndSettle();
        expect(find.byType(ModelFamilyIcon), findsOneWidget);
        await tester.tap(find.text('DeepSeek V4 Flash'));
        await tester.pump();
        expect(selected, 'deepseek');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        scroll.dispose();
      }
    },
  );
}
