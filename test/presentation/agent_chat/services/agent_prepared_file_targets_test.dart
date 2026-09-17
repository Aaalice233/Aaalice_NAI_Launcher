import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_prepared_file_targets.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_preparation_runtime.dart';

void main() {
  GenerationPreparation prepare(
    GenerationPreparationRuntime runtime, {
    String? savePath,
  }) => runtime.add(
    GenerationPreparation(
      kind: GenerationPreparationKind.generate,
      baseParams: const ImageParams(prompt: 'test'),
      params: const ImageParams(prompt: 'test'),
      batchSize: 1,
      count: 1,
      autoStart: false,
      estimatedAnlas: 0,
      arguments: const {'prompt': 'test'},
      savePath: savePath,
    ),
  );

  test('submit reports the save path registered by its preparation', () {
    final runtime = GenerationPreparationRuntime();
    final prepared = prepare(runtime, savePath: r'D:\art\out.png');

    for (final toolName in ['submit_generation', 'generate_image']) {
      expect(
        preparedFileTargets(toolName, {
          'preparation_id': prepared.id,
        }, generationRuntime: runtime),
        [r'D:\art\out.png'],
        reason: toolName,
      );
    }
  });

  test('submit without a registered save path reports no target', () {
    final runtime = GenerationPreparationRuntime();
    final prepared = prepare(runtime);

    expect(
      preparedFileTargets('submit_generation', {
        'preparation_id': prepared.id,
      }, generationRuntime: runtime),
      isEmpty,
    );
    expect(
      preparedFileTargets('generate_image', const {
        'prompt': 'inline',
      }, generationRuntime: runtime),
      isEmpty,
    );
    expect(
      preparedFileTargets('submit_generation', const {
        'preparation_id': 'unknown',
      }, generationRuntime: runtime),
      isEmpty,
    );
  });

  test('save_generated_image reports its own destination', () {
    final runtime = GenerationPreparationRuntime();

    expect(
      preparedFileTargets('save_generated_image', const {
        'destination_path': '/home/alice/out.png',
      }, generationRuntime: runtime),
      ['/home/alice/out.png'],
    );
    expect(
      preparedFileTargets('save_generated_image', const {
        'destination_path': '',
      }, generationRuntime: runtime),
      isEmpty,
    );
  });

  test('unrelated tools report no file target', () {
    final runtime = GenerationPreparationRuntime();

    expect(
      preparedFileTargets('search_tags', const {
        'destination_path': '/home/alice/out.png',
      }, generationRuntime: runtime),
      isEmpty,
    );
  });
}
