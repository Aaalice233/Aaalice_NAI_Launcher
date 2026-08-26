import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/image/image_params.dart'
    show ImageParams;
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';

void main() {
  const existingCharacter = CharacterPrompt(
    id: 'existing-character',
    name: 'Existing',
    prompt: 'existing prompt',
  );

  ProviderContainer buildContainer(
    ReplicationTask task, {
    List<CharacterPrompt> initialCharacters = const [existingCharacter],
  }) {
    return ProviderContainer(
      overrides: [
        replicationQueueNotifierProvider.overrideWith(
          () => _TestReplicationQueueNotifier([task]),
        ),
        queueExecutionNotifierProvider.overrideWith(
          _TestQueueExecutionNotifier.new,
        ),
        generationParamsNotifierProvider.overrideWith(
          _TestGenerationParamsNotifier.new,
        ),
        characterPromptNotifierProvider.overrideWith(
          () => _TestCharacterPromptNotifier(initialCharacters),
        ),
      ],
    );
  }

  test('旧任务没有角色快照时保留当前角色', () {
    final task = ReplicationTask.create(prompt: 'queued prompt');
    final container = buildContainer(task);
    addTearDown(container.dispose);

    container.read(queueExecutionNotifierProvider.notifier).prepareNextTask();

    expect(container.read(characterPromptNotifierProvider).characters, const [
      existingCharacter,
    ]);
    expect(
      container.read(generationParamsNotifierProvider).prompt,
      'queued prompt',
    );
  });

  test('法典队列任务显式应用负向提示词', () {
    final task = ReplicationTask.create(
      prompt: 'queued prompt',
      negativePrompt: 'lowres, bad hands',
      applyNegativePrompt: true,
    );
    final container = buildContainer(task);
    addTearDown(container.dispose);

    container.read(queueExecutionNotifierProvider.notifier).prepareNextTask();

    expect(
      container.read(generationParamsNotifierProvider).negativePrompt,
      'lowres, bad hands',
    );
  });

  test('显式空角色快照会清空当前角色', () {
    final task = ReplicationTask.create(
      prompt: 'queued prompt',
      characterPrompts: const [],
    );
    final container = buildContainer(task);
    addTearDown(container.dispose);

    container.read(queueExecutionNotifierProvider.notifier).prepareNextTask();

    expect(container.read(characterPromptNotifierProvider).characters, isEmpty);
  });

  test('显式角色快照会按 CharacterPrompt 语义替换当前角色', () {
    final snapshot = ReplicationCharacterPromptSnapshot.fromCharacterPrompt(
      const CharacterPrompt(
        id: 'source-character',
        name: 'Source',
        prompt: '1girl, red hair',
        negativePrompt: 'bad hands',
        positionMode: CharacterPositionMode.custom,
        customPosition: CharacterPosition(
          mode: CharacterPositionMode.custom,
          row: 0.2,
          column: 0.8,
        ),
        enabled: false,
      ),
    );
    final task = ReplicationTask.create(
      prompt: 'queued prompt',
      characterPrompts: [snapshot],
    );
    final container = buildContainer(task);
    addTearDown(container.dispose);

    container.read(queueExecutionNotifierProvider.notifier).prepareNextTask();

    final restored = container
        .read(characterPromptNotifierProvider)
        .characters
        .single;
    expect(restored.id, '${task.id}-character-0');
    expect(restored.name, 'Character 1');
    expect(restored.prompt, '1girl, red hair');
    expect(restored.negativePrompt, 'bad hands');
    expect(restored.enabled, isFalse);
    expect(restored.positionMode, CharacterPositionMode.custom);
    expect(restored.customPosition?.row, 0.2);
    expect(restored.customPosition?.column, 0.8);
  });
}

class _TestReplicationQueueNotifier extends ReplicationQueueNotifier {
  _TestReplicationQueueNotifier(this.tasks);

  final List<ReplicationTask> tasks;

  @override
  ReplicationQueueState build() => ReplicationQueueState(tasks: tasks);
}

class _TestQueueExecutionNotifier extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() => const QueueExecutionState();
}

class _TestGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() => const ImageParams();

  @override
  void updatePrompt(String prompt) {
    state = state.copyWith(prompt: prompt);
  }

  @override
  void updateNegativePrompt(String negativePrompt) {
    state = state.copyWith(negativePrompt: negativePrompt);
  }
}

class _TestCharacterPromptNotifier extends CharacterPromptNotifier {
  _TestCharacterPromptNotifier(this.initialCharacters);

  final List<CharacterPrompt> initialCharacters;

  @override
  CharacterPromptConfig build() =>
      CharacterPromptConfig(characters: initialCharacters);

  @override
  void replaceAll(List<CharacterPrompt> characters) {
    state = state.copyWith(characters: characters);
  }
}
