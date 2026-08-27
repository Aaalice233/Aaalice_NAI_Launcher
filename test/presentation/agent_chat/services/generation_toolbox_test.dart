import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/image/image_params.dart'
    show ImageParams;
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_toolbox.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';

final _refProvider = Provider<Ref>((ref) => ref);

Ref _makeRef(ProviderContainer container) => container.read(_refProvider);

void main() {
  test('registers image generation tools', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tools = GenerationToolbox(_makeRef(container)).tools();
    expect(
      tools.map((t) => t.name),
      containsAll([
        'interrogate_image',
        'generate_image',
        'queue_image_task',
        'get_generation_status',
      ]),
    );
  });

  test('queue_image_task rejects empty prompt', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tool = GenerationToolbox(
      _makeRef(container),
    ).tools().firstWhere((t) => t.name == 'queue_image_task');
    final result = await tool.execute('t2', {});
    final text = result.content
        .whereType<ToolResultTextContent>()
        .map((c) => c.text)
        .join();
    expect(text, contains('prompt'));
    expect(result.isError, isTrue);
  });

  test(
    'generate_image rejects empty prompt without touching providers',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final tool = GenerationToolbox(
        _makeRef(container),
      ).tools().firstWhere((t) => t.name == 'generate_image');
      final result = await tool.execute('t1', {});
      final text = result.content
          .whereType<ToolResultTextContent>()
          .map((c) => c.text)
          .join();
      expect(text, contains('prompt'));
      expect(result.isError, isTrue);
    },
  );

  test('generate_image rejects an excessive count before allocation', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tool = GenerationToolbox(
      _makeRef(container),
    ).tools().firstWhere((t) => t.name == 'generate_image');
    final result = await tool.execute('t-count', {
      'prompt': '1girl',
      'count': 1000000000,
    });
    final text = result.content
        .whereType<ToolResultTextContent>()
        .map((c) => c.text)
        .join();
    expect(text, contains('${GenerationToolbox.maxGenerateCount}'));
  });

  test('generate_image rejects incompatible resolutions', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tool = GenerationToolbox(
      _makeRef(container),
    ).tools().firstWhere((t) => t.name == 'generate_image');

    final offGrid = await tool.execute('t-off-grid', {
      'prompt': '1girl',
      'width': 65,
      'height': 64,
    });
    final tooManyPixels = await tool.execute('t-too-large', {
      'prompt': '1girl',
      'width': 4096,
      'height': 4096,
    });

    expect(offGrid.isError, isTrue);
    expect(
      offGrid.content.whereType<ToolResultTextContent>().single.text,
      contains('multiples of 64'),
    );
    expect(tooManyPixels.isError, isTrue);
    expect(
      tooManyPixels.content.whereType<ToolResultTextContent>().single.text,
      contains('3145728'),
    );
  });

  test('interrogate_image observes an already aborted signal', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tool = GenerationToolbox(
      _makeRef(container),
    ).tools().firstWhere((t) => t.name == 'interrogate_image');
    final controller = AbortController()..abort();

    expect(
      () => tool.execute('t-interrogate-abort', const {
        'path': 'unused.png',
      }, controller.signal),
      throwsStateError,
    );
  });

  test(
    'queue_image_task rejects an excessive count before allocation',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final tool = GenerationToolbox(
        _makeRef(container),
      ).tools().firstWhere((t) => t.name == 'queue_image_task');
      final result = await tool.execute('t-queue-count', {
        'prompt': '1girl',
        'count': 1000000000,
      });
      final text = result.content
          .whereType<ToolResultTextContent>()
          .map((c) => c.text)
          .join();
      expect(text, contains('50'));
    },
  );

  test('queue_image_task snapshots negative and character prompts', () async {
    final container = ProviderContainer(
      overrides: [
        replicationQueueNotifierProvider.overrideWith(
          _TestReplicationQueueNotifier.new,
        ),
        generationParamsNotifierProvider.overrideWith(
          _TestGenerationParamsNotifier.new,
        ),
        characterPromptNotifierProvider.overrideWith(
          _TestCharacterPromptNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    final tool = GenerationToolbox(
      _makeRef(container),
    ).tools().firstWhere((t) => t.name == 'queue_image_task');

    final result = await tool.execute('t-queue-snapshot', {
      'prompt': '1girl',
      'auto_start': false,
    });

    expect(result.isError, isFalse);
    final task = container.read(replicationQueueNotifierProvider).tasks.single;
    expect(task.negativePrompt, 'page negative');
    expect(task.applyNegativePrompt, isTrue);
    expect(task.characterPrompts, hasLength(1));
    expect(task.characterPrompts!.single.prompt, 'red hair');
    expect(task.characterPrompts!.single.negativePrompt, 'green hair');
  });

  test('get_recent_images honors the requested newest-image limit', () async {
    final history = [
      for (var index = 0; index < 25; index++)
        GeneratedImage(
          id: 'image-$index',
          bytes: Uint8List(0),
          width: 832,
          height: 1216,
          filePath: 'C:/images/image-$index.png',
        ),
      GeneratedImage(
        id: 'unsaved',
        bytes: Uint8List(0),
        width: 832,
        height: 1216,
      ),
    ];
    final container = ProviderContainer(
      overrides: [
        imageGenerationNotifierProvider.overrideWith(
          () => _TestImageGenerationNotifier(history),
        ),
      ],
    );
    addTearDown(container.dispose);
    final tool = GenerationToolbox(
      _makeRef(container),
    ).tools().firstWhere((t) => t.name == 'get_recent_images');

    final properties = tool.parameters['properties'] as Map<String, dynamic>;
    expect(properties['limit'], {
      'type': 'integer',
      'minimum': 1,
      'maximum': GenerationToolbox.maxRecentImageLimit,
      'description': isA<String>(),
    });
    expect(tool.parameters['required'], ['limit']);
    final missingResult = await tool.execute('t-history-missing', const {});
    final requestedResult = await tool.execute('t-history-requested', const {
      'limit': 2,
    });

    expect(missingResult.isError, isTrue);
    expect(
      missingResult.content.whereType<ToolResultTextContent>().single.text,
      contains('required'),
    );
    expect(requestedResult.isError, isFalse);
    expect(requestedResult.details['files'], [
      'C:/images/image-0.png',
      'C:/images/image-1.png',
    ]);
    expect(requestedResult.details['images'], hasLength(2));
  });

  test('get_recent_images rejects invalid limits', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tool = GenerationToolbox(
      _makeRef(container),
    ).tools().firstWhere((t) => t.name == 'get_recent_images');

    for (final limit in [0, 1.5, GenerationToolbox.maxRecentImageLimit + 1]) {
      final result = await tool.execute('t-history-invalid-$limit', {
        'limit': limit,
      });
      expect(result.isError, isTrue, reason: '$limit');
      expect(
        result.content.whereType<ToolResultTextContent>().single.text,
        contains('limit'),
        reason: '$limit',
      );
    }
  });

  test('get_generation_status reports generation and queue sections', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tool = GenerationToolbox(
      _makeRef(container),
    ).tools().firstWhere((t) => t.name == 'get_generation_status');
    final result = await tool.execute('t3', {});
    final text = result.content
        .whereType<ToolResultTextContent>()
        .map((c) => c.text)
        .join();
    expect(text, contains('"generation"'));
    expect(text, contains('"queue"'));
    expect(result.isError, isFalse);
  });

  test('interrogate_image rejects a path outside the workspace', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tool = GenerationToolbox(
      _makeRef(container),
    ).tools().firstWhere((t) => t.name == 'interrogate_image');
    final result = await tool.execute('t4', {'path': 'Z:/no_such.png'});
    final text = result.content
        .whereType<ToolResultTextContent>()
        .map((c) => c.text)
        .join();
    expect(text, contains('not permitted'));
  });
}

class _TestReplicationQueueNotifier extends ReplicationQueueNotifier {
  @override
  ReplicationQueueState build() => const ReplicationQueueState();

  @override
  Future<int> addAll(List<ReplicationTask> tasks) async {
    state = state.copyWith(tasks: [...state.tasks, ...tasks]);
    return tasks.length;
  }
}

class _TestGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() => const ImageParams(negativePrompt: 'page negative');
}

class _TestCharacterPromptNotifier extends CharacterPromptNotifier {
  @override
  CharacterPromptConfig build() => const CharacterPromptConfig(
    characters: [
      CharacterPrompt(
        id: 'character-1',
        name: 'Character',
        prompt: 'red hair',
        negativePrompt: 'green hair',
      ),
    ],
  );
}

class _TestImageGenerationNotifier extends ImageGenerationNotifier {
  _TestImageGenerationNotifier(this.history);

  final List<GeneratedImage> history;

  @override
  ImageGenerationState build() => ImageGenerationState(history: history);
}
