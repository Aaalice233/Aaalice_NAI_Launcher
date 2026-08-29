import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image_lib;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/core/services/anlas_calculator.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/image/image_params.dart'
    show
        ImageGenerationAction,
        ImageParams,
        ImageParamsExtension,
        PreciseReference;
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_generation_snapshot.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_preparation_runtime.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/services/queue_toolbox.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

final _refProvider = Provider<Ref>((ref) => ref);

Ref _makeRef(ProviderContainer container) => container.read(_refProvider);

Map<String, dynamic> _json(AgentToolResult result) =>
    jsonDecode(result.content.whereType<ToolResultTextContent>().single.text)
        as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registers image generation tools', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tools = GenerationToolbox(_makeRef(container)).tools();
    expect(
      tools.map((t) => t.name),
      containsAll([
        'interrogate_image',
        'prepare_generation',
        'inspect_generation_preparation',
        'update_generation_preparation',
        'cancel_generation_preparation',
        'submit_generation',
        'generate_image',
        'queue_image_task',
        'get_generation_status',
      ]),
    );
  });

  test(
    'image capability follows AgentSettings instead of legacy chat routing',
    () {
      final defaults = PromptAssistantConfigState.defaults();
      final promptAssistant = defaults.copyWith(
        providers: const [
          ProviderConfig(
            id: 'legacy-provider',
            name: 'Legacy',
            baseUrl: 'https://legacy.test',
            allowImageInput: true,
          ),
          ProviderConfig(
            id: 'agent-provider',
            name: 'Agent',
            baseUrl: 'https://agent.test',
            allowImageInput: false,
          ),
        ],
        models: const [
          ModelConfig(
            providerId: 'legacy-provider',
            name: 'legacy-model',
            displayName: 'Legacy',
            forTask: AssistantTaskType.chat,
          ),
          ModelConfig(
            providerId: 'agent-provider',
            name: 'agent-model',
            displayName: 'Agent',
            forTask: AssistantTaskType.chat,
          ),
        ],
        routing: defaults.routing.copyWith(
          chatProviderId: 'legacy-provider',
          chatModel: 'legacy-model',
        ),
      );

      expect(
        GenerationToolbox.agentChatSupportsImage(
          settings: const AgentSettings(
            chat: AgentChatConfig(
              modelReference: AgentModelReference(
                providerId: 'agent-provider',
                model: 'agent-model',
              ),
            ),
          ),
          promptAssistant: promptAssistant,
        ),
        isFalse,
      );
      expect(
        GenerationToolbox.agentChatSupportsImage(
          settings: const AgentSettings(
            chat: AgentChatConfig(
              modelReference: AgentModelReference(
                providerId: 'legacy-provider',
                model: 'legacy-model',
              ),
            ),
          ),
          promptAssistant: promptAssistant.copyWith(routing: defaults.routing),
        ),
        isTrue,
      );
    },
  );

  test('declares strict schemas for generation parameters', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tools = GenerationToolbox(_makeRef(container)).tools();
    final generate = tools.firstWhere((tool) => tool.name == 'generate_image');
    final generateProperties = generate.parameters['properties'] as Map;
    expect(generateProperties['width'], containsPair('type', 'integer'));
    expect(generateProperties['height'], containsPair('type', 'integer'));
    expect(generateProperties['count'], containsPair('type', 'integer'));
    expect(generateProperties['strength'], containsPair('minimum', 0));
    expect(generateProperties['strength'], containsPair('maximum', 0.99));

    final queue = tools.firstWhere((tool) => tool.name == 'queue_image_task');
    final queueProperties = queue.parameters['properties'] as Map;
    expect(queueProperties['count'], containsPair('type', 'integer'));

    final settings = tools.firstWhere(
      (tool) => tool.name == 'update_generation_settings',
    );
    final settingProperties = settings.parameters['properties'] as Map;
    expect(settingProperties['steps'], containsPair('type', 'integer'));
    expect(settingProperties['steps'], containsPair('maximum', 50));
    expect(settingProperties['scale'], containsPair('maximum', 10));
    expect(settingProperties['noise_schedule'], contains('enum'));
    expect(settingProperties['sampler'], contains('enum'));
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
        subscriptionNotifierProvider.overrideWith(
          _TestSubscriptionNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    final tool = GenerationToolbox(
      _makeRef(container),
    ).tools().firstWhere((t) => t.name == 'queue_image_task');

    final prepared = await tool.execute('t-queue-snapshot', {
      'prompt': '1girl',
      'auto_start': false,
    });
    final preparationId = _json(prepared)['preparation_id'] as String;
    expect(container.read(replicationQueueNotifierProvider).tasks, isEmpty);
    final result = await tool.execute('t-queue-snapshot-submit', {
      'prompt': '1girl',
      'preparation_id': preparationId,
      'confirmed': true,
    });

    expect(result.isError, isFalse);
    final task = container.read(replicationQueueNotifierProvider).tasks.single;
    expect(task.negativePrompt, 'page negative');
    expect(task.applyNegativePrompt, isTrue);
    expect(task.characterPrompts, hasLength(1));
    expect(task.characterPrompts!.single.prompt, 'red hair');
    expect(task.characterPrompts!.single.negativePrompt, 'green hair');
  });

  test(
    'queue_image_task persists a structured source reference snapshot',
    () async {
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
          subscriptionNotifierProvider.overrideWith(
            _TestSubscriptionNotifier.new,
          ),
          imagesPerRequestProvider.overrideWith(_TestImagesPerRequest.new),
        ],
      );
      addTearDown(container.dispose);
      final reference = AgentChatResourceReference(
        kind: AgentChatResourceKind.localGalleryImage,
        source: 'local_gallery',
        resourceId: 'source-1',
        display: const {'title': 'source'},
      );
      final toolbox = GenerationToolbox(
        _makeRef(container),
        resourceResolver: _TestResourceResolver(_makeRef(container), reference),
      );
      final tool = toolbox.tools().firstWhere(
        (candidate) => candidate.name == 'queue_image_task',
      );

      final prepared = await tool.execute('prepare-source', {
        'prompt': '1girl',
        'source_ref': AgentChatResourceReferenceCodec.encodeJsonMap(reference),
        'auto_start': false,
      });
      final submitted = await tool.execute('submit-source', {
        'preparation_id': _json(prepared)['preparation_id'],
        'confirmed': true,
      });

      expect(submitted.isError, isFalse);
      final task = container
          .read(replicationQueueNotifierProvider)
          .tasks
          .single;
      final restored = ReplicationTaskGenerationSnapshot.decode(
        task.generationSnapshot!,
      );
      expect(restored.action, ImageGenerationAction.img2img);
      expect(restored.sourceImage, [1, 2, 3, 4]);
    },
  );

  test(
    'queue_image_task persists prompt text resolved during preparation',
    () async {
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
          subscriptionNotifierProvider.overrideWith(
            _TestSubscriptionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      final positive = AgentChatResourceReference(
        kind: AgentChatResourceKind.fixedTag,
        source: 'fixed_tags',
        resourceId: 'positive',
      );
      final negative = AgentChatResourceReference(
        kind: AgentChatResourceKind.tagLibraryEntry,
        source: 'tag_library',
        resourceId: 'negative',
      );
      final tool = GenerationToolbox(
        _makeRef(container),
        resourceResolver: _TestResourceResolver(
          _makeRef(container),
          positive,
          textByResourceId: const {
            'positive': 'blue eyes',
            'negative': 'bad anatomy',
          },
        ),
      ).tools().firstWhere((candidate) => candidate.name == 'queue_image_task');

      final prepared = await tool.execute('prepare-prompt-refs', {
        'prompt': '1girl',
        'negative_prompt': 'lowres',
        'prompt_refs': [
          AgentChatResourceReferenceCodec.encodeJsonMap(positive),
        ],
        'negative_prompt_refs': [
          AgentChatResourceReferenceCodec.encodeJsonMap(negative),
        ],
        'auto_start': false,
      });
      final submitted = await tool.execute('submit-prompt-refs', {
        'preparation_id': _json(prepared)['preparation_id'],
        'confirmed': true,
      });

      expect(submitted.isError, isFalse);
      final task = container
          .read(replicationQueueNotifierProvider)
          .tasks
          .single;
      expect(task.prompt, '1girl, blue eyes');
      expect(task.negativePrompt, 'lowres, bad anatomy');
      final restored = ReplicationTaskGenerationSnapshot.decode(
        task.generationSnapshot!,
      );
      expect(restored.prompt, task.prompt);
      expect(restored.negativePrompt, task.negativePrompt);
    },
  );

  test(
    'prepare lifecycle estimates before fake generation provider is called',
    () async {
      final fake = _FakeImageGenerationNotifier();
      final container = ProviderContainer(
        overrides: [
          imageGenerationNotifierProvider.overrideWith(() => fake),
          imagesPerRequestProvider.overrideWith(_TestImagesPerRequest.new),
          generationParamsNotifierProvider.overrideWith(
            _TestGenerationParamsNotifier.new,
          ),
          subscriptionNotifierProvider.overrideWith(
            _TestSubscriptionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      final tools = GenerationToolbox(_makeRef(container)).tools();
      final prepare = tools.firstWhere(
        (tool) => tool.name == 'prepare_generation',
      );
      final submit = tools.firstWhere(
        (tool) => tool.name == 'submit_generation',
      );

      final prepared = await prepare.execute('prepare', const {
        'operation': 'generate',
        'prompt': '1girl',
        'width': 832,
        'height': 1216,
        'count': 1,
      });
      final payload = _json(prepared);
      final params = container.read(generationParamsNotifierProvider);
      expect(
        payload['estimated_anlas'],
        AnlasCalculator.calculateRequestCost(
          width: 832,
          height: 1216,
          steps: params.steps,
          batchCount: 1,
          batchSize: container.read(imagesPerRequestProvider),
          smea: params.effectiveSmea,
          smeaDyn: params.effectiveSmeaDyn,
          model: params.model,
          subscriptionTier: 0,
        ),
      );
      expect(payload['confirmation_required'], isTrue);
      expect(fake.generateCalls, 0);

      final rejected = await submit.execute('submit-rejected', {
        'preparation_id': payload['preparation_id'],
        'confirmed': false,
      });
      expect(rejected.isError, isTrue);
      expect(fake.generateCalls, 0);

      final confirmedBatchSize = payload['batch_size'] as int;
      container.read(imagesPerRequestProvider.notifier).set(4);
      final submitted = await submit.execute('submit', {
        'preparation_id': payload['preparation_id'],
        'confirmed': true,
      });
      expect(submitted.isError, isFalse);
      expect(fake.generateCalls, 1);
      expect(fake.batchSize, confirmedBatchSize);
      final imageSource = submitted.content
          .whereType<ToolResultImageContent>()
          .single
          .image
          .source;
      expect(imageSource.mimeType, 'image/png');
      expect(imageSource.base64Data, isNotEmpty);
      expect(submitted.details['files'], ['saved.png']);

      final replayed = await submit.execute('submit-replayed', {
        'preparation_id': payload['preparation_id'],
        'confirmed': true,
      });
      expect(replayed.isError, isTrue);
      expect(fake.generateCalls, 1);
    },
  );

  test('update and cancel keep preparation lifecycle structured', () async {
    final container = ProviderContainer(
      overrides: [
        subscriptionNotifierProvider.overrideWith(
          _TestSubscriptionNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    final reference = AgentChatResourceReference(
      kind: AgentChatResourceKind.fixedTag,
      source: 'fixed_tags',
      resourceId: 'blue-hair',
    );
    final tools = GenerationToolbox(
      _makeRef(container),
      resourceResolver: _TestResourceResolver(
        _makeRef(container),
        reference,
        textByResourceId: const {'blue-hair': 'blue hair'},
      ),
    ).tools();
    final prepare = tools.firstWhere((t) => t.name == 'prepare_generation');
    final update = tools.firstWhere(
      (t) => t.name == 'update_generation_preparation',
    );
    final inspect = tools.firstWhere(
      (t) => t.name == 'inspect_generation_preparation',
    );
    final cancel = tools.firstWhere(
      (t) => t.name == 'cancel_generation_preparation',
    );
    final first = _json(
      await prepare.execute('prepare-update', {
        'operation': 'generate',
        'prompt': '1girl',
        'prompt_refs': [
          AgentChatResourceReferenceCodec.encodeJsonMap(reference),
        ],
      }),
    );
    final updated = _json(
      await update.execute('update', {
        'preparation_id': first['preparation_id'],
        'width': 1024,
        'height': 1024,
      }),
    );
    expect(updated['preparation_id'], isNot(first['preparation_id']));
    expect(updated['parameters']['width'], 1024);
    expect(updated['parameters']['prompt'], '1girl, blue hair');
    expect(
      _json(
        await inspect.execute('inspect-old', {
          'preparation_id': first['preparation_id'],
        }),
      )['status'],
      'cancelled',
    );
    expect(
      _json(
        await cancel.execute('cancel', {
          'preparation_id': updated['preparation_id'],
        }),
      )['status'],
      'cancelled',
    );
  });

  test(
    'preparation survives toolbox recreation through shared runtime',
    () async {
      final container = ProviderContainer(
        overrides: [
          subscriptionNotifierProvider.overrideWith(
            _TestSubscriptionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      final runtime = GenerationPreparationRuntime();
      final first = GenerationToolbox(
        _makeRef(container),
        runtime: runtime,
      ).tools().firstWhere((tool) => tool.name == 'prepare_generation');
      final prepared = await first.execute('prepare-runtime', const {
        'operation': 'generate',
        'prompt': '1girl',
      });
      final id = _json(prepared)['preparation_id'] as String;

      final inspect = GenerationToolbox(_makeRef(container), runtime: runtime)
          .tools()
          .firstWhere((tool) => tool.name == 'inspect_generation_preparation');
      expect(
        _json(
          await inspect.execute('inspect-runtime', {'preparation_id': id}),
        )['status'],
        'prepared',
      );
    },
  );

  test('get_recent_images honors the requested newest-image limit', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'generation-history-',
    );
    addTearDown(() => workspace.delete(recursive: true));
    final history = [
      for (var index = 0; index < 25; index++)
        GeneratedImage(
          id: 'image-$index',
          bytes: Uint8List(0),
          width: 832,
          height: 1216,
          filePath: (await File(
            '${workspace.path}/image-$index.png',
          ).writeAsBytes(const [])).path,
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
      workspaceDir: workspace.path,
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
    expect(requestedResult.details['images'], hasLength(2));
    final images = requestedResult.details['images'] as List;
    expect(images.first['resource_ref']['resourceId'], 'image-0');
    expect(images.first['path'], 'image-0.png');
    expect(images.last['resource_ref']['resourceId'], 'image-1');
    expect(images.last['path'], 'image-1.png');
    expect(
      jsonEncode(requestedResult.details),
      isNot(contains(workspace.path)),
    );
  });

  test('get_recent_images rejects invalid limits', () async {
    final container = ProviderContainer(
      overrides: [
        subscriptionNotifierProvider.overrideWith(
          _TestSubscriptionNotifier.new,
        ),
      ],
    );
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

  test(
    'queue preparation estimates the persisted generation snapshot',
    () async {
      final params = ImageParams(
        width: 832,
        height: 1216,
        steps: 28,
        scale: 5.5,
        preciseReferences: [
          PreciseReference(
            image: Uint8List.fromList([1, 2, 3]),
            type: PreciseRefType.character,
          ),
        ],
      );
      final task = ReplicationTask.create(
        prompt: 'snapshot prompt',
        generationSnapshot: ReplicationTaskGenerationSnapshot.encode(params),
      );
      final container = ProviderContainer(
        overrides: [
          replicationQueueNotifierProvider.overrideWith(
            () => _SeededReplicationQueueNotifier(task),
          ),
          subscriptionNotifierProvider.overrideWith(
            _TestSubscriptionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      final prepare = QueueToolbox(_makeRef(container), QueueControlRuntime())
          .tools()
          .firstWhere(
            (tool) => tool.name == 'prepare_generation_queue_execution',
          );

      final result = await prepare.execute('queue-cost', {'action': 'start'});

      expect(result.isError, isFalse);
      expect(
        _json(result)['estimated_anlas'],
        AnlasCalculator.calculate(params),
      );
    },
  );

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

class _SeededReplicationQueueNotifier extends ReplicationQueueNotifier {
  _SeededReplicationQueueNotifier(this.task);

  final ReplicationTask task;

  @override
  ReplicationQueueState build() => ReplicationQueueState(tasks: [task]);
}

class _TestGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() => const ImageParams(negativePrompt: 'page negative');
}

class _TestImagesPerRequest extends ImagesPerRequest {
  @override
  int build() => 2;

  @override
  void set(int value) {
    state = value.clamp(1, 4);
  }
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

class _FakeImageGenerationNotifier extends ImageGenerationNotifier {
  int generateCalls = 0;
  int? batchSize;

  @override
  ImageGenerationState build() => const ImageGenerationState();

  @override
  Future<void> generate(ImageParams params, {int? batchSizeOverride}) async {
    generateCalls++;
    batchSize = batchSizeOverride;
    state = ImageGenerationState(
      status: GenerationStatus.completed,
      currentImages: [
        GeneratedImage(
          id: 'generated-$generateCalls',
          bytes: Uint8List.fromList(
            image_lib.encodePng(image_lib.Image(width: 1, height: 1)),
          ),
          width: 1,
          height: 1,
          filePath: 'saved.png',
        ),
      ],
    );
  }
}

class _TestSubscriptionNotifier extends SubscriptionNotifier {
  @override
  SubscriptionState build() =>
      const SubscriptionState.loaded(UserSubscription(tier: 1, active: true));
}

class _TestResourceResolver extends AgentResourceResolver {
  _TestResourceResolver(
    super.ref,
    this.reference, {
    this.textByResourceId = const {},
  });

  final AgentChatResourceReference reference;
  final Map<String, String> textByResourceId;

  @override
  Future<ResolvedAgentResource?> resolve(
    AgentChatResourceReference requested,
  ) async => ResolvedAgentResource(
    reference: reference,
    label: 'source',
    bytes: Uint8List.fromList([1, 2, 3, 4]),
    text: textByResourceId[requested.resourceId],
  );
}
