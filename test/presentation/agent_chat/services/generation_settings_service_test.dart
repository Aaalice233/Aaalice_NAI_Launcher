import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
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

  test('updateSettings rejects an empty request with a coded error', () async {
    final result = await service.updateSettings(const {});

    expect(result.isError, isTrue);
    expect(result.details, jsonDecode(_resultText(result)));
    expect(result.details['code'], 'missing_settings');
  });
}
