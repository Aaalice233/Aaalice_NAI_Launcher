import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/services/anlas_calculator.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_generation_snapshot.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_image_resource.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_preparation_runtime.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/queue_toolbox.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/cost_estimate_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

final _refProvider = Provider<Ref>((ref) => ref);

Map<String, dynamic> _json(AgentToolResult result) =>
    jsonDecode(result.content.whereType<ToolResultTextContent>().first.text)
        as Map<String, dynamic>;

Uint8List _png(int width, int height) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

final _sourceRef = AgentChatResourceReferenceCodec.encodeJsonMap(
  generationImageResourceReference('source'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'enhance derives size, strength and request flags from the source',
    () async {
      final harness = _Harness(source: _png(832, 1216));
      addTearDown(harness.dispose);

      final result = await harness.prepare({
        'operation': 'generate',
        'prompt': '1girl',
        'source_ref': _sourceRef,
        'enhance': {'level': 2, 'scale': '1.5x'},
      });

      expect(result.isError, isFalse, reason: '${_json(result)}');
      final params = harness.prepared(result).params;
      expect((params.width, params.height), (1280, 1856));
      expect(params.strength, 0.4);
      expect(params.noise, 0.0);
      expect(params.action, ImageGenerationAction.img2img);
      expect(params.isEnhanceRequest, isTrue);
      expect(params.upscaledEnhance, isFalse);
      expect(params.shouldApplyEnhancePromptAddition, isTrue);
      expect(_json(result)['parameters']['enhance'], {
        'level': 2,
        'scale': '1.5x',
        'strength': 0.4,
        'noise': 0.0,
        'strength_source': 'level',
      });
    },
  );

  test(
    'max sends the source size and is billed at the upscaled area',
    () async {
      final harness = _Harness(source: _png(832, 1216));
      addTearDown(harness.dispose);

      final result = await harness.prepare({
        'operation': 'generate',
        'prompt': '1girl',
        'source_ref': _sourceRef,
        'enhance': {'level': 3, 'scale': 'max'},
      });

      expect(result.isError, isFalse, reason: '${_json(result)}');
      final prepared = harness.prepared(result);
      final params = prepared.params;
      final billed = E2eUpscale.resolveMaxEnhanceTargetSize(832, 1216);
      expect((params.width, params.height), (832, 1216));
      expect(params.upscaledEnhance, isTrue);
      expect(params.shouldApplyEnhancePromptAddition, isFalse);
      expect(_json(result)['parameters']['enhance']['billed_size'], {
        'width': billed.width,
        'height': billed.height,
      });
      expect(
        prepared.estimatedAnlas,
        AnlasCalculator.calculate(
          params.copyWith(width: billed.width, height: billed.height),
        ),
      );
      expect(
        prepared.estimatedAnlas,
        greaterThan(AnlasCalculator.calculate(params)),
      );
    },
  );

  test(
    'an explicit scale that does not fit lists the available ones',
    () async {
      final harness = _Harness(source: _png(1536, 2048));
      addTearDown(harness.dispose);

      final result = await harness.prepare({
        'operation': 'generate',
        'prompt': '1girl',
        'source_ref': _sourceRef,
        'enhance': {'scale': '2x'},
      });

      expect(result.isError, isTrue);
      expect(_json(result)['code'], 'enhance_scale_unavailable');
      expect(_json(result)['message'], contains('Available: 1x.'));
    },
  );

  test('enhance needs one unmasked source and derives the size', () async {
    final harness = _Harness(source: _png(832, 1216));
    addTearDown(harness.dispose);
    const enhance = {'level': 3, 'scale': '1x'};

    final cases = <String, Map<String, dynamic>>{
      'enhance_requires_source': {'enhance': enhance},
      'enhance_with_mask': {
        'source_ref': _sourceRef,
        'mask_ref': _sourceRef,
        'enhance': enhance,
      },
      'enhance_size_conflict': {
        'source_ref': _sourceRef,
        'width': 1024,
        'enhance': enhance,
      },
      'invalid_enhance': {
        'source_ref': _sourceRef,
        'enhance': {'level': 6},
      },
    };
    for (final MapEntry(key: code, value: args) in cases.entries) {
      final result = await harness.prepare({
        'operation': 'generate',
        'prompt': '1girl',
        ...args,
      });

      expect(_json(result)['code'], code, reason: code);
    }
    final badScale = await harness.prepare({
      'operation': 'generate',
      'prompt': '1girl',
      'source_ref': _sourceRef,
      'enhance': {'scale': '3x'},
    });
    expect(_json(badScale)['code'], 'invalid_enhance');
  });

  test(
    'caller strength replaces the level preset and keeps its noise',
    () async {
      final harness = _Harness(source: _png(832, 1216));
      addTearDown(harness.dispose);

      final result = await harness.prepare({
        'operation': 'generate',
        'prompt': '1girl',
        'source_ref': _sourceRef,
        'strength': 0.66,
        'enhance': {'level': 5, 'scale': '1x'},
      });

      final params = harness.prepared(result).params;
      expect(params.strength, 0.66);
      expect(params.noise, 0.1);
      expect(
        _json(result)['parameters']['enhance']['strength_source'],
        'caller',
      );
    },
  );

  test(
    'omitted level and scale follow the page and updates keep that snapshot',
    () async {
      final harness = _Harness(
        source: _png(832, 1216),
        pageEnhance: const EnhanceWorkflowSettings(
          level: 5,
          upscaleFactor: 2.0,
        ),
      );
      addTearDown(harness.dispose);

      final first = await harness.prepare({
        'operation': 'generate',
        'prompt': '1girl',
        'source_ref': _sourceRef,
        'enhance': <String, dynamic>{},
      });
      final firstParams = harness.prepared(first).params;
      harness.setPageEnhance(const EnhanceWorkflowSettings(level: 1));
      final updated = await harness.update({
        'preparation_id': _json(first)['preparation_id'],
        'prompt': '1girl, smile',
      });

      // 2x 放不下时按生成页同样的规则回落到最大可用档。
      expect((firstParams.width, firstParams.height), (1280, 1856));
      expect(firstParams.strength, 0.7);
      expect(firstParams.noise, 0.1);
      final updatedParams = harness.prepared(updated).params;
      expect(updatedParams.strength, 0.7);
      expect((updatedParams.width, updatedParams.height), (1280, 1856));
    },
  );

  test('a page left in Enhance does not leak into plain requests', () async {
    final harness = _Harness(
      source: _png(832, 1216),
      pageParams: const ImageParams(
        model: ImageModels.animeDiffusionV5Curated,
        isEnhanceRequest: true,
        upscaledEnhance: true,
      ),
    );
    addTearDown(harness.dispose);

    final textToImage = await harness.prepare({
      'operation': 'generate',
      'prompt': '1girl',
    });
    final imageToImage = await harness.prepare({
      'operation': 'generate',
      'prompt': '1girl',
      'source_ref': _sourceRef,
    });

    for (final result in [textToImage, imageToImage]) {
      final params = harness.prepared(result).params;
      expect(params.isEnhanceRequest, isFalse);
      expect(params.upscaledEnhance, isFalse);
      expect(params.shouldApplyEnhancePromptAddition, isFalse);
    }
  });

  test('img2img without a size follows the source import resolution', () async {
    final harness = _Harness(source: _png(832, 1216));
    addTearDown(harness.dispose);

    final inferred = await harness.prepare({
      'operation': 'generate',
      'prompt': '1girl',
      'source_ref': _sourceRef,
    });
    final explicit = await harness.prepare({
      'operation': 'generate',
      'prompt': '1girl',
      'source_ref': _sourceRef,
      'width': 1024,
      'height': 1024,
    });

    final inferredParams = harness.prepared(inferred).params;
    final explicitParams = harness.prepared(explicit).params;
    expect((inferredParams.width, inferredParams.height), (832, 1216));
    expect((explicitParams.width, explicitParams.height), (1024, 1024));
  });

  test('queue preparations accept enhance with a source resource', () async {
    final harness = _Harness(source: _png(832, 1216));
    addTearDown(harness.dispose);

    final result = await harness.prepare({
      'operation': 'queue',
      'prompt': '1girl',
      'source_ref': _sourceRef,
      'enhance': {'level': 3, 'scale': 'max'},
    });

    expect(result.isError, isFalse, reason: '${_json(result)}');
    final params = harness.prepared(result).params;
    expect(params.isEnhanceRequest, isTrue);
    expect(params.upscaledEnhance, isTrue);
  });

  test(
    'queue execution bills a max-enhance snapshot at the upscaled area',
    () async {
      final params = ImageParams(
        model: ImageModels.animeDiffusionV5Curated,
        width: 832,
        height: 1216,
        action: ImageGenerationAction.img2img,
        sourceImage: _png(832, 1216),
        strength: 0.5,
        upscaledEnhance: true,
        isEnhanceRequest: true,
      );
      final task = ReplicationTask.create(
        prompt: '1girl',
        generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
          params,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          replicationQueueNotifierProvider.overrideWith(
            () => _SeededQueue(task),
          ),
          subscriptionNotifierProvider.overrideWith(_TestSubscription.new),
          imagesPerRequestProvider.overrideWith(_SingleImagePerRequest.new),
        ],
      );
      addTearDown(container.dispose);
      final prepare =
          QueueToolbox(
            container.read(_refProvider),
            QueueControlRuntime(),
          ).tools().firstWhere(
            (tool) => tool.name == 'prepare_generation_queue_execution',
          );

      final result = await prepare.execute('queue-max', {'action': 'start'});

      final billed = resolveGenerationBillingSize(
        width: 832,
        height: 1216,
        maxEnhance: true,
      );
      expect(
        _json(result)['estimated_anlas'],
        AnlasCalculator.calculate(
          params.copyWith(width: billed.width, height: billed.height),
        ),
      );
    },
  );
}

final class _Harness {
  _Harness({
    required Uint8List source,
    ImageParams pageParams = const ImageParams(
      model: ImageModels.animeDiffusionV5Curated,
      width: 1024,
      height: 1024,
    ),
    EnhanceWorkflowSettings pageEnhance = const EnhanceWorkflowSettings(),
  }) : _workflow = _StubWorkflowController(
         ImageWorkflowState(enhance: pageEnhance),
       ) {
    container = ProviderContainer(
      overrides: [
        generationParamsNotifierProvider.overrideWith(
          () => _StubGenerationParams(pageParams),
        ),
        imageWorkflowControllerProvider.overrideWith(() => _workflow),
        characterPromptNotifierProvider.overrideWith(_NoCharacters.new),
        subscriptionNotifierProvider.overrideWith(_TestSubscription.new),
        imagesPerRequestProvider.overrideWith(_SingleImagePerRequest.new),
      ],
    );
    final ref = container.read(_refProvider);
    _tools = GenerationToolbox(
      ref,
      runtime: runtime,
      resourceResolver: _BytesResolver(ref, source),
    ).tools();
  }

  final _StubWorkflowController _workflow;
  final runtime = GenerationPreparationRuntime();
  late final ProviderContainer container;
  late final List<AgentTool> _tools;

  Future<AgentToolResult> prepare(Map<String, dynamic> args) => _tools
      .firstWhere((tool) => tool.name == 'prepare_generation')
      .execute('prepare', args);

  Future<AgentToolResult> update(Map<String, dynamic> args) => _tools
      .firstWhere((tool) => tool.name == 'update_generation_preparation')
      .execute('update', args);

  GenerationPreparation prepared(AgentToolResult result) =>
      runtime.get(_json(result)['preparation_id'] as String)!;

  void setPageEnhance(EnhanceWorkflowSettings settings) =>
      _workflow.replace(ImageWorkflowState(enhance: settings));

  void dispose() => container.dispose();
}

final class _BytesResolver extends AgentResourceResolver {
  _BytesResolver(super.ref, this._bytes);

  final Uint8List _bytes;

  @override
  Future<ResolvedAgentResource?> resolve(
    AgentChatResourceReference requested,
  ) async => ResolvedAgentResource(
    reference: requested,
    label: 'source',
    bytes: _bytes,
  );
}

final class _StubGenerationParams extends GenerationParamsNotifier {
  _StubGenerationParams(this._params);

  final ImageParams _params;

  @override
  ImageParams build() => _params;
}

final class _StubWorkflowController extends ImageWorkflowController {
  _StubWorkflowController(this._initial);

  final ImageWorkflowState _initial;

  @override
  ImageWorkflowState build() => _initial;

  void replace(ImageWorkflowState next) => state = next;
}

final class _NoCharacters extends CharacterPromptNotifier {
  @override
  CharacterPromptConfig build() => const CharacterPromptConfig();
}

final class _TestSubscription extends SubscriptionNotifier {
  @override
  SubscriptionState build() =>
      const SubscriptionState.loaded(UserSubscription(tier: 1, active: true));
}

final class _SingleImagePerRequest extends ImagesPerRequest {
  @override
  int build() => 1;
}

final class _SeededQueue extends ReplicationQueueNotifier {
  _SeededQueue(this.task);

  final ReplicationTask task;

  @override
  ReplicationQueueState build() => ReplicationQueueState(tasks: [task]);
}
