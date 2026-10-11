import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/enums/image_model_mode.dart';
import 'package:nai_launcher/data/models/image/image_params.dart'
    show ImageParams;
import 'package:nai_launcher/presentation/agent_chat/services/generation_settings_service.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';

final _refProvider = Provider<Ref>((ref) => ref);

String _resultText(AgentToolResult result) => result.content
    .whereType<ToolResultTextContent>()
    .map((content) => content.text)
    .join();

class _MemoryGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() => const ImageParams(steps: 28);

  @override
  void updateSteps(int steps) {
    state = state.copyWith(steps: steps);
  }

  @override
  void updateModel(
    String model, {
    bool persist = true,
    bool followDefaults = true,
  }) {
    state = state.copyWith(model: model);
  }

  @override
  void updateModelMode(ImageModelMode modelMode) {
    state = state.copyWith(modelMode: modelMode);
  }
}

void main() {
  late GenerationSettingsService service;

  setUp(() {
    final container = ProviderContainer(
      overrides: [
        generationParamsNotifierProvider.overrideWith(
          _MemoryGenerationParamsNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    service = GenerationSettingsService(container.read(_refProvider));
  });

  test('settingsJson is a JSON object rather than a serialized string', () {
    final settings = service.settingsJson();

    expect(settings['steps'], 28);
    expect(settings['available_models'], isA<List<Object?>>());
  });

  test('updateSettings echoes applied fields and the current object', () async {
    final result = await service.updateSettings({'steps': 20});

    expect(result.isError, isFalse);
    expect(result.details, jsonDecode(_resultText(result)));
    expect(result.details['applied'], {'steps': 20});
    expect(result.details['current'], isA<Map<Object?, Object?>>());
    expect(result.details['current']['steps'], 20);
  });

  test(
    'effort medium switches V5 Full and reports the sent settings',
    () async {
      final result = await service.updateSettings({'effort': 'medium'});

      expect(result.isError, isFalse);
      expect(result.details['applied'], {'effort': 'medium'});
      final current = result.details['current'] as Map<Object?, Object?>;
      expect(current['model'], ImageModels.animeDiffusionV5FullMedium);
      expect(current['effort'], 'medium');
      expect(current['steps'], 14);
      expect(current['sampler'], Samplers.kEulerAncestral);
      expect(current['locked_by_effort'], contains('negative_prompt'));
    },
  );

  test('effort is rejected before anything changes on other models', () async {
    final result = await service.updateSettings({
      'model': 'v4.5 full',
      'effort': 'medium',
    });

    expect(result.isError, isTrue);
    expect(result.details['code'], 'effort_unavailable');
    expect(service.settingsJson()['model'], ImageModels.animeDiffusionV5Full);
  });

  test('friendly medium aliases resolve to the medium model', () async {
    final result = await service.updateSettings({'model': 'v5 medium'});

    expect(result.details['applied'], {
      'model': ImageModels.animeDiffusionV5FullMedium,
    });
  });

  test('model_mode switches between anime and furry', () async {
    final result = await service.updateSettings({'model_mode': 'furry'});

    expect(result.details['applied'], {'model_mode': 'furry'});
    expect(result.details['current']['model_mode'], 'furry');
    expect(result.details['current']['model_mode_applies'], isTrue);

    final invalid = await service.updateSettings({'model_mode': 'robot'});
    expect(invalid.details['code'], 'unknown_model_mode');
  });

  test('updateSettings rejects an empty request with a coded error', () async {
    final result = await service.updateSettings(const {});

    expect(result.isError, isTrue);
    expect(result.details, jsonDecode(_resultText(result)));
    expect(result.details['code'], 'missing_settings');
  });
}
