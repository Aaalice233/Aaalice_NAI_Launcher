import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image_lib;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/network/request_builders/nai_image_request_builder.dart';
import 'package:nai_launcher/core/services/anlas_calculator.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/image/image_params.dart'
    show
        ImageGenerationAction,
        ImageParams,
        ImageParamsExtension,
        PreciseReference;
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_generation_snapshot.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/presentation/agent_chat/services/execution_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_preparation_runtime.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/services/queue_toolbox.dart';
import 'package:nai_launcher/data/models/prompt_assistant/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/fixed_tags_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

final _refProvider = Provider<Ref>((ref) => ref);

Ref _makeRef(ProviderContainer container) => container.read(_refProvider);

Map<String, dynamic> _json(AgentToolResult result) =>
    jsonDecode(result.content.whereType<ToolResultTextContent>().single.text)
        as Map<String, dynamic>;

Future<String> _fakeEncodeVibe(
  Uint8List image, {
  required String model,
  double informationExtracted = 1.0,
}) async => 'encoded-vibe';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final toolName in ['submit_generation', 'generate_image']) {
    test(
      '$toolName submits zero-cost preparations once without prompt or confirmation',
      () async {
        final fake = _FakeImageGenerationNotifier();
        final container = ProviderContainer(
          overrides: [
            imageGenerationNotifierProvider.overrideWith(() => fake),
            generationParamsNotifierProvider.overrideWith(
              _TestGenerationParamsNotifier.new,
            ),
            characterPromptNotifierProvider.overrideWith(
              _TestCharacterPromptNotifier.new,
            ),
          ],
        );
        addTearDown(container.dispose);
        final runtime = GenerationPreparationRuntime();
        final prepared = runtime.add(
          GenerationPreparation(
            kind: GenerationPreparationKind.generate,
            baseParams: const ImageParams(prompt: 'test'),
            params: const ImageParams(prompt: 'test'),
            batchSize: 1,
            count: 1,
            autoStart: false,
            estimatedAnlas: 0,
            arguments: const {'prompt': 'test'},
          ),
        );
        expect(prepared.toJson()['confirmation_required'], isFalse);
        final submit = GenerationToolbox(
          _makeRef(container),
          runtime: runtime,
        ).tools().firstWhere((tool) => tool.name == toolName);
        final result = await submit.execute('free', {
          'preparation_id': prepared.id,
        });
        expect(result.isError, isFalse);
        expect(fake.generateCalls, 1);
        final duplicate = await submit.execute('duplicate', {
          'preparation_id': prepared.id,
        });
        expect(duplicate.isError, isTrue);
        expect(fake.generateCalls, 1);
      },
    );
  }

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
        'get_generation_source_image',
        'set_generation_source_image',
        'clear_generation_source_image',
        'update_generation_source_settings',
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
        resourceResolver: _TestResourceResolver(_makeRef(container)),
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
      final positiveAlias = AgentChatResourceReference(
        kind: AgentChatResourceKind.fixedTag,
        source: 'legacy_fixed_tags',
        resourceId: 'positive-alias',
      );
      final positiveCopy = AgentChatResourceReference(
        kind: AgentChatResourceKind.tagLibraryEntry,
        source: 'tag_library',
        resourceId: 'positive-copy',
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
          textByResourceId: const {
            'positive': '{{{masterpiece, best_quality, year_2024}}}',
            'positive-alias': '{{{masterpiece, best_quality, year_2024}}}',
            'positive-copy': '{{{masterpiece, best_quality, year_2024}}}',
            'negative': 'bad anatomy',
          },
          canonicalByResourceId: {'positive-alias': positive},
        ),
      ).tools().firstWhere((candidate) => candidate.name == 'queue_image_task');

      final prepared = await tool.execute('prepare-prompt-refs', {
        'prompt': '1girl, {{{masterpiece, best_quality, year_2024}}}',
        'negative_prompt': 'lowres',
        'prompt_refs': [
          AgentChatResourceReferenceCodec.encodeJsonMap(positive),
          AgentChatResourceReferenceCodec.encodeJsonMap(positiveAlias),
          AgentChatResourceReferenceCodec.encodeJsonMap(positiveCopy),
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
      expect(
        task.prompt,
        '1girl, {{{masterpiece, best_quality, year_2024}}}, '
        '{{{masterpiece, best_quality, year_2024}}}, '
        '{{{masterpiece, best_quality, year_2024}}}',
      );
      expect(task.negativePrompt, 'lowres, bad anatomy');
      final restored = ReplicationTaskGenerationSnapshot.decode(
        task.generationSnapshot!,
      );
      expect(restored.prompt, task.prompt);
      expect(restored.negativePrompt, task.negativePrompt);
    },
  );

  test(
    'enabled fixed-tag references are left to fixed-tag application',
    () async {
      final fixedEntry = FixedTagEntry.create(
        name: 'quality',
        content: 'masterpiece',
      );
      final container = ProviderContainer(
        overrides: [
          fixedTagsNotifierProvider.overrideWith(
            () => _TestFixedTagsNotifier(fixedEntry),
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
      final reference = AgentChatResourceReference(
        kind: AgentChatResourceKind.fixedTag,
        source: 'fixed_tags',
        resourceId: fixedEntry.id,
      );
      final tool =
          GenerationToolbox(
            _makeRef(container),
            resourceResolver: _TestResourceResolver(
              _makeRef(container),
              textByResourceId: {fixedEntry.id: fixedEntry.weightedContent},
            ),
          ).tools().firstWhere(
            (candidate) => candidate.name == 'prepare_generation',
          );

      final prepared = _json(
        await tool.execute('prepare-fixed-ref', {
          'operation': 'generate',
          'prompt': '1girl',
          'prompt_refs': [
            AgentChatResourceReferenceCodec.encodeJsonMap(reference),
          ],
        }),
      );

      expect(prepared['parameters']['prompt'], '1girl');
    },
  );

  test(
    'positionless multi-character preparation stays AI through submission',
    () async {
      final fake = _FakeImageGenerationNotifier();
      final container = ProviderContainer(
        overrides: [
          imageGenerationNotifierProvider.overrideWith(() => fake),
          generationParamsNotifierProvider.overrideWith(
            _TestV5GenerationParamsNotifier.new,
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
      final tools = GenerationToolbox(_makeRef(container)).tools();
      final prepare = tools.firstWhere(
        (tool) => tool.name == 'prepare_generation',
      );
      final submit = tools.firstWhere(
        (tool) => tool.name == 'submit_generation',
      );
      final layoutSchema =
          (prepare.parameters['properties']
                  as Map<String, dynamic>)['character_layout_mode']
              as Map<String, dynamic>;
      expect(layoutSchema.containsKey('default'), isFalse);

      final prepared = _json(
        await prepare.execute('prepare-ai-characters', const {
          'operation': 'generate',
          'prompt': 'two friends',
          'characters': [
            {'prompt': 'hero, black hair'},
            {'prompt': 'companion, blonde hair'},
          ],
        }),
      );
      expect(prepared['parameters']['character_layout_mode'], 'ai_choice');
      expect(
        prepared['parameters']['characters'][0],
        isNot(contains('center')),
      );
      expect(
        prepared['parameters']['characters'][1],
        isNot(contains('center')),
      );

      final submitted = await submit.execute('submit-ai-characters', {
        'preparation_id': prepared['preparation_id'],
        'confirmed': true,
      });
      expect(submitted.isError, isFalse);
      expect(fake.params?.useCoords, isFalse);
      expect(fake.params?.characters, hasLength(2));

      final request = await NAIImageRequestBuilder(
        params: fake.params!,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: Samplers.kEulerAncestral);
      expect(request.requestParameters['use_coords'], isFalse);
      expect(request.requestParameters['v4_prompt']['use_coords'], isFalse);
    },
  );

  test(
    'preparations inherit the character editor under an injected layout mode',
    () async {
      final fake = _FakeImageGenerationNotifier();
      final container = ProviderContainer(
        overrides: [
          imageGenerationNotifierProvider.overrideWith(() => fake),
          generationParamsNotifierProvider.overrideWith(
            _TestV5GenerationParamsNotifier.new,
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
      final tools = GenerationToolbox(
        _makeRef(container),
        runtime: GenerationPreparationRuntime(),
      ).tools();
      final prepare = tools.firstWhere(
        (tool) => tool.name == 'prepare_generation',
      );
      final update = tools.firstWhere(
        (tool) => tool.name == 'update_generation_preparation',
      );

      final prepared = await prepare.execute('prepare-injected-layout', const {
        'operation': 'generate',
        'prompt': '1girl',
        'character_layout_mode': 'ai_choice',
      });
      expect(prepared.isError, isFalse);
      final preparedPayload = _json(prepared);
      final preparedParams =
          preparedPayload['parameters'] as Map<String, dynamic>;
      expect(preparedParams['character_layout_mode'], 'ai_choice');
      expect(preparedParams['character_count'], 1);

      final updated = await update.execute('update-injected-layout', {
        'preparation_id': preparedPayload['preparation_id'],
        'prompt': '1girl, smile',
        'character_layout_mode': 'ai_choice',
      });
      expect(updated.isError, isFalse);
      final updatedParams =
          _json(updated)['parameters'] as Map<String, dynamic>;
      expect(updatedParams['prompt'], '1girl, smile');
      expect(updatedParams['character_count'], 1);

      final custom = await prepare.execute('prepare-custom-layout', const {
        'operation': 'generate',
        'prompt': '1girl',
        'character_layout_mode': 'custom',
      });
      expect(custom.isError, isTrue);
      expect(_json(custom)['code'], 'character_layout_without_characters');

      final invalid = await prepare.execute('prepare-invalid-layout', const {
        'operation': 'generate',
        'prompt': '1girl',
        'character_layout_mode': 'grid',
      });
      expect(invalid.isError, isTrue);
      expect(_json(invalid)['code'], 'invalid_character_layout_mode');
    },
  );

  test(
    'Agent custom characters reach the final request as one immutable scene',
    () async {
      final fake = _FakeImageGenerationNotifier();
      final container = ProviderContainer(
        overrides: [
          imageGenerationNotifierProvider.overrideWith(() => fake),
          generationParamsNotifierProvider.overrideWith(
            _TestV5GenerationParamsNotifier.new,
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
      final tools = GenerationToolbox(_makeRef(container)).tools();
      final prepare = tools.firstWhere(
        (tool) => tool.name == 'prepare_generation',
      );
      final submit = tools.firstWhere(
        (tool) => tool.name == 'submit_generation',
      );

      final prepared = await prepare.execute('prepare-characters', const {
        'operation': 'generate',
        'prompt': 'two friends',
        'character_layout_mode': 'custom',
        'characters': [
          {
            'prompt': 'hero, black hair',
            'negative_prompt': 'red hair',
            'position_x': 0.2,
            'position_y': 0.75,
          },
          {
            'prompt': 'companion, blonde hair',
            'negative_prompt': 'black hair',
            'position': 'E1',
          },
        ],
      });
      expect(prepared.isError, isFalse);
      final payload = _json(prepared);
      final preparedParams = payload['parameters'] as Map<String, dynamic>;
      expect(preparedParams['character_layout_mode'], 'custom');
      expect(preparedParams['character_count'], 2);
      expect(preparedParams['characters'][0]['center'], {'x': 0.2, 'y': 0.75});
      expect(preparedParams['characters'][1]['center'], {'x': 0.9, 'y': 0.1});

      container
          .read(characterPromptNotifierProvider.notifier)
          .clearAllCharacters();
      final submitted = await submit.execute('submit-characters', {
        'preparation_id': payload['preparation_id'],
        'confirmed': true,
      });
      expect(submitted.isError, isFalse);
      expect(fake.preserveCharacterSnapshot, isTrue);
      final params = fake.params!;
      expect(params.useCoords, isTrue);
      expect(params.characters.map((character) => character.prompt), [
        'hero, black hair',
        'companion, blonde hair',
      ]);

      final request = await NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: Samplers.kEulerAncestral);
      final parameters = request.requestParameters;
      expect(parameters['use_coords'], isTrue);
      expect(parameters['v4_prompt']['use_coords'], isTrue);
      expect(parameters['characterPrompts'][0]['center'], {
        'x': 0.2,
        'y': 0.75,
      });
      expect(parameters['characterPrompts'][1]['center'], {'x': 0.9, 'y': 0.1});
      expect(
        parameters['v4_prompt']['caption']['char_captions'][1]['centers'],
        [
          {'x': 0.9, 'y': 0.1},
        ],
      );
      expect(
        parameters['v4_negative_prompt']['caption']['char_captions'][0]['char_caption'],
        'red hair',
      );
    },
  );

  test(
    'prepare lifecycle returns a path that read accepts without translation',
    () async {
      final workspace = await Directory.systemTemp.createTemp(
        'generation-submit-contract-',
      );
      addTearDown(() => workspace.delete(recursive: true));
      final savedFile = File(
        '${workspace.path}${Platform.pathSeparator}dated'
        '${Platform.pathSeparator}actual-name.png',
      );
      await savedFile.create(recursive: true);
      await savedFile.writeAsBytes(
        image_lib.encodePng(image_lib.Image(width: 1, height: 1)),
      );
      final fake = _FakeImageGenerationNotifier(savedFile.path);
      final container = ProviderContainer(
        overrides: [
          imageGenerationNotifierProvider.overrideWith(() => fake),
          imagesPerRequestProvider.overrideWith(_TestImagesPerRequest.new),
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
      final tools = GenerationToolbox(
        _makeRef(container),
        workspaceDir: workspace.path,
      ).tools();
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
      expect(submitted.details['files'], [savedFile.path]);
      final submittedJson = _json(submitted);
      expect(submittedJson['images'], hasLength(1));
      final generated = (submittedJson['images'] as List).single as Map;
      expect(
        generated['path'],
        'dated${Platform.pathSeparator}actual-name.png',
      );
      expect(generated['resource_ref']['resourceId'], 'generated-1');
      expect(generated['path'], isNot(contains('generated-1')));

      final read = ExecutionToolbox(workspace.path).tools().single;
      final readResult = await read.execute('read-generated', {
        'path': generated['path'],
      });
      expect(readResult.isError, isFalse);
      expect(
        readResult.content.whereType<ToolResultImageContent>(),
        hasLength(1),
      );

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
        characterPromptNotifierProvider.overrideWith(
          _TestCharacterPromptNotifier.new,
        ),
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
          characterPromptNotifierProvider.overrideWith(
            _TestCharacterPromptNotifier.new,
          ),
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
    final imageBytes = Uint8List.fromList(
      image_lib.encodePng(image_lib.Image(width: 1, height: 1)),
    );
    final history = [
      for (var index = 0; index < 25; index++)
        GeneratedImage(
          id: 'image-$index',
          bytes: imageBytes,
          width: 832,
          height: 1216,
          filePath: (await File(
            '${workspace.path}/image-$index.png',
          ).writeAsBytes(imageBytes)).path,
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

    final readResult = await ExecutionToolbox(
      workspace.path,
    ).tools().single.execute('read-recent', {'path': images.first['path']});
    expect(readResult.isError, isFalse);
    expect(
      readResult.content.whereType<ToolResultImageContent>(),
      hasLength(1),
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

  test('save_path is rejected before a preparation is stored', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'generation-save-path-',
    );
    addTearDown(() => workspace.delete(recursive: true));
    await File(
      '${workspace.path}${Platform.pathSeparator}taken.png',
    ).writeAsString('user data');
    final container = _savePathContainer();
    addTearDown(container.dispose);
    final prepare = GenerationToolbox(
      _makeRef(container),
      workspaceDir: workspace.path,
    ).tools().firstWhere((tool) => tool.name == 'prepare_generation');

    const rejections = {
      'unsupported_queue_save_path': ('queue', 'out.png'),
      'invalid_save_path': ('generate', 'out.jpg'),
      'save_path_not_permitted': ('generate', '../escaped.png'),
      'save_path_exists': ('generate', 'taken.png'),
    };
    for (final entry in rejections.entries) {
      final result = await prepare.execute('reject-${entry.key}', {
        'operation': entry.value.$1,
        'prompt': '1girl',
        'save_path': entry.value.$2,
      });
      expect(result.isError, isTrue, reason: entry.key);
      expect(_json(result)['code'], entry.key, reason: entry.key);
    }

    final placeholderInDirectory = await prepare.execute('reject-dir', const {
      'operation': 'generate',
      'prompt': '1girl',
      'save_path': 'run-{index}/shot.png',
    });
    expect(_json(placeholderInDirectory)['code'], 'invalid_save_path');
    expect(_json(placeholderInDirectory)['message'], contains('file name'));
  });

  test('a batch save_path needs a placeholder in its file name', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'generation-save-path-batch-',
    );
    addTearDown(() => workspace.delete(recursive: true));
    final container = _savePathContainer(
      overrides: [
        imagesPerRequestProvider.overrideWith(_TestImagesPerRequest.new),
      ],
    );
    addTearDown(container.dispose);
    final prepare = GenerationToolbox(
      _makeRef(container),
      workspaceDir: workspace.path,
    ).tools().firstWhere((tool) => tool.name == 'prepare_generation');

    final rejected = await prepare.execute('batch-reject', const {
      'operation': 'generate',
      'prompt': '1girl',
      'save_path': 'shot.png',
    });
    expect(_json(rejected)['code'], 'invalid_save_path');
    expect(_json(rejected)['message'], contains('{index}'));

    final accepted = await prepare.execute('batch-accept', const {
      'operation': 'generate',
      'prompt': '1girl',
      'save_path': 'shot-{index}.png',
    });
    expect(accepted.isError, isFalse);
    expect(_json(accepted)['batch_size'], 2);
    expect(
      _json(accepted)['save_path'],
      '${workspace.path.replaceAll(r'\', '/')}/shot-{index}.png',
    );
  });

  test('a valid save_path is absolute and an empty update clears it', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'generation-save-path-update-',
    );
    addTearDown(() => workspace.delete(recursive: true));
    final container = _savePathContainer();
    addTearDown(container.dispose);
    final tools = GenerationToolbox(
      _makeRef(container),
      workspaceDir: workspace.path,
    ).tools();
    final prepare = tools.firstWhere(
      (tool) => tool.name == 'prepare_generation',
    );
    final update = tools.firstWhere(
      (tool) => tool.name == 'update_generation_preparation',
    );

    final prepared = _json(
      await prepare.execute('save-path-prepare', const {
        'operation': 'generate',
        'prompt': '1girl',
        'save_path': 'exports/shot.png',
      }),
    );
    expect(
      prepared['save_path'],
      '${workspace.path.replaceAll(r'\', '/')}/exports/shot.png',
    );
    expect(prepared['save_path'], isNot(contains(r'\')));
    // 准备阶段只校验，不得提前建目录。
    expect(
      await Directory(
        '${workspace.path}${Platform.pathSeparator}exports',
      ).exists(),
      isFalse,
    );

    final cleared = _json(
      await update.execute('save-path-clear', {
        'preparation_id': prepared['preparation_id'],
        'save_path': '',
      }),
    );
    expect(cleared['ok'], isTrue);
    expect(cleared.containsKey('save_path'), isFalse);
  });

  test('submitting a prepared save_path writes each finished image', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'generation-save-path-submit-',
    );
    addTearDown(() => workspace.delete(recursive: true));
    final container = _savePathContainer(
      overrides: [
        imageGenerationNotifierProvider.overrideWith(
          _FakeImageGenerationNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    final image = await _submitWithSavePath(container, workspace);

    expect(
      await File(
        '${workspace.path}${Platform.pathSeparator}exports'
        '${Platform.pathSeparator}shot.png',
      ).exists(),
      isTrue,
    );
    expect(
      image['saved_path'],
      '${workspace.path.replaceAll(r'\', '/')}/exports/shot.png',
    );
    expect(image.containsKey('save_error'), isFalse);
  });

  test('a failed save_path write never fails the generation', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'generation-save-path-conflict-',
    );
    addTearDown(() => workspace.delete(recursive: true));
    final container = _savePathContainer(
      overrides: [
        imageGenerationNotifierProvider.overrideWith(
          _FakeImageGenerationNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    final image = await _submitWithSavePath(
      container,
      workspace,
      // 准备之后目标才被占用，提交时只能报错，不能覆盖也不能重生成。
      beforeSubmit: () async => File(
        '${workspace.path}${Platform.pathSeparator}exports'
        '${Platform.pathSeparator}shot.png',
      ).create(recursive: true),
    );

    expect(image['save_error'], {
      'code': 'destination_exists',
      'message': isA<String>(),
    });
    expect(image.containsKey('saved_path'), isFalse);
    expect(image['resource_ref']['resourceId'], 'generated-1');
  });

  test('referencing the gallery original is a per-toolbox decision', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'generation-gallery-original-policy-',
    );
    addTearDown(() => workspace.delete(recursive: true));
    final container = _savePathContainer();
    addTearDown(container.dispose);

    Future<Map<String, dynamic>> prepare({
      required bool referencesGalleryOriginal,
      String operation = 'generate',
      String? savePath,
    }) async => _json(
      await GenerationToolbox(
        _makeRef(container),
        workspaceDir: workspace.path,
        referencesGalleryOriginal: referencesGalleryOriginal,
      ).tools().firstWhere((tool) => tool.name == 'prepare_generation').execute(
        'gallery-original-$operation-$referencesGalleryOriginal-$savePath',
        {
          'operation': operation,
          'prompt': '1girl',
          if (savePath != null) 'save_path': savePath,
        },
      ),
    );

    final chat = await prepare(referencesGalleryOriginal: false);
    expect(chat['ok'], isTrue);
    expect(chat.containsKey('save_path'), isFalse);
    expect(chat.containsKey('save_path_source'), isFalse);

    final external = await prepare(referencesGalleryOriginal: true);
    expect(external.containsKey('save_path'), isFalse);
    expect(external['save_path_source'], 'gallery_original');

    final queued = await prepare(
      referencesGalleryOriginal: true,
      operation: 'queue',
    );
    expect(queued['ok'], isTrue);
    expect(queued.containsKey('save_path'), isFalse);
    expect(queued.containsKey('save_path_source'), isFalse);

    final explicit = await prepare(
      referencesGalleryOriginal: true,
      savePath: 'exports/shot.png',
    );
    expect(
      explicit['save_path'],
      '${workspace.path.replaceAll(r'\', '/')}/exports/shot.png',
    );
    expect(explicit['save_path_source'], 'caller');
  });

  test('a gallery original is reported without a second copy', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'generation-gallery-original-',
    );
    addTearDown(() => workspace.delete(recursive: true));
    final autoSaved = File(
      '${workspace.path}${Platform.pathSeparator}gallery'
      '${Platform.pathSeparator}auto.png',
    );
    await autoSaved.create(recursive: true);
    await autoSaved.writeAsBytes(
      image_lib.encodePng(image_lib.Image(width: 1, height: 1)),
    );
    final container = _savePathContainer(
      overrides: [
        imageGenerationNotifierProvider.overrideWith(
          () => _FakeImageGenerationNotifier(autoSaved.path),
        ),
      ],
    );
    addTearDown(container.dispose);

    final image = await _submitReferencingOriginal(container, workspace);

    expect(image['saved_path'], autoSaved.path.replaceAll(r'\', '/'));
    expect(image['saved_path_source'], 'gallery_original');
    expect(
      await workspace.list(recursive: true).map((entry) => entry.path).toList(),
      [autoSaved.parent.path, autoSaved.path],
    );
  });

  test('a missing gallery original reports original_unavailable', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'generation-gallery-original-missing-',
    );
    addTearDown(() => workspace.delete(recursive: true));
    final missing = '${workspace.path}${Platform.pathSeparator}missing.png';
    final container = _savePathContainer(
      overrides: [
        imageGenerationNotifierProvider.overrideWith(
          () => _FakeImageGenerationNotifier(missing),
        ),
      ],
    );
    addTearDown(container.dispose);

    final image = await _submitReferencingOriginal(container, workspace);

    expect(image['save_error'], {
      'code': 'original_unavailable',
      'message': contains('save_path'),
    });
    expect(image.containsKey('saved_path'), isFalse);
    expect(await workspace.list().isEmpty, isTrue);
  });
}

/// 以引用图库原图的工具箱准备并提交一次生成，返回唯一一张图的模型侧报告。
Future<Map<String, dynamic>> _submitReferencingOriginal(
  ProviderContainer container,
  Directory workspace,
) async {
  final tools = GenerationToolbox(
    _makeRef(container),
    workspaceDir: workspace.path,
    referencesGalleryOriginal: true,
  ).tools();
  final prepared = _json(
    await tools.firstWhere((tool) => tool.name == 'prepare_generation').execute(
      'gallery-original-prepare',
      const {'operation': 'generate', 'prompt': '1girl'},
    ),
  );
  final submitted = await tools
      .firstWhere((tool) => tool.name == 'submit_generation')
      .execute('gallery-original-submit', {
        'preparation_id': prepared['preparation_id'],
        'confirmed': true,
      });
  expect(submitted.isError, isFalse);
  return ((_json(submitted)['images'] as List).single as Map)
      .cast<String, dynamic>();
}

/// 准备一个带 save_path 的生成、提交它，并返回唯一一张图的模型侧报告。
Future<Map<String, dynamic>> _submitWithSavePath(
  ProviderContainer container,
  Directory workspace, {
  Future<void> Function()? beforeSubmit,
}) async {
  final tools = GenerationToolbox(
    _makeRef(container),
    workspaceDir: workspace.path,
  ).tools();
  final prepared = _json(
    await tools.firstWhere((tool) => tool.name == 'prepare_generation').execute(
      'save-path-submit-prepare',
      const {
        'operation': 'generate',
        'prompt': '1girl',
        'save_path': 'exports/shot.png',
      },
    ),
  );
  await beforeSubmit?.call();
  final submitted = await tools
      .firstWhere((tool) => tool.name == 'submit_generation')
      .execute('save-path-submit', {
        'preparation_id': prepared['preparation_id'],
        'confirmed': true,
      });
  expect(submitted.isError, isFalse);
  expect(submitted.content.whereType<ToolResultImageContent>(), hasLength(1));
  return ((_json(submitted)['images'] as List).single as Map)
      .cast<String, dynamic>();
}

ProviderContainer _savePathContainer({List<Override> overrides = const []}) =>
    ProviderContainer(
      overrides: [
        generationParamsNotifierProvider.overrideWith(
          _TestGenerationParamsNotifier.new,
        ),
        characterPromptNotifierProvider.overrideWith(
          _TestCharacterPromptNotifier.new,
        ),
        subscriptionNotifierProvider.overrideWith(
          _TestSubscriptionNotifier.new,
        ),
        ...overrides,
      ],
    );

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

class _TestV5GenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() => const ImageParams(
    model: ImageModels.animeDiffusionV5Curated,
    negativePrompt: 'page negative',
  );
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

  @override
  void clearAllCharacters() {
    state = state.copyWith(characters: const []);
  }
}

class _TestImageGenerationNotifier extends ImageGenerationNotifier {
  _TestImageGenerationNotifier(this.history);

  final List<GeneratedImage> history;

  @override
  ImageGenerationState build() => ImageGenerationState(history: history);
}

class _FakeImageGenerationNotifier extends ImageGenerationNotifier {
  _FakeImageGenerationNotifier([this.savedPath = 'saved.png']);

  final String savedPath;
  int generateCalls = 0;
  int? batchSize;
  ImageParams? params;
  bool? preserveCharacterSnapshot;

  @override
  ImageGenerationState build() => const ImageGenerationState();

  @override
  Future<void> generate(
    ImageParams params, {
    int? batchSizeOverride,
    bool preserveCharacterSnapshot = false,
    GenerationFocusedSnapshot? focusedOverride,
  }) async {
    generateCalls++;
    batchSize = batchSizeOverride;
    this.params = params;
    this.preserveCharacterSnapshot = preserveCharacterSnapshot;
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
          filePath: savedPath,
        ),
      ],
    );
  }
}

class _TestFixedTagsNotifier extends FixedTagsNotifier {
  _TestFixedTagsNotifier(this.entry);

  final FixedTagEntry entry;

  @override
  FixedTagsState build() => FixedTagsState(entries: [entry]);
}

class _TestSubscriptionNotifier extends SubscriptionNotifier {
  @override
  SubscriptionState build() =>
      const SubscriptionState.loaded(UserSubscription(tier: 1, active: true));
}

class _TestResourceResolver extends AgentResourceResolver {
  _TestResourceResolver(
    super.ref, {
    this.textByResourceId = const {},
    this.canonicalByResourceId = const {},
  });

  final Map<String, String> textByResourceId;
  final Map<String, AgentChatResourceReference> canonicalByResourceId;

  @override
  Future<ResolvedAgentResource?> resolve(
    AgentChatResourceReference requested,
  ) async => ResolvedAgentResource(
    reference: canonicalByResourceId[requested.resourceId] ?? requested,
    label: 'source',
    bytes: Uint8List.fromList([1, 2, 3, 4]),
    text: textByResourceId[requested.resourceId],
  );
}
